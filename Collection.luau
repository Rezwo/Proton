--!strict
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)
local HttpService = game:GetService("HttpService")

local Collection = {}

export type Collection<ItemType> = {
	Signal : Types.Signal<{ [string] : ItemType }>,
	Add : (self : Collection<ItemType>, Data : { [string] : any }) -> string,
	Remove : (self : Collection<ItemType>, Id : string) -> (),
	Patch : (self : Collection<ItemType>, Id : string, Changes : { [string] : any }) -> (),
	Destroy : (self : Collection<ItemType>) -> (),
	GetPage : (self : Collection<ItemType>, PageNumber : number, ItemsPerPage : number) -> { ItemType }
}

local CollectionMetatable = {}
CollectionMetatable.__index = CollectionMetatable

function CollectionMetatable:Add(Data : { [string] : any }) : string
	local NewId : string = HttpService:GenerateGUID(false)
	local CurrentMap : { [string] : any } = self.Signal:Get()

	local ReactiveItem : { [string] : any } = {}
	for Key : string, Value : any in Data do
		ReactiveItem[Key] = State.CreateSignal(Value)
	end

	-- FIX: Create new table reference to trigger reactivity
	local NewMap : { [string] : any } = table.clone(CurrentMap)
	NewMap[NewId] = ReactiveItem
	self.Signal:Set(NewMap)
	
	return NewId
end

function CollectionMetatable:Remove(Id : string)
	local CurrentMap : { [string] : any } = self.Signal:Get()
	if not CurrentMap[Id] then
		return
	end

	-- FIX: Clean up nested signals to prevent memory leak
	local Item : { [string] : any } = CurrentMap[Id]
	for _, Signal : any in Item do
		if Signal.Destroy then
			Signal:Destroy()
		end
	end

	-- Create new table reference to trigger reactivity
	local NewMap : { [string] : any } = table.clone(CurrentMap)
	NewMap[Id] = nil
	self.Signal:Set(NewMap)
end

function CollectionMetatable:Patch(Id : string, Changes : { [string] : any })
	local CurrentMap : { [string] : any } = self.Signal:Get()
	local Item : { [string] : any } = CurrentMap[Id]

	if not Item then
		return
	end

	-- Update nested signals - they will trigger their own dependents
	for Key : string, NewValue : any in Changes do
		if Item[Key] then
			Item[Key]:Set(NewValue)
		else
			Item[Key] = State.CreateSignal(NewValue)
		end
	end
	
	-- FIX: Always trigger collection update for consistency
	-- This ensures observers of the main collection signal get updates
	local NewMap : { [string] : any } = table.clone(CurrentMap)
	self.Signal:Set(NewMap)
end

function CollectionMetatable:Destroy()
	local CurrentMap : { [string] : any } = self.Signal:Get()
	
	-- Clean up all nested signals
	for _, Item : any in CurrentMap do
		for _, Signal : any in Item do
			if Signal.Destroy then
				Signal:Destroy()
			end
		end
	end
	
	self.Signal:Set({})
end

function CollectionMetatable:GetPage(PageNumber : number, ItemsPerPage : number) : { any }
	-- FIX: Bounds checking to prevent invalid indices
	if PageNumber < 1 then
		warn("Proton: PageNumber must be >= 1, defaulting to 1")
		PageNumber = 1
	end
	
	if ItemsPerPage < 1 then
		warn("Proton: ItemsPerPage must be >= 1, defaulting to 10")
		ItemsPerPage = 10
	end
	
	local CurrentMap : { [string] : any } = self.Signal:Get()
	
	local SortedEntries : { {Key: string, Item: any} } = {}
	for Key : string, Item : any in CurrentMap do
		table.insert(SortedEntries, {Key = Key, Item = Item})
	end
	
	table.sort(SortedEntries, function(a, b) : boolean
		return a.Key < b.Key
	end)
	
	local StartIndex : number = ((PageNumber - 1) * ItemsPerPage) + 1
	local EndIndex : number = math.min(StartIndex + ItemsPerPage - 1, #SortedEntries)
	local Page : { any } = {}
	
	-- Handle case where StartIndex exceeds array size
	if StartIndex > #SortedEntries then
		return Page  -- Return empty page
	end
	
	for Index : number = StartIndex, EndIndex do
		table.insert(Page, SortedEntries[Index].Item)
	end
	
	return Page
end

function Collection.CreateCollection<ItemType>(InitialData : { [string] : any }?) : Collection<ItemType>
	local InitialMap : { [string] : any } = {}

	if InitialData then
		for Key : string, Value : any in InitialData do
			local ReactiveItem : { [string] : any } = {}
			for PropKey : string, PropValue : any in Value do
				ReactiveItem[PropKey] = State.CreateSignal(PropValue)
			end
			InitialMap[Key] = ReactiveItem
		end
	end

	local MainSignal : Types.Signal<{ [string] : any }> = State.CreateSignal(InitialMap)

	local Self : any = setmetatable({
		Signal = MainSignal
	}, CollectionMetatable)

	return Self
end

return Collection
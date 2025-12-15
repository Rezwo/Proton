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
		-- FIX: Issue 36 - Strict signal check
		if type(Value) == "table" and type(Value.Get) == "function" and Value._IsSignal then
			ReactiveItem[Key] = Value
		else
			ReactiveItem[Key] = State.CreateSignal(Value)
		end
	end

	local NewMap : { [string] : any } = table.clone(CurrentMap)
	NewMap[NewId] = ReactiveItem
	self.Signal:Set(NewMap)
	
	return NewId
end

function CollectionMetatable:Remove(Id : string)
	local CurrentMap : { [string] : any } = self.Signal:Get()
	if not CurrentMap[Id] then
		warn("Proton: Attempted to remove non-existent ID:", Id)
		return
	end

	local Item : { [string] : any } = CurrentMap[Id]
	for _, Signal : any in Item do
		if type(Signal) == "table" and type(Signal.Destroy) == "function" then
			Signal:Destroy()
		end
	end

	local NewMap : { [string] : any } = table.clone(CurrentMap)
	NewMap[Id] = nil
	self.Signal:Set(NewMap)
end

function CollectionMetatable:Patch(Id : string, Changes : { [string] : any })
	local CurrentMap : { [string] : any } = self.Signal:Get()
	local Item : { [string] : any } = CurrentMap[Id]

	if not Item then
		warn("Proton: Attempted to patch non-existent ID:", Id)
		return
	end

	for Key : string, NewValue : any in Changes do
		-- FIX: Issue 41 - Handle nil values (deletion)
		if NewValue == nil then
			if Item[Key] then
				-- FIX: Issue 46 - Clean up replaced signals
				if type(Item[Key]) == "table" and type(Item[Key].Destroy) == "function" then
					Item[Key]:Destroy()
				end
				Item[Key] = nil
			end
		elseif Item[Key] then
			Item[Key]:Set(NewValue)
		else
			if type(NewValue) == "table" and type(NewValue.Get) == "function" and NewValue._IsSignal then
				Item[Key] = NewValue
			else
				Item[Key] = State.CreateSignal(NewValue)
			end
		end
	end
	
	local NewMap : { [string] : any } = table.clone(CurrentMap)
	self.Signal:Set(NewMap)
end

function CollectionMetatable:Destroy()
	local CurrentMap : { [string] : any } = self.Signal:Get()
	
	for _, Item : any in CurrentMap do
		for _, Signal : any in Item do
			if type(Signal) == "table" and type(Signal.Destroy) == "function" then
				Signal:Destroy()
			end
		end
	end
	
	self.Signal:Set({})
end

function CollectionMetatable:GetPage(PageNumber : number, ItemsPerPage : number) : { any }
	if PageNumber < 1 then PageNumber = 1 end
	if ItemsPerPage < 1 then ItemsPerPage = 10 end
	
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
	
	if StartIndex > #SortedEntries then
		return Page
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
				if type(PropValue) == "table" and type(PropValue.Get) == "function" and PropValue._IsSignal then
					ReactiveItem[PropKey] = PropValue
				else
					ReactiveItem[PropKey] = State.CreateSignal(PropValue)
				end
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
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

	for Key : string, NewValue : any in Changes do
		if Item[Key] then
			Item[Key]:Set(NewValue)
		else
			Item[Key] = State.CreateSignal(NewValue)
		end
	end
end

function CollectionMetatable:Destroy()
	self.Signal:Set({})
end

function CollectionMetatable:GetPage(PageNumber : number, ItemsPerPage : number) : { any }
	local CurrentMap : { [string] : any } = self.Signal:Get()
	local List : { any } = {}
	
	for _, Item : any in CurrentMap do
		table.insert(List, Item)
	end
	
	local StartIndex : number = ((PageNumber - 1) * ItemsPerPage) + 1
	local EndIndex : number = StartIndex + ItemsPerPage - 1
	local Page : { any } = {}
	
	for Index : number = StartIndex, math.min(EndIndex, #List) do
		table.insert(Page, List[Index])
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
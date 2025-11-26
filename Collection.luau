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
}

local CollectionMetatable = {}
CollectionMetatable.__index = CollectionMetatable

function CollectionMetatable:Add(Data : { [string] : any }) : string
	local NewId : string = HttpService:GenerateGUID(false)
	local CurrentMap = self.Signal:Get()

	local ReactiveItem = {}
	for Key, Value in Data do
		ReactiveItem[Key] = State.CreateSignal(Value)
	end

	local NewMap = table.clone(CurrentMap)
	NewMap[NewId] = ReactiveItem

	self.Signal:Set(NewMap)
	return NewId
end

function CollectionMetatable:Remove(Id : string)
	local CurrentMap = self.Signal:Get()
	if not CurrentMap[Id] then return end

	local NewMap = table.clone(CurrentMap)
	NewMap[Id] = nil

	self.Signal:Set(NewMap)
end

function CollectionMetatable:Patch(Id : string, Changes : { [string] : any })
	local CurrentMap = self.Signal:Get()
	local Item = CurrentMap[Id]

	if not Item then return end

	for Key, NewValue in Changes do
		if Item[Key] then
			Item[Key]:Set(NewValue)
		else
			Item[Key] = State.CreateSignal(NewValue)
		end
	end
end

function Collection.CreateCollection<ItemType>(InitialData : { [string] : any }?) : Collection<ItemType>
	local InitialMap = {}

	if InitialData then
		for Key, Value in InitialData do
			local ReactiveItem = {}
			for PropKey, PropValue in Value do
				ReactiveItem[PropKey] = State.CreateSignal(PropValue)
			end
			InitialMap[Key] = ReactiveItem
		end
	end

	local MainSignal = State.CreateSignal(InitialMap :: { [string] : ItemType })

	local Self = setmetatable({
		Signal = MainSignal
	}, CollectionMetatable)

	return Self :: any
end

return Collection
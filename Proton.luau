--!strict
local State = require(script.State)
local Spring = require(script.Spring)
local Builder = require(script.Builder)
local List = require(script.List)
local Collection = require(script.Collection)
local Types = require(script.Types)

export type Signal<ValueType> = Types.Signal<ValueType>
export type ReadOnly<ValueType> = Types.ReadOnly<ValueType>
export type Reactive<ValueType> = Types.Reactive<ValueType>
export type Collection<ItemType> = Collection.Collection<ItemType>

return {
	CreateSignal = State.CreateSignal,
	CreateDerived = State.CreateDerived,
	CreateEffect = State.CreateEffect,
	CreateSpring = Spring.CreateSpring,
	For = List.For,
	CreateCollection = Collection.CreateCollection,
	New = Builder.New
}
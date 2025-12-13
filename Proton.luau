--!strict
local State = require(script.State)
local Spring = require(script.Spring)
local Builder = require(script.Builder)
local List = require(script.List)
local Collection = require(script.Collection)
local Types = require(script.Types)
local Engine = require(script.Engine)

export type Signal<ValueType> = Types.Signal<ValueType>
export type ReadOnly<ValueType> = Types.ReadOnly<ValueType>
export type Reactive<ValueType> = Types.Reactive<ValueType>
export type Collection<ItemType> = Collection.Collection<ItemType>

return {
	-- Core State
	CreateSignal = State.CreateSignal,
	CreateDerived = State.CreateDerived,
	CreateEffect = State.CreateEffect,
	Batch = State.Batch,
	
	-- Animation
	CreateSpring = Spring.CreateSpring,
	
	-- UI
	For = List.For,
	New = Builder.New,
	
	-- Data
	CreateCollection = Collection.CreateCollection,
	
	-- Diagnostics
	GetStats = Engine.GetStats
}
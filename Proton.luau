--!strict
local State = require(script.State)
local Spring = require(script.Spring)
local Builder = require(script.Builder)
local List = require(script.List)
local Collection = require(script.Collection)
local Scope = require(script.Scope)
local Types = require(script.Types)
local Engine = require(script.Engine)

export type Signal<ValueType> = Types.Signal<ValueType>
export type ReadOnly<ValueType> = Types.ReadOnly<ValueType>
export type Reactive<ValueType> = Types.Reactive<ValueType>
export type Collection<ItemType> = Collection.Collection<ItemType>
export type Scope = Scope.Scope

return {
	-- Core State (Manual Cleanup Required)
	CreateSignal = State.CreateSignal,
	CreateDerived = State.CreateDerived,
	CreateEffect = State.CreateEffect,
	Batch = State.Batch,
	
	-- Animation (Manual Cleanup Required)
	CreateSpring = Spring.CreateSpring,
	
	-- UI
	For = List.For,
	New = Builder.New,
	
	-- Data (Manual Cleanup Required)
	CreateCollection = Collection.CreateCollection,
	
	-- Automatic Cleanup System (Recommended)
	CreateScope = Scope.CreateScope,
	GetActiveScope = Scope.GetActiveScope,
	WithScope = Scope.WithScope,
	
	-- Diagnostics
	GetStats = Engine.GetStats
}
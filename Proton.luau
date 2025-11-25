--!strict
local State = require(script.State)
local Spring = require(script.Spring)
local Builder = require(script.Builder)
local Types = require(script.Types)

export type Signal<T> = Types.Signal<T>
export type ReadOnly<T> = Types.ReadOnly<T>
export type Reactive<T> = Types.Reactive<T>

return {
	CreateSignal = State.CreateSignal,
	CreateDerived = State.CreateDerived,
	CreateEffect = State.CreateEffect,
	CreateSpring = Spring.CreateSpring,
	New = Builder.New,
}
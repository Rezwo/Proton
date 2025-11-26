--!strict
local Types = require(script.Parent.Types)
local Engine = require(script.Parent.Engine)

local State = {}

local SignalMetatable = {}
SignalMetatable.__index = SignalMetatable

function SignalMetatable:Get() : any
	Engine.Track(self)
	return self.Value
end

function SignalMetatable:Set(NewValue : any)
	if self.Value ~= NewValue then
		self.Value = NewValue
		Engine.Trigger(self)
	end
end

local ReadOnlyMetatable = {}
ReadOnlyMetatable.__index = ReadOnlyMetatable

function ReadOnlyMetatable:Get() : any
	Engine.Track(self)
	return self.Value
end

function State.CreateSignal<ValueType>(InitialValue : ValueType) : Types.Signal<ValueType>
	local Internal = {
		Value = InitialValue,
		Dependents = {} :: { [Types.Dependency] : boolean },
	}

	return setmetatable(Internal, SignalMetatable) :: any
end

function State.CreateEffect(Callback : () -> (Types.Destructor?)) : () -> ()
	local EffectNode : Types.Dependency = {
		Cleanups = {},
		Dependencies = {},
		Rerun = function(self : Types.Dependency) end,
	}

	EffectNode.Rerun = function(self : Types.Dependency)
		Engine.Cleanup(self)
		Engine.PushEffect(self)

		local CleanupFunction : Types.Destructor? = Callback()
		if CleanupFunction then
			table.insert(self.Cleanups, CleanupFunction)
		end

		Engine.PopEffect()
	end

	-- Run immediately
	EffectNode:Rerun()

	return function()
		Engine.Cleanup(EffectNode)
	end
end

function State.CreateDerived<ValueType>(Processor : () -> ValueType) : Types.ReadOnly<ValueType>
	local InternalSignal = {
		Value = nil :: any,
		Dependents = {} :: { [Types.Dependency] : boolean },
	}

	setmetatable(InternalSignal, ReadOnlyMetatable)

	State.CreateEffect(function()
		local Result : ValueType = Processor()
		if InternalSignal.Value ~= Result then
			InternalSignal.Value = Result
			Engine.Trigger(InternalSignal)
		end
		return nil
	end)

	return InternalSignal :: any
end

return State
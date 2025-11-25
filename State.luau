--!strict
local Types = require(script.Parent.Types)
local Engine = require(script.Parent.Engine)

local State = {}

function State.CreateSignal<T>(InitialValue : T) : Types.Signal<T>
	local Internal = {
		_Value = InitialValue,
		_Dependents = {} :: { [Types.Dependency] : boolean },
	}

	return {
		Get = function(self : Types.ReadOnly<T>) : T
			Engine.Track(Internal)
			return Internal._Value
		end,

		Set = function(self : Types.Signal<T>, NewValue : T)
			if Internal._Value ~= NewValue then
				Internal._Value = NewValue
				Engine.Trigger(Internal)
			end
		end,
	}
end

function State.CreateEffect(Callback : () -> (Types.Destructor?)) : () -> ()
	local EffectNode : Types.Dependency = {
		_Cleanups = {},
		_Dependencies = {},
		Rerun = function(self : Types.Dependency) end,
	}

	EffectNode.Rerun = function(self : Types.Dependency)
		Engine.Cleanup(self)
		Engine.PushEffect(self)

		local CleanupFunction : Types.Destructor? = Callback()
		if CleanupFunction then
			table.insert(self._Cleanups, CleanupFunction)
		end

		Engine.PopEffect()
	end

	EffectNode:Rerun()

	return function()
		Engine.Cleanup(EffectNode)
	end
end

function State.CreateDerived<T>(Processor : () -> T) : Types.ReadOnly<T>
	local InternalSignal = State.CreateSignal(nil :: any)

	State.CreateEffect(function()
		local Result : T = Processor()
		InternalSignal:Set(Result)
		return nil
	end)

	return {
		Get = function(self : Types.ReadOnly<T>) : T
			return InternalSignal:Get()
		end
	}
end

return State
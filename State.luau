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

function SignalMetatable:Destroy()
	self.Dependents = {}
	self.Value = nil
end

local ReadOnlyMetatable = {}
ReadOnlyMetatable.__index = ReadOnlyMetatable

function ReadOnlyMetatable:Get() : any
	Engine.Track(self)
	return self.Value
end

function ReadOnlyMetatable:__newindex(Key : any, Value : any)
	error("Proton: Cannot write to ReadOnly signal")
end

function State.CreateSignal<ValueType>(InitialValue : ValueType) : Types.Signal<ValueType>
	local Internal : any = {
		Value = InitialValue,
		Dependents = {}
	}
	return setmetatable(Internal, SignalMetatable)
end

function State.CreateEffect(Callback : () -> Types.Destructor?, Priority : number?, Label : string?) : () -> ()
	local EffectNode : Types.Dependency = Engine.CreateNode(Priority, Label)

	EffectNode.Rerun = function(self : Types.Dependency)
		Engine.Cleanup(self)
		Engine.PushEffect(self)
		
		local IsSuccess : boolean, Result : any = xpcall(Callback, debug.traceback)
		
		Engine.PopEffect()
		
		if IsSuccess then
			if Result and type(Result) == "function" then
				table.insert(self.Cleanups, Result)
			end
		else
			error(Result)
		end
	end

	EffectNode:Rerun()

	return function()
		Engine.Cleanup(EffectNode)
	end
end

function State.CreateDerived<ValueType>(Processor : () -> ValueType) : Types.ReadOnly<ValueType>
	local InternalSignal : any = {
		Value = nil,
		Dependents = {}
	}
	
	local Disconnect : () -> () = State.CreateEffect(function()
		local Result : ValueType = Processor()
		if InternalSignal.Value ~= Result then
			InternalSignal.Value = Result
			Engine.Trigger(InternalSignal)
		end
		return nil
	end)

	InternalSignal.Destroy = function()
		Disconnect()
		InternalSignal.Dependents = {}
		InternalSignal.Value = nil
	end

	setmetatable(InternalSignal, ReadOnlyMetatable)
	return InternalSignal
end

function State.Batch(Callback : () -> ())
	Engine.Batch(Callback)
end

return State
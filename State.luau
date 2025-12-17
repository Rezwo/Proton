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
	table.clear(self.Dependents)
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
		Dependents = {},
		_IsSignal = true
	}
	return setmetatable(Internal, SignalMetatable)
end

function State.CreateEffect(Callback : () -> Types.Destructor?, Priority : number?, Label : string?) : () -> ()
	local EffectNode : Types.Dependency = Engine.CreateNode(Priority, Label)
	local FailureCount : number = 0
	local MaxFailures : number = 10

	EffectNode.Rerun = function(self : Types.Dependency)
		if FailureCount >= MaxFailures then
			return
		end

		Engine.Cleanup(self)
		Engine.PushEffect(self)
		
		local IsSuccess : boolean, Result : any = xpcall(Callback, debug.traceback)
		
		Engine.PopEffect()
		
		if IsSuccess then
			FailureCount = 0
			if Result and type(Result) == "function" then
				table.insert(self.Cleanups, Result)
			end
		else
			FailureCount += 1
			warn(string.format("Proton: Effect error (%d/%d): %s", FailureCount, MaxFailures, tostring(Result)))
			
			if FailureCount >= MaxFailures then
				warn("Proton: Effect disabled due to persistent errors")
				Engine.Cleanup(self)
			end
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
		Dependents = {},
		_IsSignal = true,
		_IsDerived = true
	}
	
	-- FIX: Compute initial value synchronously
	-- This prevents returning a signal with nil value that only gets populated later
	local IsSuccess : boolean, InitialResult : any = pcall(Processor)
	if IsSuccess then
		InternalSignal.Value = InitialResult
	else
		warn("Proton: Derived initial value error:", InitialResult)
	end
	
	-- Create effect to track dependencies and update value
	local Disconnect : () -> () = State.CreateEffect(function()
		local IsSuccess : boolean, Result : any = pcall(Processor)
		if IsSuccess then
			if InternalSignal.Value ~= Result then
				InternalSignal.Value = Result
				Engine.Trigger(InternalSignal)
			end
		else
			warn("Proton: Derived processor error:", Result)
		end
		return nil
	end)

	-- FIX: Store disconnect function for proper cleanup
	-- This ensures the effect can be cleaned up when signal is destroyed
	InternalSignal._Disconnect = Disconnect

	InternalSignal.Destroy = function()
		-- Clean up the internal effect
		if InternalSignal._Disconnect then
			InternalSignal._Disconnect()
			InternalSignal._Disconnect = nil
		end
		
		-- Clear dependents and value
		table.clear(InternalSignal.Dependents)
		InternalSignal.Value = nil
	end

	setmetatable(InternalSignal, ReadOnlyMetatable)
	return InternalSignal
end

function State.Batch(Callback : () -> ())
	Engine.Batch(Callback)
end

return State
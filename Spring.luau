--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)

local Spring = {}

type SpringData = {
	TargetSignal : Types.SignalLike<number>,
	InternalSignal : Types.Signal<number>,
	CurrentValue : number,
	Velocity : number,
	Speed : number,
	Damping : number,
	IsPaused : boolean,
}

local SpringObjectMetatable = {}
SpringObjectMetatable.__index = SpringObjectMetatable

function SpringObjectMetatable:Get() : number
	return self._InternalSignal:Get()
end

function SpringObjectMetatable:SetPosition(Value : number)
	local Data : SpringData? = self._Data
	if Data then
		Data.CurrentValue = Value
		Data.Velocity = 0
		Data.InternalSignal:Set(Value)
	end
end

function SpringObjectMetatable:SetVelocity(Velocity : number)
	local Data : SpringData? = self._Data
	if Data then
		Data.Velocity = Velocity
	end
end

function SpringObjectMetatable:Impulse(Force : number)
	local Data : SpringData? = self._Data
	if Data then
		Data.Velocity += Force
	end
end

function SpringObjectMetatable:Pause()
	local Data : SpringData? = self._Data
	if Data then
		Data.IsPaused = true
	end
end

function SpringObjectMetatable:Resume()
	local Data : SpringData? = self._Data
	if Data then
		Data.IsPaused = false
	end
end

function SpringObjectMetatable:Destroy()
	local Data : SpringData? = self._Data
	if Data then
		-- Explicit cleanup
		ActiveSprings[self] = nil
		Data.InternalSignal:Destroy()
		self._Data = nil
	end
end

-- Weak keys allow the spring object to be collected if user loses reference,
-- effectively "pausing" it until it is garbage collected.
local ActiveSprings : { [any] : SpringData } = setmetatable({}, {__mode = "k"})
local HeartbeatConnection : RBXScriptConnection? = nil

local function UpdateSprings(DeltaTime : number)
	local Count : number = 0
	
	for SpringObject : any, Data : SpringData in ActiveSprings do
		Count += 1
		
		if Data.IsPaused then
			continue
		end

		-- Safety: Check if target signal still exists
		local Success : boolean, Goal : any = pcall(function()
			return Data.TargetSignal:Get()
		end)
		
		if not Success then
			-- Target signal was destroyed, stop tracking this spring
			ActiveSprings[SpringObject] = nil
			continue
		end
		
		local Displacement : number = Goal - Data.CurrentValue
		local Force : number = Displacement * Data.Speed
		local NewVelocity : number = (Data.Velocity + Force * DeltaTime) * Data.Damping
		local NewValue : number = Data.CurrentValue + NewVelocity * DeltaTime
		
		-- Dynamic convergence threshold relative to the goal size, with a minimum floor
		local Epsilon = math.max(0.001, math.abs(Goal * 0.0001))
		
		if math.abs(Goal - NewValue) < Epsilon and math.abs(NewVelocity) < Epsilon then
			NewValue = Goal
			NewVelocity = 0
		end
		
		-- Only set if changed to avoid unnecessary dependency triggers
		if NewValue ~= Data.CurrentValue or NewVelocity ~= Data.Velocity then
			Data.Velocity = NewVelocity
			Data.CurrentValue = NewValue
			Data.InternalSignal:Set(NewValue)
		end
	end
	
	-- Cleanup connection if no springs are left
	if Count == 0 and HeartbeatConnection then
		HeartbeatConnection:Disconnect()
		HeartbeatConnection = nil
	end
end

function Spring.CreateSpring(TargetSignal : Types.Reactive<number>, Speed : number?, Damping : number?) : any
	local SafeTarget : Types.SignalLike<number> = TargetSignal
	local InitialValue : number = SafeTarget:Get()
	local InternalSignal : Types.Signal<number> = State.CreateSignal(InitialValue)
	
	local SpringData : SpringData = {
		TargetSignal = SafeTarget,
		InternalSignal = InternalSignal,
		CurrentValue = InitialValue,
		Velocity = 0,
		Speed = math.clamp(Speed or 10, 0.1, 1000),
		Damping = math.clamp(Damping or 0.8, 0, 0.99),
		IsPaused = false,
	}

	local SpringObject : any = setmetatable({
		_InternalSignal = InternalSignal,
		_Data = SpringData
	}, SpringObjectMetatable)

	ActiveSprings[SpringObject] = SpringData
	
	if not HeartbeatConnection then
		HeartbeatConnection = RunService.Heartbeat:Connect(UpdateSprings)
	end

	return SpringObject
end

return Spring
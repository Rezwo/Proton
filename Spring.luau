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
	IsPaused : boolean
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

local ActiveSprings : { [any] : SpringData } = {}
local HeartbeatConnection : RBXScriptConnection? = nil

local function UpdateSprings(DeltaTime : number)
	local IsActive : boolean = false
	
	for _, Data : SpringData in ActiveSprings do
		if Data.IsPaused then
			IsActive = true
			continue
		end

		IsActive = true
		local Goal : number = Data.TargetSignal:Get()
		
		local Displacement : number = Goal - Data.CurrentValue
		local Force : number = Displacement * Data.Speed
		local NewVelocity : number = (Data.Velocity + Force * DeltaTime) * Data.Damping
		local NewValue : number = Data.CurrentValue + NewVelocity * DeltaTime
		
		if math.abs(Goal - NewValue) < 0.005 and math.abs(NewVelocity) < 0.005 then
			NewValue = Goal
			NewVelocity = 0
		end
		
		Data.Velocity = NewVelocity
		Data.CurrentValue = NewValue
		Data.InternalSignal:Set(NewValue)
	end
	
	if not IsActive and HeartbeatConnection then
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
		IsPaused = false
	}

	local SpringObject : any = setmetatable({
		_InternalSignal = InternalSignal,
		_Data = SpringData
	}, SpringObjectMetatable)

	ActiveSprings[SpringObject] = SpringData
	if not HeartbeatConnection then
		HeartbeatConnection = RunService.Heartbeat:Connect(UpdateSprings)
	end
	
	State.CreateEffect(function()
		local _ : number = SafeTarget:Get()
		if not ActiveSprings[SpringObject] then
			ActiveSprings[SpringObject] = SpringData
			if not HeartbeatConnection then
				HeartbeatConnection = RunService.Heartbeat:Connect(UpdateSprings)
			end
		end
		return nil
	end)

	return SpringObject
end

return Spring
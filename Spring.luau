--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)

local Spring = {}
local MathAbs = math.abs

type SpringData = {
	TargetSignal : Types.SignalLike<number>,
	InternalSignal : Types.Signal<number>,
	CurrentValue : number,
	Velocity : number,
	Speed : number,
	Damping : number
}

local SpringObjectMetatable = {}
SpringObjectMetatable.__index = SpringObjectMetatable

function SpringObjectMetatable:Get() : number
	return self._InternalSignal:Get()
end

local ActiveSprings : { [any] : SpringData } = {}
local HeartbeatConnection : RBXScriptConnection? = nil

local function UpdateSprings(DeltaTime : number)
	if not next(ActiveSprings) then
		if HeartbeatConnection then
			HeartbeatConnection:Disconnect()
			HeartbeatConnection = nil
		end
		return
	end

	for SpringObject, Data in ActiveSprings do
		local Goal : number = Data.TargetSignal:Get()

		if Data.CurrentValue == Goal and Data.Velocity == 0 then
			continue
		end

		local Displacement : number = Goal - Data.CurrentValue
		local Force : number = Displacement * Data.Speed

		local Velocity : number = (Data.Velocity + Force * DeltaTime) * Data.Damping
		local CurrentValue : number = Data.CurrentValue + Velocity * DeltaTime

		if MathAbs(Goal - CurrentValue) < 0.001 and MathAbs(Velocity) < 0.001 then
			Velocity = 0
			CurrentValue = Goal
		end

		Data.Velocity = Velocity
		Data.CurrentValue = CurrentValue
		Data.InternalSignal:Set(CurrentValue)
	end
end

function Spring.CreateSpring(TargetSignal : Types.Reactive<number>, Speed : number?, Damping : number?) : Types.ReadOnly<number>
	local SafeTarget = TargetSignal :: Types.SignalLike<number>
	local InitialValue : number = SafeTarget:Get()
	local InternalSignal = State.CreateSignal(InitialValue)

	local SpringObject = setmetatable({
		_InternalSignal = InternalSignal
	}, SpringObjectMetatable)

	local SpringData : SpringData = {
		TargetSignal = SafeTarget,
		InternalSignal = InternalSignal,
		CurrentValue = InitialValue,
		Velocity = 0,
		Speed = Speed or 10,
		Damping = Damping or 0.8
	}

	ActiveSprings[SpringObject] = SpringData

	if not HeartbeatConnection then
		HeartbeatConnection = RunService.Heartbeat:Connect(UpdateSprings)
	end

	State.CreateEffect(function()
		local _ = SafeTarget:Get()
		if not ActiveSprings[SpringObject] then
			ActiveSprings[SpringObject] = SpringData
			if not HeartbeatConnection then
				HeartbeatConnection = RunService.Heartbeat:Connect(UpdateSprings)
			end
		end
		return nil
	end)

	return SpringObject :: any
end

return Spring
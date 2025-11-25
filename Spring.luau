--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)

local Spring = {}

type SpringData = {
	TargetSignal: Types.SignalLike<number>,
	InternalSignal: Types.Signal<number>,
	CurrentValue: number,
	Velocity: number,
	Speed: number,
	Damping: number
}

local ActiveSprings: { [any]: SpringData } = {}
local Connection : RBXScriptConnection? = nil

local function UpdateSprings(DeltaTime : number)
	if not next(ActiveSprings) then
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end
		return
	end

	for Spring, Data in ActiveSprings do
		local Goal : number = Data.TargetSignal:Get()
		local CurrentValue : number = Data.CurrentValue
		local Velocity : number = Data.Velocity
		local Speed : number = Data.Speed
		local Damping : number = Data.Damping

		local Displacement : number = Goal - CurrentValue
		local Force : number = Displacement * Speed

		Velocity = (Velocity + Force * DeltaTime) * Damping
		CurrentValue = CurrentValue + Velocity * DeltaTime

		Data.Velocity = Velocity
		Data.CurrentValue = CurrentValue
		Data.InternalSignal:Set(CurrentValue)

		if math.abs(Displacement) < 0.01 and math.abs(Velocity) < 0.01 then
			Data.CurrentValue = Goal
			Data.InternalSignal:Set(Goal)
			ActiveSprings[Spring] = nil
		end
	end
end

function Spring.CreateSpring(TargetSignal : Types.Reactive<number>, Speed : number?, Damping : number?) : Types.ReadOnly<number>
	local SafeTarget = TargetSignal :: Types.SignalLike<number>

	local InitialValue : number = SafeTarget:Get()
	local InternalSignal = State.CreateSignal(InitialValue)

	local SpringObject = {
		Get = function() return InternalSignal:Get() end
	}

	local SpringData : SpringData = {
		TargetSignal = SafeTarget,
		InternalSignal = InternalSignal,
		CurrentValue = InitialValue,
		Velocity = 0,
		Speed = Speed or 10,
		Damping = Damping or 0.8
	}

	ActiveSprings[SpringObject] = SpringData

	if not Connection then
		Connection = RunService.Heartbeat:Connect(UpdateSprings)
	end

	State.CreateEffect(function()
		local _ = SafeTarget:Get()

		if not ActiveSprings[SpringObject] then
			ActiveSprings[SpringObject] = SpringData
			if not Connection then
				Connection = RunService.Heartbeat:Connect(UpdateSprings)
			end
		end
		return nil
	end)

	return SpringObject
end

return Spring
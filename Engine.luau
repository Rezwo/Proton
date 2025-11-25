--!strict
local Types = require(script.Parent.Types)
type Dependency = Types.Dependency

local Engine = {}
local EffectStack : { Dependency } = {}

function Engine.Cleanup(Node : Dependency)
	for _, Cleanup in Node._Cleanups do
		Cleanup()
	end
	table.clear(Node._Cleanups)

	for SignalNode in Node._Dependencies do
		SignalNode._Dependents[Node] = nil
	end
	table.clear(Node._Dependencies)
end

function Engine.Track(SignalNode : { _Dependents : { [Dependency] : boolean } })
	local CurrentEffect : Dependency? = EffectStack[#EffectStack]
	if CurrentEffect then
		SignalNode._Dependents[CurrentEffect] = true
		CurrentEffect._Dependencies[SignalNode] = true
	end
end

function Engine.Trigger(SignalNode : { _Dependents : { [Dependency] : boolean } })
	for Dependent in SignalNode._Dependents do
		Dependent:Rerun()
	end
end

function Engine.PushEffect(Effect : Dependency)
	table.insert(EffectStack, Effect)
end

function Engine.PopEffect()
	table.remove(EffectStack)
end

return Engine
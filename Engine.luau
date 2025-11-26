--!strict
local Types = require(script.Parent.Types)

type Dependency = Types.Dependency

local Engine = {}
local EffectStack : { Dependency } = {}

function Engine.Cleanup(Node : Dependency)
	local Cleanups = Node.Cleanups

	for Index = #Cleanups, 1, -1 do
		Cleanups[Index]()
	end
	table.clear(Cleanups)

	for SignalNode in Node.Dependencies do
		SignalNode.Dependents[Node] = nil
	end
	table.clear(Node.Dependencies)
end

function Engine.Track(SignalNode : { Dependents : { [Dependency] : boolean } })
	local CurrentEffect : Dependency? = EffectStack[#EffectStack]
	if CurrentEffect then
		SignalNode.Dependents[CurrentEffect] = true
		CurrentEffect.Dependencies[SignalNode] = true
	end
end

function Engine.Trigger(SignalNode : { Dependents : { [Dependency] : boolean } })
	for Dependent in SignalNode.Dependents do
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
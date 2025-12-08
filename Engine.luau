--!strict
local Types = require(script.Parent.Types)

type Dependency = Types.Dependency

local Engine = {}
local EffectStack : { Dependency } = {}
local MaxStackDepth : number = 100
local IsBatching : boolean = false
local BatchQueue : { [Dependency] : boolean } = {}
local NodeCount : number = 0

function Engine.Cleanup(Node : Dependency)
	local CleanupList : { () -> () } = Node.Cleanups
	for Index : number = #CleanupList, 1, -1 do
		CleanupList[Index]()
	end
	table.clear(CleanupList)

	for DependencyNode : Dependency, _ : boolean in Node.Dependencies do
		DependencyNode.Dependents[Node] = nil
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
	for Dependent : Dependency, _ : boolean in SignalNode.Dependents do
		if IsBatching then
			BatchQueue[Dependent] = true
		else
			Dependent:Rerun()
		end
	end
end

function Engine.PushEffect(Effect : Dependency)
	if #EffectStack >= MaxStackDepth then
		error("Proton: Maximum effect depth exceeded")
	end
	table.insert(EffectStack, Effect)
end

function Engine.PopEffect()
	table.remove(EffectStack)
end

function Engine.Batch(Callback : () -> ())
	if IsBatching then
		Callback()
		return
	end

	IsBatching = true
	local IsSuccess : boolean, Error : any = xpcall(Callback, debug.traceback)
	IsBatching = false

	local Snapshot : { Dependency } = {}
	for Dependent : Dependency, _ : boolean in BatchQueue do
		table.insert(Snapshot, Dependent)
	end
	table.clear(BatchQueue)

	table.sort(Snapshot, function(NodeA : Dependency, NodeB : Dependency) : boolean
		return NodeA.Priority > NodeB.Priority
	end)

	for _, Dependent : Dependency in Snapshot do
		Dependent:Rerun()
	end

	if not IsSuccess then
		error(Error)
	end
end

function Engine.CreateNode(Priority : number?, Label : string?) : Dependency
	NodeCount += 1
	return {
		Cleanups = {},
		Dependencies = {},
		Dependents = {},
		Rerun = function(self : Dependency) end,
		Priority = Priority or 0,
		DebugLabel = Label
	}
end

function Engine.GetStats() : { NodeCount : number, StackDepth : number }
	return {
		NodeCount = NodeCount,
		StackDepth = #EffectStack
	}
end

return Engine
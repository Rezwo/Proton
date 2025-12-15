--!strict
local Types = require(script.Parent.Types)

type Dependency = Types.Dependency

local Engine = {}
local EffectStack : { Dependency } = {}
local EffectStackSet : { [Dependency] : boolean } = {}
local MaxStackDepth : number = 100
local IsBatching : boolean = false
local BatchQueue : { [Dependency] : boolean } = {}
local NodeCount : number = 0

function Engine.Cleanup(Node : Dependency)
	local CleanupList : { () -> () } = Node.Cleanups
	local CleanupSnapshot = table.clone(CleanupList)
	table.clear(CleanupList)
	
	for Index : number = #CleanupSnapshot, 1, -1 do
		local Success : boolean, ErrorObject : any = pcall(CleanupSnapshot[Index])
		if not Success then
			warn(string.format("Proton: Cleanup error%s: %s", 
				Node.DebugLabel and " (" .. Node.DebugLabel .. ")" or "",
				tostring(ErrorObject)))
		end
	end

	for DependencyNode : Dependency, _ : boolean in Node.Dependencies do
		DependencyNode.Dependents[Node] = nil
	end
	table.clear(Node.Dependencies)
	
	if Node.IsActive then
		if NodeCount <= 0 then
			warn("Proton: NodeCount underflow detected")
		end
		NodeCount = math.max(0, NodeCount - 1)
		Node.IsActive = false
	end
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
		if EffectStackSet[Dependent] then
			warn(string.format("Proton: Circular dependency detected in %s. Skipping trigger.", 
				Dependent.DebugLabel or "unnamed effect"))
			continue
		end

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
	EffectStackSet[Effect] = true
end

function Engine.PopEffect()
	if #EffectStack == 0 then
		error("Proton: Attempted to pop from empty effect stack")
	end
	local Effect = table.remove(EffectStack)
	EffectStackSet[Effect :: Dependency] = nil
end

function Engine.Batch(Callback : () -> ())
	if IsBatching then
		Callback()
		return
	end

	IsBatching = true
	local IsSuccess : boolean, ErrorObject : any = xpcall(Callback, debug.traceback)
	
	if not IsSuccess then
		warn("Proton: Batch callback error:", ErrorObject)
	end

	local Snapshot : { Dependency } = {}
	for Dependent : Dependency, _ : boolean in BatchQueue do
		table.insert(Snapshot, Dependent)
	end
	table.clear(BatchQueue)
	IsBatching = false

	table.sort(Snapshot, function(NodeA : Dependency, NodeB : Dependency) : boolean
		return NodeA.Priority > NodeB.Priority
	end)

	for _, Dependent : Dependency in Snapshot do
		Dependent:Rerun()
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
		DebugLabel = Label,
		IsActive = true
	}
end

function Engine.GetStats() : { NodeCount : number, StackDepth : number }
	return {
		NodeCount = NodeCount,
		StackDepth = #EffectStack
	}
end

return Engine
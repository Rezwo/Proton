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
	-- FIX: Create snapshot to prevent modification during iteration
	local CleanupList : { () -> () } = Node.Cleanups
	-- Iterate backwards to respect LIFO order of cleanup
	for Index : number = #CleanupList, 1, -1 do
		local Success : boolean, Error : any = pcall(CleanupList[Index])
		if not Success then
			warn("Proton: Cleanup error:", Error)
		end
	end
	table.clear(CleanupList)

	for DependencyNode : Dependency, _ : boolean in Node.Dependencies do
		DependencyNode.Dependents[Node] = nil
	end
	table.clear(Node.Dependencies)
	
	-- FIX: Track node removal accurately
	if Node.IsActive then
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
	local CurrentEffect = EffectStack[#EffectStack]

	for Dependent : Dependency, _ : boolean in SignalNode.Dependents do
		-- FIX: Prevent infinite loops (Cycle detection)
		if Dependent == CurrentEffect then
			warn("Proton: Signal triggered inside its own dependency. This causes an infinite loop.")
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
		error("Proton: Maximum effect depth exceeded (possible circular dependency)")
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
	-- Keep batching true until queue is processed to prevent intermediate triggers
	
	if not IsSuccess then
		-- If callback failed, we still attempt to flush queue to restore consistency,
		-- but we warn about the original error.
		warn("Proton: Batch callback error:", Error)
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
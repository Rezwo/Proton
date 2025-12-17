--!strict
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)
local Spring = require(script.Parent.Spring)
local Collection = require(script.Parent.Collection)

local Scope = {}

export type Scope = {
	Signal : <ValueType>(self : Scope, InitialValue : ValueType) -> Types.Signal<ValueType>,
	Derived : <ValueType>(self : Scope, Processor : () -> ValueType) -> Types.ReadOnly<ValueType>,
	Effect : (self : Scope, Callback : () -> Types.Destructor?, Priority : number?, Label : string?) -> () -> (),
	Spring : (self : Scope, TargetSignal : Types.Reactive<number>, Speed : number?, Damping : number?) -> any,
	Collection : <ItemType>(self : Scope, InitialData : { [string] : any }?) -> Collection.Collection<ItemType>,
	Scope : (self : Scope) -> Scope,
	Run : <T...>(self : Scope, Callback : () -> T...) -> T...,
	Destroy : (self : Scope) -> (),
	IsActive : (self : Scope) -> boolean
}

local ScopeMetatable = {}
ScopeMetatable.__index = ScopeMetatable

local ActiveScope : Scope? = nil
local ScopeStack : { Scope } = {}

-- Internal function to track a resource for cleanup
local function TrackResource(scope : any, resource : any, cleanup : () -> ())
	if not scope._IsActive then
		warn("Proton: Attempted to create resource in destroyed scope")
		cleanup()
		return
	end
	
	table.insert(scope._Cleanups, cleanup)
end

-- Signal: Auto-tracked signal creation
function ScopeMetatable:Signal<ValueType>(InitialValue : ValueType) : Types.Signal<ValueType>
	local signal = State.CreateSignal(InitialValue)
	
	-- Signals with large data should be destroyed
	-- We track it but only destroy if it has a Destroy method
	TrackResource(self, signal, function()
		if signal and signal.Destroy then
			signal:Destroy()
		end
	end)
	
	return signal
end

-- Derived: Auto-tracked derived signal
function ScopeMetatable:Derived<ValueType>(Processor : () -> ValueType) : Types.ReadOnly<ValueType>
	local derived = State.CreateDerived(Processor)
	
	-- Derived signals MUST be destroyed to prevent leaks
	TrackResource(self, derived, function()
		if derived and derived.Destroy then
			derived:Destroy()
		end
	end)
	
	return derived
end

-- Effect: Auto-tracked effect
function ScopeMetatable:Effect(Callback : () -> Types.Destructor?, Priority : number?, Label : string?) : () -> ()
	local cleanup = State.CreateEffect(Callback, Priority, Label)
	
	-- Effects MUST be cleaned up
	TrackResource(self, cleanup, cleanup)
	
	return cleanup
end

-- Spring: Auto-tracked spring
function ScopeMetatable:Spring(TargetSignal : Types.Reactive<number>, Speed : number?, Damping : number?) : any
	local spring = Spring.CreateSpring(TargetSignal, Speed, Damping)
	
	-- Springs MUST be destroyed
	TrackResource(self, spring, function()
		if spring and spring.Destroy then
			spring:Destroy()
		end
	end)
	
	return spring
end

-- Collection: Auto-tracked collection
function ScopeMetatable:Collection<ItemType>(InitialData : { [string] : any }?) : Collection.Collection<ItemType>
	local collection = Collection.CreateCollection(InitialData)
	
	-- Collections MUST be destroyed
	TrackResource(self, collection, function()
		if collection and collection.Destroy then
			collection:Destroy()
		end
	end)
	
	return collection
end

-- Scope: Create a nested scope
function ScopeMetatable:Scope() : Scope
	local childScope = Scope.CreateScope()
	
	-- When parent is destroyed, child is destroyed too
	TrackResource(self, childScope, function()
		if childScope and childScope.Destroy then
			childScope:Destroy()
		end
	end)
	
	return childScope
end

-- Run: Execute a callback within this scope context
-- All resources created during the callback are automatically tracked
function ScopeMetatable:Run<T...>(Callback : () -> T...) : T...
	if not self._IsActive then
		error("Proton: Cannot run in destroyed scope")
	end
	
	-- Push this scope as active
	local previousScope = ActiveScope
	ActiveScope = self
	table.insert(ScopeStack, self)
	
	-- Run the callback
	local results = table.pack(xpcall(Callback, debug.traceback))
	local success = table.remove(results, 1)
	
	-- Restore previous scope
	table.remove(ScopeStack)
	ActiveScope = previousScope
	
	if not success then
		local errorMsg = results[1]
		error("Proton: Scope callback error: " .. tostring(errorMsg))
	end
	
	return table.unpack(results, 1, results.n)
end

-- Destroy: Clean up all tracked resources
function ScopeMetatable:Destroy()
	if not self._IsActive then
		warn("Proton: Attempted to destroy scope twice")
		return
	end
	
	self._IsActive = false
	
	-- Clean up in reverse order (LIFO)
	for i = #self._Cleanups, 1, -1 do
		local cleanup = self._Cleanups[i]
		local success, err = pcall(cleanup)
		if not success then
			warn("Proton: Scope cleanup error:", err)
		end
	end
	
	table.clear(self._Cleanups)
	
	-- Remove from scope stack if present
	for i, scope in ScopeStack do
		if scope == self then
			table.remove(ScopeStack, i)
			break
		end
	end
	
	if ActiveScope == self then
		ActiveScope = nil
	end
end

-- IsActive: Check if scope is still active
function ScopeMetatable:IsActive() : boolean
	return self._IsActive
end

-- CreateScope: Create a new scope for automatic cleanup
function Scope.CreateScope() : Scope
	local self : any = setmetatable({
		_Cleanups = {},
		_IsActive = true
	}, ScopeMetatable)
	
	-- If there's an active scope, make this a child of it
	if ActiveScope then
		TrackResource(ActiveScope, self, function()
			if self and self.Destroy then
				self:Destroy()
			end
		end)
	end
	
	return self
end

-- GetActiveScope: Get the currently active scope (if any)
function Scope.GetActiveScope() : Scope?
	return ActiveScope
end

-- WithScope: Run a callback with a new scope, then auto-destroy
-- This is a convenience function for one-off scopes
function Scope.WithScope<T...>(Callback : (Scope) -> T...) : T...
	local scope = Scope.CreateScope()
	
	local results = table.pack(xpcall(function()
		return Callback(scope)
	end, debug.traceback))
	
	local success = table.remove(results, 1)
	
	-- Always destroy the scope
	scope:Destroy()
	
	if not success then
		local errorMsg = results[1]
		error("Proton: WithScope callback error: " .. tostring(errorMsg))
	end
	
	return table.unpack(results, 1, results.n)
end

return Scope
--!strict
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)

local Builder = {}

local function ApplyProperty(Instance : Instance, Key : string, Value : any, Cleanups : { () -> () })
	if type(Value) == "table" and type(Value.Get) == "function" then
		local ReactiveValue : Types.ReadOnly<any> = Value
		local HasWarned : boolean = false
		
		local Disconnect : () -> () = State.CreateEffect(function()
			local Success : boolean, ErrorObject : any = pcall(function()
				(Instance :: any)[Key] = ReactiveValue:Get()
			end)
			if not Success and not HasWarned then
				HasWarned = true
				warn("Proton: Failed to bind property '" .. Key .. "' on " .. Instance.ClassName .. ": " .. tostring(ErrorObject))
			end
			return nil
		end)
		table.insert(Cleanups, Disconnect)
	else
		local Success : boolean, ErrorObject : any = pcall(function()
			(Instance :: any)[Key] = Value
		end)
		if not Success then
			warn("Proton: Failed to set property '" .. Key .. "' on " .. Instance.ClassName .. ": " .. tostring(ErrorObject))
		end
	end
end

local function NewImplementation(ClassName : string)
	return function(Properties : Types.WidgetProperties) : Instance
		local NewInstance : Instance = Instance.new(ClassName)
		local Cleanups : { () -> () } = {}
		local ParentInstance : Instance? = nil
		local ReferenceSignal : Types.Signal<Instance?>? = nil

		for Key : any, Value : any in Properties do
			if type(Key) == "number" then
				if typeof(Value) == "Instance" then
					Value.Parent = NewInstance
					continue
				end
				
				if type(Value) == "table" and Value.Type == "For" then
					if not Value.Source or not Value.Processor then
						error("Proton: Invalid For object - missing Source or Processor")
					end
					
					local ForObject : Types.ForObject<any, any> = Value
					local InstanceCache : { [any] : {
						Instance: Instance, 
						Value: any, 
						Cleanup: (() -> ())?,
						DestroyConnection: RBXScriptConnection?
					} } = {}
					
					local Disconnect : () -> () = State.CreateEffect(function()
						local Data : { [any] : any } = ForObject.Source:Get() or {}
						local SeenKeys : { [any] : boolean } = {}
						
						for ItemKey : any, ItemValue : any in Data do
							SeenKeys[ItemKey] = true
							local CacheEntry = InstanceCache[ItemKey]
							
							if not CacheEntry then
								-- Create new instance
								local ChildInstance : Instance = ForObject.Processor(ItemKey, ItemValue)
								if ChildInstance then
									ChildInstance.Parent = NewInstance
									
									local DestroyConnection : RBXScriptConnection = ChildInstance.Destroying:Connect(function()
										InstanceCache[ItemKey] = nil
									end)
									
									InstanceCache[ItemKey] = {
										Instance = ChildInstance, 
										Value = ItemValue, 
										Cleanup = nil,
										DestroyConnection = DestroyConnection
									}
								end
							elseif CacheEntry.Value ~= ItemValue then
								-- Value changed - destroy and recreate
								-- TODO: Consider adding update-in-place optimization
								if CacheEntry.Cleanup then CacheEntry.Cleanup() end
								if CacheEntry.DestroyConnection then CacheEntry.DestroyConnection:Disconnect() end
								CacheEntry.Instance:Destroy()
								
								local ChildInstance : Instance = ForObject.Processor(ItemKey, ItemValue)
								if ChildInstance then
									ChildInstance.Parent = NewInstance
									local DestroyConnection : RBXScriptConnection = ChildInstance.Destroying:Connect(function()
										InstanceCache[ItemKey] = nil
									end)
									
									InstanceCache[ItemKey] = {
										Instance = ChildInstance, 
										Value = ItemValue, 
										Cleanup = nil,
										DestroyConnection = DestroyConnection
									}
								else
									InstanceCache[ItemKey] = nil
								end
							else
								-- Value unchanged - ensure parent is correct
								local Success : boolean = pcall(function()
									if CacheEntry.Instance.Parent ~= NewInstance then
										CacheEntry.Instance.Parent = NewInstance
									end
								end)
								if not Success then
									InstanceCache[ItemKey] = nil
								end
							end
						end
						
						-- Remove items no longer in data
						for CacheKey : any, CacheEntry in InstanceCache do
							if not SeenKeys[CacheKey] then
								if CacheEntry.Cleanup then CacheEntry.Cleanup() end
								if CacheEntry.DestroyConnection then CacheEntry.DestroyConnection:Disconnect() end
								CacheEntry.Instance:Destroy()
								InstanceCache[CacheKey] = nil
							end
						end
						return nil
					end)
					
					table.insert(Cleanups, function()
						Disconnect()
						for _, CacheEntry in InstanceCache do
							if CacheEntry.Cleanup then CacheEntry.Cleanup() end
							if CacheEntry.DestroyConnection then CacheEntry.DestroyConnection:Disconnect() end
							CacheEntry.Instance:Destroy()
						end
						table.clear(InstanceCache)
					end)
					continue
				end
				continue
			end

			if Key == "Parent" then
				ParentInstance = Value
				continue
			end

			if Key == "Reference" then
				ReferenceSignal = Value
				continue
			end
			
			if typeof(Value) == "function" then
				local Success : boolean, EventSignal : any = pcall(function() return (NewInstance :: any)[Key] end)
				if Success and typeof(EventSignal) == "RBXScriptSignal" then
					local Connection : RBXScriptConnection = EventSignal:Connect(Value)
					table.insert(Cleanups, function() Connection:Disconnect() end)
				else
					warn("Proton: Invalid event connection '" .. tostring(Key) .. "' on " .. ClassName)
				end
				continue
			end

			ApplyProperty(NewInstance, Key, Value, Cleanups)
		end

		-- FIX: Store the Destroying connection for proper tracking
		-- While Roblox will clean this up when the instance is destroyed,
		-- storing it allows for debugging and explicit cleanup if needed
		if #Cleanups > 0 or ReferenceSignal then
			local DestroyConnection : RBXScriptConnection = NewInstance.Destroying:Connect(function()
				for _, Cleanup : () -> () in Cleanups do
					Cleanup()
				end
				if ReferenceSignal then
					ReferenceSignal:Set(nil)
				end
			end)
			
			-- Store connection on instance for tracking (not strictly necessary but good practice)
			-- This allows external code to check if cleanups are registered
			-- Note: The connection is automatically cleaned up when instance is GC'd
			(NewInstance :: any)._ProtonCleanupConnection = DestroyConnection
		end

		if ParentInstance then
			NewInstance.Parent = ParentInstance
		end

		if ReferenceSignal then
			ReferenceSignal:Set(NewInstance)
		end

		return NewInstance
	end
end

local BuilderMetatable = {
	__index = function(Self : any, Key : string)
		return NewImplementation(Key)
	end
}

setmetatable(Builder, BuilderMetatable)

function Builder.New(ClassName : string)
	return NewImplementation(ClassName)
end

return Builder
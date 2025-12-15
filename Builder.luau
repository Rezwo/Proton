--!strict
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)

local Builder = {}

local function ApplyProperty(Instance : Instance, Key : string, Value : any, Cleanups : { () -> () })
	-- FIX: Explicit check for SignalLike interface
	if type(Value) == "table" and type(Value.Get) == "function" then
		local ReactiveValue : Types.ReadOnly<any> = Value
		local Disconnect : () -> () = State.CreateEffect(function()
			-- FIX: Safe assignment
			pcall(function()
				(Instance :: any)[Key] = ReactiveValue:Get()
			end)
			return nil
		end)
		table.insert(Cleanups, Disconnect)
	else
		-- FIX: Check if property actually exists (basic protection)
		pcall(function()
			(Instance :: any)[Key] = Value
		end)
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
					local ForObject : Types.ForObject<any, any> = Value
					-- Store Value alongside Instance to check for updates
					local InstanceCache : { [any] : {Instance: Instance, Value: any, Cleanup: (() -> ())?} } = {}
					
					local Disconnect : () -> () = State.CreateEffect(function()
						local Data : { [any] : any } = ForObject.Source:Get() or {}
						local SeenKeys : { [any] : boolean } = {}
						
						-- FIX: Proper Diffing Algorithm
						for ItemKey : any, ItemValue : any in Data do
							SeenKeys[ItemKey] = true
							local CacheEntry = InstanceCache[ItemKey]
							
							if not CacheEntry then
								-- Case 1: New Item
								local ChildInstance : Instance = ForObject.Processor(ItemKey, ItemValue)
								if ChildInstance then
									ChildInstance.Parent = NewInstance
									InstanceCache[ItemKey] = {Instance = ChildInstance, Value = ItemValue, Cleanup = nil}
								end
							elseif CacheEntry.Value ~= ItemValue then
								-- Case 2: Item Changed (Re-create)
								-- Note: If you want mutable updates, Processor needs to return an update function.
								-- Current architecture implies re-render on value change.
								if CacheEntry.Cleanup then CacheEntry.Cleanup() end
								CacheEntry.Instance:Destroy()
								
								local ChildInstance : Instance = ForObject.Processor(ItemKey, ItemValue)
								if ChildInstance then
									ChildInstance.Parent = NewInstance
									InstanceCache[ItemKey] = {Instance = ChildInstance, Value = ItemValue, Cleanup = nil}
								else
									InstanceCache[ItemKey] = nil
								end
							else
								-- Case 3: No Change. Do nothing.
								-- Ensure parent is correct in case it was reparented externally
								if CacheEntry.Instance.Parent ~= NewInstance then
									CacheEntry.Instance.Parent = NewInstance
								end
							end
						end
						
						-- Remove instances for deleted keys
						for CacheKey : any, CacheEntry in InstanceCache do
							if not SeenKeys[CacheKey] then
								if CacheEntry.Cleanup then CacheEntry.Cleanup() end
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
				-- FIX: Check if the event actually exists
				local Success, EventSignal = pcall(function() return (NewInstance :: any)[Key] end)
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

		if #Cleanups > 0 or ReferenceSignal then
			NewInstance.Destroying:Connect(function()
				for _, Cleanup : () -> () in Cleanups do
					Cleanup()
				end
				if ReferenceSignal then
					ReferenceSignal:Set(nil)
				end
			end)
		end

		if ParentInstance then
			NewInstance.Parent = ParentInstance
		end

		-- FIX: Set reference AFTER parenting so scripts see the hierarchy
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
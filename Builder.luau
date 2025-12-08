--!strict
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)

local Builder = {}

local function ApplyProperty(Instance : Instance, Key : string, Value : any, Cleanups : { () -> () })
	if type(Value) == "table" and (Value.Get or Value._IsSignal) then
		local ReactiveValue : Types.ReadOnly<any> = Value
		local Disconnect : () -> () = State.CreateEffect(function()
			(Instance :: any)[Key] = ReactiveValue:Get()
			return nil
		end)
		table.insert(Cleanups, Disconnect)
	else
		(Instance :: any)[Key] = Value
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
					local InstanceCache : { [any] : Instance } = {}
					
					local Disconnect : () -> () = State.CreateEffect(function()
						local Data : { [any] : any } = ForObject.Source:Get() or {}
						local SeenKeys : { [any] : boolean } = {}
						
						for ItemKey : any, ItemValue : any in Data do
							SeenKeys[ItemKey] = true
							if not InstanceCache[ItemKey] then
								local ChildInstance : Instance = ForObject.Processor(ItemKey, ItemValue)
								if ChildInstance then
									ChildInstance.Parent = NewInstance
									InstanceCache[ItemKey] = ChildInstance
								end
							end
						end
						
						for CacheKey : any, CachedInstance : Instance in InstanceCache do
							if not SeenKeys[CacheKey] then
								CachedInstance:Destroy()
								InstanceCache[CacheKey] = nil
							end
						end
						return nil
					end)
					
					table.insert(Cleanups, function()
						Disconnect()
						for _, CachedInstance : Instance in InstanceCache do
							CachedInstance:Destroy()
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
				local EventSignal : RBXScriptSignal = (NewInstance :: any)[Key]
				if typeof(EventSignal) == "RBXScriptSignal" then
					local Connection : RBXScriptConnection = EventSignal:Connect(Value)
					table.insert(Cleanups, function() Connection:Disconnect() end)
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

		if ReferenceSignal then
			ReferenceSignal:Set(NewInstance)
		end

		if ParentInstance then
			NewInstance.Parent = ParentInstance
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
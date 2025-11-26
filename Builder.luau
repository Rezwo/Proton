--!strict
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)

local Builder = {}

local function NewImplementation(ClassName : string)
	return function(Properties : Types.WidgetProperties) : Instance
		local NewInstance : Instance = Instance.new(ClassName)
		local Cleanups : { () -> () } = {}

		local ParentInstance : Instance? = nil
		local ReferenceSignal : Types.Signal<Instance?>? = nil

		for Key, Value in Properties do
			if type(Key) == "number" then
				if typeof(Value) == "Instance" then
					Value.Parent = NewInstance
					continue
				end

				if type(Value) == "table" and (Value :: any).Type == "For" then
					local ForObject = Value :: Types.ForObject<any, any>
					local InstanceCache : { [any] : Instance } = {}

					local ListEffect = State.CreateEffect(function()
						local Data = ForObject.Source:Get() or {}
						local SeenKeys : { [any] : boolean } = {}

						for ItemKey, ItemValue in Data do
							SeenKeys[ItemKey] = true

							if not InstanceCache[ItemKey] then
								local ChildInstance : Instance = ForObject.Processor(ItemKey, ItemValue)
								if ChildInstance then
									ChildInstance.Parent = NewInstance
									InstanceCache[ItemKey] = ChildInstance
								end
							end
						end

						for CacheKey, ChildInstance in InstanceCache do
							if not SeenKeys[CacheKey] then
								ChildInstance:Destroy()
								InstanceCache[CacheKey] = nil
							end
						end

						return nil
					end)

					table.insert(Cleanups, ListEffect)
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
				local EventSignal : any = (NewInstance :: any)[Key]
				if typeof(EventSignal) == "RBXScriptSignal" then
					local Connection = EventSignal:Connect(Value)
					table.insert(Cleanups, function() Connection:Disconnect() end)
				end
				continue
			end

			if type(Value) == "table" and (Value :: any).Get then
				local ReactiveValue = Value :: Types.ReadOnly<any>

				local DisposeEffect = State.CreateEffect(function()
					(NewInstance :: any)[Key] = ReactiveValue:Get()
					return nil
				end)

				table.insert(Cleanups, DisposeEffect)
				continue
			end

			(NewInstance :: any)[Key] = Value
		end

		if #Cleanups > 0 then
			NewInstance.Destroying:Connect(function()
				for _, Cleanup in Cleanups do
					Cleanup()
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

type PrimitiveConstructors = 
	(("Frame") -> (Types.BaseProperties) -> Frame)
& (("ScreenGui") -> (Types.BaseProperties) -> ScreenGui)
& (("CanvasGroup") -> (Types.BaseProperties) -> CanvasGroup)
& (("BillboardGui") -> (Types.BaseProperties) -> BillboardGui)
& (("SurfaceGui") -> (Types.BaseProperties) -> SurfaceGui)

type TextConstructors = 
	(("TextLabel") -> (Types.TextProperties) -> TextLabel)
& (("TextButton") -> (Types.TextButtonProperties) -> TextButton)
& (("TextBox") -> (Types.TextProperties) -> TextBox)

type ImageConstructors = 
	(("ImageLabel") -> (Types.ImageProperties) -> ImageLabel)
& (("ImageButton") -> (Types.ImageProperties) -> ImageButton)
& (("ScrollingFrame") -> (Types.ScrollingProperties) -> ScrollingFrame)
& (("VideoFrame") -> (Types.ImageProperties) -> VideoFrame)

type LayoutConstructors = 
	(("UIListLayout") -> (Types.LayoutProperties) -> UIListLayout)
& (("UIGridLayout") -> (Types.LayoutProperties) -> UIGridLayout)
& (("UIStroke") -> (Types.StrokeProperties) -> UIStroke)
& (("UICorner") -> (Types.CornerProperties) -> UICorner)
& (("UIPadding") -> (Types.PaddingProperties) -> UIPadding)
& (("UIScale") -> (Types.ScaleProperties) -> UIScale)

type FallbackConstructor = <InstanceType>(ClassName : string) -> (Types.WidgetProperties) -> InstanceType

type BuilderConstructor = 
	PrimitiveConstructors 
& (TextConstructors 
	& (ImageConstructors 
		& (LayoutConstructors 
			& FallbackConstructor)))

Builder.New = NewImplementation :: BuilderConstructor

return Builder
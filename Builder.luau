--!strict
local Types = require(script.Parent.Types)
local State = require(script.Parent.State)

local Builder = {}

local function NewImplementation(ClassName : string)
	return function(Properties : Types.WidgetProperties) : Instance
		local NewInstance : Instance = Instance.new(ClassName)
		local Cleanups : { () -> () } = {}

		for Key, Value in Properties do
			if type(Key) == "number" then
				if typeof(Value) == "Instance" then
					Value.Parent = NewInstance
				end
				continue
			end

			if type(Key) == "string" then
				if typeof(Value) == "function" then
					local EventSignal : any = (NewInstance :: any)[Key]
					if typeof(EventSignal) == "RBXScriptSignal" then
						EventSignal:Connect(Value)
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
		end

		if #Cleanups > 0 then
			NewInstance.Destroying:Connect(function()
				for _, Cleanup in Cleanups do
					Cleanup()
				end
			end)
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
& (("TextButton") -> (Types.TextProperties) -> TextButton)
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

type FallbackConstructor = <T>(ClassName : string) -> (Types.WidgetProperties) -> T

type BuilderConstructor = 
	PrimitiveConstructors 
& (TextConstructors 
	& (ImageConstructors 
		& (LayoutConstructors 
			& FallbackConstructor)))

Builder.New = NewImplementation :: BuilderConstructor

return Builder
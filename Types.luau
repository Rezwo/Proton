--!strict
local Types = {}

export type Destructor = () -> ()

export type Dependency = {
	Rerun : (self : Dependency) -> (),
	_Cleanups : { Destructor },
	_Dependencies : { [any] : boolean },
}

export type SignalLike<T> = {
	Get : (self : SignalLike<T>) -> T
}

export type Signal<T> = SignalLike<T> & {
	Set : (self : Signal<T>, NewValue : T) -> (),
}

export type ReadOnly<T> = SignalLike<T>

export type Reactive<T> = Signal<T> | ReadOnly<T>

export type Binding<T> = T | Reactive<T>

export type Property<T> = Binding<T>?

export type BaseProperties = {
	[any] : any,
	Name : Property<string>,
	Parent : Instance?,
	Visible : Property<boolean>,
	ZIndex : Property<number>,
	LayoutOrder : Property<number>,
	Position : Property<UDim2>,
	Size : Property<UDim2>,
	BackgroundColor3 : Property<Color3>,
	BackgroundTransparency : Property<number>,
	BorderColor3 : Property<Color3>,
	BorderSizePixel : Property<number>,
	AnchorPoint : Property<Vector2>,
	Rotation : Property<number>,
	ClipsDescendants : Property<boolean>,
	AutomaticSize : Property<Enum.AutomaticSize>,
}

export type TextProperties = BaseProperties & {
	Text : Property<string>,
	TextColor3 : Property<Color3>,
	TextSize : Property<number>,
	TextTransparency : Property<number>,
	TextWrapped : Property<boolean>,
	TextXAlignment : Property<Enum.TextXAlignment>,
	TextYAlignment : Property<Enum.TextYAlignment>,
	Font : Property<Enum.Font>,
	RichText : Property<boolean>,
	PlaceholderText : Property<string>,
}

export type ImageProperties = BaseProperties & {
	Image : Property<string>,
	ImageColor3 : Property<Color3>,
	ImageTransparency : Property<number>,
	ScaleType : Property<Enum.ScaleType>,
	SliceCenter : Property<Rect>,
	TileSize : Property<UDim2>,
}

export type ScrollingProperties = BaseProperties & {
	CanvasSize : Property<UDim2>,
	CanvasPosition : Property<Vector2>,
	ScrollBarImageColor3 : Property<Color3>,
	ScrollBarThickness : Property<number>,
	ScrollingDirection : Property<Enum.ScrollingDirection>,
}

export type LayoutProperties = {
	[any] : any,
	Padding : Property<UDim>,
	FillDirection : Property<Enum.FillDirection>,
	SortOrder : Property<Enum.SortOrder>,
	HorizontalAlignment : Property<Enum.HorizontalAlignment>,
	VerticalAlignment : Property<Enum.VerticalAlignment>,
	ItemLineAlignment : Property<Enum.ItemLineAlignment>,
}

export type WidgetProperties = {
	[any] : any
}

return Types
--!strict
export type Destructor = () -> ()

export type Dependency = {
	Rerun : (Dependency) -> (),
	Cleanups : { Destructor },
	Dependencies : { [Dependency] : boolean },
	Dependents : { [Dependency] : boolean },
	Priority : number,
	DebugLabel : string?
}

export type SignalLike<ValueType> = {
	Get : (SignalLike<ValueType>) -> ValueType,
	Destroy : ((SignalLike<ValueType>) -> ())?
}

export type Signal<ValueType> = SignalLike<ValueType> & {
	Set : (Signal<ValueType>, ValueType) -> ()
}

export type ReadOnly<ValueType> = SignalLike<ValueType>

export type Reactive<ValueType> = Signal<ValueType> | ReadOnly<ValueType>

export type Binding<ValueType> = ValueType | Reactive<ValueType>

export type Property<ValueType> = Binding<ValueType>?

export type ForObject<KeyType, ValueType> = {
	Type : "For",
	Source : ReadOnly<{ [KeyType] : ValueType }>,
	Processor : (KeyType, ValueType) -> Instance
}

export type Child = Instance | ForObject<any, any>

export type BaseProperties = {
	[number] : Child,
	Name : Property<string>?,
	Parent : Instance?,
	Visible : Property<boolean>?,
	ZIndex : Property<number>?,
	LayoutOrder : Property<number>?,
	Position : Property<UDim2>?,
	Size : Property<UDim2>?,
	BackgroundColor3 : Property<Color3>?,
	BackgroundTransparency : Property<number>?,
	BorderColor3 : Property<Color3>?,
	BorderSizePixel : Property<number>?,
	AnchorPoint : Property<Vector2>?,
	Rotation : Property<number>?,
	ClipsDescendants : Property<boolean>?,
	AutomaticSize : Property<Enum.AutomaticSize>?,
	Reference : Signal<Instance?>?
}

export type WidgetProperties = { [any] : any }

return nil
--!strict
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

export type PropertyTable = {
	[string | number] : Binding<any> | Instance
}

return nil
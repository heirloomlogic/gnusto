/// Internal face of `@Global` used by the bootstrap's Mirror walk.
protocol AnyGlobal {
    /// Identity token the bootstrap maps to an ``EntityID`` drawn from the
    /// wrapped property's name.
    var token: RefToken { get }

    /// The wrapped value boxed for seeding the world state's global storage.
    var defaultStateValue: StateValue { get }
}

/// Custom game state with the same ergonomics as built-in state:
///
/// ```swift
/// @Global var disturbances = 0
/// // … in a rule body:
/// disturbances += 1
/// ```
///
/// The value lives in `WorldState` under an ID inferred from the property
/// name, so it participates in commit/rollback and (later) save files.
@propertyWrapper
public struct Global<Value: GlobalValue>: Sendable, AnyGlobal {
    let token = RefToken()
    let defaultValue: Value

    /// Declares custom game state with the given initial value.
    ///
    /// - Parameter wrappedValue: the state's initial value.
    public init(wrappedValue: Value) {
        self.defaultValue = wrappedValue
    }

    var defaultStateValue: StateValue {
        defaultValue.stateValue
    }

    /// The current value, read from and written to the live turn's state.
    public var wrappedValue: Value {
        get {
            let frame = Ctx.current
            let id = frame.id(for: token, describing: "@Global")
            guard let stored = frame.with({ $0.state.globals[id] }) else {
                return defaultValue
            }
            guard let value = Value(stateValue: stored) else {
                fatalError(
                    """
                    Gnusto: @Global \"\(id)\" holds a \(stored) which cannot \
                    be read as \(Value.self).
                    """)
            }
            return value
        }
        nonmutating set {
            let frame = Ctx.current
            let id = frame.id(for: token, describing: "@Global")
            frame.with { $0.state.globals[id] = newValue.stateValue }
        }
    }
}

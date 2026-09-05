/// Internal face of `@Global` used by the bootstrap's Mirror walk.
protocol AnyGlobal {
    /// Identity token the bootstrap maps to an ``EntityID`` drawn from the
    /// wrapped property's name.
    var token: RefToken { get }

    /// The wrapped value boxed for seeding the world state's global storage.
    var defaultStateValue: StateValue { get }

    /// Whether a stored value can be read back as this global's declared type.
    ///
    /// The restore-time half of ``Global/wrappedValue``'s unboxing: a save
    /// carrying a value this global cannot hold would otherwise restore
    /// cleanly and trap the first time a rule read it, which is a `fatalError`
    /// in the middle of a turn instead of a refused file at the prompt (#396).
    ///
    /// It has to be a closure over the *concrete* `Value`, because the answer
    /// is `Value(stateValue:)` and nothing else knows what `Value` is by the
    /// time the definition exists. Comparing cases could not do this job: two
    /// `.data` boxes match each other whatever they hold, so a struct global
    /// whose `Codable` shape changed sailed through, and comparing the boxed
    /// `typeName` would only have caught a type that was *renamed* rather than
    /// one that was reshaped — which is the case that actually happens.
    var accepts: @Sendable (StateValue) -> Bool { get }
}

/// What the bootstrap keeps about one `@Global`, once the concrete `Value` it
/// was declared with is no longer available to ask.
///
/// One record rather than a map per fact, for the reason `ItemDefinition` and
/// `LocationDefinition` are records: two dictionaries over the same key set,
/// written on adjacent lines, are two dictionaries that can come apart, and the
/// third fact about a global would have made a third.
struct GlobalDefinition: Sendable {
    /// What the property was declared as, and what a read falls back to when
    /// nothing has written it.
    let defaultValue: StateValue
    /// See ``AnyGlobal/accepts``.
    let accepts: @Sendable (StateValue) -> Bool
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

    /// Runs the very unboxing ``wrappedValue`` would run, so restore refuses
    /// exactly what a read would have trapped on — no second opinion to drift
    /// out of step with the first.
    var accepts: @Sendable (StateValue) -> Bool {
        { Value(stateValue: $0) != nil }
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
                // The clause is shared with `TraitKey`'s, which asks the same
                // question of the same storage — one sentence in one place
                // rather than two that promise to stay in step.
                fatalError(
                    "Gnusto: @Global \"\(id)\" \(stored.cannotBeRead(as: Value.self)).")
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

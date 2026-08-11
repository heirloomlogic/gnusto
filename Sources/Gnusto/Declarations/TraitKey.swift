/// A typed handle for a custom trait, replacing the stringly-typed
/// `trait("price", 5)` / `item.trait("price", as: Int.self)` pair with a
/// single declaration that carries its own value type:
///
/// ```swift
/// extension TraitKey<Int> { static let price = Self("price") }
///
/// let lantern = Item { name("brass lantern"); trait(.price, 5) }
/// let cost = lantern[.price]   // Int?
/// ```
///
/// A key declared with a default (`TraitKey("weight", default: 1)`) can also
/// be read through `item[default: .weight]`, which returns `V` instead of
/// `V?` — a distinct subscript label rather than a same-signature overload,
/// since Swift can't pick between two subscripts that differ only in return
/// type at an unannotated call site (`lantern[.price]`, exactly as the
/// acceptance shape above writes it, would otherwise be ambiguous).
public struct TraitKey<Value: GlobalValue>: Sendable {
    let name: String
    let defaultValue: Value?

    /// Declares a trait key with no default; reading it back yields `nil`
    /// when the entity has no trait by this name.
    ///
    /// - Parameter name: the trait's storage name.
    public init(_ name: String) {
        self.name = name
        self.defaultValue = nil
    }

    /// Declares a trait key with a default value, enabling `item[default:
    /// .key]` to read back a non-optional `V`.
    ///
    /// - Parameters:
    ///   - name: the trait's storage name.
    ///   - default: the value read back when the trait is absent.
    public init(_ name: String, default: Value) {
        self.name = name
        self.defaultValue = `default`
    }

    /// What an `entity[key]` read yields, given whatever the entity holds under
    /// this key: the value, or nil when there is nothing there or it was stored
    /// as something else.
    ///
    /// - Parameter stored: what the entity holds under ``name``, or nil.
    /// - Returns: the stored value, or nil.
    func value(for stored: StateValue?) -> Value? {
        guard let stored else { return nil }
        return Value(stateValue: stored)
    }

    /// What an `entity[default: key]` read yields, given the same.
    ///
    /// All four subscripts below funnel through this pair. They were
    /// byte-identical apart from one noun, and the copy that made them two had
    /// quietly grown a wrong sentence: a value stored under a *different type*
    /// fell into the same branch as an absent one and was reported as "has no
    /// trait", sending an author to look for a declaration that was there all
    /// along.
    ///
    /// - Parameters:
    ///   - stored: what the entity holds under ``name``, or nil for nothing.
    ///   - holder: what the entity is, for the trap.
    /// - Returns: the stored value, or this key's default.
    func value(for stored: StateValue?, of holder: TraitHolder) -> Value {
        if let value = value(for: stored) { return value }
        guard let defaultValue else { fatalError(diagnostic(for: stored, of: holder)) }
        return defaultValue
    }

    /// The complaint for a read this key has no default to answer.
    ///
    /// Split out from the trap so both branches can be asserted in process, a
    /// `fatalError` being uncatchable — the shape
    /// ``Reentry/diagnostic(depth:entity:)`` uses. Only reached when
    /// ``defaultValue`` is nil, so the advice is the same either way; what
    /// changes is which mistake it is answering.
    ///
    /// - Parameters:
    ///   - stored: what the entity holds under ``name``, or nil for nothing.
    ///   - holder: what the entity is.
    /// - Returns: the message to trap with.
    func diagnostic(for stored: StateValue?, of holder: TraitHolder) -> String {
        let noun = holder.rawValue
        let complaint =
            if let stored {
                #"\#(noun) trait "\#(name)" \#(stored.cannotBeRead(as: Value.self)),"#
            } else {
                #"\#(noun) has no trait "\#(name)","#
            }
        return """
            Gnusto: \(complaint) and its TraitKey carries no default. Declare the \
            key with `TraitKey(_:default:)`, or read it with \(noun)[key], which \
            returns nil.
            """
    }
}

/// What a custom trait is hanging on, for the one sentence that has to name it.
///
/// A closed enum rather than a `String` the two callers pass: the noun lands in
/// the complaint *and* in a code-shaped piece of advice (`item[key]`), so a
/// caller free to write "Item" or "thing" is a caller free to print advice that
/// does not compile.
enum TraitHolder: String {
    case item
    case location
}

// MARK: - Trait factory

/// A custom, plugin-defined property of a location, keyed by a typed
/// `TraitKey` (`trait(.region, "docks")`). Read it back with the location's
/// typed subscript (`location[.region]`).
///
/// - Parameters:
///   - key: the typed trait key.
///   - value: the value to store.
/// - Returns: the location trait.
public func trait<V>(_ key: TraitKey<V>, _ value: V) -> LocationTrait {
    LocationTrait(kind: .custom(key: key.name, value: value.stateValue))
}

/// A custom, plugin-defined property of an item, keyed by a typed `TraitKey`
/// (`trait(.price, 5)`). Read it back with the item's typed subscript
/// (`item[.price]`).
///
/// - Parameters:
///   - key: the typed trait key.
///   - value: the value to store.
/// - Returns: the item trait.
public func trait<V>(_ key: TraitKey<V>, _ value: V) -> ItemTrait {
    ItemTrait(kind: .custom(key: key.name, value: value.stateValue))
}

// MARK: - Typed reads

extension Item {
    /// Reads a custom trait declared with `trait(.key, value)`, or `nil` if
    /// the item has no trait by that key or it was stored as a different
    /// type — including a key declared with a default, if you want to tell
    /// "absent" apart from "equal to the default" (use `item[default:
    /// .key]` when you don't).
    ///
    /// - Parameter key: the typed trait key to read.
    /// - Returns: the stored value, or `nil` when absent or a type mismatch.
    public subscript<V>(key: TraitKey<V>) -> V? {
        let (frame, id) = resolved
        return key.value(for: frame.customTrait(key.name, of: id))
    }

    /// Reads a custom trait declared with a defaulted `TraitKey`, falling
    /// back to the key's default if the item has no trait by that name or it
    /// was stored as a different type. Traps if `key` carries no default —
    /// declare it with `TraitKey(_:default:)`, or read it with the plain
    /// `item[key]` optional subscript instead.
    ///
    /// - Parameter key: the defaulted trait key to read.
    /// - Returns: the stored value, or the key's default when absent.
    public subscript<V>(default key: TraitKey<V>) -> V {
        let (frame, id) = resolved
        return key.value(for: frame.customTrait(key.name, of: id), of: .item)
    }
}

extension Location {
    /// Reads a custom trait declared with `trait(.key, value)`, or `nil` if
    /// the location has no trait by that key or it was stored as a different
    /// type — including a key declared with a default, if you want to tell
    /// "absent" apart from "equal to the default" (use `location[default:
    /// .key]` when you don't).
    ///
    /// - Parameter key: the typed trait key to read.
    /// - Returns: the stored value, or `nil` when absent or a type mismatch.
    public subscript<V>(key: TraitKey<V>) -> V? {
        let (frame, id) = resolved
        return key.value(for: frame.customTrait(key.name, of: id))
    }

    /// Reads a custom trait declared with a defaulted `TraitKey`, falling
    /// back to the key's default if the location has no trait by that name
    /// or it was stored as a different type. Traps if `key` carries no
    /// default — declare it with `TraitKey(_:default:)`, or read it with the
    /// plain `location[key]` optional subscript instead.
    ///
    /// - Parameter key: the defaulted trait key to read.
    /// - Returns: the stored value, or the key's default when absent.
    public subscript<V>(default key: TraitKey<V>) -> V {
        let (frame, id) = resolved
        return key.value(for: frame.customTrait(key.name, of: id), of: .location)
    }
}

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
    public init(_ name: String) {
        self.name = name
        self.defaultValue = nil
    }

    /// Declares a trait key with a default value, enabling `item[default:
    /// .key]` to read back a non-optional `V`.
    public init(_ name: String, default: Value) {
        self.name = name
        self.defaultValue = `default`
    }
}

// MARK: - Trait factory

/// A custom, plugin-defined property of a location, keyed by a typed
/// `TraitKey` (`trait(.region, "docks")`). Read it back with the location's
/// typed subscript (`location[.region]`).
public func trait<V>(_ key: TraitKey<V>, _ value: V) -> LocationTrait {
    LocationTrait(kind: .custom(key: key.name, value: value.stateValue))
}

/// A custom, plugin-defined property of an item, keyed by a typed `TraitKey`
/// (`trait(.price, 5)`). Read it back with the item's typed subscript
/// (`item[.price]`).
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
    public subscript<V>(key: TraitKey<V>) -> V? {
        let (frame, id) = resolved
        guard let stored = frame.customTrait(key.name, of: id) else { return nil }
        return V(stateValue: stored)
    }

    /// Reads a custom trait declared with a defaulted `TraitKey`, falling
    /// back to the key's default if the item has no trait by that name or it
    /// was stored as a different type. Traps if `key` carries no default —
    /// declare it with `TraitKey(_:default:)`, or read it with the plain
    /// `item[key]` optional subscript instead.
    public subscript<V>(default key: TraitKey<V>) -> V {
        let (frame, id) = resolved
        guard let stored = frame.customTrait(key.name, of: id), let value = V(stateValue: stored)
        else {
            guard let fallback = key.defaultValue else {
                fatalError(
                    """
                    Gnusto: item has no trait \"\(key.name)\" and its TraitKey \
                    carries no default. Use item[key] (returns nil), or declare \
                    the key with `TraitKey(_:default:)`.
                    """)
            }
            return fallback
        }
        return value
    }
}

extension Location {
    /// Reads a custom trait declared with `trait(.key, value)`, or `nil` if
    /// the location has no trait by that key or it was stored as a different
    /// type — including a key declared with a default, if you want to tell
    /// "absent" apart from "equal to the default" (use `location[default:
    /// .key]` when you don't).
    public subscript<V>(key: TraitKey<V>) -> V? {
        let (frame, id) = resolved
        guard let stored = frame.customTrait(key.name, of: id) else { return nil }
        return V(stateValue: stored)
    }

    /// Reads a custom trait declared with a defaulted `TraitKey`, falling
    /// back to the key's default if the location has no trait by that name
    /// or it was stored as a different type. Traps if `key` carries no
    /// default — declare it with `TraitKey(_:default:)`, or read it with the
    /// plain `location[key]` optional subscript instead.
    public subscript<V>(default key: TraitKey<V>) -> V {
        let (frame, id) = resolved
        guard let stored = frame.customTrait(key.name, of: id), let value = V(stateValue: stored)
        else {
            guard let fallback = key.defaultValue else {
                fatalError(
                    """
                    Gnusto: location has no trait \"\(key.name)\" and its \
                    TraitKey carries no default. Use location[key] (returns \
                    nil), or declare the key with `TraitKey(_:default:)`.
                    """)
            }
            return fallback
        }
        return value
    }
}

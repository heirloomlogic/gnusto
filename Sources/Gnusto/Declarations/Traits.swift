/// A single fact about a location, stated inside a `Location { … }` block.
public struct LocationTrait: Sendable {
    enum Kind: Sendable {
        case name(String)
        case description(String)
        case dark
        case custom(key: String, value: StateValue)
    }

    let kind: Kind
}

/// A single fact about an item, stated inside an `Item { … }` block.
public struct ItemTrait: Sendable {
    enum Kind: Sendable {
        case name(String)
        case description(String)
        case adjectives([String])
        case synonyms([String])
        case firstSight(String)
        case wearable
        case scenery
        case surface
        case container
        case openable
        case startsOpen
        case transparent
        /// Stores the key's reference token; Bootstrap resolves it to an
        /// `EntityID` once the registry exists.
        case lockable(key: RefToken)
        case startsUnlocked
        case capacity(Int)
        case hidden
        case custom(key: String, value: StateValue)
    }

    let kind: Kind
}

// MARK: - Trait vocabulary

/// The display name of a location. The last word becomes a parser noun.
public func name(_ text: String) -> LocationTrait {
    LocationTrait(kind: .name(text))
}

/// The display name of an item. The last word becomes the item's primary
/// noun; the leading words double as adjectives.
public func name(_ text: String) -> ItemTrait {
    ItemTrait(kind: .name(text))
}

/// The long description shown when the location is described in full.
public func description(_ text: String) -> LocationTrait {
    LocationTrait(kind: .description(text))
}

/// The text shown when the item is examined (or read).
public func description(_ text: String) -> ItemTrait {
    ItemTrait(kind: .description(text))
}

/// Additional words the parser accepts before the item's noun.
public func adjectives(_ words: String...) -> ItemTrait {
    ItemTrait(kind: .adjectives(words))
}

/// Alternative nouns the parser accepts for the item.
public func synonyms(_ words: String...) -> ItemTrait {
    ItemTrait(kind: .synonyms(words))
}

/// The paragraph used to mention the item in a room description until the
/// player has touched it (ZIL's FDESC).
public func firstSight(_ text: String) -> ItemTrait {
    ItemTrait(kind: .firstSight(text))
}

/// The location has no light of its own; it is dark unless lit by author code
/// (`room.isLit = true`) or by a light-providing item. Locations default to lit.
public let dark = LocationTrait(kind: .dark)

/// The item can be worn.
public let wearable = ItemTrait(kind: .wearable)

/// The item is part of the scenery: it cannot be taken, and it is never
/// listed in room descriptions (its `firstSight` text, if any, still appears).
public let scenery = ItemTrait(kind: .scenery)

/// Other items can be put on this item.
public let surface = ItemTrait(kind: .surface)

/// Other items can be placed inside this item. A container without `openable`
/// is always open; with `openable` it starts closed unless `startsOpen`. Its
/// contents are visible and reachable only while it is open (or, for
/// `transparent` containers, visible while closed but never reachable).
public let container = ItemTrait(kind: .container)

/// The item can be opened and closed. An `openable` item **starts closed**
/// unless it also declares `startsOpen`.
public let openable = ItemTrait(kind: .openable)

/// An `openable` item begins the game open rather than closed.
public let startsOpen = ItemTrait(kind: .startsOpen)

/// A container's contents are visible even while it is closed (but still not
/// reachable until it is opened) — a glass jar, a display case.
public let transparent = ItemTrait(kind: .transparent)

/// The item can be locked and unlocked with the given key item. A `lockable`
/// item **starts locked** unless it also declares `startsUnlocked`. The key is
/// captured by reference; Bootstrap resolves it to a concrete item and reports
/// a fatal diagnostic if the key is not a declared item.
public func lockable(with key: Item) -> ItemTrait {
    ItemTrait(kind: .lockable(key: key.token))
}

/// A `lockable` item begins the game unlocked rather than locked.
public let startsUnlocked = ItemTrait(kind: .startsUnlocked)

/// The maximum number of items that may be placed directly inside a container
/// (enforced by the put-in action).
public func capacity(_ n: Int) -> ItemTrait {
    ItemTrait(kind: .capacity(n))
}

/// The item is excluded from visibility and room descriptions until revealed
/// (`item.reveal()`), even though it exists and is placed like any other item.
public let hidden = ItemTrait(kind: .hidden)

// MARK: - Custom traits

/// A custom, plugin-defined property of a location (`trait("region", "docks")`).
/// The value is boxed like a `@Global`; read it back with
/// `location.trait("region", as: String.self)`. The engine never branches on
/// custom traits — they are declarative data for game/plugin code to read.
public func trait(_ key: String, _ value: some GlobalValue) -> LocationTrait {
    LocationTrait(kind: .custom(key: key, value: value.stateValue))
}

/// A custom, plugin-defined property of an item (`trait("price", 5)`). The
/// value is boxed like a `@Global`; read it back with
/// `item.trait("price", as: Int.self)`. The engine never branches on custom
/// traits — they are declarative data for game/plugin code to read.
public func trait(_ key: String, _ value: some GlobalValue) -> ItemTrait {
    ItemTrait(kind: .custom(key: key, value: value.stateValue))
}

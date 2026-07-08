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
        case startsUnlocked
        case capacity(Int)
        case hidden
        case lightSource
        case startsLit
        case enterable
        case custom(key: String, value: StateValue)
    }

    let kind: Kind
}

// MARK: - Trait vocabulary

/// The display name of a location. The last word becomes a parser noun.
///
/// - Parameter text: the location's display name.
/// - Returns: the name trait.
public func name(_ text: String) -> LocationTrait {
    LocationTrait(kind: .name(text))
}

/// The display name of an item. The last word becomes the item's primary
/// noun; the leading words double as adjectives.
///
/// - Parameter text: the item's display name.
/// - Returns: the name trait.
public func name(_ text: String) -> ItemTrait {
    ItemTrait(kind: .name(text))
}

/// The long description shown when the location is described in full.
///
/// - Parameter text: the location's long description.
/// - Returns: the description trait.
public func description(_ text: String) -> LocationTrait {
    LocationTrait(kind: .description(text))
}

/// The text shown when the item is examined (or read).
///
/// - Parameter text: the item's examine text.
/// - Returns: the description trait.
public func description(_ text: String) -> ItemTrait {
    ItemTrait(kind: .description(text))
}

/// Additional words the parser accepts before the item's noun.
///
/// - Parameter words: the adjectives to accept.
/// - Returns: the adjectives trait.
public func adjectives(_ words: String...) -> ItemTrait {
    ItemTrait(kind: .adjectives(words))
}

/// Alternative nouns the parser accepts for the item.
///
/// - Parameter words: the alternative nouns to accept.
/// - Returns: the synonyms trait.
public func synonyms(_ words: String...) -> ItemTrait {
    ItemTrait(kind: .synonyms(words))
}

/// The paragraph used to mention the item in a room description until the
/// player has touched it (ZIL's FDESC).
///
/// On an ``Actor`` the same trait is the *standing presence line* (ZIL's
/// LDESC role): printed on every look, never worn off by handling — people
/// aren't props.
///
/// - Parameter text: the first-sight paragraph.
/// - Returns: the first-sight trait.
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

/// A lockable item begins the game unlocked rather than locked. An item
/// becomes lockable (and starts locked) via a `lockedBy(_:)` entry in the
/// `map` block; this flag has no effect on an item with no such entry.
public let startsUnlocked = ItemTrait(kind: .startsUnlocked)

/// The maximum number of items that may be placed directly inside a container
/// (enforced by the put-in action).
///
/// - Parameter n: the maximum number of items.
/// - Returns: the capacity trait.
public func capacity(_ n: Int) -> ItemTrait {
    ItemTrait(kind: .capacity(n))
}

/// The item is excluded from visibility and room descriptions until revealed
/// (`item.reveal()`), even though it exists and is placed like any other item.
public let hidden = ItemTrait(kind: .hidden)

/// The item can hold light. It **starts unlit** unless it also declares
/// `startsLit`; the player operates it with `turn on`/`turn off` (and
/// `light`/`extinguish`), and rules can flip `item.isLit` directly. While lit,
/// it lights the room it is in — carried by the player, lying in the room, on
/// a surface, or inside an open or `transparent` container. There is no
/// separate "always burning" trait: refuse `.turnOff` in a rule to make a
/// torch inextinguishable.
public let lightSource = ItemTrait(kind: .lightSource)

/// A `lightSource` item begins the game lit rather than unlit.
public let startsLit = ItemTrait(kind: .startsLit)

/// The player can get inside this item (`enter`/`board`) and ride it: while
/// boarded, `go` moves the item — and everything in it — along with the
/// player. An enterable that shouldn't travel (a chair, a phone booth)
/// refuses `.go` in a rule; one that should hold cargo also declares
/// `container` (an open-topped one — no `openable`).
public let enterable = ItemTrait(kind: .enterable)

// Custom traits are declared with a typed `TraitKey` (`trait(.price, 5)`,
// read back with `item[.price]`) — see `TraitKey.swift`. The underlying
// storage (`ItemDefinition`/`LocationDefinition.customTraits: [String:
// StateValue]`) is still keyed by the trait's name string, since that's what
// `TraitKey` itself boils down to; only the stringly-typed authoring API
// (`trait("price", 5)` / `item.trait("price", as:)`) is gone.

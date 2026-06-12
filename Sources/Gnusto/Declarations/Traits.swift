/// A single fact about a location, stated inside a `Location { … }` block.
public struct LocationTrait: Sendable {
    enum Kind: Sendable {
        case name(String)
        case description(String)
        case dark
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


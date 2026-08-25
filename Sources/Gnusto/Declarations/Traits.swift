/// A single fact about a location, stated inside a `Location { … }` block.
public struct LocationTrait: Sendable {
    enum Kind: Sendable {
        case name(String)
        case description(String)
        case dark
        case alwaysDescribed
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
        case properName
        case plural
        case firstSight(String)
        case wearable
        case scenery
        case surface
        case container
        case openable
        case door
        case startsOpen
        case transparent
        case startsUnlocked
        case capacity(Int)
        case hidden
        case lightSource
        case startsLit
        case enterable
        case takesOrders
        case alwaysListed
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
/// The name is split the way the parser splits what the player types, so the
/// punctuation you want on the page costs nothing: `name("Mrs. Vane")` prints
/// with its period and answers to `mrs vane`, and `name("half-moon table")`
/// answers to `half moon table`.
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
/// Each is split the way player input is split, so `adjectives("jewel", "encrusted")`
/// and `adjectives("jewel-encrusted")` register the same two words. Prefer the
/// first: a declaration should read the way the parser stores it. An entry with
/// no letters or digits in it, or one made of nothing but filler, is a fatal
/// bootstrap error rather than a word that quietly never matches.
///
/// - Parameter words: the adjectives to accept.
/// - Returns: the adjectives trait.
public func adjectives(_ words: String...) -> ItemTrait {
    ItemTrait(kind: .adjectives(words))
}

/// Alternative nouns the parser accepts for the item.
///
/// Each entry is a noun *phrase*, split the way a name is: its last word
/// becomes a noun and any words in front of it become adjectives, so
/// `synonyms("carriage lantern")` answers to `lantern` and `carriage lantern`
/// both.
///
/// - Parameter words: the alternative nouns to accept.
/// - Returns: the synonyms trait.
public func synonyms(_ words: String...) -> ItemTrait {
    ItemTrait(kind: .synonyms(words))
}

/// The name is a proper name, so the engine's stock lines never put an article
/// in front of it: "Mrs. Vane is right here." rather than "The Mrs. Vane is
/// right here.", and "Mrs. Vane is here." rather than "A Mrs. Vane is here."
///
/// Declared rather than inferred, as in ZIL and Inform. A capital letter is
/// close to a reliable signal and not quite one — "Elvish sword" is a common
/// noun — so the bootstrap warns about a capitalized name without this trait
/// instead of guessing.
public let properName = ItemTrait(kind: .properName)

/// The name is grammatically plural, so the engine's stock lines agree with it:
/// "The rails don't budge." rather than "The rails doesn't budge.", and "some
/// rails" rather than "a rails".
///
/// Declared rather than inferred for the same reason as `properName`: a
/// trailing "s" is not a number ("the brass", "a glass"), and the alternative
/// is asking a game to rename a thing to suit a stub line. A mine has rails,
/// not a rails, and the noun should not have to apologize for it.
public let plural = ItemTrait(kind: .plural)

/// The paragraph used to mention the item in a room description until the
/// player has touched it (ZIL's FDESC).
///
/// It stands in for whichever stock listing sentence the item would otherwise
/// have earned, wherever the room lists it: on the floor, on a surface, or one
/// level down inside a container. So a thing that starts folded inside another
/// thing announces itself in its own words rather than through
/// *"In the boat is a tan label."*
///
/// One level is where that stops. A room description lists what stands in the
/// room and what those things hold, and goes no deeper, so this trait on
/// something the map buries two levels down has nowhere to print — the
/// bootstrap warns rather than leaving the line to read as live.
///
/// The *room listing* is the whole of its scope. OPEN, SEARCH and INVENTORY
/// enumerate contents into one sentence — "Opening the box reveals a violin." —
/// where a room description composes paragraphs, so those name the thing rather
/// than describing it and this line does not reach them.
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

/// The location's description is *state*, not scenery: print it in full every
/// time the room is described, not only on the first visit.
///
/// A room is normally described briefly on a revisit — its name and the things
/// lying in it, but not its long description, because the player has already
/// read it. That is right for a room made of stone. It is wrong for a room whose
/// ``Location/describe(_:)`` closure reports something the player is
/// manipulating: a sliding-block floor, a mirror box, a machine whose dials have
/// moved. There the long description is the only readout there is, and dropping
/// it on a revisit — after UNDO, after RESTORE, on walking back in through a
/// door — silently withholds the state.
///
/// ```swift
/// let puzzle = Location {
///     name("Room in a Puzzle")
///     alwaysDescribed
/// }
/// ```
///
/// Opt-in, one room at a time. Declaring it on a room with nothing to print —
/// no `description(…)` trait and no `describe { … }` rule — is a bootstrap
/// warning, since the flag then has no text to un-hide.
public let alwaysDescribed = LocationTrait(kind: .alwaysDescribed)

/// The item can be worn.
public let wearable = ItemTrait(kind: .wearable)

/// The item is part of the scenery: it cannot be taken, and it never earns a
/// stock listing sentence — on the floor, on a surface, or inside a container
/// alike. Its `firstSight` text, if any, still appears; `scenery` withholds the
/// engine's line, never the author's.
///
/// It withholds a *room description's* line, and only that. OPEN and SEARCH
/// still name a fitting: *"Opening the tin toolbox reveals a steel awl and a
/// bent clasp."* A room volunteers prose the container's own description has
/// already covered, where `look in toolbox` answers a question the player
/// asked — and a list that leaves things out is the worse answer, the more so
/// when the fitting is a puzzle (Dungeon's balloon receptacle is `scenery`, and
/// is where the newspaper burns). The two are meant to differ.
public let scenery = ItemTrait(kind: .scenery)

/// The item's listing paragraph keeps printing after the player has touched
/// it — the item-side twin of ``alwaysDescribed``.
///
/// An item's listing line normally stops at the first touch, and that is right
/// for a thing whose entrance is news exactly once. It is wrong for a mobile
/// thing whose paragraph *is* its state. Dungeon's balloon is the worked
/// example: its `presence { }` rule reports the bag, the fire and the wire,
/// all three of which change — and `board` marks the basket touched, so from
/// the first time the player climbed in, an inflated burning balloon and a
/// cold wrecked one printed the same stock sentence.
///
/// ```swift
/// let balloon = Item {
///     name("wicker basket")
///     enterable
///     alwaysListed
/// }
/// ```
///
/// Opt-in, one item at a time, and only useful beside a `presence { }` rule or
/// a `firstSight(…)` trait — declaring it on an item with no listing line of
/// its own is a bootstrap warning, since there is nothing for it to keep.
///
/// An actor needs none of this: an actor's listing line is ungated already,
/// because people are not props and handling one does not wear off their
/// entrance.
public let alwaysListed = ItemTrait(kind: .alwaysListed)

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

/// The item is a door — something a verb may reasonably treat as a way through
/// rather than as a thing.
///
/// **Most doors never declare this.** Hanging an exit on an item
/// (`hall.north(garden, via: frontDoor)`) says it already, and the bootstrap
/// reads it back into ``Item/isDoor``. The trait is for the door that leads
/// nowhere: one boarded shut, one painted on, one whose far side the map does
/// not model. Those are still doors to the player, and to any verb that asks.
///
/// It gates no movement and opens nothing. What it changes is what a rule can
/// ask: `object.isDoor` is how "knock on the front door" tells itself from
/// "knock on the bench" without the game listing its doors by hand.
public let door = ItemTrait(kind: .door)

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

/// This character carries out orders: `robot, push the triangular button`
/// becomes a real command with the robot as its agent, instead of the stock
/// refusal ``GameText/notTakingOrders``.
///
/// Opt-in, one actor at a time, because obeying is a mechanic a game has to
/// write. The engine's own default actions are all written for the player and
/// never run for somebody else — an order is answered by the addressee's own
/// rules, or by a rule on the thing it names, or not at all. Only an ``Actor``
/// can hold it; on an item the bootstrap warns that the flag has nobody to
/// describe. See <doc:ActorsAndVehicles>.
public let takesOrders = ItemTrait(kind: .takesOrders)

// Custom traits are declared with a typed `TraitKey` (`trait(.price, 5)`,
// read back with `item[.price]`) — see `TraitKey.swift`. The underlying
// storage (`ItemDefinition`/`LocationDefinition.customTraits: [String:
// StateValue]`) is still keyed by the trait's name string, since that's what
// `TraitKey` itself boils down to; only the stringly-typed authoring API
// (`trait("price", 5)` / `item.trait("price", as:)`) is gone.

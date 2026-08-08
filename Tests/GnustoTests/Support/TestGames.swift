import Gnusto

/// A small fixture exercising every default action: two lit rooms, a dark
/// cellar, a takable book, a wearable hat, and a scenery surface with a coin.
struct MiniGame: Game {
    let title = "Mini"
    let intro = "Welcome to Mini."

    let den = Location {
        name("Den")
        description("A cozy den.")
    }

    let study = Location {
        name("Study")
        description("A quiet study.")
    }

    let cellar = Location {
        name("Cellar")
        description("A damp cellar.")
        dark
    }

    let book = Item {
        name("dusty book")
        adjectives("old")
        synonyms("tome")
        description("It says: read more tests.")
    }

    let hat = Item {
        name("felt hat")
        wearable
    }

    let table = Item {
        name("oak table")
        scenery
        surface
    }

    let coin = Item {
        name("gold coin")
    }

    var map: WorldMap {
        den.east(study)
        study.west(den)
        den.down(cellar)
        cellar.up(den)
        den.north(blocked: "The door is locked.")

        player.starts(in: den)
        book.starts(in: den)
        hat.startsHeld
        table.starts(in: den)
        coin.starts(on: table)
    }
}

/// Deliberately invalid: an inline (undiscoverable) exit target, a placement
/// on a non-surface, an unnamed item, and no player start. The bootstrap must
/// report ALL of these in one error.
struct BrokenGame: Game {
    let title = "Broken"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let pebble = Item {
        name("pebble")
    }

    let nameless = Item {}

    var map: WorldMap {
        hall.east(Location { name("Inline") })  // not a stored property
        pebble.starts(on: nameless)  // not a surface
        // no player.starts(in:)
    }
}

/// Declares a stored `Item` property literally named `player`, which collides
/// with the reserved `EntityID("player")` that `Placement.heldBy` uses for the
/// player character. The bootstrap must report this as a fatal diagnostic.
struct PlayerIDCollisionGame: Game {
    let title = "PlayerIDCollision"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let player = Item {
        name("impostor")
    }

    var map: WorldMap {
        hall.east(hall)
    }
}

/// An exit whose *source* is an inline (undiscoverable) location: the source
/// token resolves to no stored property, so the bootstrap can't name it and
/// must fall back to the exit's direction as the author's anchor.
struct DanglingExitSourceGame: Game {
    let title = "DanglingExitSource"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    var map: WorldMap {
        Location { name("Orphan") }.north(hall)  // inline source, not a stored property
        player.starts(in: hall)
    }
}

/// A direction claimed twice — once plainly, once by a dynamic exit. A dynamic
/// destination is opaque until it runs, so claiming the direction is the one
/// mistake about that exit kind the bootstrap can still catch.
struct TwoNorthExitsGame: Game {
    let title = "TwoNorths"
    let intro = ""

    let start = Location {
        name("Start")
        description("A room with an argument about its north wall.")
    }

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    var map: WorldMap {
        start.north(hall)
        start.north { hall }
        player.starts(in: start)
    }
}

/// A rule attached to an inline (undiscoverable) item. The bootstrap can't name
/// the dangling item, so it names the rule's phase and watched intent instead.
struct DanglingRuleGame: Game {
    let title = "DanglingRule"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    var map: WorldMap {
        player.starts(in: hall)
    }

    var rules: Rules {
        Item { name("ghost") }.before(.examine) {}
    }
}

/// Declares a noise word that is also an item's noun. Stripping it at
/// tokenize time would make the item untypeable, so the bootstrap must
/// report a fatal diagnostic.
struct NoiseWordCollisionGame: Game {
    let title = "NoiseCollision"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let charm = Item {
        name("lucky charm")
        synonyms("spell")
        description("A little spell on a string.")
    }

    var noiseWords: [String] { ["spell"] }

    var map: WorldMap {
        player.starts(in: hall)
        charm.starts(in: hall)
    }
}

/// A synonym written as a phrase rather than a bare noun. It is split the way a
/// name is — last word the noun, the rest adjectives — so `carriage torch`,
/// `torch` and `carriage lantern` all reach the item.
struct PhraseSynonymGame: Game {
    let title = "PhraseSynonym"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let lantern = Item {
        name("brass lantern")
        synonyms("carriage torch")
        description("A brass lantern.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        lantern.starts(in: hall)
    }
}

/// An adjective with no letters or digits in it. Normalizing cannot rescue it —
/// there is no word there — so the bootstrap must reject it rather than let it
/// sit in the vocabulary unmatchable.
struct PunctuationAdjectiveGame: Game {
    let title = "PunctuationAdjective"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let lantern = Item {
        name("brass lantern")
        adjectives("---")
        description("A brass lantern.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        lantern.starts(in: hall)
    }
}

/// A synonym made of nothing but filler. `tokenize` strips "that" before any
/// matching runs, so the word is untypeable — the same fatal condition
/// ``NoiseWordCollisionGame`` reaches from the other side, for the built-in
/// filler list rather than a game's own.
struct FillerSynonymGame: Game {
    let title = "FillerSynonym"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let lantern = Item {
        name("brass lantern")
        synonyms("that")
        description("A brass lantern.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        lantern.starts(in: hall)
    }
}

/// Rules that emit stage markers so tests can assert pipeline ordering and
/// refusal semantics from the transcript alone.
struct OrderProbeGame: Game {
    let title = "Probe"
    let intro = "Probe."

    let lab = Location {
        name("Lab")
        description("A lab.")
    }

    let widget = Item {
        name("widget")
    }

    @Global var armed = false
    @Global var blunders = 0

    var map: WorldMap {
        player.starts(in: lab)
        widget.starts(in: lab)
    }

    var rules: Rules {
        world.beforeEachTurn { say("[worldBefore]") }
        world.afterEachTurn { say("[worldAfter]") }
        lab.beforeEachTurn { say("[locEachBefore]") }
        lab.before(.take) { say("[locBefore]") }
        widget.before(.take) {
            say("[itemBefore]")
            if armed {
                blunders += 1
                try refuse("[refused]")
            }
        }
        widget.after(.take) { say("[itemAfter]") }
        lab.after(.take) { say("[locAfter]") }
        lab.afterEachTurn { say("[locEachAfter]") }

        // "drop widget" arms the refusal for subsequent takes.
        widget.before(.drop) { armed = true }

        // "examine widget" reports the blunder count recorded before refusals.
        widget.before(.examine) { try reply("blunders=\(blunders)") }
    }
}

/// Rules that read and write every kind of live state, reporting through the
/// transcript: proxies, description overrides, @Global persistence, and
/// player score/location.
struct ProxyProbeGame: Game {
    let title = "ProxyProbe"
    let intro = "ProxyProbe."
    let maxScore = 10

    let porch = Location {
        name("Porch")
        description("A porch.")
    }

    let parlor = Location {
        name("Parlor")
        description("A parlor.")
    }

    let candle = Item {
        name("candle")
        description("Plain wax.")
    }

    @Global var counter = 0

    var map: WorldMap {
        porch.east(parlor)
        parlor.west(porch)
        player.starts(in: porch)
        candle.starts(in: porch)
    }

    var rules: Rules {
        candle.before(.take) {
            counter += 3
            candle.description = "Now dusted with fingerprints."
            player.score += 5
            say(
                "lit=\(porch.isLit) here=\(player.location == porch) "
                    + "counter=\(counter) heldBefore=\(candle.isHeld)")
        }
        candle.after(.take) {
            porch.isLit = false
            say("held=\(candle.isHeld) worn=\(candle.isWorn)")
        }
    }
}

/// `alwaysDescribed` on a room with no long description at all — neither the
/// static trait nor a `describe { … }` rule — so the flag has nothing to
/// un-hide on a revisit. A warning, not a diagnostic: nothing breaks, the room
/// just reads identically with the trait and without it.
struct EmptyStateRoomGame: Game {
    let title = "EmptyStateRoom"
    let intro = ""

    let landing = Location {
        name("Landing")
        description("A landing.")
    }
    let alcove = Location {
        name("Alcove")
        alwaysDescribed
    }

    var map: WorldMap {
        landing.north(alcove)
        alcove.south(landing)
        player.starts(in: landing)
    }
}

/// The edge matrix for the buried-listing-line warning. A room description
/// lists what stands in it and what those things hold, and goes no deeper — so
/// a listing line declared below that reads as live and can never print. Every
/// item here declares a channel; only the ones the map buries should be named.
///
/// The realistic case is pinned by `NestedListingGame` in `ContainerGames`;
/// this fixture exists for the boundaries around it.
struct BuriedListingGame: Game {
    let title = "Buried Listing"
    let intro = ""

    let vault = Location {
        name("Vault")
        description("Shelves of boxes inside boxes.")
    }

    let shelf = Item {
        name("iron shelf")
        surface
    }

    /// Depth 1 — the deepest the describer reaches, so this one is fine and is
    /// the control the warning must leave alone.
    let ledger = Item {
        name("brass ledger")
        firstSight("A brass ledger lies open on the shelf.")
    }

    let hamper = Item {
        name("wicker hamper")
        container
    }

    /// Depth 2 by the rule channel rather than the trait: both are listing
    /// lines and both are equally unprintable down here.
    let napkin = Item {
        name("linen napkin")
        description("Folded into a swan.")
    }

    let casket = Item {
        name("cedar casket")
        container
    }

    /// Depth 3, to prove the count is the walk's and not a two-or-more flag.
    let locket = Item {
        name("silver locket")
        firstSight("A silver locket glints in the casket.")
    }

    /// Depth 2 with nothing to print. Silent before this warning existed and
    /// silent after it: there is no line to strand.
    let pin = Item {
        name("bone pin")
    }

    /// Offstage, and so is its holder. Nothing here says where the crate will
    /// stand when it comes into play, so the map cannot be wrong about it yet.
    let crate = Item {
        name("packing crate")
        container
    }

    let stub = Item {
        name("paper stub")
        firstSight("A paper stub is wedged into the crate.")
    }

    let porter = Actor {
        name("night porter")
        description("He minds the vault, and the vault minds him.")
    }

    /// In a pocket, not in the room. What an actor carries is never listed at
    /// all, at any depth — but it can be given away or dropped, and then the
    /// line works, so this is not the map's mistake either.
    let receipt = Item {
        name("crumpled receipt")
        firstSight("A crumpled receipt lies where someone dropped it.")
    }

    var map: WorldMap {
        player.starts(in: vault)

        shelf.starts(in: vault)
        ledger.starts(on: shelf)

        hamper.starts(on: shelf)
        napkin.starts(inside: hamper)
        casket.starts(inside: hamper)
        locket.starts(inside: casket)
        pin.starts(inside: hamper)

        stub.starts(inside: crate)

        porter.starts(in: vault)
        receipt.starts(heldBy: porter)
    }

    var rules: Rules {
        napkin.presence {
            "A linen napkin is folded in the hamper."
        }
    }
}

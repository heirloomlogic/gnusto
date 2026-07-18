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

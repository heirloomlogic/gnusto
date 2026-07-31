import Gnusto

/// A room with one of everything the core table names, so every row in
/// ``SyntaxRule/coreTable`` has something to point at: things to take and to
/// drop, to wear and to take off, a surface, a plain container and a locked one
/// with its key, a lamp, something to read, somebody to follow, something to
/// board, and somewhere to walk to.
///
/// Declares no verbs and no actions — the point is what a game gets for free,
/// and that nothing here is what makes a core row answer.
struct CoreLab: Game {
    let title = "Core Lab"
    let intro = "A bare room for trying the engine's own words in."

    let lab = Location {
        name("Laboratory")
        description("A bare room with a bench along one wall.")
    }

    let annex = Location {
        name("Annex")
        description("A narrower room, and colder.")
    }

    let rod = Item {
        name("brass rod")
        adjectives("brass")
        description("A plain brass rod.")
    }

    let cloak = Item {
        name("velvet cloak")
        adjectives("velvet")
        description("Heavier than it looks.")
        wearable
    }

    let hat = Item {
        name("straw hat")
        adjectives("straw")
        wearable
    }

    let bench = Item {
        name("long bench")
        adjectives("long")
        scenery
        surface
    }

    // Always open, so PUT IN and LOOK IN reach their real work rather than the
    // closed-container refusal the box is there to cover.
    let sack = Item {
        name("canvas sack")
        adjectives("canvas")
        container
    }

    let box = Item {
        name("wooden box")
        adjectives("wooden")
        container
        openable
    }

    let key = Item {
        name("iron key")
        adjectives("iron")
    }

    let lamp = Item {
        name("oil lamp")
        adjectives("oil")
        lightSource
        startsLit
    }

    let note = Item {
        name("folded note")
        adjectives("folded")
        description("It reads: MIND THE BENCH.")
    }

    let boat = Item {
        name("wooden boat")
        adjectives("rowing")
        enterable
        container
    }

    let rat = Actor {
        name("grey rat")
        adjectives("grey")
        description("A grey rat, watching you.")
    }

    var map: WorldMap {
        lab.north(annex)
        player.starts(in: lab)
        rod.starts(in: lab)
        bench.starts(in: lab)
        sack.starts(in: lab)
        box.starts(in: lab)
        box.lockedBy(key)
        note.starts(in: lab)
        boat.starts(in: lab)
        rat.starts(in: lab)
        cloak.startsHeld
        key.startsHeld
        lamp.startsHeld
        hat.startsWorn
    }
}

/// An `actions` row for an intent the engine answers before the pipeline. The
/// row can never run, and saying so is the whole point of the fixture.
struct SaveOverrideGame: Game {
    let title = "Save Override"
    let intro = "A room, and a doomed ambition."

    let vault = Location {
        name("Vault")
        description("Nothing here is worth preserving.")
    }

    var map: WorldMap {
        player.starts(in: vault)
    }

    var actions: [IntentAction] {
        action(.save) {
            say("The scribe writes your deeds into the ledger.")
        }
    }
}

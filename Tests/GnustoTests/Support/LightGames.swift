import Gnusto

/// A fixture for light-source mechanics: a lit camp, two dark rooms (cave and
/// den), an always-burning torch, an unlit tin lamp, and the containment
/// furniture (`shelf`, opaque `chest`, transparent `glassBox`) needed to test
/// exactly where light reaches. Custom verbs flip lit state directly so
/// Task 1 can be tested before the `turn on`/`turn off` verbs exist.
struct CaveGame: Game {
    let title = "Cave"
    let intro = "Sunlight ends at the cave mouth."

    let camp = Location {
        name("Camp")
        description("A ring of stones around dead coals.")
    }

    let cave = Location {
        name("Cave")
        description("A low limestone chamber.")
        dark
    }

    let den = Location {
        name("Den")
        description("A cramped earthen den.")
        dark
    }

    /// Lit from the start of the game.
    let torch = Item {
        name("burning torch")
        lightSource
        startsLit
    }

    /// A light source that starts unlit.
    let lamp = Item {
        name("tin lamp")
        lightSource
    }

    /// Not a light source at all.
    let rock = Item {
        name("gray rock")
    }

    let shelf = Item {
        name("stone shelf")
        surface
        scenery
    }

    let chest = Item {
        name("oak chest")
        container
        openable
    }

    let glassBox = Item {
        name("glass box")
        container
        openable
        transparent
    }

    var map: WorldMap {
        player.starts(in: camp)
        torch.starts(in: camp)
        lamp.starts(in: camp)
        rock.starts(in: camp)
        shelf.starts(in: cave)
        chest.starts(in: cave)
        glassBox.starts(in: cave)

        camp.north(cave)
        cave.south(camp)
        cave.east(den)
        den.west(cave)
    }

    var verbs: [SyntaxRule] {
        // `rub <thing>` lights it by raw state assignment — proving the
        // `isLit` setter itself never auto-describes the room.
        SyntaxRule("rub", .directObject, intent: Intent("rub"))
    }

    var rules: Rules {
        lamp.before(Intent("rub")) {
            lamp.isLit = true
            try reply("The lamp flickers to life.")
        }
        rock.before(Intent("rub")) {
            // A no-op on a non-light-source; the room must stay dark.
            rock.isLit = true
            try reply("You rub the rock.")
        }
    }
}

/// Declares `startsLit` without `lightSource`: boots with a non-fatal warning
/// and the flag has no effect.
struct StartsLitWarningGame: Game {
    let title = "Warning"
    let intro = "A test rig."

    let room = Location {
        name("Rig Room")
        description("Bare boards.")
    }

    let candle = Item {
        name("wax candle")
        startsLit
    }

    var map: WorldMap {
        player.starts(in: room)
        candle.starts(in: room)
    }
}

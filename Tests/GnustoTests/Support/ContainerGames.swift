import Gnusto

/// A fixture exercising the container model: an openable opaque crate (starts
/// closed), a transparent jar (starts closed), an always-open basket (a
/// container with no `openable`), and a locked chest with its key. Every
/// container sits directly in the pantry so visibility/reachability matrices
/// can be read per state.
struct PantryGame: Game {
    let title = "Pantry"
    let intro = "Welcome to the Pantry."

    let pantry = Location {
        name("Pantry")
        description("A cool stone pantry.")
    }

    /// Openable, opaque, starts closed. Holds a can.
    let crate = Item {
        name("wooden crate")
        container
        openable
    }

    let can = Item {
        name("tin can")
    }

    /// Transparent, openable, starts closed. Holds a pickle.
    let jar = Item {
        name("glass jar")
        container
        openable
        transparent
    }

    let pickle = Item {
        name("green pickle")
    }

    /// A container with no `openable`: always open. Holds an apple.
    let basket = Item {
        name("wicker basket")
        container
    }

    let apple = Item {
        name("red apple")
    }

    /// Lockable (starts locked), openable. Holds a gem. Opened with the key
    /// via a `lockedBy` entry in `map`.
    let chest = Item {
        name("iron chest")
        container
        openable
    }

    let gem = Item {
        name("shining gem")
    }

    let key = Item {
        name("brass key")
    }

    /// A sack that starts open, holds a bottle — to test deep recursion when
    /// the sack itself is inside the (open) basket.
    let sack = Item {
        name("burlap sack")
        container
        openable
        startsOpen
    }

    let bottle = Item {
        name("clay bottle")
    }

    var map: WorldMap {
        player.starts(in: pantry)

        crate.starts(in: pantry)
        can.starts(inside: crate)

        jar.starts(in: pantry)
        pickle.starts(inside: jar)

        basket.starts(in: pantry)
        apple.starts(inside: basket)

        chest.starts(in: pantry)
        chest.lockedBy(key)
        gem.starts(inside: chest)

        key.startsHeld

        sack.starts(inside: basket)
        bottle.starts(inside: sack)
    }
}

/// A container that starts open via `startsOpen`, and a lockable that starts
/// unlocked via `startsUnlocked` — the "opposite defaults" fixture.
struct OpenDefaultsGame: Game {
    let title = "OpenDefaults"
    let intro = ""

    let room = Location {
        name("Room")
        description("A room.")
    }

    let box = Item {
        name("cardboard box")
        container
        openable
        startsOpen
    }

    let safe = Item {
        name("steel safe")
        container
        openable
        startsUnlocked
    }

    let dial = Item {
        name("combination dial")
    }

    var map: WorldMap {
        player.starts(in: room)
        box.starts(in: room)
        safe.starts(in: room)
        safe.lockedBy(dial)
        dial.startsHeld
    }
}

/// Invalid: places an item inside a non-container, and locks a container with
/// a "key" that is not a declared item. The bootstrap must report both.
struct BadContainerGame: Game {
    let title = "BadContainer"
    let intro = ""

    let room = Location {
        name("Room")
        description("A room.")
    }

    let rock = Item {
        name("plain rock")  // not a container
    }

    let pebble = Item {
        name("small pebble")
    }

    // A vault locked with a key that is never declared as a stored property.
    let vault = Item {
        name("stone vault")
        container
        openable
    }

    var map: WorldMap {
        player.starts(in: room)
        rock.starts(in: room)
        pebble.starts(inside: rock)  // rock is not a container
        vault.starts(in: room)
        // The key is an inline Item, never a stored property, so it is not
        // registered — the bootstrap must report the dangling lock key.
        vault.lockedBy(Item { name("phantom key") })
    }
}

/// A fixture for `putOn`'s parity guards (reachability + ancestor-chain
/// cycle). A `display shelf` (a surface) sits inside a closed transparent
/// `display case`, so the shelf is *visible* (parser resolves it) but not
/// *reachable*. A `serving tray` (also a surface) is held, and a `wooden box`
/// starts on the tray — so `put tray on box` would drop the tray onto its own
/// contents.
struct SurfaceReachGame: Game {
    let title = "SurfaceReach"
    let intro = ""

    let gallery = Location {
        name("Gallery")
        description("A quiet gallery.")
    }

    /// Transparent, openable, starts closed — holds the shelf, seen but not
    /// touched.
    let displayCase = Item {
        name("display case")
        container
        openable
        transparent
    }

    let shelf = Item {
        name("display shelf")
        surface
    }

    let coin = Item {
        name("bronze coin")
    }

    /// A held surface with a box on it, for the ancestor-chain cycle case.
    let tray = Item {
        name("serving tray")
        surface
    }

    let box = Item {
        name("wooden box")
        surface
    }

    var map: WorldMap {
        player.starts(in: gallery)

        displayCase.starts(in: gallery)
        shelf.starts(inside: displayCase)

        coin.startsHeld

        tray.startsHeld
        box.starts(on: tray)
    }
}

/// The push-to-reveal fixture named in the Task 4 brief: pushing the rug
/// reveals a hidden trap door beneath it. Uses `before(.push)` + `reply(...)`
/// rather than `after(.push)` — the after-hook alternative would print the
/// stock "You can't move that." ahead of "Moving the rug reveals a trap door
/// beneath it.", which reads as if the push failed before it actually
/// succeeded. `before` + `reply` fully replaces the default push message with
/// the authored one, which reads cleanly as a single beat.
struct RugGame: Game {
    let title = "Rug"
    let intro = ""

    let room = Location {
        name("Room")
        description("A bare room.")
    }

    let rug = Item {
        name("oriental rug")
        scenery
    }

    let trapDoor = Item {
        name("trap door")
        openable
        scenery
        hidden
    }

    var map: WorldMap {
        player.starts(in: room)
        rug.starts(in: room)
        trapDoor.starts(in: room)
    }

    var rules: Rules {
        rug.before(.push) {
            guard !trapDoor.isRevealed else { try reply("The rug has already been moved.") }
            trapDoor.reveal()
            try reply("Moving the rug reveals a trap door beneath it.")
        }
    }
}

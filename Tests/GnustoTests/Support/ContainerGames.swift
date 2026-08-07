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

/// A container and a surface that each hold one ordinary item and one fixed
/// fitting, for the room-listing rule that `scenery` means "don't list me"
/// wherever the thing is standing — not only when it is standing on the floor.
///
/// The balloon in `Sources/Dungeon/` is what wanted this: its cloth bag, its
/// receptacle and its braided wire are all named by the basket's own
/// description, and each of them was getting a line of its own underneath it.
///
/// The toolbox and the sconce carry the *other* half of the same question —
/// where the room-listing rule stops. OPEN and SEARCH enumerate what is in a
/// thing and name its fittings, which the room describer does not; the sconce
/// is the case that decides it, since a container holding nothing but fittings
/// must not answer "empty".
struct FittedBasketGame: Game {
    let title = "Fitted Basket"
    let intro = ""

    let shed = Location {
        name("Shed")
        description("A shed with a bench in it, and a sconce bolted beside the door.")
    }

    let basket = Item {
        name("wicker basket")
        container
    }

    /// Part of the basket, and named by its description rather than by a line
    /// of its own.
    let handle = Item {
        name("basket handle")
        synonyms("handle")
        description("Woven into the rim, and not coming out of it.")
        scenery
    }

    let apple = Item {
        name("red apple")
    }

    let bench = Item {
        name("workbench")
        surface
    }

    /// The same case one level up: a fitting screwed to the bench.
    let vise = Item {
        name("iron vise")
        synonyms("vise")
        description("Bolted through the bench top.")
        scenery
    }

    let hammer = Item {
        name("claw hammer")
    }

    /// Openable, and starts closed — so the same question can be put to OPEN's
    /// reveal line as to SEARCH's report.
    let toolbox = Item {
        name("tin toolbox")
        synonyms("toolbox")
        container
        openable
    }

    /// A fitting one lid deeper: riveted inside the toolbox.
    let clasp = Item {
        name("bent clasp")
        synonyms("clasp")
        description("Riveted through the lid, and going nowhere.")
        scenery
    }

    let awl = Item {
        name("steel awl")
    }

    /// A container whose only contents are fixed, for the edge SEARCH has to
    /// answer honestly.
    let sconce = Item {
        name("brass sconce")
        synonyms("sconce")
        description("Bolted to the wall, with a wick still in it.")
        container
        scenery
    }

    let wick = Item {
        name("charred wick")
        synonyms("wick")
        description("Burnt to a stub.")
        scenery
    }

    var map: WorldMap {
        player.starts(in: shed)
        basket.starts(in: shed)
        handle.starts(inside: basket)
        apple.starts(inside: basket)
        bench.starts(in: shed)
        vise.starts(on: bench)
        hammer.starts(on: bench)
        toolbox.starts(in: shed)
        clasp.starts(inside: toolbox)
        awl.starts(inside: toolbox)
        sconce.starts(in: shed)
        wick.starts(inside: sconce)
    }
}

/// A fixture for the listing channel a nested item has: an item the room
/// describes as another item's contents earns the same paragraph an item on the
/// floor does, rather than only the stock *"In the X is a Y."*
///
/// The boat label in `Sources/Dungeon/` is what wanted this. Its `presence`
/// rule had a branch for the label lying in the boat it came in, and that
/// branch could not run: the describer asked for a presence line only for the
/// things standing in the room, so a line declared for the nested position read
/// as live and silently never printed.
struct NestedListingGame: Game {
    let title = "Nested Listing"
    let intro = ""

    let workshop = Location {
        name("Workshop")
        description("A workshop with a bench along one wall.")
    }

    /// A container with no `openable`: always open.
    let crate = Item {
        name("packing crate")
        container
    }

    /// The plain case — a first-sight line, worn off by handling exactly as it
    /// is for an item on the floor.
    let scroll = Item {
        name("yellowed scroll")
        firstSight("A yellowed scroll lies curled in the crate.")
        description("Brittle, and covered in a hand you cannot read.")
    }

    /// Nested `scenery` *with* a line. `scenery` suppresses the stock listing
    /// sentence, never the author's own.
    let plaque = Item {
        name("brass plaque")
        synonyms("plaque")
        firstSight("A brass plaque is screwed to the inside of the lid.")
        description("FROBOZZ PACKING CO.")
        scenery
    }

    /// Nested `scenery` without one: silent, as it was before the channel
    /// existed.
    let nail = Item {
        name("bent nail")
        synonyms("nail")
        description("Hammered flat against the slats.")
        scenery
    }

    let bench = Item {
        name("workbench")
        surface
    }

    /// The same channel one level up, on a surface.
    let lantern = Item {
        name("dented lantern")
        firstSight("A dented lantern stands at the end of the bench.")
    }

    /// Opaque, openable, starts closed. Its contents stay out of the room
    /// listing however good their line is.
    let strongbox = Item {
        name("iron strongbox")
        container
        openable
    }

    let ledger = Item {
        name("leather ledger")
        firstSight("A leather ledger lies open in the strongbox.")
    }

    /// Two levels down: inside a sack that is itself on the bench. The
    /// describer walks one level, so this is not listed at all — the line is
    /// declared here to pin that, not because it prints.
    let sack = Item {
        name("canvas sack")
        container
    }

    let thimble = Item {
        name("silver thimble")
        firstSight("A silver thimble winks from the bottom of the sack.")
    }

    /// The boat label in miniature: one rule, two branches, and the item
    /// crosses between them without the player ever touching it.
    let tag = Item {
        name("paper tag")
        description("A tag on a string.")
    }

    let lever = Item {
        name("iron lever")
        scenery
    }

    var map: WorldMap {
        player.starts(in: workshop)

        crate.starts(in: workshop)
        scroll.starts(inside: crate)
        plaque.starts(inside: crate)
        nail.starts(inside: crate)
        tag.starts(inside: crate)

        bench.starts(in: workshop)
        lantern.starts(on: bench)
        sack.starts(on: bench)
        thimble.starts(inside: sack)

        strongbox.starts(in: workshop)
        ledger.starts(inside: strongbox)

        lever.starts(in: workshop)
    }

    var rules: Rules {
        tag.presence {
            crate.holds(tag)
                ? "A paper tag is lying inside the crate."
                : "There is a paper tag here."
        }

        lever.before(.pull) {
            tag.move(to: workshop)
            try reply("The crate tips, and the tag slides out onto the floor.")
        }
    }
}

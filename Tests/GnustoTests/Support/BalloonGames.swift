import Gnusto

/// The `Dungeon` M0 balloon spike (#133): a vehicle that rides a volcano shaft
/// **vertically**, under the player's control, on a fuel clock.
///
/// The question the spike answers is *in-game rule, new plugin, or engine
/// change?*, and this fixture is the answer in code. Note what is **not** here:
/// no `verbs` block, no plugin, no engine hook. Every beat is a stock verb and a
/// rule —
///
/// - board / disembark — the `enterable` trait and the core `.board` / `.disembark`
/// - the receptacle — a `container` placed inside the hull, reachable while aboard
/// - feed it, light it — core `.putIn`, and the `.burn` stub promoted in both forms
/// - rise, sink — a daemon calling `balloon.move(to:)`, which carries the
///   passenger and the cargo; the same shape as `Zork1`'s river current
/// - the fuel clock — one fuse, started by the fire and read by the daemon
/// - tie off — the `.tie` stub, whose `tie <thing> to <thing>` row already parses
/// - no steering, fatal exits — `before(.go)` keyed on `player.vehicle`, and `die`
///
/// The shaft is three levels — bottom, core, and the level of the narrow ledge —
/// plus the ledge itself and one room beyond it, so that reaching the ledge is
/// worth something. `Volcano Bottom` / `Volcano Core` / `Narrow Ledge` are the
/// mainframe's `VLBOT` / `VAIR1` / `LEDG2`, reduced to the smallest map that
/// still exercises every beat.
struct VolcanoGame: Game {
    let title = "Volcano"
    let intro = "A dormant shaft, a wicker basket, and one newspaper."

    let volcanoBottom = Location {
        name("Volcano Bottom")
        description("Ash underfoot, and the shaft opening wide overhead.")
    }

    let coreLow = Location {
        name("Volcano Core")
        description("Bare rock on every side. There is no floor to speak of.")
    }

    let coreLedge = Location {
        name("Volcano near small ledge")
        description("A narrow ledge juts from the west wall, near enough to step to.")
    }

    let narrowLedge = Location {
        name("Narrow Ledge")
        description("A shelf of rock halfway up the shaft. An iron hook is set into the wall.")
    }

    let library = Location {
        name("Library")
        description("Shelves, robbed long ago, and dust.")
    }

    let balloon = Item {
        name("wicker basket")
        synonyms("balloon", "basket")
        adjectives("wicker")
        description("A wicker basket under a great cloth bag, with a receptacle amidships.")
        enterable
        container
    }

    let receptacle = Item {
        name("metal receptacle")
        synonyms("receptacle")
        adjectives("metal")
        description("A shallow metal pan, sized for something that will burn.")
        container
    }

    let braidedRope = Item {
        name("braided rope")
        synonyms("rope")
        adjectives("braided")
        description("Stout rope, spliced to the basket at one end and free at the other.")
    }

    let hook = Item {
        name("iron hook")
        adjectives("iron")
        description("A hook, set deep into the ledge's rock.")
        scenery
    }

    let newspaper = Item {
        name("newspaper")
        synonyms("paper")
        description("Yesterday's news, and good for nothing else.")
    }

    let torch = Item {
        name("burning torch")
        synonyms("torch")
        adjectives("burning")
        description("Pitch and rag, burning far too well.")
        lightSource
        startsLit
    }

    let matchbook = Item {
        name("matchbook")
        synonyms("match", "matches")
        description("Three matches left in it.")
    }

    let pebble = Item {
        name("smooth pebble")
        adjectives("smooth")
    }

    /// True while the receptacle holds a fire.
    @Global var burning = false

    /// True while the rope is through the hook. A moored balloon does not drift.
    @Global var moored = false

    /// The rim line is worth saying once. Said every turn it becomes nagging,
    /// and a player who has read it already can see the ledge in the room
    /// description anyway.
    @Global var toldAboutRim = false

    /// The shaft, bottom first. The balloon's altitude is not a stored number:
    /// it is which of these rooms the balloon is in, so nothing can fall out of
    /// step with the world. `nil` means it is off the shaft entirely — resting
    /// on the ledge.
    private var shaft: [Location] { [volcanoBottom, coreLow, coreLedge] }

    var map: WorldMap {
        // The shaft has no walkable exits: the only way up or down it is the
        // balloon, and the only way off it is the ledge.
        coreLedge.west(narrowLedge)
        narrowLedge.east(coreLedge)
        narrowLedge.south(library)
        library.north(narrowLedge)

        player.starts(in: volcanoBottom)
        balloon.starts(in: volcanoBottom)
        receptacle.starts(inside: balloon)
        braidedRope.starts(inside: balloon)
        hook.starts(in: narrowLedge)
        newspaper.starts(in: volcanoBottom)
        torch.starts(in: volcanoBottom)
        matchbook.starts(in: volcanoBottom)
        pebble.starts(in: volcanoBottom)
    }

    var timers: [TimedEvent] {
        let shaft = shaft
        let balloon = balloon
        let coreLedge = coreLedge
        let newspaper = newspaper

        // The vertical daemon the charter said did not exist. It is the river
        // current with a different room list: one `move(to:)` per turn, which
        // carries the passenger and everything in the hull.
        daemon("balloonDrift", autostart: true) {
            guard !moored else { return }
            let aboard = player.vehicle == balloon
            // Asked before the move, so somebody watching from the ledge sees
            // the balloon leave rather than not-arrive.
            let watched = aboard || balloon.isVisible
            guard let level = shaft.firstIndex(where: { balloon.isIn($0) }) else {
                // Resting on the ledge. A lit burner takes it back up — but not
                // with a passenger's weight in the basket, which is the whole
                // reason the hook is there.
                guard burning else { return }
                if aboard {
                    if watched {
                        say("The bag strains upward. Only your weight is holding it down.")
                    }
                    return
                }
                balloon.move(to: coreLedge)
                if watched {
                    say("The balloon lifts off the ledge and drifts out over the shaft.")
                }
                return
            }
            if burning {
                guard level + 1 < shaft.count else {
                    if watched, !toldAboutRim {
                        toldAboutRim = true
                        say("The balloon nudges the rim and rises no further.")
                    }
                    return
                }
                toldAboutRim = false
                balloon.move(to: shaft[level + 1])
                if watched { say("The balloon rises.") }
            } else {
                guard level > 0 else { return }
                balloon.move(to: shaft[level - 1])
                if watched { say("The balloon sinks.") }
            }
            if aboard { describeSurroundings() }
        }

        // The fuel clock. Fuses fire before daemons, so the turn the paper runs
        // out is the turn the balloon starts down — sag, then sink, in that
        // order and in one turn's output.
        //
        // Seven turns is not arbitrary: two to climb the shaft, one to cross to
        // the ledge, and enough left over to tie off, step out, and *untie* —
        // so the stranding the flight is built to prevent stays reachable, and
        // provable, rather than being ruled out by the clock.
        fuse("fuelSpent", after: 7) {
            let watched = balloon.isVisible
            burning = false
            newspaper.vanish()
            if watched { say("The last of the newspaper goes to ash, and the bag sags.") }
        }
    }

    var rules: Rules {
        // Only fuel goes in the receptacle, and the torch is not fuel — it is
        // the mainframe's way of ending a flight early.
        receptacle.before(.putIn) {
            guard let fuel = command.directObject else { return }
            if fuel == torch {
                try die(
                    """
                    The torch takes the cloth of the bag before it takes anything else,
                    and the shaft turns out to be a very long way down.
                    """)
            }
            try require(fuel == newspaper, else: "That would not burn long enough to matter.")
        }

        // Promoting the `.burn` stub, in both its rows — bare `burn newspaper`
        // and `burn newspaper with match`, one intent and so one rule. Stage 4
        // would `say` its own line over the top of a `say` here, which is why a
        // promotion always ends in `reply` or `refuse`.
        newspaper.before(.burn) {
            try require(
                receptacle.holds(newspaper),
                else: "Burning it in your hands would cost you the newspaper and nothing else.")
            try require(
                command.indirectObject == matchbook,
                else: "You have nothing to set it alight with.")
            burning = true
            startFuse("fuelSpent")
            try reply("The newspaper catches, and the bag overhead begins to fill.")
        }

        // The `.tie` stub already parses `tie <thing> to <thing>`, indirect
        // object and all, so mooring costs one rule and no new grammar.
        braidedRope.before(.tie) {
            try require(
                command.indirectObject == hook,
                else: "There is nothing here to tie the rope to.")
            moored = true
            try reply("You loop the braided rope through the hook and draw it tight.")
        }

        braidedRope.before(.untie) {
            try require(moored, else: "The rope isn't tied to anything.")
            moored = false
            try reply("You lift the rope clear of the hook.")
        }

        // A balloon is not steered. The terrain-gate idiom, keyed on
        // `player.vehicle` exactly as the boat's is.
        world.before(.go) {
            guard player.vehicle == balloon else { return }
            if command.direction == .up || command.direction == .down {
                try refuse("The balloon goes where the fire takes it, not where you point.")
            }
        }

        // Landing it wrongly is fatal, and tying it off is what makes a ledge
        // safe to leave.
        //
        // On `world`, not on the balloon: bare `get out` carries no direct
        // object, so an item rule would never see it. See `ActorsAndVehicles.md`.
        world.before(.disembark) {
            guard player.vehicle == balloon else { return }
            if balloon.isIn(narrowLedge) {
                try require(
                    moored || !burning,
                    else: """
                        The balloon would lift off the moment your weight left the basket.
                        Tie it to the hook first.
                        """)
                return
            }
            guard balloon.isIn(volcanoBottom) else {
                try die(
                    """
                    You step over the side of the basket into a great deal of nothing at all.
                    The floor of the volcano arrives shortly afterward.
                    """)
            }
        }
    }
}

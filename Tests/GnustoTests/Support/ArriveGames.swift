import Gnusto

/// Fixture for the `arrive(at:)` turn helper. A hall and a vault with a
/// teleport between them that is not a door, a ledge the map keeps as one room
/// however far you walk along it, and a fuse that moves the player from outside
/// any rule at all.
///
/// The vault's `onEnter` is the point of the vault: it fires when you walk in
/// and not when you are put there, which is the caveat `arrive(at:)` documents.
struct BlinkGame: Game {
    let title = "Blink"
    let intro = "A hall, a vault, and a way between them that is not a door."

    let hall = Location {
        name("Hall")
        description("Panelled, and longer than it is wide.")
    }

    let vault = Location {
        name("Vault")
        description("Cold, and quite empty.")
    }

    /// One room, walked about inside — so a step along it reprints everything
    /// except the heading. `alwaysDescribed` because the description is the
    /// state.
    let ledge = Location {
        name("Ledge")
        description("A shelf of rock, with a long way down on one side of it.")
        alwaysDescribed
    }

    let lamp = Item { name("brass lamp") }

    var verbs: [SyntaxRule] {
        SyntaxRule("blink", intent: Intent("blink"))
        SyntaxRule("edge", intent: Intent("edge"))
        SyntaxRule("summon", intent: Intent("summon"))
    }

    var timers: [TimedEvent] {
        // `arrive` from a fuse, where `reply` would be a programmer error and
        // nothing needs to end the turn.
        fuse("recall", after: 2) {
            say("The floor tilts, and you are somewhere else.")
            arrive(at: hall)
        }
    }

    var rules: Rules {
        world.before(Intent("blink")) {
            arrive(at: vault)
            try handled()
        }

        // A step taken *within* the ledge: everything but the heading.
        ledge.before(Intent("edge")) {
            arrive(at: ledge, withRoomName: false)
            try handled()
        }

        world.before(Intent("summon")) {
            startFuse("recall")
            try reply("Something takes hold of you.")
        }

        vault.onEnter { say("A bell rings somewhere below.") }
    }

    var map: WorldMap {
        hall.north(vault)
        vault.south(hall)
        hall.east(ledge)
        ledge.west(hall)
        player.starts(in: hall)
        lamp.starts(in: vault)
    }
}

/// Fixture for the `enter(_:)` turn helper — the move that walks the player in
/// rather than putting them there. Both helpers are wired to the *same* vault so
/// one transcript can show the difference: `step` enters it and `blink` arrives
/// at it.
///
/// The rest of the rooms are each one consequence of running the destination's
/// `onEnter` rules: a ledge whose description is its state, a pit that kills, a
/// sill that refuses, and a cave with no light in it.
struct StepGame: Game {
    let title = "Step"
    let intro = "A porch, and five ways to be somewhere else."

    let porch = Location {
        name("Porch")
        description("Two boards and a bootscraper.")
    }

    /// The room that announces on arrival, which is the whole difference between
    /// the two moves.
    let vault = Location {
        name("Vault")
        description("Cold, and quite empty.")
    }

    /// Its description is its state, so every entry has to print it — the
    /// property every conversion in `Sources/Dungeon/`'s endgame leans on.
    let ledge = Location {
        name("Ledge")
        description("A shelf of rock, with a long way down on one side of it.")
        alwaysDescribed
    }

    let pit = Location {
        name("Pit")
        description("Rather deeper than it looked.")
    }

    let sill = Location {
        name("Sill")
        description("A stone lip, and a draught over it.")
    }

    let cave = Location {
        name("Cave")
        description("Dry sand, and a smell of bats.")
        dark
    }

    let lamp = Item { name("brass lamp") }

    /// Counts the vault's `onEnter` firings, so a test can prove it runs on
    /// *every* entry rather than only the first.
    @Global var bells = 0

    var verbs: [SyntaxRule] {
        SyntaxRule("step", intent: Intent("step"))
        SyntaxRule("blink", intent: Intent("blink"))
        SyntaxRule("back", intent: Intent("back"))
        // Two spellings of one intent, so a test can enter the ledge twice
        // without repeating a command — `turnOutput(of:in:)` matches the first
        // occurrence.
        SyntaxRule("shelve", intent: Intent("shelve"))
        SyntaxRule("perch", intent: Intent("shelve"))
        SyntaxRule("plunge", intent: Intent("plunge"))
        SyntaxRule("balk", intent: Intent("balk"))
        SyntaxRule("delve", intent: Intent("delve"))
        SyntaxRule("summon", intent: Intent("summon"))
        SyntaxRule("tally", intent: Intent("tally"))
    }

    var timers: [TimedEvent] {
        // `enter` from a fuse, where `reply` would be a programmer error and
        // nothing needs to end the turn.
        fuse("recall", after: 2) {
            say("The floor tilts, and you are somewhere else.")
            try enter(vault)
        }
    }

    var rules: Rules {
        world.before(Intent("step")) {
            try enter(vault)
            try handled()
        }

        world.before(Intent("blink")) {
            arrive(at: vault)
            try handled()
        }

        world.before(Intent("back")) {
            arrive(at: porch)
            try handled()
        }

        world.before(Intent("shelve")) {
            try enter(ledge)
            try handled()
        }

        world.before(Intent("plunge")) {
            try enter(pit)
            try handled()
        }

        world.before(Intent("balk")) {
            try enter(sill)
            try handled()
        }

        world.before(Intent("delve")) {
            try enter(cave)
            try handled()
        }

        world.before(Intent("summon")) {
            startFuse("recall")
            try reply("Something takes hold of you.")
        }

        world.before(Intent("tally")) {
            try reply("Bells: \(bells).")
        }

        vault.onEnter {
            bells += 1
            say("A bell rings somewhere below.")
        }

        pit.onEnter { try die("The floor was a courtesy.") }

        sill.onEnter { try refuse("The draught pushes you back.") }
    }

    var map: WorldMap {
        porch.north(vault)
        vault.south(porch)
        player.starts(in: porch)
        lamp.starts(in: vault)
    }
}

/// Fixture for the half of `enter(_:)` that `arrive(at:)` cannot do: carrying a
/// boarded vehicle, and its cargo with it. `ferry` enters the island and `drift`
/// arrives at it, so one transcript shows the raft coming along and being left
/// behind.
struct FerryGame: Game {
    let title = "Ferry"
    let intro = "A slip, an island, and one raft between them."

    let slip = Location {
        name("Slip")
        description("A concrete ramp into the water.")
    }

    let island = Location {
        name("Island")
        description("Sand enough for two gulls.")
    }

    let raft = Item {
        name("red raft")
        adjectives("red")
        enterable
        container
    }

    let pebble = Item {
        name("smooth pebble")
        adjectives("smooth")
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("ferry", intent: Intent("ferry"))
        SyntaxRule("drift", intent: Intent("drift"))
    }

    var rules: Rules {
        world.before(Intent("ferry")) {
            try enter(island)
            try handled()
        }

        world.before(Intent("drift")) {
            arrive(at: island)
            try handled()
        }
    }

    var map: WorldMap {
        slip.north(island)
        island.south(slip)
        player.starts(in: slip)
        raft.starts(in: slip)
        pebble.starts(inside: raft)
    }
}

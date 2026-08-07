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
            try reply("")
        }

        // A step taken *within* the ledge: everything but the heading.
        ledge.before(Intent("edge")) {
            arrive(at: ledge, withRoomName: false)
            try reply("")
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

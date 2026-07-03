import Gnusto

/// A fixture for fuse/daemon mechanics: a bomb fuse the player primes and
/// defuses, a drip daemon summoned and banished, plus takable clutter and a
/// scenery boulder for refused-turn and `take all` tick discipline.
struct ClockGame: Game {
    let title = "Clock"
    let intro = "The workshop ticks."

    let workshop = Location {
        name("Workshop")
        description("Gears everywhere.")
    }

    let boulder = Item {
        name("granite boulder")
        scenery
    }

    let cog = Item { name("brass cog") }
    let spring = Item { name("coiled spring") }
    let widget = Item { name("dull widget") }

    var map: WorldMap {
        player.starts(in: workshop)
        boulder.starts(in: workshop)
        cog.starts(in: workshop)
        spring.starts(in: workshop)
        widget.starts(in: workshop)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("prime", intent: Intent("prime"))
        SyntaxRule("shortprime", intent: Intent("shortprime"))
        SyntaxRule("defuse", intent: Intent("defuse"))
        SyntaxRule("summon", intent: Intent("summon"))
        SyntaxRule("banish", intent: Intent("banish"))
        SyntaxRule("probe", intent: Intent("probe"))
    }

    var rules: Rules {
        world.before(Intent("prime")) {
            startFuse("bomb")
            try reply("You prime the bomb.")
        }
        world.before(Intent("shortprime")) {
            startFuse("bomb", after: 1)
            try reply("You prime the bomb on a short fuse.")
        }
        world.before(Intent("defuse")) {
            stopFuse("bomb")
            try reply("Defused.")
        }
        world.before(Intent("summon")) {
            startDaemon("drip")
            try reply("Summoned.")
        }
        world.before(Intent("banish")) {
            stopDaemon("drip")
            try reply("Banished.")
        }
        world.before(Intent("probe")) {
            try reply("Remaining: \(fuseRemaining("bomb").map(String.init) ?? "none")")
        }
    }

    var timers: [TimedEvent] {
        fuse("bomb", after: 3) {
            say("The bomb goes off!")
        }
        daemon("drip") {
            say("Drip.")
        }
    }
}

/// Autostarted timers: a heartbeat daemon running from turn one and a dawn
/// fuse that fires on its own schedule, no rule involved. The doom fuse ends
/// the game, proving a fatal fuse stops the daemons behind it that turn.
struct HeartbeatGame: Game {
    let title = "Heartbeat"
    let intro = "A quiet room with a pulse."

    let room = Location {
        name("Quiet Room")
        description("Nothing here but the sound.")
    }

    var map: WorldMap {
        player.starts(in: room)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("doom", intent: Intent("doom"))
    }

    var rules: Rules {
        world.before(Intent("doom")) {
            startFuse("doom", after: 1)
            try reply("The countdown starts.")
        }
    }

    var timers: [TimedEvent] {
        daemon("heartbeat", autostart: true) {
            say("Thump.")
        }
        fuse("dawn", after: 2, autostart: true) {
            say("Dawn breaks.")
        }
        fuse("doom", after: 9) {
            say("Doom arrives.")
            try end(won: false)
        }
    }
}

/// Invalid timer declarations: a duplicate name and a fuse with a zero count,
/// both fatal, reported together.
struct BadTimersGame: Game {
    let title = "Bad Timers"
    let intro = "Should never boot."

    let room = Location { name("Room") }

    var map: WorldMap {
        player.starts(in: room)
    }

    var timers: [TimedEvent] {
        fuse("dup", after: 2) {}
        daemon("dup") {}
        fuse("zero", after: 0) {}
    }
}

import Gnusto

/// A fixture for death mechanics: taking the poison kills instantly (a
/// stage-3 rule), `beckon` summons a reaper daemon that kills at the end of
/// the same turn (the tick path), and the whisper daemon runs every turn —
/// proving a fatal timer stops the timers behind it. The apple and bread
/// bracket the poison alphabetically for the take-all death test.
struct MorgueGame: Game {
    let title = "Morgue"
    let intro = "Cold tile, one table."

    let slabRoom = Location {
        name("Slab Room")
        description("Everything here is scrubbed and labeled.")
    }

    let apple = Item { name("crisp apple") }
    let poison = Item { name("green poison") }
    let bread = Item { name("stale bread") }

    var map: WorldMap {
        player.starts(in: slabRoom)
        apple.starts(in: slabRoom)
        poison.starts(in: slabRoom)
        bread.starts(in: slabRoom)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("beckon", intent: Intent("beckon"))
    }

    var rules: Rules {
        poison.before(.take) {
            try die("Ill-advised. The world goes dark.")
        }
        world.before(Intent("beckon")) {
            startDaemon("reaper")
            try reply("You beckon.")
        }
    }

    var timers: [TimedEvent] {
        daemon("reaper") {
            try die("The reaper collects.")
        }
        daemon("whisper", autostart: true) {
            say("A whisper.")
        }
    }
}

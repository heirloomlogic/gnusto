import Gnusto

/// Fixture for the built-in `wait` verb: a kettle fuse primed on turn one
/// that boils after three ticks. Because `wait` is a normal turn (not meta),
/// three waits must tick the fuse to zero and boil the kettle — that's the
/// whole point of the verb.
struct KettleGame: Game {
    let title = "Kettle"
    let intro = "A kettle sits on the hob, warming."

    let kitchen = Location {
        name("Kitchen")
        description("Warm, with a kettle on the hob.")
    }

    var map: WorldMap {
        player.starts(in: kitchen)
    }

    var timers: [TimedEvent] {
        fuse("kettle", after: 3, autostart: true) {
            say("The kettle boils.")
        }
    }
}

/// The same kettle, but the `timePasses` line is re-skinned — proving the
/// wait line is a `GameText` value a game can restyle.
struct QuietKettleGame: Game {
    let title = "Quiet Kettle"
    let intro = "A kettle, and a great stillness."

    let kitchen = Location {
        name("Kitchen")
        description("Warm, with a kettle on the hob.")
    }

    var text: GameText {
        var text = GameText()
        text.timePasses = "A moment slips by."
        return text
    }

    var map: WorldMap {
        player.starts(in: kitchen)
    }
}

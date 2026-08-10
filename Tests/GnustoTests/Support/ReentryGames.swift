import Gnusto

/// Fixture for the half of issue #223's guard that must *not* fire: a live
/// `describe { }` entered over and over, turn after turn.
///
/// The distinction the guard has to draw is nesting versus frequency. Sixty-three
/// sites across the demo games call `describeSurroundings()` from `before`,
/// `after` and daemon bodies, none of which run inside a live-text closure — so
/// each is depth 1, and a counter that measured calls per turn rather than depth
/// would condemn every one of them by the fifth turn.
struct EchoGame: Game {
    let title = "Echo"
    let intro = "A gallery that answers every turn."

    let gallery = Location { name("Gallery") }

    var rules: Rules {
        // The guarded seam itself, entered twice a turn for twenty turns.
        gallery.describe { "Hung with nothing at all." }

        // Runs after every turn, the closure above already returned —
        // sequential, not nested. The counter must be back at zero by now.
        gallery.afterEachTurn {
            say("The gallery answers.")
            describeSurroundings()
        }
    }

    var map: WorldMap {
        player.starts(in: gallery)
    }
}

/// Fixture for legitimate nesting: a chain of rooms that passes the player
/// along, each `onEnter` walking them into the next.
///
/// This is the deepest real case the cap is sized against — the issue puts it
/// "under five" — so the guard has to tolerate it rather than mistake a slide
/// for a runaway. Walking north from the mouth cascades through three chutes and
/// lands in the sump, which forwards nobody.
struct SlideGame: Game {
    let title = "Slide"
    let intro = "A mouth, three chutes, and whatever is at the bottom."

    let mouth = Location {
        name("Mouth")
        description("A hole in the rock, worn smooth at the lip.")
    }

    let firstChute = Location {
        name("First Chute")
        description("Too steep to stand in.")
    }

    let secondChute = Location {
        name("Second Chute")
        description("Steeper.")
    }

    let thirdChute = Location {
        name("Third Chute")
        description("Steepest.")
    }

    let sump = Location {
        name("Sump")
        description("Level ground, and a smell of standing water.")
    }

    var rules: Rules {
        firstChute.onEnter { try enter(secondChute) }
        secondChute.onEnter { try enter(thirdChute) }
        thirdChute.onEnter {
            say("You come to rest.")
            try enter(sump)
        }
    }

    var map: WorldMap {
        mouth.north(firstChute)
        player.starts(in: mouth)
    }
}

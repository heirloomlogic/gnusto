import Gnusto

/// The fixture for ``alwaysDescribed`` (issue #149): a room whose description
/// *is* its state.
///
/// A room is described in full the first time the player walks in and briefly
/// on every entry after — its name and what lies in it, but not its long
/// description, because the player has already read it. That is right for a
/// room made of stone and wrong for a room the player is rewriting. UNDO,
/// RESTORE and walking back in through an exit all re-describe as an *entry*,
/// so the readout silently stops printing and the player gets a bare heading.
///
/// The `chamber` declares the trait and the `landing` deliberately does not, so
/// the trait and its control sit one move apart in a single transcript. The
/// warning case — the trait on a room with nothing to un-hide — is
/// `EmptyStateRoomGame` in `TestGames.swift`.
struct DialRoomGame: Game {
    let title = "The Dial Room"
    let intro = "A landing, and a room that keeps changing its mind."

    /// The whole of the chamber's state, and the whole of its description.
    @Global var notch = 0

    /// The description is the state, so it has to print on every entry.
    let chamber = Location {
        name("Dial Room")
        alwaysDescribed
    }

    /// The control: an ordinary room with an ordinary description, which goes
    /// quiet on a revisit exactly as it should.
    let landing = Location {
        name("Landing")
        description("Scrubbed bare, and longer than it is wide.")
    }

    /// Declared so the noun the chamber's description prints is answerable.
    let brassDial = Item {
        name("brass dial")
        description("A brass dial, notched round its rim and stiff to the hand.")
        scenery
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("notch", intent: Intent("notch"))
    }

    var map: WorldMap {
        landing.north(chamber)
        chamber.south(landing)
        player.starts(in: landing)
        brassDial.starts(in: chamber)
    }

    var rules: Rules {
        chamber.describe {
            "A round room, and set into it a brass dial standing at notch \(notch)."
        }

        // Turning the dial is not travel, so the re-describe drops the heading
        // — see `ArriveTests`, which is where that half of #149 is pinned.
        chamber.before(Intent("notch")) {
            notch += 1
            say("The dial clicks round one notch.")
            describeSurroundings(withRoomName: false)
            try reply("")
        }
    }
}

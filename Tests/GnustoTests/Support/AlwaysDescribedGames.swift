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
            try handled()
        }
    }
}

/// ``alwaysListed`` — the item-side twin of ``alwaysDescribed``, and the
/// fixture for it (#329).
///
/// An item's listing paragraph normally stops at the first touch, which is
/// right for a thing whose entrance is news exactly once and wrong for a thing
/// whose paragraph *is* its state. Dungeon's balloon is the site: its
/// `presence { }` rule reports the bag, the fire and the wire, and `board`
/// marks the basket touched — so from the first time anybody climbed in, an
/// inflated burning balloon and a cold deflated one printed the same stock
/// sentence.
///
/// Two braziers here, alike in everything but the trait, so one transcript
/// carries both the claim and its control. `turn on` is the handle because it
/// sets `touched` and leaves the thing standing in the room, which is the
/// shape `board` has and TAKE does not.
struct BrazierRoomGame: Game {
    let title = "The Brazier Room"
    let intro = "Two braziers, and only one of them keeps talking."

    let hall = Location {
        name("Hall")
        description("A bare hall with two braziers in it.")
    }

    /// The one under test.
    let ironBrazier = Item {
        name("iron brazier")
        adjectives("iron")
        scenery
        lightSource
        alwaysListed
    }

    /// The control, identical but for the trait.
    let stoneBrazier = Item {
        name("stone brazier")
        adjectives("stone")
        scenery
        lightSource
    }

    var map: WorldMap {
        player.starts(in: hall)
        ironBrazier.starts(in: hall)
        stoneBrazier.starts(in: hall)
    }

    var rules: Rules {
        ironBrazier.presence {
            ironBrazier.isLit ? "The iron brazier is burning." : "The iron brazier stands cold."
        }
        stoneBrazier.presence {
            stoneBrazier.isLit ? "The stone brazier is burning." : "The stone brazier stands cold."
        }
    }
}

/// The bootstrap complaint: ``alwaysListed`` on an item with no listing line
/// has nothing to keep, and the transcript reads the same with the trait and
/// without it. (#329)
struct MuteAlwaysListedGame: Game {
    let title = "The Mute Fixture"
    let intro = "A trait with nothing to hold on to."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    /// No `firstSight(…)` and no `presence { }`, so the flag is inert.
    let sconce = Item {
        name("sconce")
        alwaysListed
    }

    /// The control: a listing line of its own, so it is not implicated.
    let lantern = Item {
        name("lantern")
        firstSight("A lantern hangs from a nail.")
        alwaysListed
    }

    var map: WorldMap {
        player.starts(in: hall)
        sconce.starts(in: hall)
        lantern.starts(in: hall)
    }
}

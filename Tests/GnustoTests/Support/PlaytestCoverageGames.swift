import Gnusto

/// Three rooms, one fuse, one daemon, and the egg in miniature — the fixture
/// the coverage ledger's arithmetic is pinned against.
///
/// Everything in it is here for one assertion, because coverage arithmetic is
/// the one part of the play-test server that can be subtly wrong while looking
/// right:
///
/// - **A climbable thing holding a takeable thing that lies once you take it.**
///   `oak` reads as climbable; `nest` is only named by examining the oak;
///   `pebble` is only named by examining the nest, and its description claims it
///   is *tucked into the nest* whatever the player has done with it. That is the
///   egg: `take pebble` then `x pebble` is a two-channel defect, and nothing
///   finds it unless something insists on the second look. `restate:` is that
///   insistence, and this fixture is where the insistence is checked.
/// - **A noun a room description prints with nothing behind it.** The Yard's
///   description names *grout*, and no item answers to the word. A tester handed
///   the vocabulary would never type it; one going by the prose types it and
///   finds the hole — which is the whole argument for the firewall, made small
///   enough to assert on.
/// - **A room reachable only by a direction the prose names.** The Yard says a
///   gap leads south, so `exit:south@Yard` is an item until somebody goes that
///   way, and the Lane is unnameable until they do.
/// - **A fuse and a daemon**, so the timer detection has something real to find
///   — and so a session that never stands still leaves them undiscovered rather
///   than being handed a timer roster.
struct AviaryGame: Game {
    let title = "Aviary"
    /// Noun-free, though it no longer has to be. This once read "deliberately
    /// noun-free … an intro that named things would put them in it", which was
    /// a workaround for the opening harvest filing the blurb's nouns under the
    /// starting room. That is fixed at the source now — ``BlurbGame`` is the
    /// fixture that pins it — and this stays plain only so the exact-set
    /// assertion below reads as one thing.
    let intro = "Look at everything twice."

    let yard = Location {
        name("Yard")
        description(
            """
            A walled yard. The brickwork is old and the grout between the bricks
            is crumbling. An oak stands against the north wall, and a gap in the
            wall leads south.
            """)
    }

    let shed = Location {
        name("Shed")
        description("A lean-to with a bench and nothing on it.")
    }

    /// Reachable only through the gap. Nothing but the Yard's description says
    /// so, which is the point.
    let lane = Location {
        name("Lane")
        description("A cinder lane running past the wall.")
    }

    let oak = Item {
        name("oak")
        synonyms("tree")
        description("A broad oak, easy enough to climb. A nest sits in the crook of a branch.")
        scenery
    }

    let nest = Item {
        name("nest")
        description("A cup of twigs and moss. Something pale is tucked into it.")
        container
        scenery
    }

    /// The egg in miniature. The description is deliberately stale: it says
    /// where the pebble was found rather than where it is, so a tester that
    /// takes it and looks again reads a false sentence — and a tester that never
    /// looks again does not.
    let pebble = Item {
        name("pale pebble")
        adjectives("pale", "smooth")
        synonyms("stone")
    }

    let bench = Item {
        name("bench")
        description("A plank on two blocks.")
        scenery
    }

    var rules: Rules {
        pebble.describe { "A smooth pebble, pale as an egg. It is tucked into the nest." }
    }

    var map: WorldMap {
        yard.north(shed)
        yard.south(lane)
        shed.south(yard)
        lane.north(yard)

        player.starts(in: yard)
        oak.starts(in: yard)
        nest.starts(in: yard)
        pebble.starts(inside: nest)
        bench.starts(in: shed)
    }

    var timers: [TimedEvent] {
        fuse("bell", after: 2, autostart: true) {
            say("A bell rings somewhere behind the wall.")
        }
        daemon("wind", autostart: true) {
            guard player.location == yard, player.moves % 3 == 0 else { return }
            say("Something stirs overhead.")
        }
    }
}

/// A game whose intro sets a scene the player is not standing in.
///
/// `begin()` prints three things at once — the intro, the banner and the first
/// room — and only the last of them is *about* where the player is. This
/// fixture exists to pin that seam. `cathedral`, `harbour` and `plague` are
/// named by the blurb and by nothing in the Doorway, so a queue offering them
/// is sending a tester to examine scenery that is not there, and then inviting
/// it to file the resulting "you can't see any such thing" as a printed noun
/// the parser denies.
///
/// ``AviaryGame`` cannot catch this: its intro is deliberately noun-free, which
/// was the workaround for exactly this behaviour rather than a fix for it.
struct BlurbGame: Game {
    let title = "Blurb"
    let intro = "A cathedral burned in the harbour city, and the plague came after."

    let doorway = Location {
        name("Doorway")
        description("A stone doorway. A lantern hangs from a hook.")
    }

    let lantern = Item {
        name("lantern")
        scenery
    }

    var map: WorldMap {
        player.starts(in: doorway)
        lantern.starts(in: doorway)
    }
}

/// Two rooms under one display name.
///
/// Dungeon's seven rooms called "Coal Mine", shrunk to the two it takes to
/// prove the point: a coverage record keyed on the *display name* charges a
/// tester who walked all seven with one room.
/// ``PlaytestSession/Closing/roomsVisited`` has what that cost, and
/// `closing.json`'s copy of it is what this fixture pins.
struct CoalMineGame: Game {
    let title = "Coal Mine"
    let intro = "The passages here all look alike."

    let upperMine = Location {
        name("Coal Mine")
        description("A non-descript part of a coal mine. A passage leads north.")
    }

    let lowerMine = Location {
        name("Coal Mine")
        description("A non-descript part of a coal mine. A passage leads south.")
    }

    var map: WorldMap {
        upperMine.north(lowerMine)
        lowerMine.south(upperMine)

        player.starts(in: upperMine)
    }
}

/// A room reached by a verb rather than by an exit.
///
/// Dungeon has eight of these — the balloon flight, the bank curtain, the river
/// current, the cage drop — and they are why the coverage record credits work
/// to the room a line was *typed* in rather than the room it ended in. Crediting
/// the destination files the climb under the branch and leaves the ground it was
/// climbed from looking untouched.
///
/// `perch` is on no exit table, so it is also this suite's one declared room
/// nothing leads to, which is the other half of the same fault.
struct ClimbGame: Game {
    let title = "Climb"
    let intro = "There is a way up that is not a direction."

    let ground = Location {
        name("Ground")
        description("Beaten earth under a broad beech. Nothing leads anywhere.")
    }

    let perch = Location {
        name("Perch")
        description("A fork in the beech, high enough to see over the wall.")
    }

    let beech = Item {
        name("beech")
        synonyms("tree")
        scenery
    }

    var rules: Rules {
        beech.before(.climb) {
            arrive(at: perch)
            try handled()
        }
    }

    var map: WorldMap {
        player.starts(in: ground)
        beech.starts(in: ground)
    }
}

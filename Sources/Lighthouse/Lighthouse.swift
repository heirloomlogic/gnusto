import Gnusto
import GnustoActors
import GnustoScoring

extension Intent {
    /// A custom verb so the player can speak to the keeper. The engine has no
    /// built-in `talk`; `#verb` declares the intent and both sentence shapes the
    /// parser accepts ("talk to keeper" and the terser "talk keeper"). The
    /// `verbs` block below lists it and a rule answers it — the three beats of a
    /// custom verb.
    #verb("talk", ["talk", "to", .directObject], ["talk", .directObject])
}

/// *The Lighthouse* — the engine's feature-tour example. Where
/// ``/CloakOfDarkness`` is the minimal acceptance benchmark and `Zork1` is the
/// full reconstruction, this sits between them: one small, winnable game whose
/// every piece exists to show an idiom an author reaches for early —
///
/// - **containers & surfaces**: the storeroom `chest` and the base `shelf`,
/// - **doors & locks**: the `storeroomDoor`, locked by the `brassKey`,
/// - **a fuse**: the `oilLamp` burning down (relighting restarts it),
/// - **a daemon**: the rising `tide` that eventually floods the jetty,
/// - **an actor**: the roaming `keeper`, moved by the `GnustoActors` plugin,
/// - **`@Global` state**: `tideStage` and `keeperGreeted`,
/// - **plugins**: `GnustoActors` and `GnustoScoring`,
/// - **a content bundle**: the ``Tower``, which owns the Lamp Room and beacon.
///
/// A full winning playthrough and each feature in isolation are exercised by
/// `LighthouseTranscriptTests`.
struct Lighthouse: Game {
    let title = "The Lighthouse"
    let tagline = "Relight the beacon before the tide comes in."
    /// The two scored events: reaching the storeroom (5) and relighting the
    /// beacon (20). `maxScore` is the author's to total — the engine reads it at
    /// bootstrap, before any scoring rule can run.
    let maxScore = 25
    let intro = """
        The keeper's boat brought you out on the last of the ebb, and already
        the sea is turning. The lighthouse stands dark above the jetty — and a
        dark lighthouse is how ships are lost.
        """

    // MARK: - Rooms

    /// The starting room, and the one the tide threatens. Its look-text is a
    /// live ``Location/describe(_:)`` that reads the `tideStage` `@Global`, so
    /// the prose rises with the water.
    let jetty = Location {
        name("Jetty")
    }

    let base = Location {
        name("Base of the Lighthouse")
        description(
            """
            The round stone room at the foot of the tower. A shelf is set into
            the wall, stairs climb into the dark above, and a stout door leads
            east to the storeroom. The jetty is back to the south.
            """)
    }

    let storeroom = Location {
        name("Storeroom")
        description(
            """
            A cramped space that smells of tar and brine. Coils of rope and a
            heavy chest fill most of it. The only door is back to the west.
            """)
    }

    // MARK: - Things

    /// A `surface` (the parser accepts "put … on shelf"; the key rests on it)
    /// and `scenery`, so it stays part of the room rather than something to cart
    /// around.
    let shelf = Item {
        name("stone shelf")
        firstSight("A brass key lies on the stone shelf.")
        surface
        scenery
    }

    let brassKey = Item {
        name("brass key")
        description("A stubby brass key, green at the teeth.")
    }

    /// A door is just an `openable` item named as the gate on an exit (see the
    /// `map` block). Locked shut until the `brassKey` works it. The leading word
    /// of a name is already an adjective and the last word the noun, so "stout"
    /// is all this needs to add — the parser knows "storeroom" and "door" from
    /// the name.
    let storeroomDoor = Item {
        name("storeroom door")
        adjectives("stout")
        openable
        scenery
    }

    /// A `container` with a lid (`openable` ⇒ starts closed). It holds the lamp
    /// and the oil.
    let chest = Item {
        name("heavy chest")
        adjectives("wooden")
        description("A brine-swollen sea chest with an iron clasp.")
        container
        openable
    }

    /// The portable `lightSource`. It starts unlit inside the chest; lighting it
    /// starts the burn-down fuses below.
    let oilLamp = Item {
        name("oil lamp")
        synonyms("lantern")
        description("A dented brass lamp with a stub of wick. It sloshes — still some oil in it.")
        lightSource
    }

    let oilCan = Item {
        name("oil can")
        adjectives("tin")
        synonyms("oilcan")
        description("A tin can heavy with lamp oil.")
    }

    // MARK: - People

    /// The one other soul in the game. Declared like an item, stored like one,
    /// but listed as a person and given a standing `firstSight` line. The
    /// `GnustoActors` plugin moves her between rooms (see `timers`); a rule below
    /// answers when the player talks to her.
    let keeper = Actor {
        name("lighthouse keeper")
        adjectives("old")
        synonyms("woman", "her")
        firstSight("The old keeper stands by the window, favoring one leg.")
    }

    // MARK: - Bundles & plugins

    /// The tower's rooms and the beacon live in their own ``GameContent``
    /// bundle; the host wires the stairs that reach it and the puzzle that spans
    /// the two (relighting needs the oil found down here).
    let tower = Tower()

    /// Treasure/event scoring, a `GameContent` plugin. Added to `content`; its
    /// awards are spliced into `rules` below.
    let scoring = Scoring()

    /// NPC behavior (roaming), a logic-only `GamePlugin`. It owns no state — the
    /// keeper's position *is* her placement — so the host splices its factories
    /// into its own `timers`.
    let actors = ActorBehaviors()

    // MARK: - State

    /// How far the tide has come in. Bumped every turn by the `tide` daemon and
    /// read by the jetty's live description — a plain piece of custom world
    /// state that saves and restores with everything else.
    @Global var tideStage = 0

    /// Whether the keeper has given her one-time briefing yet.
    @Global var keeperGreeted = false

    // MARK: - Content

    var content: GameContents {
        tower
        scoring
    }

    // MARK: - Map

    var map: WorldMap {
        // The storeroom door: an openable item shared on the exit both ways,
        // locked until the brass key works it.
        storeroomDoor.lockedBy(brassKey)
        base.east(storeroom, via: storeroomDoor)
        storeroom.west(base, via: storeroomDoor)

        // Ordinary exits, plus the cross-bundle stairs up into the Tower bundle.
        jetty.north(base)
        base.south(jetty)
        base.up(tower.lampRoom)
        tower.lampRoom.down(base)

        // Initial placement.
        player.starts(in: jetty)
        keeper.starts(in: base)
        shelf.starts(in: base)
        brassKey.starts(on: shelf)
        chest.starts(in: storeroom)
        oilLamp.starts(inside: chest)
        oilCan.starts(inside: chest)
    }

    // MARK: - Vocabulary

    var verbs: [SyntaxRule] {
        .talk
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        // A daemon: the rising tide, ticking at the end of every turn. Time
        // passes wherever the player is, but the sea only threatens on the
        // jetty — stand there too long and it closes over you.
        daemon("tide", autostart: true) {
            tideStage += 1
            guard player.location == jetty else { return }
            switch tideStage {
            case 1, 2:
                say("Cold water sluices between the planks of the jetty.")
            case 3:
                say("The tide is coming in fast now — the jetty is awash to your ankles.")
            default:
                try die("The sea closes over the jetty, and over you.")
            }
        }

        // Two fuses that burn the lamp down: a warning flicker, then out. They
        // are started (and restarted) when the lamp is lit and stopped when it
        // is doused — the classic Zork lantern shape. A fuller model would bank
        // the remaining fuel on turn-off; here a clean restart keeps the idiom
        // legible.
        fuse("lampDims", after: 6) {
            if oilLamp.isLit {
                say("The oil lamp's flame sinks to a sullen flicker.")
            }
        }
        fuse("lampDies", after: 9) {
            oilLamp.isLit = false
            say("The oil lamp gutters, and goes out.")
        }

        // The keeper roams between the base and the lamp room, moved by the
        // plugin's daemon. She's silent in the dark or a room away; her draws
        // come from the seeded stream, only when she might actually be seen.
        actors.roams(
            keeper,
            daemonName: "keeperRoams",
            rooms: [base, tower.lampRoom],
            chancePerTurn: 40,
            arrival: "The keeper climbs stiffly into the room.",
            departure: "The keeper limps away up the stairs.")
    }

    // MARK: - Rules

    var rules: Rules {
        // The jetty's live description reads the tide `@Global`.
        jetty.describe {
            let body = """
                A short stone jetty runs out from the foot of the lighthouse to
                the mooring where the boat is tied.
                """
            switch tideStage {
            case 0:
                return body + " The tide is low, the boards dry underfoot."
            case 1, 2:
                return body + " Water is beginning to lap over the far boards."
            default:
                return body + " The sea is nearly over the boards — no time left."
            }
        }

        // Talking to the keeper: a one-time briefing, then a shorter reminder.
        // Reads and writes the `keeperGreeted` `@Global`.
        keeper.before(.talk) {
            guard !keeperGreeted else {
                try reply(
                    """
                    "Key's on the shelf, oil's in the chest," the keeper says
                    again, patient as tide. "Light her before the water's full in."
                    """)
            }
            keeperGreeted = true
            try reply(
                """
                The old keeper turns from the window. "Storm doused the beacon
                and my leg's no good for the stairs," she says. "The storeroom
                key's on the shelf yonder; the oil's in the chest inside. Light
                her again before the tide's full in, would you?"
                """)
        }

        // Lamp fuel: start the burn on lighting, stop it on dousing.
        oilLamp.after(.turnOn) {
            startFuse("lampDims")
            startFuse("lampDies")
        }
        oilLamp.after(.turnOff) {
            stopFuse("lampDims")
            stopFuse("lampDies")
        }

        // The winning move, and a cross-bundle seam: lighting the beacon (a
        // Tower item) depends on the oil found down here, so the host owns it.
        tower.beacon.before(.turnOn) {
            try require(
                oilCan.isHeld,
                else: "The beacon's reservoir is dry. You'll want the oil from the storeroom.")
            scoring.awardOnce("beacon", points: 20)
            say(
                """
                You tip the last of the oil into the beacon's reservoir and
                touch your lamp to the wick. Flame runs along it — and the great
                beacon roars alight, its beam wheeling out across the black
                water. Far off, a ship's bell answers.
                """)
            try end(won: true)
        }

        // Scoring: reaching the storeroom pays five points, once.
        scoring.visit(storeroom, register: "storeroom", points: 5)
    }
}

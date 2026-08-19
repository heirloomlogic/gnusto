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
/// - **content bundles**: the ``Tower``, which owns the Lamp Room and beacon,
///   and ``Fixtures``, which owns the scenery every room description names.
///
/// A full winning playthrough and each feature in isolation are exercised by
/// `LighthouseTranscriptTests`.
struct Lighthouse: Game {
    let title = "The Lighthouse"
    let tagline = "Keep the light."
    /// The two scored events: reaching the storeroom (5) and relighting the
    /// beacon (20). The engine reads `maxScore` at bootstrap, before any scoring
    /// rule can run, so it stays a literal — but the bootstrap now checks it
    /// against ``scoring``'s declared award table and warns if they disagree.
    let maxScore = 25
    let intro = """
        The keeper's boat brought you out on the last of the ebb, and the sea has
        been turning since. Above the jetty the lighthouse stands dark. "A dark
        light is how ships are lost," she said on the crossing — flat, the way
        you would say the stove had gone out. Then she handed you the mooring
        line.
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
            the wall at hand height, worn smooth at one spot about the size of a
            key. The stairs climb into the dark above, each tread hollowed at the
            center, and a stout door leads east to the storeroom. The jetty is
            back to the south.
            """)
    }

    let storeroom = Location {
        name("Storeroom")
        description(
            """
            Tar, brine, and forty years of things put where they go. Coiled rope
            hangs on pegs by size, and the sea chest sits against the far wall.
            The only door is back to the west.
            """)
    }

    // MARK: - Things

    /// A `surface` (the parser accepts "put … on shelf"; the key rests on it)
    /// and `scenery`, so it stays part of the room rather than something to cart
    /// around. It carries no listing line of its own: the engine already prints
    /// *On the stone shelf is a brass key*, and that line stops the moment the
    /// key does. A `firstSight` here would say the same thing a second time on
    /// the first visit and go on saying it after the key was pocketed, because a
    /// listing line runs until its own item is touched and nothing ever touches
    /// a shelf.
    let shelf = Item {
        name("stone shelf")
        adjectives("worn")
        synonyms("ledge", "slab")
        description(
            """
            A slab set into the wall at hand height, and one spot on it is
            polished where forty years of hands have put the same key down.
            """)
        surface
        scenery
    }

    let brassKey = Item {
        name("brass key")
        synonyms("teeth")
        description("A stubby brass key, green at the teeth.")
    }

    /// A door is just an `openable` item named as the gate on an exit (see the
    /// `map` block). Locked shut until the `brassKey` works it. The leading word
    /// of a name is already an adjective and the last word the noun, so "stout"
    /// is all this needs to add — the parser knows "storeroom" and "door" from
    /// the name. The `storeroom` synonym is what makes the *noun* answer, since
    /// the base's description names the storeroom before the player has seen it.
    let storeroomDoor = Item {
        name("storeroom door")
        adjectives("stout")
        synonyms("storeroom")
        description(
            """
            Stout, salt-swollen, and hung to open inward, which is how you hang a
            door on a rock.
            """)
        openable
        scenery
    }

    /// A `container` with a lid (`openable` ⇒ starts closed). It holds the lamp
    /// and the oil.
    ///
    /// `scenery` as well, because the storeroom's own description already says
    /// where it sits: a floor listing on top of that would announce it twice, the
    /// way the shelf used to announce the key twice. Scenery also makes it a
    /// fixture, which it is — see the refusal in `rules`, which says so in the
    /// game's voice rather than the engine's.
    let chest = Item {
        name("heavy chest")
        adjectives("sea")
        synonyms("clasp", "wire", "trunk")
        description(
            """
            A brine-swollen sea chest, its clasp mended twice with copper wire —
            both times by somebody who meant it to last.
            """)
        container
        openable
        scenery
    }

    /// The portable `lightSource`. It starts unlit inside the chest; lighting it
    /// starts the burn-down fuses below.
    let oilLamp = Item {
        name("oil lamp")
        synonyms("lantern", "wick", "flame")
        description(
            """
            A dented brass lamp, its wick trimmed square — the keeper's trim. It
            sloshes; there is oil in it yet. A wick kept like this burns from the
            top every time it is lit: snuff it and strike it fresh, and it gives
            you the same stretch of light again.
            """)
        lightSource
    }

    let oilCan = Item {
        name("oil can")
        adjectives("tin")
        synonyms("oilcan", "oil", "handle")
        description("A tin can heavy with lamp oil, its handle worn bright.")
    }

    // MARK: - People

    /// The one other soul in the game. Declared like an item, stored like one,
    /// but listed as a person and given a standing `firstSight` line. The
    /// `GnustoActors` plugin moves her between rooms (see `timers`); a rule below
    /// answers when the player talks to her.
    let keeper = Actor {
        name("lighthouse keeper")
        adjectives("old")
        synonyms("woman", "her", "leg")
        description(
            """
            Small, weathered, and square-set. The bad leg is the newest thing
            about her, and she has already stopped mentioning it.
            """)
        firstSight(
            """
            The old keeper is here, her weight on the good leg, listening to the
            sea the way most people listen to a room.
            """)
    }

    // MARK: - Bundles & plugins

    /// The tower's rooms and the beacon live in their own ``GameContent``
    /// bundle; the host wires the stairs that reach it and the puzzle that spans
    /// the two (relighting needs the oil found down here).
    let tower = Tower()

    /// The scenery behind the room descriptions, in a bundle of its own so the
    /// host file stays the short read it is meant to be. Placed by this game's
    /// `map`, because the rooms it furnishes are this game's.
    let fixtures = Fixtures()

    /// Treasure/event scoring, a `GameContent` plugin. Added to `content`; its
    /// awards are spliced into `rules` below. The table is what `maxScore` is
    /// checked against, so a third award added here without touching the total
    /// is a bootstrap warning rather than a game that quietly outruns its own
    /// ceiling.
    let scoring = Scoring(awards: ["storeroom": 5, "beacon": 20])

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
        fixtures
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

        // The scenery bundle's items, placed here because these are this game's
        // rooms. A bundle's own `map` can only reach the rooms it declares.
        fixtures.sea.starts(in: jetty)
        fixtures.planks.starts(in: jetty)
        fixtures.boat.starts(in: jetty)
        fixtures.lighthouse.starts(in: jetty)
        fixtures.wall.starts(in: base)
        fixtures.stairs.starts(in: base)
        fixtures.rope.starts(in: storeroom)
        fixtures.stores.starts(in: storeroom)
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
                say(
                    """
                    The sea is at your ankles, filling the spaces between the
                    planks without hurry. It has never once needed to hurry.
                    """)
            default:
                try die(
                    """
                    The sea comes over the planks in one long push and takes you
                    with it — without malice, without much noticing. High above,
                    the tower stays dark. Forty years that light burned on every
                    tide of the year. It does not burn tonight.
                    """)
            }
        }

        // Two fuses that burn the lamp down: a warning flicker, then out. They
        // are started (and restarted) when the lamp is lit and stopped when it
        // is doused — the classic Zork lantern shape. A fuller model would bank
        // the remaining fuel on turn-off; here a clean restart keeps the idiom
        // legible.
        //
        // The state change is unconditional and the prose is not. A fuse fires
        // wherever the lamp is, and the lamp can be lit and left in a room the
        // player is not standing in — so both lines check that the flame is
        // somewhere the player could actually watch it go. `isVisible` and not
        // `isReachable`: watching is not touching, and `turn on` needed reach,
        // not possession, so the lamp can be burning in the open chest with the
        // player standing over it.
        fuse("lampDims", after: 6) {
            if oilLamp.isLit, oilLamp.isVisible {
                say("The oil lamp's flame sinks to a sullen flicker.")
            }
        }
        fuse("lampDies", after: 9) {
            // Asked before it goes out, because in the lamp room the lamp is the
            // only thing lighting it: extinguish first and the player is in the
            // dark, the lamp is out of sight, and the one line that explains the
            // blackout is the line that gets swallowed.
            let watched = oilLamp.isVisible
            oilLamp.isLit = false
            if watched {
                say("The oil lamp gutters, and goes out.")
            }
        }

        // The keeper roams between the base and the lamp room, moved by the
        // plugin's daemon. She's silent in the dark or a room away; her draws
        // come from the seeded stream, only when she might actually be seen.
        //
        // `roams` takes one arrival line and one departure line for the whole
        // room set, and this set is two rooms stacked one above the other — so
        // both lines name the stairs and neither names a direction. A line that
        // said "up the stairs" would be a lie every time she came down.
        actors.roams(
            keeper,
            daemonName: "keeperRoams",
            rooms: [base, tower.lampRoom],
            chancePerTurn: 40,
            arrival: "A slow tread on the stairs, and the keeper arrives at her own pace, the bad leg last.",
            departure: "The keeper takes to the stairs, both hands to the rail, a step at a time.")
    }

    // MARK: - Rules

    var rules: Rules {
        // The jetty's live description reads the tide `@Global`.
        jetty.describe {
            let body = """
                A short timber jetty on stone footings runs out from the foot of
                the lighthouse to the mooring where the keeper's boat rides.
                """
            switch tideStage {
            case 0:
                return "\(body) The tide is low, the planks dry underfoot."
            case 1, 2:
                return "\(body) Water is beginning to lap over the far planks."
            default:
                return "\(body) The sea stands over the planks now, and it is not going back."
            }
        }

        // Talking to the keeper: a one-time briefing, then a shorter reminder.
        // Reads and writes the `keeperGreeted` `@Global`. Neither line says where
        // she is standing or what the player is already carrying, so both stay
        // true wherever she has wandered to and however far along the player is.
        keeper.before(.talk) {
            guard !keeperGreeted else {
                try reply(
                    """
                    "Key's on the shelf, oil's in the chest," the keeper says
                    again, patient as tide. "The light's waited long enough."
                    """)
            }
            keeperGreeted = true
            try reply(
                """
                The keeper looks you over once, the way she would look over
                weather. "Storm took the light, and my leg won't take those
                stairs with an oil can in hand," she says. "Key's on the shelf.
                Lamp and oil are in the chest in the storeroom. Get her burning.
                There's boats out on this water tonight, and I know every one of
                them by her bell."
                """)
        }

        // The chest is furniture, and the storeroom's description says so. A
        // takeable one would let the player carry the room's own prose out of
        // the room.
        chest.before(.take) {
            try refuse("Brine-swollen, full of oil, and going nowhere. Take what's in it.")
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

        // Three stub verbs whose stock lines are false in this game, promoted
        // where they're wrong and left alone everywhere else. `reply`/`refuse`
        // rather than `say`, because the stage-4 default says its line — a rule
        // that only said its own would print both.
        oilCan.before(.pour, .empty) {
            try refuse("Not on the floor. That oil has one place to go tonight.")
        }
        oilLamp.before(.burn) {
            try reply("That is what it is for. Light it.")
        }
        tower.beacon.before(.burn) {
            try reply("That is the whole idea. Light it.")
        }
        jetty.before(.swim, .dive) {
            try refuse(
                """
                The sea is right there and it is coming to you. Going to meet it
                would only save it the trip.
                """)
        }

        // The winning move, and a cross-bundle seam: lighting the beacon (a
        // Tower item) depends on the oil found down here, so the host owns it.
        // The refusal names your hands rather than the storeroom, because the
        // gate is "the can is held" — a player standing over a can they set down
        // needs to be told to pick it up, not sent downstairs for it.
        tower.beacon.before(.turnOn) {
            try require(
                oilCan.isHeld,
                else: """
                    The wick takes your flame and starves on it: the reservoir is
                    dry. You'll want the oil can in hand before you try that.
                    """)
            scoring.awardOnce("beacon")
            tower.beacon.isLit = true
            say(
                """
                You tip the last of the oil into the reservoir and touch your
                lamp to the wick. Flame runs the ring — and the great beacon
                comes up roaring, its beam wheeling out across the black water.

                Far off, thin under the wind, a ship's bell answers. Then
                another, farther out. The keeper could name them both.
                """)
            try end(won: true)
        }

        // Scoring: reaching the storeroom pays five points, once.
        scoring.visit(storeroom, register: "storeroom")
    }
}

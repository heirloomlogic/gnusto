import Gnusto
import GnustoScoring

/// The underground crossroads east of the Troll Room: the East-West Passage,
/// the Deep Ravine, the Chasm, the North-South Passage, Deep Canyon, the Loud
/// Room, the Damp Cave — and, at the middle of all of it, the Round Room, which
/// in this game is a **carousel**.
///
/// **This is not Zork I's Round Room hub.** The trilogy kept the room names and
/// re-cut almost every passage between them:
///
/// - the Round Room has **nine** exits, not three, and while the machinery
///   beneath it turns, every one of them puts you somewhere else than you asked
///   for. Zork I's Round Room is an ordinary junction with cave-ins;
/// - the **Deep Ravine** is a room Zork I has no counterpart for at all, and it
///   is the junction that ties the East-West Passage, the Chasm and Reservoir
///   South together;
/// - the **Loud Room hangs off the North-South Passage**, not off the Round
///   Room, and climbs to the Damp Cave rather than to Deep Canyon;
/// - the **Damp Cave** runs south and east — east being the dam — where Zork I
///   runs it west and east and narrows it to the south;
/// - **Deep Canyon** opens east onto the dam and northwest down to Reservoir
///   South, and its third passage is the Round Room;
/// - the **Chasm** is a two-exit path (south and east), not the four-way one
///   Zork I builds.
///
/// The Loud Room's acoustics are this region's puzzle, and they are **not** the
/// dam's business here: the mainframe's `ECHO-ROOM` never reads the sluice-gate
/// flag, so the room roars from the first moment until somebody says `echo` in
/// it. Zork I is the version that couples the two. See `FIDELITY.md`.
///
/// Seams left for later milestones, and recorded in `FIDELITY.md`: five of the
/// Round Room's nine passages, the Deep Ravine's west crawl, and the Loud
/// Room's east door onto the Ancient Chasm.
struct DungeonRoundRoom: GameContent {
    // MARK: - Rooms

    /// Worth five points on first arrival — the mainframe's `RVAL`, paid by the
    /// host's `scoring.visit`.
    let eastWestPassage = Location {
        name("East-West Passage")
        description(Prose.eastWestPassage)
        dark
    }

    /// The carousel. Its description is a rule rather than a constant because
    /// it carries state: the compass line prints only while the machinery
    /// turns.
    let roundRoom = Location {
        name("Round Room")
        dark
    }

    let nsPassage = Location {
        name("North-South Passage")
        description(Prose.nsPassage)
        dark
    }

    /// Mainframe-only. Zork I merged this crossing away; here it is the way
    /// down to Reservoir South and the way east to the Chasm.
    let deepRavine = Location {
        name("Deep Ravine")
        description(Prose.deepRavine)
        dark
    }

    /// The Chasm *room* — the path along the chasm's south edge, distinct from
    /// the ``DungeonCellar`` scenery item of the same name at West of Chasm.
    let chasmRoom = Location {
        name("Chasm")
        description(Prose.chasmRoom)
        dark
    }

    let deepCanyon = Location {
        name("Deep Canyon")
        description(Prose.deepCanyon)
        dark
    }

    let loudRoom = Location {
        name("Loud Room")
        description(Prose.loudRoom)
        dark
    }

    let dampCave = Location {
        name("Damp Cave")
        description(Prose.dampCave)
        dark
    }

    // MARK: - State

    /// Whether the machinery under the Round Room is turning. It is, from the
    /// first turn: the mainframe starts with `CAROUSEL-FLIP` clear and the only
    /// thing that clears it is the triangular button in the Machine Room, which
    /// arrives with a later milestone. Until then every passage out of the
    /// Round Room is a lottery.
    @Global var carouselSpinning = true

    /// Which of ``carouselDestinations`` the spin will hand you this turn.
    /// Rolled once per `go` attempt by the rule below — one draw per attempt,
    /// as the mainframe's `CAROUSEL-OUT` does — and read by the dynamic exits,
    /// which must be pure.
    @Global var carouselTwist = 0

    /// Whether saying `echo` has settled the Loud Room's acoustics. Once set,
    /// the room stops flinging your words back and the platinum bar can be
    /// lifted.
    @Global var loudRoomAcousticsFixed = false

    // MARK: - Items

    /// The platinum bar. The mainframe pays **12** to find it and **10** to
    /// case it, where Zork I pays 10 and 5. It cannot be taken while the room
    /// roars — the original's `SACREDBIT`, cleared by `echo`.
    let platinumBar = Item {
        name("platinum bar")
        adjectives("platinum", "large")
        firstSight(Prose.platinumBarFirstSight)
        description(Prose.platinumBar)
        trait(.weight, 20)
        trait(.takeValue, 12)
        trait(.depositValue, 10)
    }

    // MARK: - Scenery

    /// The Round Room's whirring is the one thing about it a player can point
    /// at, and the Winding Passage two milestones from now names it from the
    /// far side.
    let machinery = Item {
        name("machinery")
        adjectives("unseen")
        synonyms("machine", "whirring", "whir", "floor")
        description(Prose.roundRoomMachinery)
        scenery
    }

    let eastWestStairway = Item {
        name("stairway")
        adjectives("narrow")
        synonyms("stairs", "stair", "steps")
        description(Prose.eastWestStairway)
        scenery
    }

    let ravine = Item {
        name("ravine")
        adjectives("deep")
        synonyms("steps", "staircase", "stairs", "stair", "crawlway")
        description(Prose.ravine)
        scenery
    }

    /// Named `chasmEdge` rather than `chasm` because ``chasmRoom`` — the room
    /// this scenery stands in — is the other half of the pair, and one bundle
    /// cannot spell two properties the same way. ``DungeonCellar``'s `chasm` is
    /// no constraint on this one: a bundle's entity IDs are namespaced under its
    /// type, so that one is `DungeonCellar.chasm` and this one would be
    /// `DungeonRoundRoom.chasm`.
    let chasmEdge = Item {
        name("chasm")
        synonyms("crack", "path")
        description(Prose.chasmScenery)
        scenery
    }

    let canyon = Item {
        name("canyon")
        adjectives("deep")
        synonyms("edge", "water")
        description(Prose.canyonScenery)
        scenery
    }

    let loudRoomCeiling = Item {
        name("ceiling")
        synonyms("stairway", "roar", "noise")
        description(Prose.loudRoomCeiling)
        scenery
    }

    let dampEarth = Item {
        name("earth")
        adjectives("damp")
        synonyms("ground", "dirt", "crack")
        description(Prose.dampEarth)
        scenery
    }

    /// The North-South Passage names its fork and nothing else.
    let passageFork = Item {
        name("fork")
        synonyms("passage")
        description(Prose.passageFork)
        scenery
    }

    // MARK: - Map

    var map: WorldMap {
        // East-West Passage. West is the Troll Room, a ``DungeonCellar`` room
        // gated on the troll's fall — host-wired. North and down are the same
        // staircase, which is the mainframe's own doubling.
        eastWestPassage.east(roundRoom)
        eastWestPassage.north(deepRavine)
        eastWestPassage.down(deepRavine)

        // The Round Room's own nine passages are **not** declared here. Eight of
        // them are built as of milestone 3 and they reach four different
        // bundles, so the host owns the whole carousel — its exits, its draw
        // and the list both read. See ``Dungeon``.

        // North-South Passage.
        nsPassage.north(chasmRoom)
        nsPassage.northeast(loudRoom)
        nsPassage.south(roundRoom)

        // Deep Ravine. Down is Reservoir South, a ``DungeonDam`` room —
        // host-wired. West is the Rocky Crawl, a later milestone.
        deepRavine.south(eastWestPassage)
        deepRavine.east(chasmRoom)

        // Chasm.
        chasmRoom.south(deepRavine)
        chasmRoom.east(nsPassage)
        chasmRoom.down(blocked: Prose.chasmRoomDownRefusal)

        // Deep Canyon. East is the Dam and northwest is Reservoir South, both
        // ``DungeonDam`` rooms — host-wired.
        deepCanyon.south(roundRoom)

        // Loud Room. East is the Ancient Chasm, a later milestone.
        loudRoom.west(nsPassage)
        loudRoom.up(dampCave)

        // Damp Cave. East is the Dam — host-wired.
        dampCave.south(loudRoom)
        dampCave.west(blocked: Prose.dampCaveTooNarrow)

        platinumBar.starts(in: loudRoom)
        machinery.starts(in: roundRoom)
        eastWestStairway.starts(in: eastWestPassage)
        passageFork.starts(in: nsPassage)
        ravine.starts(in: deepRavine)
        chasmEdge.starts(in: chasmRoom)
        canyon.starts(in: deepCanyon)
        loudRoomCeiling.starts(in: loudRoom)
        dampEarth.starts(in: dampCave)
    }

    // MARK: - Rules

    var rules: Rules {
        // The room's description carries the state of the machinery, so it is
        // a rule rather than a constant.
        roundRoom.describe {
            carouselSpinning
                ? "\(Prose.roundRoom)\n\n\(Prose.roundRoomCompass)"
                : Prose.roundRoom
        }

        // The Loud Room's read-loop: your voice booms and the walls fling the
        // last word back at you. Movement, looking and `echo` pass through;
        // reaching for the bar is refused by the bar's own lock below, so it
        // answers with the roar rather than with a bare echo.
        loudRoom.before {
            guard !loudRoomAcousticsFixed else { return }
            guard command.intent != .go,
                command.intent != .look,
                command.intent != .echo,
                command.intent != .take
            else { return }
            let echoed =
                command.rawInput.split(separator: " ").last.map(String.init)
                ?? command.verbPhrase
            try refuse(Prose.loudRoomEcho(echoed))
        }

        // Saying `echo` settles the acoustics for good.
        loudRoom.before(.echo) {
            guard !loudRoomAcousticsFixed else { return }
            loudRoomAcousticsFixed = true
            try reply(Prose.loudRoomAcousticsFixed)
        }

        // The bar is sacred while the room roars.
        platinumBar.before(.take) {
            try require(loudRoomAcousticsFixed, else: Prose.platinumBarTooLoud)
        }
    }
}

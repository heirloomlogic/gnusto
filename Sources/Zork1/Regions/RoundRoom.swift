import Gnusto
import GnustoScoring

/// The Round Room hub and its vicinity — the underground crossroads that the
/// later regions branch off. East of the Troll Room lies the East-West Passage
/// (worth five points on first arrival); beyond it the Round Room proper, from
/// which passages run to the North-South Passage, the Chasm, Deep Canyon, and
/// the Loud Room with its platinum bar.
///
/// Only the exits that stay *inside* this region are wired here. The passages
/// that lead onward — the Round Room's south (Narrow Passage) and southeast
/// (Engravings Cave), the Chasm's and Deep Canyon's northwest edges toward the
/// reservoir, Deep Canyon's east to the dam, and Damp Cave's east to the White
/// Cliffs — belong to regions that don't exist yet, so they're simply absent
/// (the engine's plain "you can't go that way") rather than honest stubs. The
/// Troll Room's now-open east passage is host-wired in ``Zork1`` because it
/// crosses into ``ZorkCellar``. See `FIDELITY.md`.
///
/// The Loud Room is the region's one puzzle. On still water it garbles every
/// command but movement and looking, until the player says `echo` — after
/// which the acoustics settle and the platinum bar can be taken. While the
/// dam's gates drive water through (a state the dam region owns and will set,
/// via ``waterMoving``), the room is instead too loud to bear and scrambles the
/// player out to a random neighbour. That ejection is this region's only source
/// of randomness, and it stays dormant until the dam turns the water on.
struct ZorkRoundRoom: GameContent {
    // MARK: - Rooms

    let eastWestPassage = Location {
        name("East-West Passage")
        description(Prose.eastWestPassage)
        dark
    }

    let roundRoom = Location {
        name("Round Room")
        description(Prose.roundRoom)
        dark
    }

    let nsPassage = Location {
        name("North-South Passage")
        description(Prose.nsPassage)
        dark
    }

    /// The Chasm *room* — the path along the chasm's south edge, distinct from
    /// the ``ZorkCellar`` scenery item of the same name at East of Chasm.
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

    let dampCave = Location {
        name("Damp Cave")
        description(Prose.dampCave)
        dark
    }

    let loudRoom = Location {
        name("Loud Room")
        description(Prose.loudRoom)
        dark
    }

    // MARK: - Loud Room state

    /// Whether the dam's gates are driving water through the depths. False
    /// until the dam region (a later phase) opens the sluice; while true, the
    /// Loud Room is unbearable and ejects anyone who enters.
    @Global var waterMoving = false

    /// Whether saying `echo` has quieted the Loud Room's acoustics. Once set,
    /// the room stops garbling commands and the platinum bar can be taken.
    @Global var loudRoomAcousticsFixed = false

    // MARK: - Items

    /// The platinum bar: a treasure worth ten on the find and five in the case.
    /// It can't be taken until the Loud Room's acoustics are fixed with `echo`
    /// — the original's SACREDBIT, modeled as the bar's own take-lock (the
    /// `before(.take)` rule below).
    let platinumBar = Item {
        name("platinum bar")
        adjectives("platinum", "large")
        firstSight(Prose.platinumBarFirstSight)
        description(Prose.platinumBar)
        trait(.weight, 20)  // the original's SIZE
        trait(.takeValue, 10)  // find
        trait(.depositValue, 5)  // case
    }

    // MARK: - Map

    var map: WorldMap {
        // East-West Passage. Its west exit to the Troll Room crosses into
        // ZorkCellar, so the host wires it (and gates it on the troll's fall).
        eastWestPassage.east(roundRoom)
        eastWestPassage.north(chasmRoom)
        eastWestPassage.down(chasmRoom)

        // Round Room. South (Narrow Passage) and southeast (Engravings Cave)
        // await their regions.
        roundRoom.east(loudRoom)
        roundRoom.west(eastWestPassage)
        roundRoom.north(nsPassage)

        // North-South Passage.
        nsPassage.north(chasmRoom)
        nsPassage.northeast(deepCanyon)
        nsPassage.south(roundRoom)

        // Chasm. Northeast (toward the reservoir) awaits its region; down is a
        // sheer drop the game won't let you take.
        chasmRoom.southwest(eastWestPassage)
        chasmRoom.up(eastWestPassage)
        chasmRoom.south(nsPassage)
        chasmRoom.down(blocked: Prose.chasmDownRefusal)

        // Deep Canyon. Northwest (reservoir) and east (dam) await their region.
        deepCanyon.southwest(nsPassage)
        deepCanyon.down(loudRoom)

        // Loud Room.
        loudRoom.east(dampCave)
        loudRoom.west(roundRoom)
        loudRoom.up(deepCanyon)

        // Damp Cave. East (White Cliffs) awaits its region; south narrows to an
        // impassable crack.
        dampCave.west(loudRoom)
        dampCave.south(blocked: Prose.dampCaveTooNarrow)

        platinumBar.starts(in: loudRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        // While the gates drive water through, the Loud Room is unbearable: it
        // scrambles the player out to one of three neighbours at the start of
        // the turn. The guard comes before the draw, so still-water turns never
        // touch the random stream — the dam region will exercise this path.
        loudRoom.beforeEachTurn {
            guard waterMoving else { return }
            let bounces = [dampCave, roundRoom, deepCanyon]
            say(Prose.loudRoomEjects)
            player.location = bounces[random(0...(bounces.count - 1))]
            describeSurroundings()
            try reply("")
        }

        // On still water the acoustics are the original's read-loop: your
        // voice booms and the walls fling the last word of your command back
        // at you. Movement, looking, and `echo` pass through untouched; taking
        // the platinum bar is refused by the bar's own take-lock (the
        // SACREDBIT rule below), so it answers with the roar rather than a bare
        // echo. Every other command echoes.
        loudRoom.before {
            guard !loudRoomAcousticsFixed, !waterMoving else { return }
            guard command.intent != .go,
                command.intent != .look,
                command.intent != .echo,
                command.intent != .take
            else { return }
            let echoed = command.rawInput.split(separator: " ").last.map(String.init)
                ?? command.verbPhrase
            try refuse(Prose.loudRoomEcho(echoed))
        }

        // The platinum bar is sacred while the room roars — untakeable until
        // the acoustics are fixed (the original's SACREDBIT). Saying `echo`
        // lifts the lock.
        platinumBar.before(.take) {
            try require(loudRoomAcousticsFixed, else: Prose.platinumBarTooLoud)
        }

        // Saying `echo` on still water settles the acoustics for good, so the
        // platinum bar becomes takeable. Once fixed (or when the water is
        // moving), `echo` falls through to its ordinary reply.
        loudRoom.before(.echo) {
            guard !loudRoomAcousticsFixed, !waterMoving else { return }
            loudRoomAcousticsFixed = true
            try reply(Prose.loudRoomAcousticsFixed)
        }
    }
}

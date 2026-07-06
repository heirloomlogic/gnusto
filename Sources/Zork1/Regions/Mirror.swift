import Gnusto
import GnustoScoring

/// The Mirror Rooms and their vicinity — the connective tissue of the
/// underground. Two Mirror Rooms, joined only by touching their enormous
/// mirrors, sit at the heart of a tangle of passages that finally knots the map
/// together: north through the Narrow Passage to the Round Room hub, down past
/// the Small Cave to the drowned Atlantis Room and on to the reservoir, and west
/// through the Cold Passage to a steep slide that drops one-way into the Cellar.
///
/// The two Mirror Rooms share the name "Mirror Room" (as the game's several
/// "Forest" and "Cave" rooms share theirs). Touching either mirror swaps you to
/// the other — the only passage between the map's two halves, and the reason the
/// whole underground reads as one graph once this region lands.
///
/// The seams that cross out of this region are host-wired in ``Zork1``, the same
/// way every other cross-bundle exit is: the Narrow Passage's north to the Round
/// Room, the Atlantis Room's south to the reservoir, the Slide Room's one-way
/// drop into the Cellar, and the Tiny Cave (``ZorkTemple``'s ``cave``) that the
/// mirror network reconnects to the temple complex. Everything inside the region
/// is wired here. See `FIDELITY.md`.
struct ZorkMirror: GameContent {
    // MARK: - Rooms

    let narrowPassage = Location {
        name("Narrow Passage")
        description(Prose.narrowPassage)
        dark
    }

    /// The northern Mirror Room, on the Round Room side. Naturally lit — the one
    /// exception among these dark passages (the original's `ONBIT`), so its
    /// mirror can be found and touched without a lamp. See `FIDELITY.md`.
    let mirrorRoomNorth = Location {
        name("Mirror Room")
        description(Prose.mirrorRoomNorth)
    }

    let windingPassage = Location {
        name("Winding Passage")
        description(Prose.windingPassage)
        dark
    }

    /// The southern Mirror Room, on the Atlantis side. Dark, unlike its northern
    /// twin.
    let mirrorRoomSouth = Location {
        name("Mirror Room")
        description(Prose.mirrorRoomSouth)
        dark
    }

    let coldPassage = Location {
        name("Cold Passage")
        description(Prose.coldPassage)
        dark
    }

    let twistingPassage = Location {
        name("Twisting Passage")
        description(Prose.twistingPassage)
        dark
    }

    let smallCave = Location {
        name("Cave")
        description(Prose.smallCave)
        dark
    }

    let atlantisRoom = Location {
        name("Atlantis Room")
        description(Prose.atlantisRoom)
        dark
    }

    let slideRoom = Location {
        name("Slide Room")
        description(Prose.slideRoom)
        dark
    }

    // MARK: - Items

    /// The crystal trident: a treasure worth four on the find and eleven in the
    /// case (the original's SIZE 20 / VALUE 4 / TVALUE 11).
    let crystalTrident = Item {
        name("crystal trident")
        adjectives("crystal", "poseidon")
        synonyms("trident", "fork")
        firstSight(Prose.crystalTridentFirstSight)
        description(Prose.crystalTrident)
        trait(.weight, 20)  // the original's SIZE
        trait(.takeValue, 4)  // find
        trait(.depositValue, 11)  // case
    }

    /// The enormous mirror in the northern Mirror Room. Touching it (the
    /// `before(.touch)` rule below) whisks you to the southern room.
    let mirrorNorth = Item {
        name("mirror")
        adjectives("enormous")
        synonyms("mirror", "reflection")
        description(Prose.mirror)
        scenery
    }

    /// The enormous mirror in the southern Mirror Room — touch it to return
    /// north.
    let mirrorSouth = Item {
        name("mirror")
        adjectives("enormous")
        synonyms("mirror", "reflection")
        description(Prose.mirror)
        scenery
    }

    // MARK: - Map

    var map: WorldMap {
        // Narrow Passage. Its north exit runs to the Round Room hub, which
        // crosses into ZorkRoundRoom, so the host wires it.
        narrowPassage.south(mirrorRoomNorth)

        // Northern Mirror Room. Its east opening onto the Tiny Cave (the
        // temple's ``cave``) crosses bundles, so the host wires it.
        mirrorRoomNorth.north(narrowPassage)
        mirrorRoomNorth.west(windingPassage)

        // Winding Passage. Its east exit is the Tiny Cave (host-wired).
        windingPassage.north(mirrorRoomNorth)

        // Southern Mirror Room.
        mirrorRoomSouth.north(coldPassage)
        mirrorRoomSouth.west(twistingPassage)
        mirrorRoomSouth.east(smallCave)

        // Cold Passage.
        coldPassage.south(mirrorRoomSouth)
        coldPassage.west(slideRoom)

        // Twisting Passage.
        twistingPassage.north(mirrorRoomSouth)
        twistingPassage.east(smallCave)

        // Small Cave. Both its down staircase and its south opening lead to the
        // Atlantis Room (as in the original).
        smallCave.north(mirrorRoomSouth)
        smallCave.west(twistingPassage)
        smallCave.down(atlantisRoom)
        smallCave.south(atlantisRoom)

        // Atlantis Room. Its south exit to Reservoir North crosses into ZorkDam,
        // so the host wires it.
        atlantisRoom.up(smallCave)

        // Slide Room. Its down chute drops one-way into the Cellar and its north
        // opening onto the Mine Entrance both cross bundle boundaries (into
        // ZorkHouse and ZorkCoalMine), so the host wires them.
        slideRoom.east(coldPassage)

        crystalTrident.starts(in: atlantisRoom)
        mirrorNorth.starts(in: mirrorRoomNorth)
        mirrorSouth.starts(in: mirrorRoomSouth)
    }

    // MARK: - Rules

    var rules: Rules {
        // Touching a mirror whisks the player to the other Mirror Room, the only
        // passage between the map's two halves. Deterministic — no draw. The
        // original swaps the two rooms' floor contents too and can be broken for
        // seven years' bad luck; here it moves the player (held items ride along)
        // and can't be broken (FIDELITY.md).
        mirrorNorth.before(.touch) {
            say(Prose.mirrorRumble)
            player.location = mirrorRoomSouth
            describeSurroundings()
            try reply("")
        }
        mirrorSouth.before(.touch) {
            say(Prose.mirrorRumble)
            player.location = mirrorRoomNorth
            describeSurroundings()
            try reply("")
        }
    }
}

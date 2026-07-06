import Gnusto
import GnustoScoring

/// The cellar region below the house: East of Chasm, the Gallery with its
/// painting, and the Studio whose chimney climbs back up to the kitchen.
/// Together with the lit lantern this closes the Phase-5 "dark cellar
/// soft-lock" — a sealed-in player either carries light or dashes for the
/// Gallery's daylight and the chimney. The `Cellar` room itself stays in
/// ``ZorkHouse`` (the trap door joins two rooms one bundle owns); this
/// bundle meets it through the host-wired exits in ``Zork1``. The grue that
/// makes the darkness lethal is the `DangerousDark` plugin, wired by the
/// host with this game's prose.
///
/// The troll passage north of the cellar and the maze beyond are later
/// phases — see `FIDELITY.md`.
struct ZorkCellar: GameContent {
    // MARK: - Rooms

    let eastOfChasm = Location {
        name("East of Chasm")
        description(Prose.eastOfChasm)
        dark
    }

    /// Lit, as in the original — daylight from somewhere high above. Also
    /// the resting point that makes the lightless chimney dash survivable.
    let gallery = Location {
        name("Gallery")
        description(Prose.gallery)
    }

    let studio = Location {
        name("Studio")
        description(Prose.studio)
        dark
    }

    /// North of the cellar. East now opens onto the Round Room hub once the
    /// troll falls; west toward the maze stays an honest stub until that
    /// region exists — see `FIDELITY.md`.
    let trollRoom = Location {
        name("Troll Room")
        description(Prose.trollRoom)
        dark
    }

    // MARK: - The troll

    let troll = Actor {
        name("troll")
        description(Prose.troll)
        firstSight(Prose.trollPresence)
    }

    @Global var trollDefeated = false

    // MARK: - The thief (reduced — see FIDELITY.md)

    let thief = Actor {
        name("thief")
        adjectives("shadowy")
        synonyms("figure")
        description(Prose.thief)
        firstSight(Prose.thiefPresence)
    }

    @Global var thiefDefeated = false

    // MARK: - Items

    let chasm = Item {
        name("chasm")
        description(Prose.chasm)
        scenery
    }

    let painting = Item {
        name("painting")
        adjectives("beautiful")
        firstSight(Prose.paintingFirstSight)
        description(Prose.painting)
        // The original's values: 4 for the find, 6 for the case.
        trait(.takeValue, 4)
        trait(.depositValue, 6)
    }

    let chimney = Item {
        name("chimney")
        adjectives("dark", "narrow")
        description(Prose.chimney)
        scenery
    }

    // MARK: - Map

    var map: WorldMap {
        eastOfChasm.east(gallery)
        gallery.west(eastOfChasm)
        gallery.north(studio)
        studio.south(gallery)

        chasm.starts(in: eastOfChasm)
        painting.starts(in: gallery)
        chimney.starts(in: studio)
        troll.starts(in: trollRoom)
        thief.starts(in: gallery)
    }

    var rules: Rules {
        // The troll gates the west passage: his while he lives, and a
        // collapsed stub after (the maze beyond is a later phase). The east
        // passage is now a real exit to the Round Room hub — the host wires it
        // (it crosses into ``ZorkRoundRoom``) and gates it on ``trollDefeated``.
        trollRoom.before(.go) {
            guard command.direction == .west else { return }
            guard trollDefeated else {
                try refuse(Prose.trollBlocksTheWay)
            }
            try refuse(Prose.trollRoomPassagesCollapsed)
        }
    }
}

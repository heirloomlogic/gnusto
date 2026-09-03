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
/// The Troll Room's passages — east to the Round Room hub, west into the maze —
/// are host-wired conditional exits gated on ``trollDefeated`` (see ``Zork1``).
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

    /// North of the cellar. Both the troll's passages open once he falls: east
    /// onto the Round Room hub, west down into the maze. Both crossings are
    /// host-wired (they span other bundles) and gated on ``trollDefeated``.
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

    /// The troll's bloody axe. It begins ``.nowhere`` — in his hands, out of
    /// reach while he lives — and clatters to the Troll Room floor when he falls
    /// (his `onDefeat`, host-wired in ``Zork1``). Sharp enough to hole the river
    /// boat, like the other blades.
    let axe = Item {
        name("bloody axe")
        adjectives("bloody")
        synonyms("axe", "ax")
        description(Prose.axe)
        trait(.weight, 20)
        trait(.weapon, true)
        trait(.sharp, true)
    }

    @Global var trollDefeated = false

    // The thief who once haunted this cellar now roams the whole underground:
    // his actor, weapon, and defeat flag live in ``ZorkThief``, and all his
    // behaviour is host-wired in ``Zork1``.

    // MARK: - Items

    let chasm = Item {
        name("chasm")
        description(Prose.chasm)
        scenery
    }

    let painting = Item {
        name("painting")
        adjectives("beautiful")
        // (#407) The Gallery's prose speaks of paintings; the plural noun is
        // this one and its stolen fellows.
        synonyms("paintings")
        firstSight(Prose.paintingFirstSight)
        description(Prose.painting)
        // The original's values: 4 for the find, 6 for the case.
        trait(.takeValue, 4)
        trait(.depositValue, 6)
    }

    // MARK: - (#407) scenery: nouns the room prose prints

    /// (#407) Named by `Prose.gallery` — narrative, not a fixture, but the
    /// engine's rule is that every noun a room description prints must be
    /// answerable.
    let vandals = Item {
        name("vandals")
        description(Prose.galleryVandals)
        scenery
    }

    /// (#407) Named by `Prose.studio`.
    let studioFireplace = Item {
        name("fireplace")
        description(Prose.studioFireplace)
        scenery
    }

    /// (#407) Named by `Prose.studio`.
    let studioDoor = Item {
        name("open door")
        adjectives("open")
        synonyms("door")
        description(Prose.studioDoor)
        scenery
    }

    /// (#407) Named by `Prose.studio` — the paints and the splattered walls
    /// and floors they cover are one fixture.
    let studioPaints = Item {
        name("splattered walls")
        adjectives("splattered")
        synonyms("paints", "paint", "walls", "wall", "floors", "floor")
        description(Prose.studioPaints)
        scenery
    }

    /// (#407) Named by `Prose.trollRoom`.
    let bloodstains = Item {
        name("bloodstains")
        synonyms("stains", "blood")
        description(Prose.trollBloodstains)
        scenery
    }

    /// (#407) Named by `Prose.trollRoom`.
    let scratches = Item {
        name("deep scratches")
        adjectives("deep")
        synonyms("scratches", "scratch")
        description(Prose.trollScratches)
        scenery
    }

    /// (#407) Named by `Prose.trollRoom`.
    let forbiddingHole = Item {
        name("forbidding hole")
        adjectives("forbidding")
        synonyms("hole")
        description(Prose.trollHole)
        scenery
    }

    /// (#407) Named by `Prose.eastOfChasm`, beyond the audit's list.
    let chasmPassage = Item {
        name("narrow passage")
        adjectives("narrow")
        synonyms("passage")
        description(Prose.chasmPassage)
        scenery
    }

    /// (#407) Named by `Prose.eastOfChasm`, beyond the audit's list.
    let chasmPath = Item {
        name("path")
        description(Prose.chasmPath)
        scenery
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
        chasmPassage.starts(in: eastOfChasm)
        chasmPath.starts(in: eastOfChasm)
        painting.starts(in: gallery)
        chimney.starts(in: studio)
        vandals.starts(in: gallery)
        studioFireplace.starts(in: studio)
        studioDoor.starts(in: studio)
        studioPaints.starts(in: studio)
        bloodstains.starts(in: trollRoom)
        scratches.starts(in: trollRoom)
        forbiddingHole.starts(in: trollRoom)
        troll.starts(in: trollRoom)
        // The thief's start (Gallery) is host-wired in ``Zork1``: he lives in
        // ``ZorkThief`` now and can't be placed from this bundle's map.
    }
}

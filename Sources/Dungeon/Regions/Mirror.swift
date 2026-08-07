import Gnusto
import GnustoScoring

/// The mirror rooms and the tangle of passages around them — the hinge the
/// whole underground turns on. Two rooms called Mirror Room, each with an
/// enormous mirror on its south wall, and rubbing either one puts you in the
/// other along with everything lying on the floor.
///
/// **The two mirrors are not a sub-room space.** They are two ordinary rooms
/// joined by a teleport, and the sameness of their names is the same joke the
/// Caves and the coal mine make. What is a sub-room space in this game is the
/// mirror *box* of the Endgame, which is a later milestone and a different
/// object entirely.
///
/// **This is not Zork I's mirror network, either.** The trilogy kept the two
/// rooms and re-cut everything around them:
///
/// - the northern Mirror Room is **dark** and the southern one **lit**, which
///   is the way round Zork I does not have it;
/// - the passages that reach them are the **Steep** and **Narrow Crawlways**,
///   rooms Zork I never built, and the Narrow Crawlway climbs north to the
///   Grail Room;
/// - the **Cold Passage crosses a path running north**, not south;
/// - the **Winding Passage has one exit**, and the whirring to the north is a
///   wall you cannot get through rather than a way out;
/// - the **Atlantis Room's tunnel runs southeast**;
/// - the two Caves are different rooms: the northern one drops to Atlantis,
///   the southern one to the gate of Hades.
///
/// The seams the host wires are the Narrow Crawlway's climb to the Grail Room,
/// the southern Cave's staircase down to Hades, the Atlantis Room's tunnel to
/// Reservoir North, the Slide Room's chute into the Cellar, and its opening
/// north onto the Mine Entrance. See `FIDELITY.md`.
struct DungeonMirror: GameContent {
    // MARK: - Rooms

    /// The northern Mirror Room, on the Atlantis side. Dark — the mainframe
    /// gives it no light bit. Always described, because a smashed mirror shows
    /// only in the long description and a brief re-entry would hide it.
    let mirrorRoomNorth = Location {
        name("Mirror Room")
        alwaysDescribed
        dark
    }

    /// The southern Mirror Room, on the temple side. **Lit**, as in the
    /// mainframe (`RLIGHTBIT`) — and it is the southern one that is lit here,
    /// where Zork I lights the northern.
    let mirrorRoomSouth = Location {
        name("Mirror Room")
        alwaysDescribed
    }

    let caveNorth = Location {
        name("Cave")
        description(Prose.caveNorth)
        dark
    }

    let caveSouth = Location {
        name("Cave")
        description(Prose.caveSouth)
        dark
    }

    let steepCrawlway = Location {
        name("Steep Crawlway")
        description(Prose.steepCrawlway)
        dark
    }

    let narrowCrawlway = Location {
        name("Narrow Crawlway")
        description(Prose.narrowCrawlway)
        dark
    }

    let coldPassage = Location {
        name("Cold Passage")
        description(Prose.coldPassage)
        dark
    }

    let windingPassage = Location {
        name("Winding Passage")
        description(Prose.windingPassage)
        dark
    }

    let atlantisRoom = Location {
        name("Atlantis Room")
        description(Prose.atlantisRoom)
        dark
    }

    /// Always described, and with no static description: as of milestone 8 the
    /// chute can have a rope tied off at the head of it, and whether it has is
    /// a fact the room's paragraph carries. ``Dungeon/palantirRules`` supplies
    /// the text, because the rope and the chute below it are
    /// ``DungeonPalantir``'s.
    let slideRoom = Location {
        name("Slide Room")
        alwaysDescribed
        dark
    }

    // MARK: - State

    /// Whether a mirror has been smashed — the mainframe's `MIRROR-MUNG`. One
    /// blow breaks both, because they are two faces of the same passage, and
    /// nothing in the game mends them.
    @Global var mirrorBroken = false

    // MARK: - Items

    let mirrorNorth = Item {
        name("mirror")
        adjectives("enormous", "large")
        synonyms("reflection", "glass")
        scenery
    }

    let mirrorSouth = Item {
        name("mirror")
        adjectives("enormous", "large")
        synonyms("reflection", "glass")
        scenery
    }

    let mirrorRoomNorthCeiling = Item {
        name("tall ceiling")
        adjectives("tall")
        synonyms("ceilings", "ceiling", "wall", "walls", "exits", "exit")
        description(Prose.mirrorRoomCeiling)
        scenery
    }

    let mirrorRoomSouthCeiling = Item {
        name("tall ceiling")
        adjectives("tall")
        synonyms("ceilings", "ceiling", "wall", "walls", "exits", "exit")
        description(Prose.mirrorRoomCeiling)
        scenery
    }

    let caveNorthStairway = Item {
        name("staircase")
        synonyms("stairway", "stairs", "entrance")
        description(Prose.caveStairway)
        scenery
    }

    let caveSouthStairway = Item {
        name("staircase")
        adjectives("dark", "forbidding")
        synonyms("stairway", "stairs", "entrances", "entrance")
        description(Prose.caveStairway)
        scenery
    }

    let steepCrawlwayWalls = Item {
        name("crawlway")
        adjectives("steep", "narrow")
        synonyms("walls", "wall", "rock", "ways", "way")
        description(Prose.crawlwayWalls)
        scenery
    }

    let narrowCrawlwayWalls = Item {
        name("crawlway")
        adjectives("narrow")
        synonyms("walls", "wall", "rock", "branch", "branches", "end")
        description(Prose.crawlwayWalls)
        scenery
    }

    let coldPassageWalls = Item {
        name("corridor")
        adjectives("cold", "damp")
        synonyms("passageway", "passage", "path", "walls", "wall")
        description(Prose.crawlwayWalls)
        scenery
    }

    let whirring = Item {
        name("whirring")
        adjectives("faint")
        synonyms("whir", "sound", "machinery", "rock", "wall")
        description(Prose.windingPassageWhirring)
        scenery
    }

    let atlantisWalls = Item {
        name("ancient walls")
        adjectives("ancient")
        synonyms("wall", "walls", "water", "room", "shore")
        description(Prose.atlantisWalls)
        scenery
        plural
    }

    /// The crystal trident: four to find and eleven to case, the mainframe's
    /// values and the trilogy's alike.
    let crystalTrident = Item {
        name("crystal trident")
        adjectives("crystal", "poseidon")
        synonyms("trident", "fork")
        firstSight(Prose.crystalTridentFirstSight)
        description(Prose.crystalTrident)
        trait(.weight, 20)
        trait(.takeValue, 4)
        trait(.depositValue, 11)
    }

    let graniteWallLettering = Item {
        name("granite wall")
        adjectives("granite", "south")
        synonyms("letters", "lettering", "wall", "walls", "rock")
        description(Prose.graniteWallLettering)
        scenery
    }

    let metalSlide = Item {
        name("metal slide")
        adjectives("steep", "metal")
        synonyms("slide", "chute", "opening", "chamber")
        description(Prose.metalSlide)
        scenery
    }

    // MARK: - Map

    var map: WorldMap {
        // The northern Mirror Room and its neighbours.
        mirrorRoomNorth.west(coldPassage)
        mirrorRoomNorth.north(steepCrawlway)
        mirrorRoomNorth.east(caveNorth)

        // The southern Mirror Room and its neighbours.
        mirrorRoomSouth.west(windingPassage)
        mirrorRoomSouth.north(narrowCrawlway)
        mirrorRoomSouth.east(caveSouth)

        // The northern Cave, which drops to Atlantis.
        caveNorth.north(mirrorRoomNorth)
        caveNorth.down(atlantisRoom)

        // The southern Cave. Its dark staircase falls to the gate of Hades, a
        // ``DungeonTemple`` room — host-wired.
        caveSouth.north(narrowCrawlway)
        caveSouth.west(mirrorRoomSouth)

        steepCrawlway.south(mirrorRoomNorth)
        steepCrawlway.southwest(coldPassage)

        // The Narrow Crawlway. North is the Grail Room, a ``DungeonTemple``
        // room — host-wired.
        narrowCrawlway.south(caveSouth)
        narrowCrawlway.southwest(mirrorRoomSouth)

        coldPassage.east(mirrorRoomNorth)
        coldPassage.west(slideRoom)
        coldPassage.north(steepCrawlway)

        // The Winding Passage. North is a wall with a noise behind it — a real
        // declared exit that always refuses, because the source declares it
        // that way and the refusal is half the room.
        windingPassage.east(mirrorRoomSouth)
        windingPassage.north(blocked: Prose.noEntranceToTheRoundRoom)

        // The Atlantis Room. Southeast is Reservoir North, a ``DungeonDam``
        // room — host-wired.
        atlantisRoom.up(caveNorth)

        // The Slide Room. Down the chute is the Cellar and north is the Mine
        // Entrance, both across a bundle — host-wired.
        slideRoom.east(coldPassage)

        mirrorNorth.starts(in: mirrorRoomNorth)
        mirrorSouth.starts(in: mirrorRoomSouth)
        mirrorRoomNorthCeiling.starts(in: mirrorRoomNorth)
        mirrorRoomSouthCeiling.starts(in: mirrorRoomSouth)

        caveNorthStairway.starts(in: caveNorth)
        caveSouthStairway.starts(in: caveSouth)

        steepCrawlwayWalls.starts(in: steepCrawlway)
        narrowCrawlwayWalls.starts(in: narrowCrawlway)
        coldPassageWalls.starts(in: coldPassage)
        whirring.starts(in: windingPassage)

        crystalTrident.starts(in: atlantisRoom)
        atlantisWalls.starts(in: atlantisRoom)

        graniteWallLettering.starts(in: slideRoom)
        metalSlide.starts(in: slideRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        // Everything either mirror does, the other does too — they are two
        // faces of one passage, so the pair is a loop rather than ten rules
        // written twice.
        //
        // Rubbing one trades the two rooms' floors and puts you down in the
        // other. `rub` and `touch` are one intent in the engine and the
        // mainframe's verb is `RUB`, so both sentences work; a shattered
        // mirror is dead glass and the touch falls through to the stock line.
        // Breaking either breaks both, for good.
        for (glass, room, far) in [
            (mirrorNorth, mirrorRoomNorth, mirrorRoomSouth),
            (mirrorSouth, mirrorRoomSouth, mirrorRoomNorth),
        ] {
            room.describe { mirrorRoomDescription() }
            glass.describe { mirrorBroken ? Prose.mirrorBroken : Prose.mirror }
            glass.before(.touch) { try stepThroughMirror(to: far) }
            glass.before(.attack, .throwAt) { try breakMirror() }
            glass.before(.take) { try reply(Prose.mirrorTakeRefused) }
        }
    }

    /// The mirror rooms' shared description, plus the wreckage if there is any.
    private func mirrorRoomDescription() -> String {
        mirrorBroken ? "\(Prose.mirrorRoom)\n\n\(Prose.mirrorShattered)" : Prose.mirrorRoom
    }

    /// Trade the two rooms' loose floor contents and move the player to the
    /// far one. Both floors are read before either is written, so the swap is
    /// order-independent; fixtures — the mirrors themselves included — stay
    /// where they stand, which is the one place this departs from the source's
    /// wholesale list swap.
    private func stepThroughMirror(to destination: Location) throws {
        guard !mirrorBroken else { return }
        let northLoose = mirrorRoomNorth.contents.filter(\.isTakable)
        let southLoose = mirrorRoomSouth.contents.filter(\.isTakable)
        for item in northLoose { item.move(to: mirrorRoomSouth) }
        for item in southLoose { item.move(to: mirrorRoomNorth) }
        say(Prose.mirrorRumble)
        arrive(at: destination)
        try reply("")
    }

    /// Break the mirror if it is whole, or shrug off a blow against glass
    /// already in pieces.
    private func breakMirror() throws {
        guard !mirrorBroken else { try reply(Prose.mirrorAlreadyBroken) }
        mirrorBroken = true
        try reply(Prose.mirrorBreaks)
    }
}

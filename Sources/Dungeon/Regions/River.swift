import Gnusto
import GnustoScoring

extension Intent {
    /// The word cut into the staves of the barrel at the top of Aragain Falls.
    /// Declared here rather than in ``DungeonSystems`` because a verb lives
    /// with the region that answers it.
    #verb("geronimo", ["geronimo"])
}

/// The Frigid River and the country below Flood Control Dam #3 — seventeen
/// rooms, forked from `Sources/Zork1/Regions/River.swift` and re-topologized
/// against `dung.355`.
///
/// **The banks are the other way round.** In Zork I the White Cliffs wall the
/// west shore and the sandy beach lies east; in the mainframe the cliffs are
/// **east** and the beach, the shore and the rocky western approach are
/// **west**. Every description that names a bank is adapted for it, and the
/// exits are the atlas's.
///
/// Four more differences worth stating, because each is a line a contributor
/// would "fix" back toward the trilogy:
///
/// - **There is no current.** `dung.355` registers no clock interrupt for the
///   river, so nothing carries the boat downstream; `down` is the only thing
///   that moves it. Zork I's drift is Zork I's.
/// - **The river is dark.** The mainframe gives the light bit to the Rainbow
///   Room and the End of Rainbow and to nothing else down here — not the five
///   stretches, not either beach, not Aragain Falls.
/// - **There is no Sandy Cave and no scarab.** The shovel lies in the Small
///   Cave on the western approach, and four digs in the beach turn up a
///   statue worth ten and thirteen.
/// - **The White Cliffs have no passage inland.** Zork I squeezes a foot-path
///   west into the Damp Cave; here the wall is solid, and the way to the west
///   bank on foot is the Loud Room's own crawl east — the Ancient Chasm, the
///   Small Cave, and Rocky Shore.
///
/// Seams host-wired in ``Dungeon``, because each names another bundle: the
/// boat's pile of plastic and the broken sharp stick both start at the Dam
/// Base; inflating needs the reservoir's pump and patching the tube's gunk;
/// `launch` and `land` cross between the Dam Base and the water; the Loud
/// Room's east door opens on the Ancient Chasm; and Canyon Bottom's path north
/// reaches the End of Rainbow. See `FIDELITY.md`.
struct DungeonRiver: GameContent {
    // MARK: - The five stretches

    /// One dark stretch of water or wet bank. Every room in this region but
    /// the Rainbow Room, the End of Rainbow and the Small Cave is one: the
    /// mainframe withholds the light bit from all of them, and every one of
    /// them can fill a bottle. Built from a factory for the same reason the
    /// maze's passages are — the bootstrap still names each after its own
    /// property.
    private static func wetAndDark(_ roomName: String, _ text: String) -> Location {
        Location {
            name(roomName)
            description(text)
            dark
            trait(.waterSource, true)
        }
    }

    // The five stretches share the display name "Frigid River". Upstream is
    // refused from all of them; `down` is the only way on.
    let river1 = wetAndDark("Frigid River", Prose.river1)
    let river2 = wetAndDark("Frigid River", Prose.river2)
    let river3 = wetAndDark("Frigid River", Prose.river3)
    let river4 = wetAndDark("Frigid River", Prose.river4)
    let river5 = wetAndDark("Frigid River", Prose.river5)

    // MARK: - The east bank: the White Cliffs

    let whiteCliffsNorth = wetAndDark("White Cliffs Beach", Prose.whiteCliffsNorth)
    let whiteCliffsSouth = wetAndDark("White Cliffs Beach", Prose.whiteCliffsSouth)

    // MARK: - The west bank

    let sandyBeach = wetAndDark("Sandy Beach", Prose.sandyBeach)
    let shore = wetAndDark("Shore", Prose.shore)

    /// Always described, because the rainbow's state is only ever reported
    /// here and a brief re-entry would print a bare room name over a solid
    /// rainbow. The defect ``alwaysDescribed`` exists for.
    let aragainFalls = Location {
        name("Aragain Falls")
        alwaysDescribed
        dark
        trait(.waterSource, true)
    }

    /// Lit, as in the mainframe — one of only two lit rooms in this region.
    let rainbowRoom = Location {
        name("Rainbow Room")
        description(Prose.rainbowRoom)
    }

    /// Lit, as in the mainframe: the canyon opens here and lets the day down.
    let endOfRainbow = Location {
        name("End of Rainbow")
        description(Prose.endOfRainbow)
        trait(.waterSource, true)
    }

    // MARK: - The western approach

    let rockyShore = wetAndDark("Rocky Shore", Prose.rockyShore)

    /// Dry, and the only room in this region that is.
    let smallCave = Location {
        name("Small Cave")
        description(Prose.smallCave)
        dark
    }

    let ancientChasm = Location {
        name("Ancient Chasm")
        description(Prose.ancientChasm)
        dark
    }

    private static func chasmDeadEnd() -> Location {
        Location {
            name("Dead End")
            description(Prose.chasmDeadEnd)
            dark
        }
    }

    let chasmDeadEndNorth = chasmDeadEnd()
    let chasmDeadEndWest = chasmDeadEnd()

    // MARK: - The boat

    /// The boat before air. Starts at the Dam Base, which is a ``DungeonDam``
    /// room, so the host places it.
    let pileOfPlastic = Item {
        name("pile of plastic")
        adjectives("plastic", "folded", "inflatable")
        synonyms("boat", "pile", "plastic", "valve")
        firstSight(Prose.pileOfPlastic)
        description(Prose.pileOfPlastic)
        trait(.weight, 20)
    }

    /// The boat with air in it: an open-topped container you climb into and
    /// ride. Begins offstage; the pump puts it in play.
    let magicBoat = Item {
        name("magic boat")
        adjectives("magic", "plastic", "seaworthy")
        synonyms("boat", "raft")
        description(Prose.magicBoat)
        enterable
        container
        capacity(100)
        trait(.weight, 20)
    }

    /// The boat after the stick has been through it. Begins offstage.
    let puncturedBoat = Item {
        name("punctured boat")
        adjectives("punctured", "plastic", "deflated")
        synonyms("boat", "pile", "plastic")
        description(Prose.puncturedBoat)
        trait(.weight, 20)
    }

    /// The manufacturer's label, and the warning that names the one thing in
    /// the game that holes the boat.
    let tanLabel = Item {
        name("tan label")
        adjectives("tan")
        synonyms("label", "fine", "print", "instructions", "warranty", "warning")
        description(Prose.tanLabel)
        trait(.weight, 2)
    }

    /// The broken sharp stick — this game's sceptre and this game's puncture,
    /// in one object. Waving it at either end of the rainbow turns the rainbow
    /// solid; carrying it aboard the boat lets the air out. Starts at the Dam
    /// Base, so the host places it.
    let sharpStick = Item {
        name("broken sharp stick")
        adjectives("broken", "sharp")
        synonyms("stick", "branch")
        firstSight(Prose.stickInPlace)
        description(Prose.stick)
        trait(.weight, 3)
        // And one of the source's four `PALOBJS`, which is this object's third
        // job. See ``DungeonPalantir``.
        trait(.keyholeTool, true)
    }

    // MARK: - The buoy

    let buoy = Item {
        name("red buoy")
        adjectives("red")
        synonyms("buoy")
        firstSight(Prose.buoy)
        description(Prose.buoyExamined)
        container
        openable
        capacity(20)
        trait(.weight, 10)
    }

    /// Five on the find and ten in the case — the mainframe's values, which
    /// here are the trilogy's too.
    let emerald = Item {
        name("large emerald")
        adjectives("large", "enormous")
        synonyms("emerald", "jewel")
        firstSight(Prose.emeraldInPlace)
        description(Prose.emerald)
        trait(.weight, 5)
        trait(.takeValue, 5)
        trait(.depositValue, 10)
    }

    // MARK: - The beach

    /// The thing you dig. `container` so `search sand` answers as a search
    /// rather than as the engine's refusal.
    let sand = Item {
        name("sand")
        adjectives("sandy")
        synonyms("sand", "beach", "ground", "shore")
        description(Prose.sand)
        container
        scenery
    }

    /// Ten to find and **thirteen** to case — the mainframe's own values, and
    /// a treasure Zork I does not have at all. Buried; the fourth dig bares it.
    let statue = Item {
        name("statue")
        adjectives("beautiful", "small")
        synonyms("statue", "sculpture", "figure", "rock")
        firstSight(Prose.statueInPlace)
        description(Prose.statue)
        hidden
        trait(.weight, 8)
        trait(.takeValue, 10)
        trait(.depositValue, 13)
    }

    // MARK: - The Small Cave

    let shovel = Item {
        name("shovel")
        synonyms("shovel", "spade")
        firstSight(Prose.shovelInPlace)
        description(Prose.shovel)
        trait(.weight, 15)
    }

    /// Takeable, diggable, and worth nothing whatever. The mainframe keeps it
    /// for the joke and for the three digs it answers.
    let guano = Item {
        name("hunk of bat guano")
        adjectives("bat")
        synonyms("guano", "hunk", "dung")
        firstSight(Prose.guanoInPlace)
        description(Prose.guano)
        trait(.weight, 20)
    }

    // MARK: - The falls

    /// A vehicle, in the mainframe's sense: you can get into it, and getting
    /// into it is the whole point.
    let barrel = Item {
        name("wooden barrel")
        adjectives("wooden", "man-sized")
        synonyms("barrel", "cask")
        firstSight(Prose.barrelInPlace)
        description(Prose.barrel)
        enterable
        container
        capacity(100)
        trait(.weight, 70)
    }

    /// Ten and ten, and — unlike Zork I's — already standing at the End of
    /// Rainbow from turn one. It is `hidden` until the rainbow wakes, which is
    /// the source's own `OVISON` flip rather than a conjuring.
    let potOfGold = Item {
        name("pot of gold")
        adjectives("gold", "golden")
        synonyms("pot", "gold")
        firstSight(Prose.potOfGoldInPlace)
        description(Prose.potOfGold)
        hidden
        trait(.weight, 15)
        trait(.takeValue, 10)
        trait(.depositValue, 10)
    }

    // MARK: - Scenery

    // One per room, because an item lives in exactly one place and each of
    // these rooms prints its own water, its own cliffs or its own rock. The
    // tax milestone 1 records under "every printed noun answers", and the
    // factories below are what keeps the tax from being paid in paragraphs.

    /// The Frigid River, seen from the eight rooms that name it. Each takes
    /// the nouns its own description prints.
    private static func riverScenery(_ adjective: String, _ nouns: ItemTrait) -> Item {
        Item {
            name("river")
            adjectives("frigid", adjective)
            nouns
            description(Prose.frigidRiverHere)
            scenery
        }
    }

    /// The White Cliffs from the two beaches under them.
    /// The White Cliffs from the rooms that name them. The default text is the
    /// view from the beach at their foot, which says there is no climbing them;
    /// a boat wants told that they are the bank, so the three stretches pass
    /// their own. ``pathScenery(_:)``'s shape — the nouns stay at the call site
    /// and the text is the parameter.
    private static func cliffScenery(
        _ adjective: String,
        _ nouns: ItemTrait,
        _ text: String = Prose.whiteCliffsFromBelow
    ) -> Item {
        Item {
            name("white cliffs")
            adjectives("white", adjective)
            nouns
            description(text)
            scenery
            plural
        }
    }

    /// The rainbow, from the three rooms it is visible from. Its description
    /// is a rule rather than a constant, because whether it is solid is a
    /// thing you can see about it.
    private static func rainbowScenery(_ nouns: ItemTrait) -> Item {
        Item {
            name("rainbow")
            adjectives("beautiful", "solid")
            nouns
            scenery
        }
    }

    private static func deadEndScenery() -> Item {
        Item {
            name("rock")
            adjectives("blank")
            synonyms("rock", "wall", "passage")
            description(Prose.deadEndWall)
            scenery
        }
    }

    /// Six bank rooms name a path and not one of them modelled it, so `x path`
    /// answered with the water, the cliffs or the falls — three different wrong
    /// things for one word. Same shape as ``DungeonAboveGround``'s factory: the
    /// nouns are fixed and the text is the parameter, because every one of them
    /// is a path and the whole of what differs is where it goes. (#286)
    private static func pathScenery(_ text: String) -> Item {
        Item {
            name("path")
            adjectives("beaten", "narrow")
            synonyms("path", "track", "trail")
            description(text)
            scenery
        }
    }

    /// Aragain Falls, from the three rooms that name it — the lip you stand on
    /// and the two that can see it from downstream and above. The rainbow was
    /// answering for the water it crosses in both of the latter, which is the
    /// near thing speaking for the far one. (#286)
    private static func fallsScenery(_ nouns: ItemTrait) -> Item {
        Item {
            name("waterfall")
            adjectives("enormous", "aragain")
            nouns
            description(Prose.aragainFallsItself)
            scenery
        }
    }

    // Each stretch used to carry every noun its paragraph printed — `dam`,
    // `landing`, `shore`, `cliffs`, `rocks`, `bank`, `valley`, `beach` — as a
    // synonym of the water, so all eight answered "The Frigid River lives up to
    // its name". Not a denial, which is what the round filed, but the same fault
    // one turn later: the near thing speaking for the far one, eight times in
    // one room. The stretches keep only what means the water; everything they
    // name from the water is declared below. (#332)
    let riverAtOne = riverScenery("quiet", synonyms("water", "vicinity"))
    let riverAtTwo = riverScenery("winding", synonyms("water", "corner"))
    let riverAtThree = riverScenery("descending", synonyms("water", "rumbling"))
    let riverAtFour = riverScenery("fast", synonyms("water", "sound"))
    let riverAtFive = riverScenery("rushing", synonyms("water", "sound"))

    /// Flood Control Dam #3 from the two stretches that name it, both of which
    /// name it as something upstream. ``DungeonDam``'s own dam is the one you
    /// stand on; this is the one you are being carried away from.
    private static func damFromTheWater() -> Item {
        Item {
            name("dam")
            adjectives("flood", "control", "abandoned")
            description(Prose.damFromTheWater)
            scenery
        }
    }

    /// The landing on the west shore — small on River-1, large on River-5, and
    /// the only two stretches that print the word.
    private static func landingScenery(
        _ size: String, _ nouns: ItemTrait = synonyms("landing")
    ) -> Item {
        Item {
            name("landing")
            adjectives(size)
            nouns
            description(Prose.riverLanding(size))
            scenery
        }
    }

    /// The west bank, from a boat going past it. Four stretches print `shore`
    /// or `bank` and none of them modelled either.
    private static func westBankScenery() -> Item {
        Item {
            name("shore")
            adjectives("west", "western")
            synonyms("shore", "bank")
            description(Prose.westBankFromTheWater)
            scenery
        }
    }

    let damAtRiverOne = damFromTheWater()
    let damAtRiverTwo = damFromTheWater()

    let landingAtRiverOne = landingScenery("small")
    let landingAtRiverFive = landingScenery("large", synonyms("landing", "area"))

    let bankAtRiverOne = westBankScenery()
    let bankAtRiverTwo = westBankScenery()
    let bankAtRiverThree = westBankScenery()
    let bankAtRiverFive = westBankScenery()

    /// The rocks that are River-2's reason the west bank is no landing.
    let rocksAtRiverTwo = Item {
        name("rocks")
        adjectives("large")
        synonyms("rocks", "rock")
        description(Prose.riverRocks)
        scenery
        plural
    }

    /// The valley River-3 descends into.
    let valleyAtRiverThree = Item {
        name("valley")
        description(Prose.riverValley)
        scenery
    }

    /// The strip of beach under the east cliffs, from the water. River-3 calls
    /// it narrow and River-4 calls it a small area; it is the same sand.
    private static func eastBeachScenery(_ nouns: ItemTrait = synonyms("beach")) -> Item {
        Item {
            name("beach")
            adjectives("narrow", "east", "eastern", "small")
            nouns
            description(Prose.beachFromTheWater)
            scenery
        }
    }

    let beachAtRiverThree = eastBeachScenery()
    let beachAtRiverFour = eastBeachScenery(synonyms("beach", "area"))

    /// And River-4's other one, which is the sand you can actually land on.
    let sandyBeachAtRiverFour = Item {
        name("sandy beach")
        adjectives("sandy", "west", "western")
        synonyms("beach", "sand", "shore")
        description(Prose.sandyBeachFromTheWater)
        scenery
    }

    private static func cliffsFromTheWater() -> Item {
        cliffScenery("sheer", synonyms("cliffs", "cliff"), Prose.cliffsFromTheWater)
    }

    let cliffsAtRiverTwo = cliffsFromTheWater()
    let cliffsAtRiverThree = cliffsFromTheWater()
    let cliffsAtRiverFour = cliffsFromTheWater()

    let riverAtSandyBeach = riverScenery("flowing", synonyms("water"))
    let riverAtShore = riverScenery("treacherous", synonyms("water", "shore", "corner"))
    let riverAtRockyShore = riverScenery("rocky", synonyms("water", "shore", "rocks", "rock"))

    let cliffsAtNorthBeach = cliffScenery("narrow", synonyms("cliff", "cliffs", "beach", "strip", "base"))
    let cliffsAtSouthBeach = cliffScenery("rocky", synonyms("cliff", "cliffs", "beach", "strip", "shore"))

    // The two White Cliffs beaches are `.waterSource` rooms whose only scenery
    // was the cliffs, so the river a bottle fills from had no noun in them at
    // all: `fill bottle` worked and `x water` did not. Repaired by inspection
    // rather than from a transcript — no charter entered either room in the
    // 2026-08-11 round. (#233)
    let riverAtNorthBeach = riverScenery("cold", synonyms("water", "river"))
    let riverAtSouthBeach = riverScenery("cold", synonyms("water", "river"))

    let rainbowAtFalls = rainbowScenery(synonyms("rainbow", "stairs", "bannister"))
    let rainbowAtRainbowRoom = rainbowScenery(synonyms("rainbow", "view"))
    let rainbowAtEndOfRainbow = rainbowScenery(synonyms("rainbow"))

    let pathAtNorthBeach = pathScenery(Prose.pathAtNorthBeach)
    let pathAtSouthBeach = pathScenery(Prose.pathAtSouthBeach)
    let pathAtSandyBeach = pathScenery(Prose.pathAtSandyBeach)
    let pathAtShore = pathScenery(Prose.pathAtShore)
    let pathAtFalls = pathScenery(Prose.pathAtFalls)
    let pathAtEndOfRainbow = pathScenery(Prose.pathAtEndOfRainbow)

    let fallsAtRainbowRoom = fallsScenery(synonyms("falls", "waterfall"))
    let fallsAtEndOfRainbow = fallsScenery(synonyms("falls", "waterfall"))

    let wallAtChasmDeadEndNorth = deadEndScenery()
    let wallAtChasmDeadEndWest = deadEndScenery()

    let fallsAtFalls = fallsScenery(synonyms("falls", "waterfall", "water", "drop", "end"))

    /// The ground the End of Rainbow stands you on, which its own first
    /// sentence is about and which the rainbow overhead was answering for.
    /// (#286)
    let beachAtEndOfRainbow = Item {
        name("beach")
        adjectives("small", "rocky", "narrow")
        synonyms("beach", "shore", "ground")
        description(Prose.endOfRainbowBeach)
        scenery
    }

    /// The White Cliffs from the third room that names them. The beach here is
    /// narrow *because* of them, so the word had to answer for something.
    /// (#286)
    let cliffsAtEndOfRainbow = cliffScenery("pale", synonyms("cliff", "cliffs"))

    let canyonAtEndOfRainbow = Item {
        name("river canyon")
        adjectives("river")
        synonyms("canyon", "sunlight", "river", "water", "walls", "wall")
        description(Prose.riverCanyonHere)
        scenery
    }

    let caveAtSmallCave = Item {
        name("cave")
        adjectives("small", "low", "dry")
        synonyms("cave", "exits", "exit", "walls", "wall")
        description(Prose.caveMouth)
        scenery
    }

    /// The mouth Rocky Shore points at to the northwest. The river carried
    /// `cave`, `mouth` and `entrance`, which put a description of the water on
    /// the room's one working exit. (#286)
    let caveAtRockyShore = Item {
        name("cave")
        adjectives("dark")
        synonyms("cave", "mouth", "entrance", "opening")
        description(Prose.caveMouthFromTheShore)
        scenery
    }

    /// The hole the beach's dig progression starts printing on the first turn
    /// of digging, and nothing modelled. Hidden until there is one. (#286)
    let beachHole = Item {
        name("hole")
        synonyms("hole", "pit")
        scenery
        hidden
    }

    let chasmAtAncientChasm = Item {
        name("chasm")
        adjectives("ancient", "deep")
        synonyms("chasm", "cave", "river", "passages", "passage")
        description(Prose.ancientChasmItself)
        scenery
    }

    // MARK: - State

    /// Whether the rainbow is walkable — the mainframe's `RAINBOW-FLAG`. Set
    /// and cleared by waving the broken sharp stick at either end of it, and
    /// nothing else in the game touches it.
    @Global var rainbowSolid = false

    /// How many times the beach has been dug. The fourth bares the statue; the
    /// fifth brings the hole down on you. (Zork I's third bares its scarab —
    /// this is one dig longer, and the mainframe's own count.)
    @Global var beachDigs = 0

    /// How many times the guano has been dug. Nothing is under it; the source
    /// answers three times and then says so.
    @Global var guanoDigs = 0

    /// Whether the buoy has already given itself away.
    @Global var buoyNoticed = false

    /// Whether the inflated boat is out of the way — neither in your hands nor
    /// under you. What the cliff path asks before it lets anybody along it.
    var boatIsStowed: Bool { !magicBoat.isHeld && player.vehicle != magicBoat }

    /// Every place a boat can be put in and taken out, as one table: the shore
    /// and the stretch it reaches. `launch` is the forward lookup and `land`
    /// the inverse, so the river's topology is stated once. The Dam Base is a
    /// sixth mooring and belongs to ``DungeonDam``, so the host appends it
    /// rather than this bundle naming a room it cannot see.
    ///
    /// Internal, because both of those rules live in the host.
    var moorings: [(shore: Location, water: Location)] {
        [
            (whiteCliffsNorth, river3),
            (rockyShore, river3),
            (whiteCliffsSouth, river4),
            (sandyBeach, river4),
            (shore, river5),
        ]
    }

    /// The five stretches of open water, in order. The map's blocked `up`
    /// exits and ``isAfloat(_:)`` both read this, so "which rooms are the
    /// river" is written once.
    var stretches: [Location] { [river1, river2, river3, river4, river5] }

    /// Whether the player is standing on open water. Internal because the
    /// host's `land` rule asks it too.
    func isAfloat(_ here: Location) -> Bool { stretches.contains(here) }

    var verbs: [SyntaxRule] { [.geronimo] }

    /// The battle cry, anywhere there is nothing to leap from.
    var actions: [IntentAction] {
        action(.geronimo) { try reply(Prose.geronimoNotInBarrel) }
    }

    // MARK: - Map

    var map: WorldMap {
        riverExits
        riverPlacements
    }

    @MapBuilder private var riverExits: WorldMap {
        // The river. Upstream is refused from every stretch, `down` is the
        // only way on, and the last `down` is the falls (the host's rule, so
        // that it can die rather than travel). The mainframe's `FCHMP`
        // — "Moby lossage", one blocked exit and a room function that kills on
        // any verb but LOOK — is not built.
        for stretch in stretches {
            stretch.up(blocked: Prose.noRowingUpstream)
        }
        river1.down(river2)
        river2.down(river3)
        river3.down(river4)
        river4.down(river5)
        // River-5's `down` is the falls, and a rule rather than an exit.

        // The two upper stretches run between the cliffs and the rocks.
        river1.east(blocked: Prose.cliffsPreventLanding)
        river2.east(blocked: Prose.cliffsPreventLanding)
        // River-1's west bank is the Dam Base: host-wired.

        // The two lower stretches have a bank on either hand, which is why
        // `land` makes you say which one you mean.
        river3.east(whiteCliffsNorth)
        river3.west(rockyShore)
        river4.east(whiteCliffsSouth)
        river4.west(sandyBeach)

        // The White Cliffs beaches. The path between them is too narrow for
        // the boat — the mainframe gates it on `DEFLATE-FLAG`, which its
        // cliff-room function clears whenever the player is *carrying* the
        // firm boat. Sitting in it counts here too: the source's test does not
        // catch that case, and a player riding an inflatable down a foot-wide
        // ledge is the sort of thing the source did not think to forbid rather
        // than a thing it meant to allow (`FIDELITY.md`). Neither beach has
        // any exit inland.
        whiteCliffsNorth.exit(
            .south, to: whiteCliffsSouth, when: { boatIsStowed },
            otherwise: Prose.cliffPathTooNarrow)
        whiteCliffsSouth.exit(
            .north, to: whiteCliffsNorth, when: { boatIsStowed },
            otherwise: Prose.cliffPathTooNarrow)

        // The west bank on foot, north to south: the beach, the shore, the
        // falls.
        sandyBeach.south(shore)
        shore.north(sandyBeach)
        shore.south(aragainFalls)
        aragainFalls.north(shore)
        aragainFalls.down(blocked: Prose.fallsAreALongWayDown)

        // The rainbow. Its near end is the falls, its far end the End of
        // Rainbow, and both crossings need it solid. The mainframe gives the
        // falls two ways on (east and up) and the far end three (up, west and
        // northwest), because from down in the canyon the rainbow is overhead.
        for heading in [Direction.east, .up] {
            aragainFalls.exit(
                heading, to: rainbowRoom, when: { rainbowSolid },
                otherwise: Prose.rainbowNotSolid)
        }
        for heading in [Direction.up, .northwest, .west] {
            endOfRainbow.exit(
                heading, to: rainbowRoom, when: { rainbowSolid },
                otherwise: Prose.rainbowNotSolid)
        }
        rainbowRoom.west(aragainFalls)
        rainbowRoom.east(endOfRainbow)
        // The End of Rainbow's path southeast to Canyon Bottom is host-wired.

        // The western approach, which is how the west bank is reached on foot:
        // the Loud Room's east door (host-wired) onto the Ancient Chasm, then
        // the Small Cave and Rocky Shore.
        ancientChasm.east(smallCave)
        ancientChasm.north(chasmDeadEndNorth)
        ancientChasm.west(chasmDeadEndWest)
        chasmDeadEndNorth.southwest(ancientChasm)
        chasmDeadEndWest.east(ancientChasm)
        smallCave.northwest(ancientChasm)
        smallCave.south(rockyShore)
        rockyShore.northwest(smallCave)

        // Entities. The pile of plastic and the broken sharp stick both start
        // at the Dam Base, so the host places them.
        tanLabel.starts(inside: magicBoat)
    }

    /// The second half of the same list. Split when hazard #174 was thought to
    /// be a limit on body size; kept because it reads better in two.
    @MapBuilder private var riverPlacements: WorldMap {
        buoy.starts(in: river4)
        emerald.starts(inside: buoy)
        sand.starts(in: sandyBeach)
        statue.starts(in: sandyBeach)
        shovel.starts(in: smallCave)
        guano.starts(in: smallCave)
        barrel.starts(in: aragainFalls)
        potOfGold.starts(in: endOfRainbow)

        riverAtOne.starts(in: river1)
        riverAtTwo.starts(in: river2)
        riverAtThree.starts(in: river3)
        riverAtFour.starts(in: river4)
        riverAtFive.starts(in: river5)

        damAtRiverOne.starts(in: river1)
        damAtRiverTwo.starts(in: river2)
        landingAtRiverOne.starts(in: river1)
        landingAtRiverFive.starts(in: river5)
        bankAtRiverOne.starts(in: river1)
        bankAtRiverTwo.starts(in: river2)
        bankAtRiverThree.starts(in: river3)
        bankAtRiverFive.starts(in: river5)
        rocksAtRiverTwo.starts(in: river2)
        valleyAtRiverThree.starts(in: river3)
        beachAtRiverThree.starts(in: river3)
        beachAtRiverFour.starts(in: river4)
        sandyBeachAtRiverFour.starts(in: river4)
        cliffsAtRiverTwo.starts(in: river2)
        cliffsAtRiverThree.starts(in: river3)
        cliffsAtRiverFour.starts(in: river4)
        cliffsAtNorthBeach.starts(in: whiteCliffsNorth)
        cliffsAtSouthBeach.starts(in: whiteCliffsSouth)
        riverAtNorthBeach.starts(in: whiteCliffsNorth)
        riverAtSouthBeach.starts(in: whiteCliffsSouth)
        riverAtSandyBeach.starts(in: sandyBeach)
        riverAtShore.starts(in: shore)
        fallsAtFalls.starts(in: aragainFalls)
        rainbowAtFalls.starts(in: aragainFalls)
        rainbowAtRainbowRoom.starts(in: rainbowRoom)
        rainbowAtEndOfRainbow.starts(in: endOfRainbow)
        canyonAtEndOfRainbow.starts(in: endOfRainbow)
        riverAtRockyShore.starts(in: rockyShore)
        caveAtSmallCave.starts(in: smallCave)

        pathAtNorthBeach.starts(in: whiteCliffsNorth)
        pathAtSouthBeach.starts(in: whiteCliffsSouth)
        pathAtSandyBeach.starts(in: sandyBeach)
        pathAtShore.starts(in: shore)
        pathAtFalls.starts(in: aragainFalls)
        pathAtEndOfRainbow.starts(in: endOfRainbow)
        beachAtEndOfRainbow.starts(in: endOfRainbow)
        cliffsAtEndOfRainbow.starts(in: endOfRainbow)
        fallsAtRainbowRoom.starts(in: rainbowRoom)
        fallsAtEndOfRainbow.starts(in: endOfRainbow)
        caveAtRockyShore.starts(in: rockyShore)
        beachHole.starts(in: sandyBeach)
        chasmAtAncientChasm.starts(in: ancientChasm)
        wallAtChasmDeadEndNorth.starts(in: chasmDeadEndNorth)
        wallAtChasmDeadEndWest.starts(in: chasmDeadEndWest)
    }

    // MARK: - Rules

    var rules: Rules {
        riverRules
        moreRiverRules
    }

    @RuleBuilder private var riverRules: Rules {
        // Every room in this region is `.waterSource`, so the bottle fills in
        // all of them — while `drink water` fell through to ``DungeonSystems``'
        // stage-4 default and denied the river the player was standing in.
        // ``DungeonDam`` does the same for its seven. The bottle's own line,
        // because it is the same water; nothing is emptied, because a river is
        // not a bottle. (#233)
        for water in [
            riverAtOne, riverAtTwo, riverAtThree, riverAtFour, riverAtFive,
            riverAtNorthBeach, riverAtSouthBeach, riverAtSandyBeach,
            riverAtShore, riverAtRockyShore, fallsAtFalls, canyonAtEndOfRainbow,
        ] {
            water.before(.drink) { try reply(Prose.drinkWater) }
        }

        // Aragain Falls reports the rainbow's state, and only ever from here —
        // unless you have climbed into the barrel, in which case the falls are
        // exactly what you cannot see. The source answers `look` from the
        // barrel itself; this is the same thing said the other way round.
        aragainFalls.describe {
            guard player.vehicle != barrel else { return Prose.barrelInside }
            return """
                \(Prose.aragainFalls)

                \(rainbowSolid ? Prose.fallsRainbowSolid : Prose.fallsRainbowVapor)
                """
        }

        // And what that paragraph says about the view, the outdoor scenery has
        // to agree with. The falls, the rainbow over them and the path off the
        // north end were plain `scenery` with no guard of any kind, so `x
        // falls` answered in full on the turn after `look` said the falls could
        // not be seen from inside the barrel. (#286)
        //
        // Two rules apiece, because one cannot do both jobs — the same split
        // the mirror box's own guard is written in. `reach { }` runs at stage
        // 0, ahead of every `before` rule, and covers every verb that has to
        // *touch* the thing, gating `Item/isReachable` with it — including the
        // `drink` row above, which is a river arriving at the bottom of a
        // 450-foot drop and not something a man in a barrel is reaching. But
        // EXAMINE is `reach: .notNeeded` in `CoreVerbs`, and rightly, because a
        // thing you cannot lay a hand on is usually a thing you can still look
        // at. Here it is exactly what you cannot, so the look gets its own
        // guard and the two refuse in the same words.
        for view in [fallsAtFalls, rainbowAtFalls, pathAtFalls] {
            view.reach(otherwise: Prose.barrelBlocksTheView) { player.vehicle != barrel }
            view.before(.examine) {
                try require(player.vehicle != barrel, else: Prose.barrelBlocksTheView)
            }
        }

        // Paddling off the end of River-5. The mainframe drops you into a room
        // whose only job is to kill you; this says so in one move.
        river5.before(.go) {
            guard command.direction == .down else { return }
            try die(Prose.overTheFalls)
        }

        // You cannot step out of the boat onto open water. Guarded on `world`
        // rather than on the boat, because bare `get out` carries no direct
        // object and an item rule would never see it.
        world.before(.disembark) {
            guard isAfloat(player.location) else { return }
            try refuse(Prose.disembarkOntoWater)
        }

        // Boarding with the broken sharp stick in your hands lets the air out.
        // Boarding happens on a bank, so this only ever wrecks the boat — the
        // mainframe has no way to hole it afloat.
        magicBoat.before(.board) {
            guard sharpStick.isHeld else { return }
            puncture()
            try refuse(Prose.boatHissesFlat)
        }

        // Letting the air back out: on dry land, and not while sitting in it.
        magicBoat.before(.deflate) {
            try require(player.vehicle != magicBoat, else: Prose.deflateWhileAboard)
            try require(!magicBoat.isHeld, else: Prose.deflateNotOnGround)
            magicBoat.replace(with: pileOfPlastic)
            try reply(Prose.boatDeflates)
        }

        // The label lists differently once the boat it came in has been
        // punctured out from under it. A `presence` rule rather than a static
        // `firstSight`, because that line has to stop being true — and both
        // branches reach the room description, the first through the nested
        // listing channel (#176) while the label is still folded in the boat.
        tanLabel.presence {
            magicBoat.holds(tanLabel) ? Prose.tanLabelInBoat : Prose.tanLabelOnGround
        }

        magicBoat.before(.inflate) { try reply(Prose.boatAlreadyFirm) }
        puncturedBoat.before(.inflate) { try reply(Prose.boatWillNotInflate) }
    }

    /// The second half of the same list. Split when hazard #174 was thought to
    /// be a limit on body size; kept because it reads better in two.
    @RuleBuilder private var moreRiverRules: Rules {
        // The buoy gives itself away once, and only while it is in your hands
        // on the stretch it floats on — the source's `RIVR4-ROOM`.
        river4.afterEachTurn {
            guard !buoyNoticed, buoy.isHeld else { return }
            buoyNoticed = true
            say(Prose.buoyFeelsFunny)
        }

        // The hole the digging leaves, which the progression has named from the
        // first turn of it. A rule rather than a constant because the beach
        // says how deep it has got, and that is the thing an examine is asking.
        // (#286)
        beachHole.describe {
            beachDigs < Prose.beachDigs.count ? Prose.beachHoleShallow : Prose.beachHoleDeep
        }

        // Digging the beach. The shovel is the only thing that gets anywhere;
        // the fourth dig bares the statue and the fifth buries you.
        sand.before(.dig) {
            try requireDiggingTool()
            let digs = beachDigs + 1
            beachDigs = digs
            beachHole.reveal()
            if digs > Prose.beachDigs.count + 1 {
                try die(Prose.digCollapses)
            }
            if digs == Prose.beachDigs.count + 1 {
                statue.reveal()
                try reply(Prose.digRevealsStatue)
            }
            try reply(Prose.beachDigs[digs - 1])
        }

        // Digging the guano gets you guano.
        guano.before(.dig) {
            try requireDiggingTool()
            let digs = guanoDigs + 1
            guanoDigs = digs
            guard digs <= Prose.guanoDigs.count else {
                try reply(Prose.guanoDigsPointless)
            }
            try reply(Prose.guanoDigs[digs - 1])
        }

        // The barrel at the lip of the falls: heavy, damp, and enterable.
        barrel.before(.take) { try refuse(Prose.barrelTooHeavy) }
        barrel.before(.burn) { try reply(Prose.barrelTooDamp) }
        // The rainbow, from all three rooms that can see it. Solid is a thing
        // you can see about a rainbow, so it says so.
        for arc in [rainbowAtFalls, rainbowAtRainbowRoom, rainbowAtEndOfRainbow] {
            arc.describe { rainbowSolid ? Prose.rainbowSolidItself : Prose.rainbowItself }
        }

        // The one room in the game too loud to hear anything else in.
        aragainFalls.before(.listen) { try reply(Prose.fallsSound) }

        // The word cut into the staves. Said at the falls in the barrel it is a
        // decision; anywhere else — including at the falls on your own two
        // feet — the region's own default answers it.
        aragainFalls.before(.geronimo) {
            guard player.vehicle == barrel else { return }
            try die(Prose.barrelGoesOver)
        }

        // Waving the broken sharp stick. At either end of the rainbow it turns
        // the rainbow solid — and the pot of gold, which has stood at the far
        // end all along, becomes something you can see. On the rainbow itself
        // it takes the rainbow out from under you.
        sharpStick.before(.wave) {
            let here = player.location
            if here == rainbowRoom {
                rainbowSolid = false
                try die(Prose.rainbowWaveFatal)
            }
            guard here == aragainFalls || here == endOfRainbow else {
                try reply(Prose.stickWavedIdly)
            }
            rainbowSolid.toggle()
            guard rainbowSolid else { try reply(Prose.rainbowFades) }
            potOfGold.reveal()
            try reply(Prose.rainbowSolidifies)
        }
    }

    // MARK: - Helpers

    /// Burst the boat: swap the wreck in for it and tip its cargo onto the
    /// ground. Shared by the board rule and by anything a later milestone adds.
    private func puncture() {
        let here = player.location
        for cargo in magicBoat.contents {
            cargo.move(to: here)
        }
        magicBoat.replace(with: puncturedBoat)
    }

    /// The mainframe grades digging by what you are holding: the shovel works,
    /// another tool is slow and tedious, anything else is silly, and bare
    /// hands get nowhere. Both diggable things in this region ask the same way.
    private func requireDiggingTool() throws {
        guard let tool = command.indirectObject else {
            try reply(Prose.digWithoutTool)
        }
        guard tool == shovel else {
            try reply(Prose.digSilly(tool.indefiniteName))
        }
    }
}

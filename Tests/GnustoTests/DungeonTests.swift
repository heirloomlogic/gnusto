import Foundation
import GnustoTestSupport
import Testing

@testable import Dungeon
@testable import Gnusto

/// The mainframe-Zork reconstruction, milestone by milestone: milestone 1 is
/// above ground, the white house and the cellar; milestone 2 is the underground
/// crossroads and Flood Control Dam #3.
///
/// Most of these tests exist to pin the **map**, because the map is the one
/// thing `docs/games/dungeon.md`'s mechanics contract calls non-negotiable —
/// and because these regions are where the mainframe and Zork I differ most. A
/// contributor who "fixes" a room back toward the trilogy's layout should fail
/// a test that says why.
struct DungeonTests {
    /// The house-to-cellar descent, which most of the tests below need before
    /// they can get to what they are actually about: in at the kitchen window,
    /// west to the living room, lamp lit, rug aside, down through the trap door
    /// (which bars itself behind you). Spliced in with `+`, so a change to the
    /// route is one edit rather than six.
    private static let intoTheCellar = [
        "south", "east", "open window", "west", "west",
        "take lamp", "turn on lamp", "push rug", "open trap door", "down",
    ]

    /// In at the kitchen window.
    private static let intoTheKitchen = ["south", "east", "open window", "west"]

    /// On through the living room and down the trap door, with the lamp lit and
    /// the sword off its hooks.
    private static let downTheTrapDoor = [
        "west", "take lamp", "take sword", "turn on lamp",
        "push rug", "open trap door", "down",
    ]

    /// The whole descent with the troll cut down at the end of it, which is what
    /// the milestone-2 tests need before they can get east.
    ///
    /// Seed 18 throughout, recorded: the troll falls to the first blow, so the
    /// fight is one command and the transcript is about the map.
    private static let pastTheTroll =
        intoTheKitchen + downTheTrapDoor + ["east", "attack troll with sword"]

    /// From the Troll Room to the Loud Room by the carousel-free road: north to
    /// the East-West Passage, down the ravine staircase, along the chasm to the
    /// North-South Passage, and northeast into the din.
    private static let crossroadsToTheLoudRoom = [
        "north", "down", "east", "east", "northeast",
    ]

    /// And on up through the Damp Cave, which opens east onto the dam.
    private static let crossroadsToTheDam = crossroadsToTheLoudRoom + ["up", "east"]

    /// The whole way down and east, past him.
    private static let toTheLoudRoom = pastTheTroll + crossroadsToTheLoudRoom
    private static let toTheDam = pastTheTroll + crossroadsToTheDam

    /// Milestone 3's roads, spliced onto milestone 2's.
    ///
    /// The temple quarter is reached west out of the Deep Ravine; the mirror
    /// network is reached by draining the reservoir and walking its bed; and
    /// the coal mine hangs off the Slide Room past the northern Mirror Room.
    /// Each is a road several tests need before they can get to what they are
    /// about.

    /// The descent with the attic rope in hand. The Attic is dark in this
    /// game, so the lamp has to be lit before the stairs.
    private static let intoTheCellarWithTheRope =
        intoTheKitchen + [
            "west", "take lamp", "take sword", "turn on lamp",
            "east", "up", "take rope", "down", "west",
            "push rug", "open trap door", "down",
        ]

    /// From the Troll Room to the rim of the dome, rope in hand.
    private static let trollRoomToTheDome = [
        "north", "down", "west", "east",
    ]

    /// Down the rope into the Torch Room, torch in hand.
    private static let toTheTorchRoom =
        intoTheCellarWithTheRope
        + ["east", "attack troll with sword"]
        + trollRoomToTheDome
        + ["tie rope to railing", "down", "take torch"]

    /// And out of it the only way there is: the staircase into milestone 1's
    /// North-South Crawlway.
    private static let fetchTheTorch = toTheTorchRoom + ["down"]

    /// Charge the panel, pocket both tools, open the gates.
    private static let openTheSluiceGates =
        ["north", "north", "push yellow button", "take screwdriver", "take wrench"]
        + ["south", "south", "turn bolt with wrench", "drop wrench"]

    /// Reservoir South to the northern Mirror Room, over the drained bed and
    /// up through Atlantis. The mirror network's only road on foot.
    private static let acrossTheReservoirBed = [
        "north", "north", "north", "up", "north",
    ]

    /// From the Dam to the northern Mirror Room: drain the reservoir, cross
    /// its bed, climb out through Atlantis.
    private static let damToTheMirrors =
        fetchTheWrench + ["turn bolt with wrench", "drop wrench", "south", "northwest"]
        + acrossTheReservoirBed

    /// The house-to-mirror road, with the garlic and the matchbook picked up on
    /// the way, because half of what milestone 3 does needs one or the other.
    ///
    /// Seed 18 throughout, recorded: the troll falls to the first blow.
    private static let toTheMirrors =
        intoTheKitchen + ["open sack", "take garlic"]
        + downTheTrapDoor
        + ["east", "attack troll with sword", "drop sword"]
        + crossroadsToTheDam
        + ["north", "take matchbook", "south"]
        + damToTheMirrors

    /// On through the mirror to the Temple, which in this game is not below the
    /// Torch Room at all but above the Grail Room.
    private static let toTheTemple = toTheMirrors + ["rub mirror", "north", "north", "up"]

    /// And down to the gate of Hades with the ceremony's three pieces in hand.
    private static let toTheGateOfHades =
        toTheTemple
        + [
            "take bell", "east", "take book", "take candles",
            "west", "west", "east", "south", "down",
        ]

    /// The whole road to the head of the shaft with the ivory torch in hand —
    /// the light the bottom of the shaft needs, since the crack past the Timber
    /// Room takes nothing carried and only the basket can bring one down.
    private static let toTheShaftWithTheTorch =
        fetchTheTorch + ["east"] + crossroadsToTheDam + openTheSluiceGates
        + ["south", "northwest"] + acrossTheReservoirBed + mirrorsToTheShaft

    /// From the northern Mirror Room to the Shaft Room at the head of the coal
    /// mine's chain.
    private static let mirrorsToTheShaft = ["west", "west", "north", "northeast"]

    /// The thread through the seven-room coal maze, from the Wooden Tunnel to
    /// the Timber Room. There is no trick to it but knowing it, which is the
    /// puzzle.
    private static let coalMazeToTheLadderBottom = [
        "north", "northeast", "north", "northeast", "northwest", "down", "down",
    ]

    /// And on south into the Timber Room, at the head of the crack.
    private static let throughTheCoalMaze = coalMazeToTheLadderBottom + ["south"]

    /// From the top of the dam: charge the panel, pick up the wrench, come
    /// back. Ends where it started.
    private static let fetchTheWrench = [
        "north", "north", "push yellow button", "take wrench", "south", "south",
    ]

    /// Milestone 4's roads.

    /// From the Troll Room into the maze and along to Maze-5, where the dead
    /// adventurer and the grating's keys are: south into it, then south, east
    /// and up.
    private static let trollRoomToMazeFive = ["south", "south", "east", "up"]

    /// And on from Maze-5 to the Cyclops Room: southwest, east, south,
    /// northeast.
    private static let mazeFiveToTheCyclops = ["southwest", "east", "south", "northeast"]

    /// From Maze-5 to the Grating Room: southwest, up, east, northeast.
    private static let mazeFiveToTheGrating = ["southwest", "up", "east", "northeast"]

    /// The whole descent, past the troll, and into the maze as far as the
    /// skeleton. Seed 18 throughout: the troll falls to the first blow.
    private static let toMazeFive = pastTheTroll + trollRoomToMazeFive

    /// From the Loud Room out to the west bank of the Frigid River on foot —
    /// the mainframe's own road, and the one Zork I replaced with a passage
    /// through the White Cliffs.
    private static let loudRoomToTheRiver = ["east", "east", "south"]

    /// From the top of the dam: charge the panel, open the gates, fetch the
    /// pump off the drained reservoir's north shore, and come back down to the
    /// Dam Base where the boat is.
    private static let damToTheBoat =
        fetchTheWrench
        + ["turn bolt with wrench", "drop wrench", "south", "northwest"]
        + ["north", "north", "take pump", "south", "south", "up", "east", "down"]

    /// Pump the boat up, get in, and push off. The last three commands of any
    /// road to the water.
    private static let castOff = ["inflate plastic with pump", "board boat", "launch"]

    /// As far as the boat itself: the Dam Base, with the pump in hand and the
    /// plastic still folded.
    private static let toTheBeachedBoat =
        pastTheTroll + ["drop sword"] + crossroadsToTheDam + damToTheBoat

    /// The whole road to the Dam Base with the boat inflated and boarded.
    private static let afloatOnTheRiver = toTheBeachedBoat + castOff

    /// From the Dam Base back to the Troll Room, which is the road out once the
    /// trap door has barred itself: up the dam, east and south to the Loud
    /// Room, and west along the crossroads.
    private static let damBackToTheTrollRoom = [
        "east", "south", "west", "north", "south", "south", "west",
    ]

    /// From the Troll Room out to the trophy case, the only way there is once
    /// the trap door has barred itself: the crawlway south, the Gallery, the
    /// Studio, and up the chimney.
    private static let outByTheChimney = [
        "west", "south", "south", "south", "up", "west",
    ]

    // MARK: - The above-ground map is the mainframe's

    /// Zork I sends Behind House east into forest and keeps two clearings. The
    /// mainframe has one clearing, and Behind House opens straight onto it.
    @Test func behindHouseOpensEastOntoTheOneClearing() async throws {
        let transcript = try await play(
            Dungeon(),
            ["south", "east", "east", "southwest"])

        expectInOrder(
            transcript,
            [
                "South of House",
                "Behind House",
                "Clearing",
                "You are in a clearing, with a forest surrounding you on all sides.",
                "Behind House",
            ])
    }

    /// There is no Forest Path in the mainframe. North of the house is plain
    /// forest, and the climbable tree with the egg in it stands in that forest.
    @Test func thereIsNoForestPathAndTheGreatTreeStandsInPlainForest() async throws {
        let transcript = try await play(
            Dungeon(),
            ["north", "north", "examine tree", "up", "take egg", "down"])

        expectInOrder(
            transcript,
            [
                "North of House",
                "North of you the forest begins.",
                "Forest",
                "particularly large tree",
                "A tall, gnarled tree with branches low enough to reach.",
                "Up a Tree",
                "Taken.",
                "Forest",
            ])
        #expect(!transcript.contains("Forest Path"))
    }

    /// Two of the deep forest's exits lead back into it. That is not a bug in
    /// the map — it is the mainframe's way of making the wood feel like a wood.
    @Test func theDeepForestLoopsBackIntoItself() async throws {
        let transcript = try await play(
            Dungeon(),
            ["west", "north", "look", "west", "look", "east"])

        expectInOrder(
            transcript,
            [
                "This is a forest, with trees standing close on every side.",
                "one direction looks very",
                "one direction looks very",
                "particularly large tree",
            ])
    }

    /// The mainframe stands its Canyon View on the canyon's **south** wall,
    /// reached from the forest east of the clearing — where Zork I stands it on
    /// the west wall and leads a path northwest.
    @Test func theCanyonHangsOffTheSouthWallAndClimbsBothWays() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "south", "east", "east", "southeast", "southeast",
                "down", "down", "up", "up",
            ])

        expectInOrder(
            transcript,
            [
                "Clearing",
                "Forest",
                "Canyon View",
                "You are at the top of the Great Canyon on its south wall.",
                "Rocky Ledge",
                "Canyon Bottom",
                "Rocky Ledge",
                "Canyon View",
            ])
        #expect(!transcript.contains("west wall"))
    }

    /// The mainframe's own refusals, at the front door and at the windows.
    @Test func theHouseIsSealedInTheMainframesWords() async throws {
        let transcript = try await play(
            Dungeon(),
            ["east", "open front door", "north", "south", "examine windows"])

        expectInOrder(
            transcript,
            [
                "The door is locked, and there is evidently no key.",
                "The door is locked, and there is evidently no key.",
                "North of House",
                "The windows are all barred.",
                "The windows are all barred.",
            ])
    }

    /// The mailbox lists itself, as it does in the mainframe, and the leaflet
    /// inside is the trilogy's licensed text.
    @Test func theMailboxListsItselfAndHoldsTheLeaflet() async throws {
        let transcript = try await play(
            Dungeon(),
            ["open mailbox", "read leaflet", "read mat"])

        expectInOrder(
            transcript,
            [
                "Opening the small mailbox reveals a leaflet.",
                "A leaflet sits inside, waiting to be read.",
                "WELCOME TO ZORK",
                "WELCOME TO ZORK",
            ])
    }

    // MARK: - The house

    /// The Attic has no light of its own in the mainframe, so the lamp has to
    /// come up the stairs with you.
    @Test func theAtticIsDark() async throws {
        let transcript = try await play(
            Dungeon(),
            ["south", "east", "open window", "west", "up"])

        expectInOrder(
            transcript,
            [
                "Kitchen",
                "It is pitch black. You are likely to be eaten by a grue.",
            ])
        #expect(!transcript.contains("The only exit is a stairway leading down."))
    }

    /// The Kitchen and the Cellar carry the mainframe's room values — 10 and 25
    /// — paid on first entry.
    @Test func theKitchenAndTheCellarPayTheirRoomValues() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "south", "east", "open window", "west", "score",
                "west", "take lamp", "turn on lamp", "push rug", "open trap door",
                "down", "score",
            ])

        expectInOrder(
            transcript,
            [
                "Your score is 10 of a possible 716",
                "Cellar",
                "Your score is 35 of a possible 716",
            ])
    }

    /// Zork I's trap door is barred by the thief and freed when he falls. The
    /// mainframe's bars itself, with nobody to blame and no way to argue — and
    /// the Studio chimney is the way back out.
    @Test func theTrapDoorBarsItselfForGood() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellar
                + [
                    "open trap door", "up",
                ])

        expectInOrder(
            transcript,
            [
                "The door reluctantly opens to reveal a rickety staircase",
                "The trap door crashes shut, and you hear someone barring it.",
                "Cellar",
                "The door is locked from above.",
            ])
    }

    /// The chimney takes the lamp and one thing more — the mainframe's rule
    /// exactly: at most two things in hand, and one of them must be the lamp.
    /// Empty-handed it refuses outright.
    @Test func theChimneyTakesTheLampAndOneThingMore() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                // Not `intoTheCellar`: the sword has to come off the hooks on
                // the way past, so the climb can be refused for being overfull.
                "south", "east", "open window", "west", "west",
                "take lamp", "take sword", "turn on lamp",
                "push rug", "open trap door", "down",
                "south", "south", "take painting", "south",
                "up",
                "drop sword", "drop lamp", "drop painting", "up",
                "take lamp", "take painting", "up",
            ],
            // Seed 18, recorded: the thief never crosses your path. Lifting the
            // painting summons him, and a theft leaves the hands this test is
            // counting one lighter — 19 seeds in 5,000 failed that way unpinned.
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Studio",
                "The chimney is too narrow for you and all of your baggage.",
                "Going up empty-handed is a bad idea.",
                "Kitchen",
            ])
    }

    // MARK: - The cellar region

    /// The Gallery and the Studio hang off the crawlway south of the Cellar, so
    /// the painting can be had without ever meeting the troll. That is a
    /// mainframe fact: Zork I put the Gallery behind him.
    @Test func theGalleryIsReachableWithoutFightingTheTroll() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellar
                + [
                    "south", "south", "take painting", "score",
                ])

        expectInOrder(
            transcript,
            [
                "West of Chasm",
                "You stand at the west lip of a chasm",
                "Gallery",
                "The vandals left through the north,",
                "Taken.",
                "Your score is 39 of a possible 716",
            ])
        #expect(!transcript.contains("nasty-looking troll"))
    }

    /// The Cellar's passage runs east, not north, and the troll stands at the
    /// end of it holding three of the four ways out of his room.
    @Test func theCellarRunsEastToTheTrollWhoGatesTheCrawlway() async throws {
        // Seed 39, recorded: he starts nothing at all on this one, so the
        // transcript is about the gate rather than about a fight. Before #237 he
        // swung every turn and the seed was picked for a run of misses; now it is
        // picked for the two turns in three he spends blocking instead.
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellar
                + [
                    "north", "east", "east",
                ],
            seed: 39)

        expectInOrder(
            transcript,
            [
                "Cellar",
                "narrow passageway leading",
                // The Cellar's passage is east; north is nothing at all.
                "You can't go that way.",
                "The Troll Room",
                "passages leading off in every",
                "The troll fends you off with a menacing gesture.",
            ])
    }

    /// The troll is the only thing in this milestone that swings back. Dying to
    /// him costs ten points and everything in your hands, and puts you back
    /// among the trees — and `diagnose` keeps the tally.
    ///
    /// The fight is picked here rather than walked into, which is the #237
    /// change showing up in a test's shape: he answers a blow every turn, but
    /// unprovoked he starts one on only a third of them, so a player who walks
    /// in and reads the room is very unlikely to die and a route that counted on
    /// it would be pinning a one-in-twenty seed. What is being measured — that
    /// death costs ten points and your hands — is the same either way.
    ///
    /// Seed 4, recorded: four blows and he is still standing; his answer to the
    /// fourth is the last word.
    @Test func dyingToTheTrollCostsTenPointsAndYourHands() async throws {
        let transcript = try await play(
            Dungeon(),
            ["diagnose"] + Self.intoTheKitchen + Self.downTheTrapDoor
                + [
                    "east", "attack troll with sword", "attack troll with sword",
                    "attack troll with sword", "attack troll with sword",
                    "diagnose", "inventory", "score",
                ],
            seed: 4)

        expectInOrder(
            transcript,
            [
                "You have not been killed yet",
                "The troll neatly removes your head.",
                "you find yourself standing among the trees",
                "Forest",
                "You have been killed once.",
                // Thirty-five points earned, ten paid back to the troll.
                "Your score is 25 of a possible 716",
            ])
    }

    /// West of Chasm and the North-South Crawlway are rooms Zork I never had.
    /// The crawlway's hole overhead goes nowhere, and the chasm has no bottom.
    @Test func theMainframeOnlyRoomsBelowTheHouseAnswerForThemselves() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellar
                + [
                    "south", "down", "north", "up", "south", "northwest",
                ])

        expectInOrder(
            transcript,
            [
                "West of Chasm",
                "The chasm probably leads straight to the infernal regions.",
                "North-South Crawlway",
                "Not even a human fly could get up it.",
                "Studio",
                "At the north and northwest of the",
                "Gallery",
            ])
    }

    // MARK: - Scoring and treasures

    /// The canary and the bauble carry the mainframe's values — and the canary's
    /// case value is **2**, where Zork I pays 4.
    ///
    /// Read off the built world rather than through a transcript, and *only*
    /// these two, because these two are the ones the milestone declares before
    /// their route exists. The egg's and the painting's values are proven the
    /// proper way, by the score deltas in
    /// ``aCompleteMilestoneOneHaulScoresFiftySix``. This test should shrink to
    /// nothing as later milestones make the bird reachable.
    @Test func theUnreachableTreasuresCarryTheMainframesValues() throws {
        let (definition, _) = try Bootstrap.build(Dungeon())
        var values: [String: [StateValue?]] = [:]
        for item in definition.items.values {
            let take = item.customTraits["takeValue"]
            let deposit = item.customTraits["depositValue"]
            guard take != nil || deposit != nil, let name = item.name else { continue }
            values[name] = [take, deposit]
        }

        #expect(values["golden clockwork canary"] == [.int(6), .int(2)])
        #expect(values["beautiful brass bauble"] == [.int(1), .int(1)])
    }

    /// The ceiling ratchets per milestone, and the bootstrap check is what
    /// keeps it honest — so the award table plus the treasures must come to
    /// exactly `maxScore`, with nothing to complain about.
    @Test func theCeilingTotalsTheAwardTableExactly() throws {
        let (definition, _) = try Bootstrap.build(Dungeon())

        #expect(definition.maxScore == 716)
        #expect(definition.warnings.isEmpty, "\(definition.warnings)")
    }

    /// Forcing the egg by hand wrecks *both* objects, as in the mainframe: the
    /// atlas carries `BEGG` alongside `BCANA`, and the shell that comes back to
    /// your hand is a different, worthless one. Which is why the canary's
    /// points wait on the thief, why the bauble he makes possible does too, and
    /// why the egg's own ten now go with them.
    @Test func forcingTheEggWrecksTheCanaryAndForfeitsItsPoints() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "north", "north", "up", "take egg", "open egg",
                "examine egg", "examine canary", "inventory", "score",
            ])

        expectInOrder(
            transcript,
            [
                "Taken.",
                "The egg is now open, but the clumsiness of your attempt has",
                "Inside, among the sprung gold inlay, lies a broken clockwork canary.",
                "The lid is sprung and will not sit true again.",  // the wreck's own text
                "the mainspring seems sprung",
                "You are carrying a broken jewel-encrusted egg",
                "Your score is 5 of a possible 716",
            ])

        // The jewel-encrusted egg is gone from the game rather than merely
        // opened, so nothing answers to its description any more.
        #expect(!transcript.contains("hinged and closed"))
    }

    /// The forfeit stated in points. Force the egg, carry the wreck home, and
    /// the trophy case will not take it — so the run tops out fifteen short of
    /// where the same route would have stood had the thief done the opening:
    /// the shell's five for the case, the canary's six and two, and the
    /// bauble's one and one.
    @Test func aForcedEggCannotBeCased() async throws {
        let transcript = try await play(
            Dungeon(),
            ["north", "north", "up", "take egg", "open egg", "down"]
                + ["east", "southwest", "open window", "west", "west"]
                + ["open case", "put egg in case", "score"])

        // The case takes the wreck — nothing refuses it — and pays nothing.
        #expect(turnOutput(of: "score", in: transcript).contains("Your score is 15"))
    }

    /// The wreck takes the egg's *place*, not the player's. Force the egg while
    /// it is down in the brown sack and the ruined one is still in the sack —
    /// the case the hand-rolled swap could not reach, because a game could read
    /// `isHeld` and nothing else, so anything not in your hands fell on the
    /// floor (#182).
    @Test func aForcedEggIsWreckedWhereItSits() async throws {
        let transcript = try await play(
            Dungeon(),
            ["north", "north", "up", "take egg", "down"]
                + ["east", "southwest", "open window", "west"]
                + ["take sack", "put egg in sack", "open egg", "look in sack", "look"])

        #expect(turnOutput(of: "look in sack", in: transcript).contains("broken jewel-encrusted egg"))
        // And not on the kitchen floor, which is where it used to land.
        #expect(!turnOutput(of: "look", in: transcript).contains("somewhat ruined egg"))
    }

    /// The ruined bird only grinds; a canary is not wound anywhere but among
    /// the trees.
    @Test func theRuinedCanaryOnlyGrinds() async throws {
        let transcript = try await play(
            Dungeon(),
            ["north", "north", "up", "take egg", "open egg", "wind canary"])

        #expect(
            turnOutput(of: "wind canary", in: transcript)
                .contains("unpleasant grinding noise"))
    }

    /// A full milestone-1 haul: the egg out of the tree and the painting out of
    /// the gallery, both in the trophy case, plus both room values. 56 of the
    /// declared 66 — the other 10 wait on the thief, the only one who can open
    /// the egg without wrecking the bird inside it.
    ///
    /// The route is worth reading. The trap door bars itself behind you and the
    /// chimney only takes the lamp and one thing more, so the two treasures
    /// cannot come up together: it is two descents, one apiece.
    @Test func aCompleteMilestoneOneHaulScoresFiftySix() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "north", "north", "up", "take egg", "down",
                "east", "southwest", "open window", "west", "west",
                "open case", "put egg in case", "score",
                "take lamp", "turn on lamp", "push rug", "open trap door", "down",
                "south", "south", "take painting", "south", "up",
                "west", "put painting in case",
                "score",
            ],
            // Seed 18, recorded: the thief never crosses your path. The painting
            // is carried the length of the dungeon here, so a theft costs the
            // deposit and the score lands short — 19 seeds in 5,000 unpinned.
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Up a Tree",
                "Kitchen",
                "Living Room",
                "Your score is 20 of a possible 716",
                "Cellar",
                "Gallery",
                "Studio",
                "Kitchen",
                "Living Room",
                "Your score is 56 of a possible 716",
            ])
    }

    // MARK: - Every printed noun answers

    /// The one-scenery-item-per-room tax this region pays — four white houses,
    /// four stands of trees, six songbirds, three cliffs — exists so that a
    /// noun the prose prints is a noun the parser knows. These three sweeps are
    /// what make that tax verifiable: they walk each region examining what its
    /// rooms have just named, and fail on either flavour of unanswered noun.
    @Test func everyNounTheGroundsPrintAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "examine house", "examine front door", "examine mailbox", "examine mat",
                "examine field",
                "north", "examine house", "examine windows", "examine forest",
                "north", "examine trees", "examine tree", "examine songbird",
                "up", "examine nest", "examine egg", "examine branches",
                "down", "east", "examine leaves", "push leaves", "examine grating",
                "examine forest", "examine clearing", "examine path",
                "south", "examine trees",
                "north", "examine house", "examine windows", "examine path",
                "examine trees",
                // Behind House, the fourth side and the one whose path names a
                // clearing it cannot see.
                "east", "examine house", "examine window", "examine path",
                "examine clearing", "examine trees",
            ])

        expectEveryNounAnswered(transcript, "the house exterior, the wood, the clearing")
        expectNoAmbiguity(transcript, "the four house sides and the clearing")
    }

    @Test func everyNounTheCanyonPrintsAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "south", "east", "east", "southeast", "examine trees",
                "southeast", "examine cliff", "examine rainbow", "examine falls",
                "examine cliffs", "examine dam", "examine river", "examine forest",
                "down", "examine cliff", "examine falls", "examine passage",
                "down", "examine cliff", "examine stream", "examine runoff",
                "examine path", "examine walls",
            ])

        expectEveryNounAnswered(transcript, "the Great Canyon")
        expectNoAmbiguity(transcript, "the Great Canyon")
    }

    /// The house and the rooms below it, by the route that does not go past the
    /// troll — he is his own sweep, below, because he kills too readily to
    /// share a walk with anything else.
    @Test func everyNounTheHouseAndCellarPrintAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "south", "east", "examine window",
                "open window", "west",
                "examine table", "examine staircase", "examine chimney",
                "examine sack", "examine bottle", "examine window",
                "examine passage",
                "west", "examine rug", "examine case", "examine sword",
                "examine mantelpiece", "examine wooden door", "examine newspaper",
                "examine doorway",
                "take lamp", "turn on lamp",
                "east", "up",
                "examine table", "examine rope", "examine knife", "examine brick",
                "down", "west",
                "push rug", "examine trap door", "open trap door", "down",
                "examine ramp", "examine passageway", "examine crawlway",
                "south", "examine chasm",
                "north", "examine hole",
                "south", "examine chimney", "examine fireplace", "examine paints",
                "northwest", "examine painting", "examine paintings",
            ])

        expectEveryNounAnswered(transcript, "the house interior and the cellar")
    }

    /// The Troll Room's own nouns. Its own test, and a pinned seed, because the
    /// troll's axe lands often enough that a longer walk through his room does
    /// not survive to the end of its list.
    @Test func everyNounTheTrollRoomPrintsAnswers() async throws {
        // Seed 19, recorded: he starts nothing in the four turns this walk
        // spends in his room. Still pinned rather than dropped — a third of
        // seeds have him open one, and a fight would eat the end of the list.
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellar
                + [
                    "east", "examine troll", "examine bloodstains", "examine walls",
                    "examine passages",
                ],
            seed: 19)

        expectEveryNounAnswered(transcript, "the Troll Room")
    }

    // MARK: - Milestone 2: the crossroads map is the mainframe's

    /// The Troll Room's fourth passage — milestone 1's seam — is the front door
    /// of the crossroads, and he holds it as he holds the crawlway. Beyond it
    /// the East-West Passage pays its five points, and its stair north and its
    /// stair down are the same stair, reaching a room Zork I does not have.
    @Test func theTrollGuardsTheWayNorthToTheCrossroads() async throws {
        // Seed 18, recorded: the troll falls to the first blow.
        // The gate first, on its own short walk and its own seed. It used to be
        // separate because he killed too readily to spend a spare turn in his
        // room; since #237 it is separate because it is a walk that never draws a
        // blade, and the seed buys a troll who does not draw one either. Seed 39,
        // recorded — the same one milestone 1 uses for his eastward gate.
        let gate = try await play(
            Dungeon(), Self.intoTheCellar + ["east", "north"], seed: 39)

        expectInOrder(
            gate,
            [
                "The Troll Room",
                "The troll fends you off with a menacing gesture.",
            ])

        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll + ["north", "score", "north", "south", "down"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "East-West Passage",
                "Your score is 40 of a possible 716",
                // North and down out of the passage are the same stair, and
                // they reach a room Zork I does not have.
                "Deep Ravine",
                "East-West Passage",
                "Deep Ravine",
            ])
    }

    /// The Round Room is a **carousel**, which is the single largest thing the
    /// trilogy threw away here: nine passages, machinery under the floor, and
    /// not one of them going where you asked while it turns. Zork I's Round
    /// Room is an ordinary three-way junction with cave-ins.
    @Test func theRoundRoomIsACarouselAndScramblesEveryPassage() async throws {
        // Seed 18, recorded. Three attempts west, and the room is under no
        // obligation to answer any of them with the East-West Passage.
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll
                + ["north", "east", "examine machinery", "examine passages"]
                + ["west", "west", "west"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Round Room",
                "circular stone room with passages leading off in eight",
                "machinery whirs",
                "compass needle swings",
                "the room turns under you as you go",
            ])
        #expect(!transcript.contains("blocked by cave-ins"))
    }

    /// The Loud Room hangs off the North-South Passage and climbs to the Damp
    /// Cave — where Zork I hangs it off the Round Room and climbs to Deep
    /// Canyon. And its acoustics are **nobody's business but its own**: the
    /// mainframe's room routine never reads the sluice-gate flag, so it roars
    /// from the first moment, where Zork I only makes it unbearable while the
    /// dam drives water through. The platinum bar is sacred until `echo`.
    @Test func theLoudRoomRoarsWithoutTheDamAndTheBarIsSacredUntilEcho() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheLoudRoom
                + [
                    "examine bar", "take bar", "echo", "take bar", "score",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "North-South Passage",
                "Loud Room",
                "difficult to hear yourself think",
                "“bar... bar... bar...”",
                "cannot get hold of it while the acoustics rage",
                "The acoustics of the room change subtly.",
                "Taken.",
                // Five for the passage, twelve for the bar — and twelve is the
                // mainframe's find value, where Zork I pays ten.
                "Your score is 52 of a possible 716",
            ])
    }

    /// The Damp Cave runs south and east, not west and east, and east is the
    /// top of the dam. There is no path from the Dam to Reservoir South at
    /// all — Zork I invented that one; the mainframe reaches the shore from
    /// Deep Canyon or from the Deep Ravine.
    @Test func theDampCaveOpensEastOntoTheDamAndTheDamHasNoWestPath() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam + ["west", "south", "northwest"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Damp Cave",
                "exits to the south and east",
                "Dam",
                "quite a tourist attraction",
                // West off the dam is Zork I's route to the reservoir.
                "You can't go that way.",
                "Deep Canyon",
                "Reservoir South",
            ])
    }

    // MARK: - Milestone 2: the dam

    /// The bolt turns only with the wrench and only with the panel charged,
    /// and when it turns the reservoir empties **at once** — the mainframe
    /// re-bits the room in the same breath as the message. Zork I's eight-turn
    /// drain is the trilogy's addition and this game does not have it.
    @Test func theGatesMoveTheWaterOnTheSameTurnTheBoltTurns() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam
                + [
                    "turn bolt with wrench",
                    "north", "north", "take wrench", "south", "south",
                    "turn bolt with wrench",
                    "north", "north", "push yellow button", "south", "south",
                    "turn bolt with wrench", "look",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You can't see any such thing.",
                "Maintenance Room",
                "Taken.",
                "The bolt won't turn with your best effort.",
                "Click.",
                "The sluice gates open and water pours through the dam.",
                "The water level behind the dam is low",
                "The green bubble is glowing serenely.",
            ])
    }

    /// The trunk lies under the water until the gates uncover it, and it pays
    /// the mainframe's values: fifteen to find and **eight** to case, where
    /// Zork I pays five. Crossing a full reservoir is refused.
    @Test func theTrunkIsUncoveredByTheGatesAndPaysEightIntoTheCase() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam + Self.fetchTheWrench
                + [
                    "south", "northwest", "north",
                    "up", "east", "turn bolt with wrench",
                    "south", "northwest", "north", "drop sword", "take trunk",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Reservoir South",
                "south shore of a large reservoir",
                // The full reservoir refuses the crossing.
                "burglary rather than for swimming",
                "The sluice gates open and water pours through the dam.",
                "Reservoir",
                "mud pile",
                "Lying half buried in the mud is an old trunk",
                "Taken.",
            ])
    }

    /// Closing the gates again refills the reservoir at once, and the bed you
    /// were walking on is water before you can be told about it. Zork I needs a
    /// drowning for this moment because its gates take eight turns; the
    /// mainframe's cannot reach anyone, since the bolt is on top of the dam and
    /// the bed is a walk away. See `FIDELITY.md`.
    @Test func closingTheGatesFillsTheReservoirAgainOnTheSameTurn() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam + Self.fetchTheWrench
                + [
                    "turn bolt with wrench",
                    "south", "northwest", "north",
                    "south", "up", "east", "turn bolt with wrench",
                    "south", "northwest", "look", "north",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The sluice gates open and water pours through the dam.",
                "mud pile",
                "The sluice gates close and water starts to collect behind the dam.",
                "south shore of a large reservoir",
                // And the bed is water again, so it refuses the crossing.
                "burglary rather than for swimming",
            ])
    }

    /// The blue button springs a leak the mainframe lets you plug — Zork I
    /// dropped the putty and the verb both. The water climbs the ladder from
    /// the ankles up, and the button jams once it has run at all, so plugging
    /// the leak keeps the room rather than postponing the loss of it.
    @Test func theLeakCanBePluggedWithTheGunkFromTheTube() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam
                + [
                    "north", "north", "push blue button", "open tube",
                    "squeeze tube", "plug leak with putty",
                    "examine leak", "push blue button",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "a leak has occurred in a",
                "The water level here is now up to your ankles.",
                "The water level here is now up to your shin.",
                "The viscous material oozes into your hand.",
                "It sets hard almost",
                "hardened gunk in the east wall",
                "The blue button appears to be jammed.",
            ])
    }

    /// Left alone, the water walks all nine rungs and then takes the room for
    /// good — and anyone still standing in it.
    @Test func theFloodDrownsYouAndSealsTheMaintenanceRoom() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam
                + [
                    "north", "north", "push blue button",
                ]
                // One rung a turn, and one more turn to go under.
                + Array(repeating: "wait", count: Prose.floodLadder.count),
            seed: 18)

        expectInOrder(
            transcript,
            [
                "up to your ankles.",
                "high in your lungs.",
                "I'm afraid you have done drowned yourself.",
            ])
    }

    /// The dam brings the first water in the game, so the bottle in the Kitchen
    /// at last has something to fill from — the mainframe's `RGWATER` rooms,
    /// of which milestone 1 had none.
    @Test func theBottleCanAtLastBeFilled() async throws {
        let transcript = try await play(
            Dungeon(),
            // The bottle comes off the kitchen table and is emptied on the way.
            Self.intoTheKitchen + ["take bottle", "open bottle", "pour water"]
                + Self.downTheTrapDoor + ["east", "attack troll with sword"]
                + Self.crossroadsToTheDam
                + ["fill bottle", "north", "north", "pour water", "fill bottle"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The water spills out and is quickly gone.",
                "The bottle is now full of water.",
                // The Maintenance Room is dry until somebody presses blue.
                "There is no water here to fill it from.",
            ])
    }

    // MARK: - Milestone 2: scoring

    /// The two milestone-2 treasures carry the mainframe's values, and neither
    /// is Zork I's. Read off the built world, because the deposit values only
    /// show up in a transcript at the end of a two-descent haul.
    @Test func bothMilestoneTwoTreasuresPayTheirMainframeValues() throws {
        let (definition, _) = try Bootstrap.build(Dungeon())
        var values: [String: [StateValue?]] = [:]
        for item in definition.items.values {
            let take = item.customTraits["takeValue"]
            let deposit = item.customTraits["depositValue"]
            guard take != nil || deposit != nil, let name = item.name else { continue }
            values[name] = [take, deposit]
        }

        // Zork I pays 10+5 for the bar and 15+5 for the trunk.
        #expect(values["platinum bar"] == [.int(12), .int(10)])
        #expect(values["trunk of jewels"] == [.int(15), .int(8)])
    }

    /// The whole game as it stands: egg, painting, platinum bar and trunk of
    /// jewels in the trophy case, both room values and the East-West Passage's
    /// five. 106 of the declared 116 — the other ten are the canary and the
    /// bauble, which this route does not go the long way round for; the thief
    /// pays them out in ``theThiefOpensTheEggAndTheBirdPaysItsTen``.
    ///
    /// Four descents, because the trap door bars itself behind you and the
    /// chimney takes the lamp and one thing more. The troll has to be cut down
    /// on the second of them, and the crossroads and the dam are both behind
    /// him.
    @Test func aCompleteHaulThroughMilestoneTwoScoresOneHundredAndSix() async throws {
        // Seed 9, recorded, and re-recorded when the thief landed: the painting
        // comes out of the Gallery before the second descent, which is the
        // treasure that puts him into play, so his roaming has been drawing
        // from the stream since — and the troll's fight is a different fight.
        let transcript = try await play(
            Dungeon(),
            // The egg out of the tree and into the case, then the painting.
            ["north", "north", "up", "take egg", "down"]
                + ["east", "southwest", "open window", "west", "west"]
                + ["open case", "put egg in case"]
                + ["take lamp", "turn on lamp", "push rug", "open trap door", "down"]
                + ["south", "south", "take painting", "south", "up", "west"]
                + ["put painting in case", "score"]
                // Down again with the sword: the troll, then the Loud Room.
                + ["take sword", "open trap door", "down"]
                + ["east", "attack troll with sword", "attack troll with sword"]
                // The sword is dropped here: the chimney home takes the lamp
                // and one thing more, and that one thing is the bar.
                + Self.crossroadsToTheLoudRoom + ["echo", "take bar", "drop sword"]
                // Back the way we came to the Troll Room, then out over the
                // Studio chimney.
                + ["west", "north", "south", "south", "west"] + Self.outByTheChimney
                + ["put bar in case", "score"]
                // And once more for the trunk, which the gates have to uncover.
                + ["open trap door", "down", "east"] + Self.crossroadsToTheDam
                + Self.fetchTheWrench + ["turn bolt with wrench", "drop wrench"]
                + ["south", "northwest", "north", "take trunk"]
                + ["south", "south", "south", "west"] + Self.outByTheChimney
                + ["put trunk in case", "score"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Your score is 56 of a possible 716",
                "The troll takes a fatal blow",
                "Loud Room",
                "The acoustics of the room change subtly.",
                "You put the platinum bar in the trophy case.",
                "Your score is 83 of a possible 716",
                "The sluice gates open and water pours through the dam.",
                "Lying half buried in the mud is an old trunk",
                "You put the trunk of jewels in the trophy case.",
                "Your score is 106 of a possible 716",
            ])
    }

    // MARK: - Milestone 2: every printed noun answers

    @Test func everyNounTheCrossroadsPrintAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll
                + [
                    "north", "examine stairway",
                    "down", "examine ravine", "examine crawlway",
                    "east", "examine chasm",
                    "east", "examine fork",
                    "northeast", "echo", "examine ceiling", "examine bar",
                    "up", "examine earth", "examine crack",
                    // Deep Canyon is reached deterministically off the dam;
                    // the Round Room's own nouns are swept by the carousel test
                    // and by `DungeonProseTests`, which needs both its states.
                    "east", "south", "examine canyon",
                ],
            seed: 18)

        expectEveryNounAnswered(transcript, "the underground crossroads")
    }

    @Test func everyNounTheDamPrintsAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam
                + [
                    "examine dam", "examine bolt", "examine bubble",
                    "examine control panel", "examine reservoir",
                    "north", "examine desk", "examine doorways",
                    "examine guidebook", "examine matchbook",
                    "north", "examine buttons", "examine labels",
                    "examine doorways", "examine equipment", "examine wreckage",
                    "examine chests", "examine tube", "examine wrench",
                    "examine screwdriver",
                    "south", "south", "down",
                    "examine dam", "examine river", "examine cliffs",
                ],
            seed: 18)

        expectEveryNounAnswered(transcript, "Flood Control Dam #3")
    }

    @Test func everyNounTheReservoirPrintsAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam + Self.fetchTheWrench
                + [
                    "turn bolt with wrench",
                    "south", "northwest", "examine reservoir", "examine cliff",
                    "west", "examine stream", "examine wire", "examine path",
                    "examine bank",
                    "east", "north", "examine mud", "examine trunk",
                    "north", "examine tunnel", "examine pump",
                    "south", "up", "examine beach", "examine walls",
                ],
            seed: 18)

        expectEveryNounAnswered(transcript, "the reservoir and the stream")
    }

    // MARK: - Milestone 3: the temple, Hades, the mirrors and the coal mine

    /// **The Temple hangs off the Grail Room, not the Torch Room.** Zork I
    /// folds the whole quarter into one shaft — Torch Room down to Temple down
    /// to Altar down to Hades. In the mainframe `TEMP1`'s only door is
    /// `MGRAI`'s staircase, the Torch Room drops to a milestone-1 crawlway
    /// instead, and the Altar is a dead end. Which is why this milestone builds
    /// the Grail Room at all: without it the temple, the bell, the book and the
    /// candles are unreachable, and so is the whole exorcism.
    @Test func theTempleHangsOffTheGrailRoomAndNotTheTorchRoom() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheTemple + ["east", "west", "west", "down", "south"], seed: 18)

        expectInOrder(
            transcript,
            [
                "Grail Room",
                "This is a small round chamber",
                "Temple",
                "This is the west end of a large temple",
                "Altar",
                "This is the east end of a large temple",
                "Temple",
                "Grail Room",
                "You can't go that way.",
                "You can't go that way.",
            ])
    }

    /// **The Torch Room drops into the North-South Crawlway** — a milestone-1
    /// room — and the drop is one way, because the rope hangs out of reach
    /// above and the crawlway's own hole is unclimbable. Zork I runs the Torch
    /// Room down into its Temple.
    @Test func theTorchRoomDropsIntoAMilestoneOneCrawlway() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTorchRoom + ["up", "down", "up"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The rope drops over the side and comes within ten feet of the floor.",
                "Torch Room",
                "An ivory torch, burning, is here.",
                "You cannot reach the rope.",
                "North-South Crawlway",
                "Not even a human fly could get up it.",
            ])
    }

    /// **The Rocky Crawl and the Deep Ravine both run west into each other.**
    /// Not a transcription slip: `CRAW1` west is `RAVI1` and `RAVI1` west is
    /// `CRAW1`, and the mainframe's map has several of these.
    @Test func theRockyCrawlAndTheDeepRavineBothRunWest() async throws {
        let transcript = try await play(
            Dungeon(), Self.pastTheTroll + ["north", "down", "west", "west"], seed: 18)

        expectInOrder(
            transcript,
            [
                "Deep Ravine",
                "Rocky Crawl",
                "This is a crawlway with a ceiling three feet above the floor",
                "Deep Ravine",
            ])
    }

    /// **The gold coffin is three to find and seven to case**, where the
    /// trilogy pays ten and fifteen — and it will not go through the crawl it
    /// sits beside. The mainframe's `COFFIN-CURE` shuts every narrow way out of
    /// this quarter while it is in your hands, which is why the staircase up to
    /// the glacier is the way it leaves.
    @Test func theCoffinWillNotFitThroughTheCrawlItSitsBeside() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll
                + ["north", "down", "west", "northwest", "take coffin", "east", "up"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Egyptian Room",
                "The solid-gold coffin used for the burial of Ramses II is here.",
                "Taken.",
                "The passage is too narrow to accommodate coffins.",
                "Glacier Room",
            ])

        let (definition, _) = try Bootstrap.build(Dungeon())
        let coffin = try #require(
            definition.items.values.first { $0.name == "gold coffin" })
        #expect(coffin.customTraits["takeValue"] == .int(3))
        #expect(coffin.customTraits["depositValue"] == .int(7))
    }

    /// **The coffin also shuts the narrow ways off the reservoir's south
    /// shore.** Milestone 2 declared them plain because the Egyptian Room the
    /// coffin starts in had not been built and the gate was vacuously open. It
    /// is not any more.
    @Test func theCoffinShutsTheReservoirShoresNarrowWays() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll
                + [
                    "north", "down", "west", "northwest", "take coffin",
                    "up", "north", "east", "south", "up",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Glacier Room",
                "Stream View",
                "Reservoir South",
                "The coffin will not fit through this passage.",
                "The stairs are too steep for you with your burden.",
            ])
    }

    /// **Throwing the burning torch at the glacier opens the Ruby Room** — and
    /// costs you the torch, which the flood carries off to Stream View, black
    /// and out.
    @Test func theTorchThrownAtTheGlacierOpensTheRubyRoomAndIsQuenched() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.fetchTheTorch
                + [
                    "east", "north", "down", "west", "northwest", "up",
                    "west", "throw torch at glacier", "look",
                    "west", "take ruby", "south", "north",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "A mass of ice fills the western half of the room.",
                "quenched, and black now",
                "broad passage now opens westward",
                "Ruby Room",
                "There is a ruby here.",
                "Taken.",
                "Stream View",
                "ivory torch",
            ])
    }

    /// Holding a flame against the ice instead is the source's own wrong idea:
    /// it drowns you, which is the reason the torch has to be thrown.
    @Test func meltingTheGlacierByHandDrownsYou() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.fetchTheTorch
                + ["east", "north", "down", "west", "northwest", "up"]
                + ["melt glacier with torch"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Glacier Room",
                "Part of the glacier melts, drowning you under a torrent of water.",
            ])
    }

    /// **The exorcism, and the thirty points behind the gate.** Ring the bell,
    /// relight the candles it made you drop, read the marked prayer. The Land of
    /// the Living Dead carries a room value of 30 in the mainframe and holds
    /// **no crystal skull** — that treasure, and the sceptre the trilogy puts in
    /// the coffin, are both Zork I's inventions.
    @Test func theExorcismOpensTheGateAndPaysThirty() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheGateOfHades
                + [
                    "east", "ring bell", "take candles", "light match",
                    "burn candles with match", "read book", "east", "score",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The way through the gate is barred by evil spirits",
                "Some invisible force prevents you from passing through the gate.",
                "The bell suddenly becomes red hot and falls to the ground.",
                "In your confusion, the candles drop to the ground (and they are out).",
                "One of the matches starts to burn.",
                "The candles are lighted.",
                "The spirits cower at your unearthly power.",
                "Begone, fiends!",
                "Land of the Living Dead",
                "Passages exit to the east and to the west.",
            ])
        #expect(!transcript.contains("crystal skull"))
    }

    /// The ceremony has a clock on it — six turns after the bell in the source,
    /// three after the candles. Let either lapse and the wraiths come back.
    @Test func theCeremonyLapsesIfItStalls() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheGateOfHades
                + ["ring bell", "wait", "wait", "wait", "wait", "wait", "wait", "east"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The bell suddenly becomes red hot",
                "The tension of this ceremony is broken",
                "Some invisible force prevents you from passing through the gate.",
            ])
    }

    /// The red-hot bell is a **reach** problem, not a per-verb one. The source
    /// answers take, ring and everything else with one sentence; one
    /// ``Item/reach(otherwise:)`` rule says it once and every verb the engine
    /// gates on reach inherits it.
    @Test func theRedHotBellIsOutOfReachRatherThanRefusedVerbByVerb() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheGateOfHades + ["ring bell", "take bell", "ring bell", "examine bell"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The bell suddenly becomes red hot",
                "The bell is too hot to reach.",
                "The bell is too hot to reach.",
                "The bell glows a dull, angry red",
            ])
    }

    /// **The southern Mirror Room is the lit one**, where Zork I lights the
    /// northern; and rubbing a mirror trades the two rooms' floors along with
    /// you, which is how anything too wide for a crawlway crosses the map.
    @Test func theSouthernMirrorRoomIsLitAndRubbingTradesTheFloors() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors + ["drop garlic", "rub mirror", "turn off lamp", "look"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Mirror Room",
                "There is a rumble from deep within the earth and the room shakes.",
                "Mirror Room",
                "There is a clove of garlic here.",
            ])
        #expect(!transcript.contains("pitch black"))
    }

    /// One blow breaks both mirrors, because they are two faces of one passage,
    /// and nothing in the game mends them. The wreckage shows on every entry —
    /// the rooms are ``alwaysDescribed`` — rather than only on a deliberate
    /// `look`.
    @Test func breakingTheMirrorKillsThePassageForGood() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors + ["attack mirror", "rub mirror", "north", "south", "attack mirror"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You have broken the mirror.",
                "Unfortunately, the mirror has been destroyed by your recklessness.",
                "Haven't you done enough already?",
            ])
    }

    /// **The Winding Passage has one exit and the sound of another.** Zork I
    /// gives it a north passage; the mainframe gives it a wall with the round
    /// room's machinery behind it — a real declared exit that always refuses,
    /// because the refusal is half the room.
    @Test func theWindingPassageHearsTheRoundRoomAndCannotReachIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors + ["rub mirror", "west", "examine whirring", "north", "east"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Winding Passage",
                "The only way out of it appears to be east",
                "behind a wall with no door in it",
                "You hear the whir from the round room but can find no entrance.",
                "Mirror Room",
            ])
    }

    /// **Praying at the Altar puts you in the forest with your hands still
    /// full.** The mainframe's `PRAYER`, and the only way a gold coffin leaves
    /// the dungeon without a climb.
    @Test func prayingAtTheAltarLandsYouInTheForest() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheTemple + ["pray", "east", "pray"], seed: 18)

        expectInOrder(
            transcript,
            [
                "Temple",
                "Nothing in particular answers.",
                "Altar",
                "the temple dissolves around you",
                "Forest",
            ])
    }

    /// **Without the garlic the bat carries you off** into the coal maze, and
    /// the maze is where he leaves you. Holding it, he hangs in the corner
    /// holding his nose instead — which is what makes the jade takeable.
    @Test func theBatCarriesYouOffWithoutTheGarlic() async throws {
        let carried = try await play(
            Dungeon(),
            Self.toTheMirrors + ["drop garlic", "west", "west", "north", "northwest", "west"],
            seed: 9)

        expectInOrder(
            carried,
            [
                "Squeaky Room",
                "A deranged giant vampire bat (a reject from WUMPUS) swoops down",
                "Ladder Bottom",
            ])
        #expect(!carried.contains("Bat Room"))

        let held = try await play(
            Dungeon(),
            Self.toTheMirrors + ["west", "west", "north", "northwest", "west", "take jade"],
            seed: 18)

        expectInOrder(
            held,
            [
                "Bat Room",
                "You are in a small room which has a door only to the east.",
                "obviously deranged and holding his nose",
                "There is an exquisite jade figurine here.",
                "Taken.",
            ])
    }

    /// **The Gas Room is a dead end off the Wooden Tunnel**, not a door into the
    /// maze as it is in Zork I — and a struck match in it is the last thing you
    /// do.
    @Test func theGasRoomIsADeadEndAndAFlameInItIsFatal() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors + Self.mirrorsToTheShaft
                + ["north", "west", "down", "take bracelet", "east", "light match"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Wooden Tunnel",
                "Smelly Room",
                "Gas Room",
                "short climb up some stairs",
                "A sapphire-encrusted bracelet lies here.",
                "Taken.",
                "You can't go that way.",
                "adventurers are stupid enough to light a flame",
                "** BOOOOOOOOOOOM **",
            ])
    }

    /// **The coal maze is seven rooms with one name and one description.** Zork
    /// I cut it to four. Nothing tells them apart but the thread through them.
    @Test func theCoalMazeIsSevenRoomsUnderOneName() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors + Self.mirrorsToTheShaft + Self.throughTheCoalMaze,
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Coal Mine", "Coal Mine", "Coal Mine", "Coal Mine",
                "Ladder Top", "Ladder Bottom", "Timber Room",
            ])

        let (definition, _) = try Bootstrap.build(Dungeon())
        #expect(definition.locations.values.filter { $0.name == "Coal Mine" }.count == 7)
    }

    /// **The crack takes nothing carried in the hands**, either way round — a
    /// pair of conditional exits, as in the source, rather than a rule. Which is
    /// why the basket on the chain and not your arms is what gets the coal, the
    /// light and the screwdriver to the bottom of the shaft.
    @Test func theCrackAdmitsNothingCarried() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheShaftWithTheTorch + ["put torch in basket", "lower basket"]
                + Self.throughTheCoalMaze
                + ["southwest", "drop all", "southwest", "northeast"],
            seed: 14)

        expectInOrder(
            transcript,
            [
                "Timber Room",
                "You cannot fit through this passage with that load.",
                "brass lantern: Dropped.",
                "Lower Shaft",
                "Timber Room",
            ])
    }

    /// The Lower Shaft names the shaft it is at the bottom of, the chain
    /// hanging in it and two narrow passages out, and until #233 not one of the
    /// three answered — `ironChain` carries `chain` and `shaft` and stands a
    /// hundred feet up in the Shaft Room.
    @Test func everyNounTheLowerShaftPrints() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheShaftWithTheTorch + ["put torch in basket", "lower basket"]
                + Self.throughTheCoalMaze
                + ["southwest", "drop all", "southwest"]
                + ["examine shaft", "examine chain", "examine passage", "examine basket"],
            seed: 14)

        #expect(transcript.contains("Lower Shaft"))
        expectEveryNounAnswered(transcript, "the Lower Shaft")
        expectNoAmbiguity(transcript, "the Lower Shaft")
    }

    /// **`LIGHT-SHAFT`: ten points, once, for standing at the bottom of the
    /// shaft with light.** An event award and not a room value — a room value
    /// would pay out to anybody who stumbled in in the dark, which is the
    /// opposite of the puzzle. The light has to arrive in the basket, because
    /// the crack takes nothing carried.
    @Test func theBasketCarriesTheLightDownAndTheShaftPaysTen() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheShaftWithTheTorch
                + ["put torch in basket", "lower basket", "raise basket", "lower basket"]
                + Self.throughTheCoalMaze
                + ["southwest", "score", "drop all", "southwest", "score"],
            seed: 14)

        expectInOrder(
            transcript,
            [
                "The basket is lowered to the bottom of the shaft.",
                "The basket is raised to the top of the shaft.",
                "The basket is lowered to the bottom of the shaft.",
                "Timber Room",
                "Your score is 54 of a possible 716",
                "Lower Shaft",
                "In the basket is an ivory torch.",
                "Your score is 64 of a possible 716",
            ])
    }

    /// **Coal shut in the machine and its switch thrown becomes a diamond** —
    /// ten to find and **six** to case, where the trilogy pays ten. The switch
    /// takes the screwdriver and nothing else, and an open lid does nothing at
    /// all.
    @Test func theMachineTurnsCoalIntoADiamond() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheShaftWithTheTorch
                + Self.coalMazeToTheLadderBottom
                + [
                    "northeast", "take coal", "south", "up", "up", "east", "east", "south",
                    "put coal in basket", "put screwdriver in basket",
                    "put torch in basket", "lower basket",
                ]
                + Self.throughTheCoalMaze
                + [
                    "southwest", "drop all", "southwest", "take coal", "take screwdriver",
                    "take torch", "east",
                    "turn switch", "open machine", "turn switch with screwdriver",
                    "put coal in machine", "close machine",
                    "turn switch with screwdriver", "open machine", "take diamond",
                ],
            seed: 14)

        expectInOrder(
            transcript,
            [
                "Machine Room",
                "which is closed.",
                "It's not clear how to turn it on with your bare hands.",
                "Opened.",
                "The machine doesn't seem to want to do anything.",
                "The machine comes to life (figuratively)",
                "huge diamond",
                "Taken.",
            ])
    }

    /// The prayer at the Altar is not a curiosity, it is the **route**: it puts
    /// you above ground with your hands still full, which is how the temple
    /// quarter's treasures reach the trophy case at all — the trap door bars
    /// itself and the Studio chimney takes the lamp and one other thing.
    ///
    /// Two of milestone 3's eight treasures, found and cased, proving both
    /// halves of their mainframe values: the crystal trident (4+11) and the
    /// grail (2+5), which the trilogy does not carry at all.
    @Test func theAltarPrayerCarriesTreasureUpToTheTrophyCase() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors
                + ["east", "down", "take trident", "up", "north"]
                + ["rub mirror", "north", "north", "take grail", "up", "east"]
                + ["score", "pray", "south", "north", "east", "west", "west"]
                + ["open case", "put trident in case", "put grail in case", "score"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "On the shore lies Poseidon's own crystal trident.",
                "On the pedestal is a grail.",
                "Your score is 46 of a possible 716",
                "the temple dissolves around you",
                "Forest",
                "Living Room",
                "Your score is 62 of a possible 716",
            ])
    }

    // MARK: - Milestone 3: every printed noun answers

    @Test func everyNounTheDomeAndTheEgyptianRoomPrintAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellarWithTheRope
                + ["east", "attack troll with sword"]
                + [
                    "north", "down", "west", "examine rock",
                    "east", "examine railing", "examine dome",
                    "tie rope to railing", "down",
                    "examine pedestal", "examine doorway", "examine torch",
                    "down", "east", "north", "down", "west",
                    "northwest", "examine coffin", "examine staircase", "examine doors",
                    "up", "examine glacier",
                ],
            seed: 18)

        expectEveryNounAnswered(transcript, "the dome, the Torch Room and the Egyptian Room")
    }

    @Test func everyNounTheTempleAndHadesPrintAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors + ["rub mirror", "north", "north"]
                + [
                    "examine pedestal", "examine stairs", "examine grail",
                    "up", "examine inscription", "examine granite wall", "examine pillars",
                    "examine bell",
                    "east", "examine altar", "examine book", "examine candles",
                    "west", "west", "east", "south", "down",
                    "examine gate", "examine spirits", "examine bodies",
                ],
            seed: 18)

        expectEveryNounAnswered(transcript, "the Grail Room, the Temple and the gate of Hades")
    }

    @Test func everyNounTheMirrorsAndTheMinePrintAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors
                + [
                    "examine mirror", "examine ceiling",
                    "west", "examine corridor",
                    "west", "examine granite wall", "examine slide",
                    "north", "examine entrances",
                    "northwest", "examine sounds",
                    "west", "examine bat", "examine jade",
                    "east", "south", "northeast", "examine chain", "examine basket",
                    "north", "examine beams",
                    "west", "examine odor", "examine staircase",
                    "down", "examine gas", "examine stairs", "examine bracelet",
                    "up", "east", "northeast", "examine coal",
                ],
            seed: 18)

        expectEveryNounAnswered(transcript, "the mirror network and the coal mine")
    }

    // MARK: - Milestone 4: the maze is entered from the south

    /// Zork I hangs the maze west of the Troll Room. The mainframe hangs it
    /// **south**, and Maze-1 comes back **west** — an asymmetry that is the
    /// first thing the maze does to you.
    @Test func theMazeIsEnteredSouthAndComesBackWest() async throws {
        let transcript = try await play(
            Dungeon(), Self.pastTheTroll + ["south", "west"], seed: 18)

        expectInOrder(
            transcript,
            [
                "The Troll Room",
                "Maze",
                "This is part of a maze of twisty little passages,",
                "The Troll Room",
            ])
    }

    /// Six bearings in this maze are not the trilogy's, and every one would
    /// look like a transcription slip to somebody checking against Zork I.
    /// Maze-2 reaches Maze-4 by going **north** where the trilogy goes down.
    @Test func theMazeBearingsAreTheMainframesNotTheTrilogys() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll + ["south", "south", "north", "east"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Maze", "Maze", "Maze",
                "Dead End",
                "You have come to a dead end in the maze.",
            ])
    }

    /// The mainframe's Maze-15 opens on the cyclops to the **northeast**; Zork
    /// I's does it to the southeast.
    @Test func theCyclopsIsNortheastOfMazeFifteen() async throws {
        let transcript = try await play(
            Dungeon(), Self.toMazeFive + Self.mazeFiveToTheCyclops, seed: 18)

        expectInOrder(
            transcript,
            [
                "Cyclops Room",
                "This room has an exit on the west side, and a",
            ])
    }

    // MARK: - Milestone 4: the maze's finds

    /// Disturbing the dead adventurer's bones curses everything you are
    /// carrying and everything loose in the room, and sends it all to the Land
    /// of the Living Dead.
    @Test func theSkeletonsGhostBanishesYourValuablesToTheDead() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + ["take bag", "take skeleton", "inventory"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "An old leather bag, bulging with coins, is here.",
                "A ghost appears in the room",
                "banishes them to the Land of the Living Dead",
            ])
        #expect(!transcript.contains("bag of coins\n"))
    }

    /// The rusty knife announces itself to the elvish sword, and then kills
    /// whoever swings it — which is very likely what happened to the last
    /// person who carried it this far.
    @Test func theRustyKnifeFlaresTheSwordAndThenTurnsOnYou() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + ["take knife", "attack skeleton with rusty knife"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "gives a single pulse of",
                "twists round and buries itself in you",
            ])
    }

    // MARK: - Milestone 4: the grating

    /// The grating is locked with a skull-and-crossbones lock, the keys are in
    /// Maze-5, and the lock is on the underside — so it opens only from the
    /// maze, and opening it lets the daylight into the room below.
    @Test func theGratingIsUnlockedFromBelowAndLetsTheDaylightIn() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + ["take keys"] + Self.mazeFiveToTheGrating
                + ["open grating", "unlock grating with keys", "open grating", "turn off lamp"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Above you is a grating locked with a",
                "The grating is locked.",
                "The grate is unlocked.",
                "The grating opens to reveal trees above you.",
            ])
        #expect(!transcript.contains("It is pitch black"))
    }

    /// And from above, the Clearing reports it — which the mainframe does in
    /// its own room routine and milestone 1's static description could not.
    @Test func theClearingReportsTheGratingOnceItIsOpen() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + ["take keys"] + Self.mazeFiveToTheGrating
                + ["unlock grating with keys", "open grating", "up", "look"],
            seed: 18)

        expectInOrder(
            transcript,
            ["Clearing", "There is an open grating, descending into darkness."])
    }

    // MARK: - Milestone 4: the cyclops

    /// The shout sends him through the **north** wall — Zork I's goes through
    /// the east one — and that opens both the stair he was blocking and the
    /// shortcut back to the Living Room.
    @Test func theCyclopsLeavesByTheNorthWallAndOpensTheWayHome() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + Self.mazeFiveToTheCyclops
                + ["north", "odysseus", "look", "north", "east"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The north wall is solid rock.",
                "knocking down the wall on the north",
                "previously solid, now has a cyclops-sized",
                "Strange Passage",
                "To the south is one entrance.",
                "Living Room",
            ])
    }

    /// Feeding him works too, and it does **not** open the wall: the drugged
    /// water only puts him to sleep at the foot of the stairs. The hot peppers
    /// have to come first — the water alone he refuses.
    @Test func theLunchAndTheWaterPutHimToSleepButOpenNoWall() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["take bottle", "open sack", "take lunch"]
                + Self.downTheTrapDoor + ["east", "attack troll with sword"]
                + Self.trollRoomToMazeFive + Self.mazeFiveToTheCyclops
                + ["give water to cyclops", "give lunch to cyclops", "give water to cyclops"]
                + ["up", "down", "north"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "apparently is not thirsty",
                "I love hot peppers",
                "falls fast asleep",
                "Treasure Room",
                "The north wall is solid rock.",
            ])
    }

    /// And the shout still works on the sleeper — the source asks only whether
    /// he is still standing in the room, and the water leaves him there.
    @Test func theShoutStillWorksOnTheSleepingCyclops() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["take bottle", "open sack", "take lunch"]
                + Self.downTheTrapDoor + ["east", "attack troll with sword"]
                + Self.trollRoomToMazeFive + Self.mazeFiveToTheCyclops
                + ["give lunch to cyclops", "give water to cyclops", "odysseus", "north"],
            seed: 18)

        expectInOrder(
            transcript,
            ["falls fast asleep", "knocking down the wall on the north", "Strange Passage"])
    }

    /// Provoke him and stay, and the wrath ladder runs its six rungs and then
    /// he eats you. Steel never touches him on the way.
    @Test func theCyclopsEatsYouIfYouProvokeHimAndLinger() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + Self.mazeFiveToTheCyclops
                + ["attack cyclops with sword", "wait", "wait", "wait", "wait", "wait", "wait"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The cyclops ignores all injury to his body with a shrug.",
                "The cyclops seems somewhat agitated.",
                "You have two choices: 1. Leave  2. Become dinner.",
                "Just like Mom used to make 'em",
            ])
    }

    // MARK: - Milestone 4: the Treasure Room

    /// The Treasure Room pays 25 for arriving and the Strange Passage 10 — two
    /// room values Zork I does not have at all.
    @Test func theTreasureRoomPaysTwentyFiveAndTheStrangePassageTen() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + Self.mazeFiveToTheCyclops
                + ["odysseus", "score", "up", "score", "down", "north", "score"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Your score is 35 of a possible 716",
                "Your score is 60 of a possible 716",
                "Your score is 70 of a possible 716",
            ])
    }

    /// The Temple and the Treasure Room share a north wall of solid granite,
    /// and one word said in either room takes you to the other. Mainframe-only:
    /// nothing in the trilogy connects them, and the trilogy's Treasure Room
    /// puts its granite on the east wall because it has no Royal Puzzle to open
    /// onto.
    ///
    /// The word is said on the turn after arrival, and the wall is examined at
    /// the Temple end rather than the hoard's, because the hoard has a thief
    /// standing over it who does not wait for you to finish sightseeing.
    @Test func theGraniteWallCarriesYouBetweenTheTempleAndTheHoard() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + Self.mazeFiveToTheCyclops
                + ["odysseus", "up", "temple", "examine granite wall", "treasure"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "whose north wall is solid granite",
                "newly created",
                "The granite wall shivers",
                "Temple",
                "The north wall is solid granite here.",
                "The granite wall shivers",
                "Treasure Room",
            ])
    }

    /// The word is inert everywhere the granite wall is not.
    @Test func theGraniteWordDoesNothingElsewhere() async throws {
        let transcript = try await play(Dungeon(), ["treasure", "temple"])

        #expect(transcript.contains("Nothing happens."))
    }

    // MARK: - Milestone 4: the Frigid River

    /// The Loud Room's east door is the mainframe's road to the west bank on
    /// foot: the Ancient Chasm, the Small Cave and Rocky Shore. Zork I has none
    /// of these rooms and reaches the water only by boat.
    @Test func theLoudRoomsEastDoorReachesTheRiverOnFoot() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheLoudRoom + Self.loudRoomToTheRiver, seed: 18)

        expectInOrder(
            transcript,
            [
                "Loud Room",
                "Ancient Chasm",
                "Passages lead off in every direction.",
                "Small Cave",
                "Rocky Shore",
                "You are on the west shore of the river.",
            ])
    }

    /// The banks are reversed from the trilogy's: the White Cliffs are **east**
    /// and the sandy beach **west**. Both stretches that touch a bank say so,
    /// and both exits go the mainframe's way.
    @Test func theRiverBanksAreReversedFromTheTrilogys() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.afloatOnTheRiver + ["down", "down", "east", "launch", "down", "west"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "There is a narrow beach on the",
                "White Cliffs Beach",
                "On the west shore is a sandy beach.",
                "Sandy Beach",
            ])
    }

    /// There is no current in this river. `dung.355` registers no clock
    /// interrupt for it, so a boat that is not paddled stays exactly where it
    /// is — where Zork I's drifts a stretch downstream every few turns.
    @Test func thereIsNoCurrentAndTheBoatStaysWhereYouLeaveIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.afloatOnTheRiver + ["wait", "wait", "wait", "wait", "wait", "wait", "look"],
            seed: 18)

        #expect(!transcript.contains("carries you"))
        expectInOrder(
            transcript, ["Frigid River", "There is a landing on the west shore."])
    }

    /// Paddling off the end of River-5 goes over Aragain Falls. The mainframe
    /// drops you into a room whose only job is to kill you; this does it in one
    /// move.
    @Test func paddlingOffTheEndOfRiverFiveGoesOverTheFalls() async throws {
        let transcript = try await play(
            Dungeon(), Self.afloatOnTheRiver + ["down", "down", "down", "down", "down"],
            seed: 18)

        #expect(transcript.contains("swept over the lip of Aragain Falls"))
    }

    /// Only one thing in this game holes the boat, and the label names it. Zork
    /// I bursts it on any sharp thing at all; here the broken sharp stick is
    /// the whole class.
    @Test func onlyTheBrokenStickHolesTheBoatAndTheGunkPatchesIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll + ["drop sword"] + Self.crossroadsToTheDam
                + ["north", "north", "take tube", "south", "south"] + Self.damToTheBoat
                + [
                    "inflate plastic with pump", "read label", "take stick", "board boat",
                    "open tube", "take putty", "plug boat with putty",
                    "drop stick", "inflate plastic with pump", "board boat",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Keep sharp objects, such as",
                "There is a hissing sound and the boat deflates.",
                "Well done. The boat is repaired.",
                "The boat inflates and appears seaworthy.",
            ])
    }

    /// The White Cliffs path is too narrow for the boat — whether you carry it
    /// or sit in it — and the cliffs have no way inland at all, where Zork I
    /// bores a foot-path west into the Damp Cave.
    @Test func theCliffPathRefusesTheBoatAndTheCliffsHaveNoWayInland() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.afloatOnTheRiver
                + ["down", "down", "east", "south", "west", "get out", "deflate boat", "south"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "White Cliffs Beach",
                "The path is too narrow to take the boat along it.",
                "You can't go that way.",
                "The boat deflates.",
                "White Cliffs Beach",
            ])
    }

    // MARK: - Milestone 4: the beach, the falls and the rainbow

    /// Four digs in the sand bare a statue worth ten and **thirteen** — where
    /// Zork I buries a scarab in a Sandy Cave the mainframe does not have — and
    /// a fifth brings the hole down on you.
    @Test func theBeachGivesUpAStatueAndThenBuriesYou() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll + ["drop sword"] + Self.crossroadsToTheLoudRoom
                + ["east", "east", "take shovel", "northwest", "south", "up", "east"]
                + Self.damToTheBoat + Self.castOff
                + ["down", "down", "down", "west"]
                + [
                    "dig sand with shovel", "dig sand with shovel", "dig sand with shovel",
                    "dig sand with shovel", "take statue", "score",
                    "dig sand with shovel",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Sandy Beach",
                "You seem to be digging a hole here.",
                "You can see a small statue here in the sand.",
                "Your score is 50 of a possible 716",
                "The hole collapses, smothering you.",
            ])
    }

    /// Waving the broken sharp stick at either end of the rainbow makes the
    /// rainbow solid and the pot of gold visible. The 1981 source has **no
    /// sceptre at all**; this stick does both of the sceptre's jobs — and doing
    /// it while standing on the rainbow takes the rainbow out from under you.
    @Test func theStickWavesTheRainbowSolidAndShowsThePotOfGold() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll + ["drop sword"] + Self.crossroadsToTheDam
                + ["down", "take stick", "north"] + Self.damBackToTheTrollRoom
                + Self.outByTheChimney
                + ["east", "east", "east", "southeast", "southeast", "down", "down", "north"]
                + ["wave stick", "look", "take pot", "score", "west", "wave stick"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "End of Rainbow",
                "the rainbow appears to become solid",
                "At the end of the rainbow is a pot of gold.",
                "Your score is 50 of a possible 716",
                "Rainbow Room",
                "and fifty feet above the river, do you",
            ])
    }

    /// Aragain Falls says which kind of rainbow it has, every time — the room
    /// is ``alwaysDescribed`` for exactly that.
    @Test func aragainFallsReportsTheRainbowOnEveryLook() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.afloatOnTheRiver + ["down", "down", "down", "down", "land", "south"]
                + ["get out", "look", "board barrel", "look", "geronimo"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Aragain Falls",
                "A beautiful rainbow can be seen over the falls and to the east.",
                "There is a man-sized barrel here",
                "You are inside a barrel. Congratulations.",
                "the finest ride in the Great Underground",
            ])
    }

    // MARK: - Milestone 4: the graph is joined up

    /// With this milestone in, the main dungeon is one connected graph: the
    /// house, the crossroads, the dam, the river, the temple quarter, the
    /// mirrors, the mine and the maze all reach one another without a save.
    /// This walks the seams milestone 4 closed, in one run.
    @Test func theMainDungeonIsOneConnectedGraph() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll
                // North through the crossroads and out to the river on foot,
                // by the Loud Room's east door.
                + Self.crossroadsToTheLoudRoom + Self.loudRoomToTheRiver
                // Back the way we came, and south into the maze instead.
                + ["northwest", "northwest", "south", "west", "north", "south", "south", "west"]
                + Self.trollRoomToMazeFive + Self.mazeFiveToTheCyclops
                // Out by the cyclops's north wall, into the Living Room.
                + ["odysseus", "north", "east"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The Troll Room",
                "East-West Passage",
                "Loud Room",
                "Ancient Chasm",
                "Small Cave",
                "Rocky Shore",
                "The Troll Room",
                "Maze",
                "Cyclops Room",
                "Strange Passage",
                "Living Room",
            ])
    }

    // MARK: - Milestone 4: every printed noun answers

    @Test func everyNounTheMazeAndTheCyclopsPrint() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive
                + [
                    "examine maze", "examine passages", "examine skeleton",
                    "examine bag", "examine knife", "examine lantern", "examine keys",
                ]
                + Self.mazeFiveToTheCyclops
                + ["examine cyclops", "examine staircase", "examine wall", "odysseus", "examine wall"]
                + ["north", "examine passage", "examine hole"],
            seed: 18)

        expectEveryNounAnswered(transcript, "the maze, the cyclops and the Strange Passage")
    }

    @Test func everyNounTheWesternApproachPrints() async throws {
        let onFoot = try await play(
            Dungeon(),
            Self.toTheLoudRoom + ["east", "examine chasm", "examine passages"]
                + ["east", "examine cave", "examine guano", "examine shovel"]
                + ["south", "examine river", "examine cave"],
            seed: 18)

        expectEveryNounAnswered(onFoot, "the Ancient Chasm, the Small Cave and Rocky Shore")
    }

    @Test func everyNounTheRiverPrints() async throws {
        let afloat = try await play(
            Dungeon(),
            Self.afloatOnTheRiver
                + ["examine river", "examine label", "examine boat"]
                + ["down", "examine river", "down", "examine river", "examine beach"]
                + ["east", "examine cliffs", "examine path", "launch"]
                + ["down", "examine buoy", "west", "examine river", "examine sand"]
                + ["south", "examine shore", "south", "examine falls", "examine rainbow"]
                + ["examine barrel"],
            seed: 18)

        expectEveryNounAnswered(afloat, "the river, its banks and the falls")
    }

    // MARK: - Milestone 5: the roads in

    /// Milestone 5's road: down, past the troll, and out of the Round Room's
    /// carousel into the Engravings Cave. Seed 41 throughout, recorded, because
    /// the carousel is a lottery until the triangular button stops it and this
    /// is the draw that lands.
    ///
    /// The bottle comes along from the kitchen table with the water still in
    /// it: the well will not lift anybody without it.
    private static let toTheEngravingsCave =
        intoTheKitchen + ["take bottle", "open bottle"] + downTheTrapDoor
        + ["east", "attack troll with sword", "drop sword", "north", "east", "north"]

    /// On through the riddle to the bottom of the well.
    private static let toTheWell =
        toTheEngravingsCave + ["southeast", "answer well", "east", "east"]

    /// And up it, into the tea party.
    private static let toTheTeaRoom =
        toTheWell + ["board bucket", "pour water in bucket", "get out", "east"]

    /// The Bank hangs off the Gallery, which is two rooms south of the Cellar
    /// and needs no fight and no seed.
    private static let toTheBank = intoTheCellar + ["south", "south", "west"]

    // MARK: - Milestone 5: the riddle

    /// The Engravings Cave's second passage. Zork I's cave has two exits too,
    /// and they are northwest and east; the mainframe's are north and
    /// **southeast**, and the southeast one is the only road to the well, the
    /// Bank's neighbours and everything above them.
    @Test func theEngravingsCaveOpensSoutheastOnTheRiddleRoom() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheEngravingsCave + ["southeast", "look"], seed: 41)

        expectInOrder(
            transcript,
            ["Engravings Cave", "Riddle Room", "great door of dressed stone"])
    }

    /// The door opens for one word and for nothing else. The riddle is written
    /// fresh — `RIDDL`'s trilogy column in the comparison document is empty,
    /// because no trilogy room answers to it — but the **answer** is the
    /// source's, since the answer is puzzle logic and puzzle logic is
    /// structure.
    @Test func theStoneDoorOpensOnlyForTheWordWell() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheEngravingsCave
                + ["southeast", "read inscription", "east", "answer well", "east"],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "No one passes who cannot say",
                "Something you cannot see stands between you and the doorway",
                "the great door swings back",
                "Pearl Room",
            ])
    }

    /// And the word is inert everywhere else, because it is a word in the
    /// game's vocabulary everywhere.
    @Test func theRiddleWordIsInertEverywhereElse() async throws {
        let transcript = try await play(Dungeon(), ["answer well"], seed: 41)

        #expect(transcript.contains("Nothing here is waiting on an answer."))
    }

    /// `MPEAR` is an `identical` entry, so the room is the trilogy's line
    /// verbatim. The pearls pay **9** to find and **5** to case — the one
    /// treasure in this milestone worth more in the hand than in the case.
    @Test func thePearlNecklaceIsWorthMoreFoundThanCased() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheEngravingsCave
                + ["southeast", "answer well", "east", "score", "take necklace", "score"],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "This is a former broom closet.",
                "There is a pearl necklace here with hundreds of large pearls.",
                "Your score is 40 of a possible 716",
                "Your score is 49 of a possible 716",
            ])
    }

    // MARK: - Milestone 5: the well

    /// The bucket is a vehicle, and the only lift in the game. Water in it
    /// sends it up; emptying it sends it back down, which is what keeps the
    /// whole area above the well from being a one-way trip — it has no other
    /// exit.
    @Test func theBucketRisesOnWaterAndSinksWhenItIsEmptied() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheWell
                + ["board bucket", "pour water in bucket", "empty bucket", "look"],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "There is a wooden bucket here, 3 feet in diameter",
                "The bucket rises",
                "Top of Well",
                "the bucket sinks gently",
                "Circular Room",
            ])
    }

    /// The Top of Well's ten points are the mainframe's `RVAL`, and this game
    /// pays them from an each-turn rule rather than from `scoring.visit`. A
    /// room value is an arrival award, and the usual way into this room is
    /// riding a vehicle up — which moves the bucket and carries the player,
    /// and runs no `onEnter` at all. The Bank of Zork spike (#132) recorded
    /// that hole; this is the first room in the game to fall into it.
    @Test func theTopOfWellPaysItsRoomValueToSomebodyWhoRodeUp() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheWell + ["score", "board bucket", "pour water in bucket", "score"],
            seed: 41)

        expectInOrder(
            transcript,
            ["Your score is 40 of a possible 716", "Your score is 50 of a possible 716"])
    }

    /// Two rooms carry the well's etchings, and the ring of letters is legible
    /// only at the top. Written fresh: the source's figure is 1981 MDL
    /// typography and this game reproduces none of that — but what it spells is
    /// the riddle's answer, which is a hint, and a hint is structure.
    @Test func theEtchingsAreHalfGoneBelowAndWholeAbove() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheWell
                + ["read etchings", "board bucket", "pour water in bucket", "read etchings"],
            seed: 41)

        expectInOrder(
            transcript,
            ["the damp has had the", "M A G I C", "W E L L"])
    }

    // MARK: - Milestone 5: the tea party

    /// The three iced cakes carry writing the size of the icing, and only
    /// somebody four inches high can read it.
    @Test func theIcedCakesCannotBeReadUntilYouAreSmall() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + [
                    "take red cake", "take eat-me cake", "read red cake",
                    "eat eat-me cake", "read red cake",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "far too small to make out",
                "Posts Room",
                "EVAPORATE ME",
            ])
    }

    /// The 'Eat-Me' cake works in the Tea Room and nowhere else, and what it
    /// does is put you on the floor under the table — which is `ALISM`, a room
    /// with no exit into it anywhere in the atlas because eating is the only
    /// way to arrive.
    @Test func theEatMeCakeDropsYouUnderTheTable() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom + ["take eat-me cake", "eat eat-me cake", "east"],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "four wooden posts",
                "Pool Room",
                "rope of goop falls from a leak",
            ])
    }

    /// And the orange one brings you back, but only from under the table:
    /// there is nowhere in the Pool Room for a full-sized person to be.
    @Test func theOrangeCakeOnlyWorksUnderTheTable() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + [
                    "take eat-me cake", "take orange cake", "eat eat-me cake",
                    "east", "eat orange cake", "west", "eat orange cake",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "Posts Room",
                "Pool Room",
                "growing to full size in here would be the last",
                "Posts Room",
                "you are standing in the Tea Room at your proper size",
            ])
    }

    /// The blue one is a mistake, and the source's own adjective for it —
    /// *ecch* — says so before you make it.
    @Test func theBlueCakeIsAMistake() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheTeaRoom + ["take blue cake", "eat blue cake"], seed: 41)

        #expect(transcript.contains("chemistry set ever sold"))
    }

    /// The red cake in the pool is the source's `LOW-TIDE`: the depression
    /// boils dry and the tin of spices the Pool Room has been holding all along
    /// — declared in its contents and denied its `OVISON` — is finally there to
    /// pick up. Five to find and five to case.
    @Test func theRedCakeEvaporatesThePoolAndShowsTheSpices() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + [
                    "take eat-me cake", "take red cake", "eat eat-me cake", "east",
                    "take tin", "throw red cake in pool", "look", "take tin", "score",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "You can't see any such thing.",
                "goes up at once in a column of steam",
                "There is a tin of rare spices here.",
                "Taken.",
                "Your score is 55 of a possible 716",
            ])
    }

    /// The flask is not a puzzle. It is a skull and crossbones with a stopper
    /// in it.
    @Test func theFlaskIsATrapAndNotATool() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + ["take eat-me cake", "eat eat-me cake", "east", "open flask"],
            seed: 41)

        #expect(transcript.contains("the vapour goes into you"))
    }

    // MARK: - Milestone 5: the robot

    /// `MAGNE` has **nine** exits and they reach two rooms: five of them the
    /// Machine Room and four the Tea Room. The source gates every one on
    /// `MAGNET-ROOM-EXIT`, a routine `dung.355` does not carry, so the
    /// destinations are the atlas's and the gate is not built.
    @Test func theLowRoomsNinePassagesReachExactlyTwoRooms() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + ["northwest", "north", "west", "northeast", "west", "southwest", "northwest"],
            seed: 41)

        expectInOrder(
            transcript,
            ["Low Room", "Machine Room", "Low Room", "Machine Room", "Low Room", "Tea Room"])
    }

    /// The robot walks on your word, and the engine runs no default action for
    /// somebody else — so the order is answered by a rule in this game or by
    /// nothing at all. #130 is what made the sentence reach a rule; the table
    /// it walks is `DungeonAlice`'s.
    @Test func theRobotWalksOnYourWordAndNotOtherwise() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom + ["northwest", "read paper", "robot, up", "robot, north", "north"],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "FROBOZZ MAGIC ROBOT COMPANY",
                "ROBOT, LIFT THE CAGE",
                "The robot's treads grind against the rock",
                "The robot turns on its treads and clanks away.",
                "Machine Room",
                "There is a robot here.",
            ])
    }

    /// Lifting the sphere off its pedestal drops a steel cage on whoever did
    /// it. Done by hand it costs you the room; the way out is the one order
    /// the green paper spells out, and the robot mangles the cage getting it
    /// up. The six points are paid on the take, because the trap is an `after`
    /// rule that does not throw.
    @Test func theSphereSpringsACageAndTheRobotLiftsItOff() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + [
                    "northwest", "robot, north", "north", "robot, south", "south",
                    "take sphere", "score", "robot, lift cage", "look",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "Dingy Closet",
                "There is a beautiful white crystal sphere here.",
                "Taken.",
                "a steel cage falls from the ceiling",
                "You are trapped inside a solid steel cage.",
                "the robot stands exactly where you",
                "Your score is 56 of a possible 716",
                "with a scream of tearing steel",
                "There is a mangled steel cage here.",
            ])
    }

    /// Ordered to fetch it instead, the robot springs the trap on itself and
    /// does not mind. An order never reaches stage 4, so that half of the trap
    /// has to be a `before` rule where the player's half is an `after` one.
    @Test func theRobotOrderedToTakeTheSphereWearsTheCageInstead() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + [
                    "northwest", "robot, north", "north", "robot, south", "south",
                    "robot, take sphere", "look", "take sphere",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "lands on the robot, which does not appear",
                "There is a mangled steel cage here.",
                "Taken.",
            ])
    }

    // MARK: - Milestone 5: the three buttons

    /// The triangular button stops the machinery under the Round Room — a room
    /// in another bundle a very long way off, which is why the host presses it
    /// — and what the stopped floor stops hiding is the dented steel box that
    /// has stood in the Round Room since turn one. Milestone 2 declined to
    /// declare the box for exactly this reason.
    @Test func theTriangularButtonStopsTheCarouselAndShowsTheSteelBox() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + [
                    "northwest", "north", "push triangular button", "push triangular button",
                    "push round button", "push square button",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "a great deal of machinery slows and",
                "the machinery it spoke to has already",
                "takes note of the round",
                "takes note of the square",
            ])
    }

    // MARK: - Milestone 5: the Bank of Zork

    /// The Gallery's west door, which milestone 1 left undeclared. Nine rooms
    /// hang off it and none of them reached Zork I.
    @Test func theGalleryOpensWestOnTheBankOfZork() async throws {
        let transcript = try await play(Dungeon(), Self.toTheBank + ["look"], seed: 41)

        expectInOrder(
            transcript,
            ["Gallery", "Bank Entrance", "the largest banking"])
    }

    /// The whole of the Bank's puzzle in one run: the curtain of light answers
    /// to the bearing you last walked into the Depository on, and the one
    /// bearing that opens the Vault is *south* — which no doorway can give you,
    /// because the only thing north of the Depository is the curtain itself.
    @Test func theCurtainAnswersToTheBearingYouCameInOn() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheBank
                + [
                    "northwest", "west", "walk through curtain", "walk through curtain",
                    "walk through curtain", "take bills", "score",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "West Teller's Room",
                "Safety Depository",
                "Viewing Room",
                "Safety Depository",
                "This is the Vault of the Bank of Zork, in which there are no doors.",
                "On the floor sit 200 neatly stacked zorkmid bills.",
                "Your score is 45 of a possible 716",
            ])
    }

    /// And the other road in: from the Chairman's Office you walk into the
    /// Depository heading north, and the curtain opens on the Small Room, whose
    /// south wall is one of the four pairings in the source's `SCOL-WALLS`.
    @Test func theSmallRoomsSouthWallIsTheOtherWayIntoTheVault() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheBank
                + [
                    "northeast", "east", "south", "north", "walk through curtain",
                    "walk through south wall", "look",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "East Teller's Room",
                "Chairman's Office",
                "Safety Depository",
                "This is a small, bare room",
                "The wall gives like water",
                "This is the Vault of the Bank of Zork",
            ])
    }

    /// Every wall the source does not pair puts you in the entrance hall, which
    /// is `SCOLEXIT`'s destination — and the only way to leave the building
    /// with the takings, because the Depository's own doorways ring the alarm
    /// on anything belonging to the bank.
    @Test func theAlarmHoldsBankPropertyAndTheWallsDoNot() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheBank
                + [
                    "northwest", "west", "south", "take portrait", "north", "west", "east",
                    "walk through curtain", "walk through curtain", "walk through curtain",
                    "take bills", "walk through east wall", "score",
                ],
            seed: 41)

        expectInOrder(
            transcript,
            [
                "A portrait of J. Pierpont Flathead hangs on the wall.",
                "An alarm rings briefly and an invisible force prevents your leaving.",
                "An alarm rings briefly and an invisible force prevents your leaving.",
                "The wall gives like water",
                "Bank Entrance",
                "Your score is 55 of a possible 716",
            ])
    }

    // MARK: - Milestone 5: every printed noun answers

    @Test func everyNounTheRiddleRoomAndTheWellPrint() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheEngravingsCave
                + ["southeast", "examine door", "examine inscription", "answer well"]
                + ["east", "examine necklace", "examine shelves"]
                + ["east", "examine bucket", "examine etchings", "examine well"]
                + ["board bucket", "pour water in bucket", "get out", "examine crack"],
            seed: 41)

        expectEveryNounAnswered(transcript, "the Riddle Room, the Pearl Room and the well")
    }

    @Test func everyNounTheTeaPartyAndTheRobotPrint() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + ["examine table", "examine hole", "examine eat-me cake", "examine blue cake"]
                + ["northwest", "examine robot", "examine paper", "examine ceiling"]
                + ["north", "examine round button", "examine square button"]
                + ["examine triangular button", "south", "examine sphere", "examine pedestal"]
                + ["examine sticker"],
            seed: 41)

        expectEveryNounAnswered(transcript, "the Tea Room, the Low Room and the closet")
    }

    @Test func everyNounTheBankPrints() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheBank
                + ["examine signs", "northwest", "examine counter", "west"]
                + ["examine cube", "read cube", "examine curtain", "examine walls"]
                + ["examine boxes", "examine doorways", "south"]
                + ["examine wreckage", "examine portrait", "north", "walk through curtain"]
                + ["examine northern wall", "examine eastern wall", "examine curtain"]
                + ["walk through curtain", "walk through curtain", "examine bills"],
            seed: 41)

        expectEveryNounAnswered(transcript, "the Bank of Zork")
    }

    /// Round the well, up to the Machine Room for the triangular button, and
    /// back down to a Round Room whose floor has stopped turning — which is
    /// what stops hiding the dented steel box.
    private static let toTheStoppedRoundRoom =
        toTheTeaRoom
        + ["northwest", "north", "push triangular button", "west", "southeast"]
        + ["west", "board bucket", "empty bucket", "get out", "west", "west", "down"]
        + ["north"]

    /// With milestone 5 in, the Bank and everything above the well join the
    /// graph — the Bank off the Gallery, the well off the Engravings Cave — and
    /// the Round Room stops being a lottery for anybody who has reached the
    /// Machine Room.
    @Test func milestoneFiveJoinsTheBankAndTheWellToTheGraph() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheStoppedRoundRoom + ["look"], seed: 41)

        expectInOrder(
            transcript,
            [
                "Machine Room",
                "a great deal of machinery slows and",
                "Low Room",
                "Tea Room",
                "Top of Well",
                "Circular Room",
                "Pearl Room",
                "Riddle Room",
                "Engravings Cave",
                "Round Room",
                "the machinery that turned it has",
                "There is a dented steel box here.",
            ])
    }

    // MARK: - The listing lines a nested thing earns

    // Ten of these lines were written for the position the object starts in —
    // on a table, inside a boat — and none of them could print: the describer
    // asked for a presence line only for the things standing on the floor, and
    // listed everything one level down through the stock *"On the X is a Y."*
    // instead. #176 widened the channel; these pin what it now carries, since
    // no other test in the suite reads a line that was dead when it was
    // written.

    /// The kitchen table and the attic table. Both lines are the source's own,
    /// and both used to lose to *"On the kitchen table is a bottle."*
    @Test func theHousesTableTopsPrintTheSourcesOwnLines() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["west", "take lamp", "turn on lamp", "east", "up"])

        expectInOrder(
            transcript,
            [
                "Kitchen",
                "A bottle is sitting on the table.",
                "On the table is an elongated brown sack, smelling of hot peppers.",
                "Attic",
                "On a table is a nasty-looking knife.",
            ])
        #expect(!transcript.contains("On the kitchen table is"))
        #expect(!transcript.contains("On the attic table is"))
    }

    /// The mad tea party. Four cakes on one oblong table, four lines, none of
    /// them the stock one.
    @Test func theTeaTablePrintsEachCakesOwnLine() async throws {
        let transcript = try await play(Dungeon(), Self.toTheTeaRoom, seed: 41)

        expectInOrder(
            transcript,
            [
                "Tea Room",
                "There is a piece of cake with blue (ecch) icing here.",
                "There is a piece of cake here with the words 'Eat-Me' on it.",
                "There is a piece of cake with orange icing here.",
                "There is a piece of cake with red icing here.",
            ])
        #expect(!transcript.contains("On the large oblong table is"))
    }

    /// The label the boat comes folded around — the object #176 was filed
    /// about. Its `presence` rule has always had two branches; until the
    /// channel widened, only the out-on-the-bank one could ever run.
    @Test func theBoatPrintsTheLabelFoldedInsideIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheBeachedBoat + ["inflate plastic with pump", "look"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The boat inflates and appears seaworthy.",
                "There is a magic boat here.",
                "A tan label is lying inside the boat.",
            ])
        #expect(!transcript.contains("In the magic boat is a tan label"))
    }

    /// And the same for something the player opens rather than inflates: the
    /// violin's line waits inside the steel box until the box does.
    @Test func theOpenedSteelBoxPrintsTheViolinsOwnLine() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheStoppedRoundRoom + ["open box", "look"], seed: 41)

        expectInOrder(
            transcript,
            [
                "Opening the dented steel box reveals a fancy violin.",
                "There is a dented steel box here.",
                "There is a Stradivarius here.",
            ])
        #expect(!transcript.contains("In the dented steel box is"))
    }

    /// The buoy is the same shape, three bends down the Frigid River.
    @Test func theOpenedBuoyPrintsTheEmeraldsOwnLine() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.afloatOnTheRiver + ["down", "down", "down", "open buoy", "look"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Opening the red buoy reveals a large emerald.",
                "There is a red buoy here (probably a warning).",
                "There is a large emerald here.",
            ])
        #expect(!transcript.contains("In the red buoy is"))
    }

    // MARK: - Milestone 6: the roads in

    /// The house with the two things the volcano wants out of it: the brick in
    /// the Attic, which is the safe's charge, and the newspaper on the living
    /// room floor, which is the balloon's fuel.
    private static let houseWithTheBrickAndThePaper =
        intoTheKitchen + [
            "west", "take lamp", "take sword", "turn on lamp",
            "east", "up", "take rope", "take brick", "down", "west",
            "take newspaper", "push rug", "open trap door", "down",
        ]

    /// Past the troll, out to the Dam Lobby for the matchbook — the only flame
    /// in the game that can be carried to the volcano — and back to the Rocky
    /// Crawl. Seed 18: the troll falls to the first blow.
    private static let fetchTheMatchbook =
        ["east", "attack troll with sword", "drop sword"]
        + crossroadsToTheDam
        + ["north", "take matchbook", "south"]
        + ["east", "south", "west", "north", "south", "west"]

    /// Down the rope for the torch, out of the Torch Room the only way there
    /// is, and round to the face of the glacier.
    private static let toTheGlacier =
        houseWithTheBrickAndThePaper + fetchTheMatchbook
        + ["east", "tie rope to railing", "down", "take torch", "down"]
        + torchRoomToTheGlacier

    /// Out of the North-South Crawlway the torch drops you into, back round the
    /// crossroads and up the Egyptian Room's staircase to the face of the ice.
    private static let torchRoomToTheGlacier = [
        "east", "north", "down", "west", "northwest", "up",
    ]

    /// And through it, which is the same four commands whichever errand took
    /// you to the Glacier Room.
    private static let throughTheGlacier = [
        "throw torch at glacier", "west", "west", "south",
    ]

    /// Through it, and down the two rooms milestone 3 left hanging: the Ruby
    /// Room's west passage and the Lava Room's south one.
    /// Not `private`, for ``toTheNarrowLedge``'s reason: `DungeonProseTests`
    /// walks the shaft's scenery from the floor up.
    static let toTheVolcano = toTheGlacier + throughTheGlacier

    /// The third ledge, and the one no balloon reaches: on foot, south out of
    /// the Egyptian Room. Not `private`, for the same reason. Seed 18.
    static let toVolcanoView =
        pastTheTroll + ["north", "down", "west", "northwest", "south", "down"]

    /// The same road with the wire coil picked up off the bank at Stream View,
    /// which is what the brick wants in it.
    private static let toTheVolcanoWithTheWire =
        toTheGlacier + ["north", "take wire", "north"] + throughTheGlacier

    /// Fuel in the pan, a match to it, and the four turns that carry the basket
    /// from the floor to the level of the Narrow Ledge. The drift clock runs on
    /// threes, and `look` costs a turn like anything else.
    private static let liftOff = [
        "board basket", "put newspaper in receptacle",
        "burn match", "burn newspaper with match",
        "look", "wait", "wait", "wait", "wait",
    ]

    /// Not `private`: `DungeonProseTests` asserts that this level's paragraph
    /// still says *west*, which is the untouched control for the Wide Ledge's
    /// corrected bearing.
    static let toTheNarrowLedge = toTheVolcano + liftOff + ["west"]

    /// Six turns further up the shaft is the Wide Ledge, and one level above
    /// that is the rim.
    /// Moor the basket, walk into the Dusty Room, load the hole and light the
    /// wire, then get out on the ledge and wait for the blast.
    /// Not `private`, for ``toTheNarrowLedge``'s reason: `DungeonProseTests`
    /// asks the small door what it is before and after the room comes down.
    static let lightTheCharge = [
        "tie braided wire to hook", "get out", "south",
        "put brick in hole", "put wire in brick", "burn match",
        "burn wire with match", "north", "wait",
    ]

    /// Not `private`, for ``toTheNarrowLedge``'s reason.
    static let toTheWideLedge =
        toTheVolcanoWithTheWire + liftOff
        + ["wait", "wait", "wait", "wait", "wait", "wait", "east"]

    // MARK: - Milestone 6: the two doors into the volcano

    /// **The Ruby Room opens west, and it opens west from both ends.** Milestone
    /// 3 built the room and left the passage as a seam; the mainframe runs it
    /// west out of `RUBYR` *and* west out of `LAVA`, the same doubling the Deep
    /// Ravine's crawl has.
    @Test func theRubyRoomOpensWestOnTheLavaRoomAndTheVolcanoFloor() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheVolcano + ["north", "west", "west", "south"], seed: 18)

        expectInOrder(
            transcript,
            [
                "Ruby Room",
                "Lava Room",
                "walls are formed by an old lava flow",
                "Volcano Bottom",
                "The only exit is to the north.",
                "There is a large and extremely heavy wicker basket here.",
                "Lava Room",
                "Ruby Room",
                "Lava Room",
                "Volcano Bottom",
            ])
    }

    /// **Volcano View is reached on foot, south out of the Egyptian Room** — a
    /// door that room's description has named since milestone 3. It is the one
    /// ledge no balloon can land on, and the source says so twice: `DOWN` and
    /// `CROSS` are both declared, and both refuse.
    @Test func theEgyptianRoomOpensSouthOnVolcanoView() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll
                + ["north", "down", "west", "northwest", "south", "down", "cross", "east"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Egyptian Room",
                "Volcano View",
                "this ledge is intermediate in elevation between those on the other side.",
                "I wouldn't try that.",
                "It is impossible to cross this distance.",
                "Egyptian Room",
            ])
    }

    // MARK: - Milestone 6: the balloon

    /// **The balloon is a fuse and a fire, and nothing else.** Fuel in the
    /// receptacle, a match to it, and it goes up a level every three turns —
    /// the mainframe's `BINT`.
    @Test func theBalloonRisesThreeTurnsAtATimeOnAFireInThePan() async throws {
        let transcript = try await play(Dungeon(), Self.toTheVolcano + Self.liftOff, seed: 18)

        expectInOrder(
            transcript,
            [
                "The newspaper burns inside the receptacle.",
                "The cloth bag inflates as it fills with hot air.",
                "The balloon rises slowly from the ground.",
                "Volcano Core",
                "The balloon ascends.",
                "Volcano Near Small Ledge",
                "There is a small ledge on the west side.",
            ])
    }

    /// **Closing the lid is how you come down.** The source rises only while
    /// the receptacle is *open* and alight; shut it over a live fire and the
    /// basket sinks and lands intact, which is the difference between a landing
    /// and a crash.
    @Test func closingTheReceptacleBringsTheBalloonDownIntact() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheVolcano + Self.liftOff
                + ["close receptacle", "wait", "wait", "wait", "wait", "wait", "wait"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Volcano Near Small Ledge",
                "The balloon descends.",
                "Volcano Core",
                "The balloon has landed.",
                "Volcano Bottom",
            ])
    }

    /// **A balloon is not steered.** Only the two levels with a ledge beside
    /// them answer a compass bearing at all, and the four air rooms will not let
    /// you step over the side.
    @Test func theBalloonCannotBeSteeredAndCannotBeLeftInMidAir() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheVolcano + Self.liftOff + ["north", "get out", "up", "land"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You can't control the balloon this way.",
                "You realize, just in time, that disembarking here would probably be",
                "You can't control the balloon this way.",
                "Narrow Ledge",
            ])
    }

    /// **The Narrow Ledge and the Library**, and the priceless zorkmid on the
    /// floor of the first: ten to find and twelve to case, the mainframe's own
    /// values.
    @Test func theNarrowLedgeCarriesTheZorkmidAndTheLibraryBehindIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheNarrowLedge
                + ["tie braided wire to hook", "look", "get out", "take coin"]
                + ["read coin", "score", "south", "north"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Narrow Ledge",
                "There is a small hook attached to the rock here.",
                "On the floor is an engraved gold zorkmid",
                "The balloon is fastened to the hook.",
                "The basket is anchored to a small hook by the braided wire.",
                "Taken.",
                "IN FROBS WE TRUST",
                "of a possible 716",
                "Library",
                "gnawed to pieces by unfriendly gnomes",
                "Narrow Ledge",
            ])
    }

    /// **The Flathead stamp is inside the purple book, and reading the book is
    /// what shakes it out.** Four to find and ten to case; the other three books
    /// are in a tongue nobody here reads.
    @Test func thePurpleBookGivesUpTheFlatheadStamp() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheNarrowLedge
                + ["tie braided wire to hook", "get out", "south"]
                + ["read blue book", "read green book", "read white book"]
                + ["read purple book", "take stamp", "read stamp", "score"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Worn and battered in one corner of the room is a blue book.",
                "This book is written in a tongue with which I am unfamiliar.",
                "The pages fall apart at a place somebody kept",
                "Taken.",
                "OUR EXCESSIVE LEADER",
                "of a possible 716",
            ])
    }

    /// **And once the book is open the stamp lists in its own words**, which is
    /// the third of #207's four lines. *Loose* among the pages rather than
    /// pressed between them, because `purpleBookOpens` has just said it slid out
    /// of them: the two sentences describe one stamp and have to agree.
    ///
    /// The book travels — it is takable, and 10 units of it — but the stamp
    /// travels inside it, and the lister prints a container's contents directly
    /// under the container's own line. So *its pages* has an antecedent wherever
    /// the book is set down.
    @Test func theFlatheadStampListsInsideThePurpleBook() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheNarrowLedge
                + ["tie braided wire to hook", "get out", "south"]
                + ["read purple book", "look", "take purple book", "north"]
                + ["drop purple book", "look", "read stamp"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The pages fall apart at a place somebody kept",
                "Lying in the dust, and covered with mold, is a purple book.",
                "A Flathead stamp rests loose among its pages.",
                // Carried out of the Library and set down on the ledge: still in
                // the book, so still the same sentence, and still directly under
                // the book's own — which by now is the stock line, the book
                // having been handled.
                "Narrow Ledge",
                "There is a purple book here.",
                "A Flathead stamp rests loose among its pages.",
                // Never taken, and still readable where it lies.
                "OUR EXCESSIVE LEADER",
            ])
        #expect(!transcript.contains("In the purple book is"))
    }

    /// **Untying a still-burning balloon strands you on the ledge.** The #133
    /// spike reproduced this seven turns from the fixture's start and left the
    /// choice to this milestone; the choice is to keep it, because the source's
    /// own answer to it walks out of the wall ten turns later.
    @Test func untyingAStillBurningBalloonLeavesWithoutYou() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheNarrowLedge
                + ["get out", "look", "wait", "wait", "look"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You get out of the wicker basket.",
                "You watch as the balloon slowly floats away.",
                "Narrow Ledge",
            ])
        #expect(!transcript.contains("wicker basket here.\n\nThe basket is anchored"))
    }

    /// **The gnome is the source's own anti-softlock**, and he sells the way
    /// down for any treasure at all. The door he opens is one-way and never
    /// shuts again — the mainframe's `GNOME-DOOR`.
    @Test func theGnomeSellsTheWayDownForATreasure() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheNarrowLedge
                + ["get out", "take coin", "look"]
                + Array(repeating: "wait", count: 11)
                + ["give coin to gnome", "west", "look"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "A volcano gnome seems to walk straight out of the wall",
                "little time to waste on trespassers",
                "Thank you very much for the priceless zorkmid.",
                "a door appears",
                "Volcano Bottom",
            ])
    }

    /// **And the ledge counts the door he opened.** His chimney is `scenery`, so
    /// the room listing never mentions it and the room's own paragraph is the
    /// only place a second way off the ledge can be reported — and it went on
    /// saying "There is an exit to the south" with two, which is what the
    /// 2026-08-11 round (#233) caught.
    @Test func theNarrowLedgeCountsTheDoorTheGnomeOpened() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheNarrowLedge
                + ["get out", "take coin", "look"]
                + Array(repeating: "wait", count: 11)
                + ["give coin to gnome", "look"],
            seed: 18)

        let halves = transcript.components(
            separatedBy: "Thank you very much for the priceless zorkmid.")
        #expect(halves.count == 2)
        // Before the fee: one exit, and no chimney in the paragraph.
        #expect(halves[0].contains("exit to the south."))
        #expect(!halves[0].contains("A narrow chimney has been opened"))
        // After it: the same line, plus the way he opened.
        #expect(halves[1].contains("exit to the south."))
        #expect(halves[1].contains("A narrow chimney has been opened in the west wall"))
    }

    /// **Each book's examine text used to say it survived the gnomes "by being
    /// on a shelf too high for them"**, which the room's own listing lines
    /// contradict three times over — the green one sits in the centre of the
    /// floor, the blue one in a corner, the purple one in the dust. One line
    /// answers for all four wherever they lie.
    @Test func theBooksDoNotClaimAShelfTheRoomHasThemOffOf() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheNarrowLedge + ["get out", "south"]
                + ["x purple book", "x green book", "x white book"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                // The room lists three of the four off any shelf at all.
                "Worn and battered in one corner of the room is a blue book.",
                "A handsome book, bound in green leather, sits in the center of the room.",
                "Lying in the dust, and covered with mold, is a purple book.",
                "A purple book, thick and unlabelled, and whole: whatever the gnomes",
            ])
        #expect(!transcript.contains("too high for them"))
    }

    /// **And he waits indefinitely until you speak to him.** The mainframe arms
    /// his five-turn watch on the first word said to him and not before, which
    /// is what makes ignoring a gnome the safe thing to do with one.
    @Test func theGnomeOnlyStartsCountingOnceYouSpeakToHim() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheNarrowLedge
                + ["get out", "take coin", "look"]
                + Array(repeating: "wait", count: 11)
                + ["greet gnome"]
                + Array(repeating: "wait", count: 5)
                + ["look"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "A volcano gnome seems to walk straight out of the wall",
                "The gnome appears increasingly nervous.",
                "I'm late for an appointment!",
            ])
    }

    // MARK: - Milestone 6: the Wide Ledge and the box

    /// **The Wide Ledge and the Dusty Room.** Both print from a room routine in
    /// both sources, which is why neither appears in the prose comparison at
    /// all; the box's front is what the Dusty Room's second paragraph reports.
    @Test func theWideLedgeOpensSouthOnTheDustyRoomAndItsBox() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheWideLedge
                + ["tie braided wire to hook", "get out", "south", "examine box", "open box"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Wide Ledge",
                "precipitous drop to the bottom.",
                "There is a small door to the south.",
                "Dusty Room",
                "an oblong hole has been chipped out of the front of it",
                "A steel box set into the stone",
                "The box is rusted and will not open.",
            ])
        // Closed, so the crown does not list through the door.
        #expect(!transcript.contains("In the rusty box is a gaudy crown."))
    }

    /// **The brick, the wire and the hole are one puzzle across three
    /// milestones.** The brick landed inert in the Attic at milestone 1 and the
    /// wire on the bank at Stream View at milestone 2; this is the milestone
    /// that gives them something to do. The crown is fifteen and ten.
    @Test func theBrickAndTheWireBlowTheBoxOpen() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheWideLedge + Self.lightTheCharge + ["south", "take crown", "score"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You put the brick in the oblong hole.",
                "You put the wire coil in the brick.",
                "The wire starts to burn.",
                "Wide Ledge",
                "There is an explosion nearby.",
                "Dusty Room",
                "whose door has been blown off",
                "Inside it sits the excessively gaudy crown of Lord Dimwit Flathead.",
                "of a possible 716",
            ])
    }

    /// **The crown and the card say their own sentences inside the box** — the
    /// two of milestone 6's four listing lines that live in the Dusty Room, and
    /// the reason #207 existed. Until they were declared both treasures
    /// announced themselves with the engine's stock *"In the rusty box is a
    /// gaudy crown."*, which is the one line in the room written by nobody.
    ///
    /// Both are `firstSight` rather than a `presence` rule: the box is `scenery`
    /// and imbedded in the wall, the thief's prowl does not reach this room, and
    /// the only way either leaves the box is a hand, which touches it. There is
    /// no second frame for a second line to be true in.
    @Test func theCrownAndTheCardListInTheirOwnWordsInsideTheBox() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheWideLedge + Self.lightTheCharge + ["south", "take crown", "look"],
            seed: 18)

        // The whole paragraph in one piece, because the order is the point and
        // the two lines are written for it: `ContainmentIndex` sorts a
        // container's contents by id, so the card comes first and the crown
        // closes the paragraph, and the crown's *inside it* leans on the box
        // having just been named. `expectInOrder` would pass on a transcript
        // that printed the two the other way round, because the room is
        // described twice in this route and it matches the first of each.
        #expect(
            transcript.contains(
                """
                On the far wall is a rusty box, whose door has been blown off.

                A card with writing on it lies in the bottom of the box.

                Inside it sits the excessively gaudy crown of Lord Dimwit Flathead.
                """))

        // And the card keeps its own line after the crown has gone, which is why
        // neither sentence leans on the other. The room is described twice in
        // this route — walking in, and the `look` after `take crown` — so the
        // card's line lands twice and the crown's only once. Counted rather than
        // read off a single turn: the route has an earlier `look` in it, and
        // `turnOutput` would hand back that one.
        #expect(
            occurrences(of: "A card with writing on it lies in the bottom of the box.", in: transcript)
                == 2)
        #expect(occurrences(of: "Inside it sits the excessively gaudy crown", in: transcript) == 1)

        // The stock nested lister lost to both of them.
        #expect(!transcript.contains("In the rusty box is"))
    }

    /// **And the card in the box was right about the rock strata.** Five turns
    /// after the blast the Dusty Room comes down, and eight turns after that the
    /// ledge it stood on follows it.
    @Test func theDustyRoomComesDownAndTakesTheWideLedgeWithIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheWideLedge + Self.lightTheCharge
                + ["south", "take crown", "take card", "north", "read card", "look"]
                + ["board basket", "untie braided wire", "launch", "close receptacle"]
                + Array(repeating: "wait", count: 8),
            seed: 18)

        expectInOrder(
            transcript,
            [
                "There is an explosion nearby.",
                "You may recall that recent explosion.",
                "Detonation of explosives in this room is strictly prohibited!",
                "The way to the south is blocked by rubble.",
                "The balloon leaves the ledge.",
                "The ledge collapses. (That was a narrow escape!)",
            ])
    }

    /// **Burning the brick in your own hands is the joke the source tells
    /// once.** It works wherever you are standing.
    @Test func burningTheBrickInYourHandsBlowsYouToSmithereens() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.houseWithTheBrickAndThePaper + Self.fetchTheMatchbook
                + ["burn match", "burn brick with match"],
            seed: 18)

        #expect(transcript.contains("blow you to smithereens"))
    }

    /// **The rim is fifteen feet across and the bag is a great deal wider.**
    /// The mainframe tears the balloon on it and drops the wreck on the floor;
    /// Zork II flies it out of the volcano and into the Flathead Mountains, and
    /// the mainframe is the authority on what a puzzle does.
    @Test func theBalloonTearsItselfOpenOnTheRim() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheVolcano + Self.liftOff + Array(repeating: "wait", count: 12),
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Volcano Near Wide Ledge",
                "the cloth goes over the rock with a sound like",
                "you feel relieved of your burdens",
            ])
    }

    /// **The blue label is the fourth of #207's lines, and the only one of the
    /// four that needs two.** Its holder is the one container in the region that
    /// can be destroyed: `wreckTheBalloon` spills the basket's takable cargo
    /// onto the volcano floor, and a label lying in the ash is not "inside the
    /// basket". So it carries a `presence` rule, exactly as its sibling the tan
    /// label does for the punctured boat.
    ///
    /// Both branches are read from one spot on the floor: light the burner from
    /// outside the basket, watch the label drop into it, then let the empty
    /// balloon fly up and tear itself open on the rim and come back down.
    @Test func theBlueLabelListsInTheBasketAndThenOnTheFloor() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheVolcano
                + ["put newspaper in receptacle", "burn match", "burn newspaper with match"]
                + ["look"]
                + Array(repeating: "wait", count: 20)
                + ["look"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Volcano Bottom",
                "The cloth bag inflates",
                "A blue label is lying inside the basket.",
                // Up the shaft without a pilot, and onto the rim — watched from
                // the floor, so it is the onlooker's line rather than the
                // pilot's.
                "You watch the balloon strike the rim and come apart",
                "There is a blue label here.",
                "There is a balloon here, broken into pieces.",
            ])
        // The basket line stopped being true the moment the basket did.
        #expect(!transcript.contains("In the wicker basket is"))
    }

    // MARK: - Milestone 6: every printed noun answers

    @Test func everyNounTheVolcanoFloorAndTheShaftPrint() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheVolcano
                + ["north", "examine lava", "examine walls", "south"]
                + ["examine volcano", "examine cone", "examine ash", "examine floor"]
                + ["examine exit", "examine basket", "examine cloth bag"]
                + ["examine receptacle", "examine braided wire"]
                + Self.liftOff
                + ["west", "tie braided wire to hook", "get out", "examine label"]
                + ["examine hook", "examine ledge", "examine coin"]
                + ["examine rim", "examine floor", "examine shaft", "south"]
                + ["examine shelves", "examine gnomes", "examine pages"]
                + ["examine purple book", "examine white book"],
            seed: 18)

        expectEveryNounAnswered(transcript, "the volcano floor, the shaft and the Library")
        // No `expectNoAmbiguity` here, and it is the one sweep that cannot have
        // one: `x pages` in the Library is answered by four books, which is the
        // room's own long-standing four-way `book` and not this pass's doing.
        // The volcano floor's own two items are pinned positively instead, by
        // `theVolcanoFloorIsNotTheShaftOverhead`.
    }

    /// Volcano View is reached on foot and by no other road, so it belongs to no
    /// balloon sweep. It names five things — the ledge underfoot, the pair
    /// across the shaft, the bottom below and the rim above — and until #233 one
    /// item answered for four of them and nothing for the fifth.
    @Test func everyNounVolcanoViewPrints() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toVolcanoView
                + ["examine ledge", "examine ledges", "examine rim", "examine bottom"]
                + ["examine volcano", "examine exit", "examine walls"],
            seed: 18)

        #expect(transcript.contains("Volcano View"))
        expectEveryNounAnswered(transcript, "Volcano View")
        expectNoAmbiguity(transcript, "Volcano View")
    }

    @Test func everyNounTheWideLedgeAndTheDustyRoomPrint() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheWideLedge
                + ["tie braided wire to hook", "get out", "examine ledge", "examine hook"]
                + ["examine rim", "examine drop", "examine bottom", "examine volcano"]
                + ["examine door"]
                + ["south", "examine box", "examine hole", "examine dust", "look in hole"]
                + ["put brick in hole", "examine brick"],
            seed: 18)

        expectEveryNounAnswered(transcript, "the Wide Ledge and the Dusty Room")
        // Only one door stands here until the gnome is paid on this ledge, so
        // the bare noun resolves. `theTwoDoorsOnTheWideLedgeAreTwoDoors` owns
        // the frame where it does not.
        expectNoAmbiguity(transcript, "the Wide Ledge, with the gnome unpaid")
    }

    /// With milestone 6 in, the volcano joins the graph at both ends: the Ruby
    /// Room's west passage on foot, and Volcano View south of the Egyptian Room.
    @Test func milestoneSixJoinsTheVolcanoToTheGraph() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheVolcano + ["north", "west", "south", "east", "south", "east"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Volcano Bottom",
                "Lava Room",
                "Ruby Room",
                "Glacier Room",
                "Egyptian Room",
                "Volcano View",
                "Egyptian Room",
            ])
    }

    // MARK: - The thief

    /// The whole road to the hoard: down, past the troll, through the maze,
    /// past the cyclops, up. Every test below needs it before it can get to
    /// what it is about.
    ///
    /// Seeds vary from test to test here in a way they do not elsewhere in this
    /// file, and the reason is the thief himself. He draws from the seeded
    /// stream every turn he is at large, and his fight is the one in the game
    /// that can go either way, so each test records the seed that gives it the
    /// fight it is describing.
    private static let trollRoomToTheHoard =
        trollRoomToMazeFive + mazeFiveToTheCyclops + ["odysseus", "up"]
    private static let toTheHoard = pastTheTroll + trollRoomToTheHoard

    /// He guards the Treasure Room whether or not you have met him before —
    /// this route lifts nothing on the way, so the only thing that puts him
    /// into play is arriving at the hoard.
    ///
    /// The 25 points milestone 4 declared for walking in are what he is
    /// standing on, and until this milestone the room was a room with a chalice
    /// in it and nothing to take it back from.
    @Test func theHoardIsGuardedByWhoeverFilledIt() async throws {
        let transcript = try await play(Dungeon(), Self.toTheHoard, seed: 18)

        expectInOrder(
            transcript,
            [
                "Treasure Room",
                "There is a silver chalice, intricately engraved, here.",
                "There is a suspicious-looking individual, holding a large bag",
                "He is armed with a deadly stiletto.",
            ])
    }

    /// He fights to the death in his lair, and when he falls everything in the
    /// bag falls with him — named in the line, because a colon that promises a
    /// list should deliver one.
    ///
    /// Seed 120, recorded: he pinks your arm and lifts the chalice off the
    /// floor on the turn you arrive, takes a gash in the side, misses three
    /// times more, and dies to the fourth blow.
    @Test func theThiefFallsAndTheHoardFallsWithHim() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheHoard
                + Array(repeating: "attack thief with sword", count: 4)
                + ["look"],
            seed: 120)

        expectInOrder(
            transcript,
            [
                "You suddenly notice that the silver chalice vanished.",
                "The thief takes a fatal blow and slumps to the floor dead.",
                "reappear: the silver chalice",
                "His stiletto clatters to the floor",
                "There is a silver chalice, intricately engraved, here.",
                "There is a stiletto here.",
            ])
    }

    /// **The sharpest divergence from `Sources/Zork1/`'s thief.** There, the
    /// bar under the trap door is his doing and his death lifts it. Here the
    /// trap door bars itself for good — milestone 1's finding, and the reason
    /// the chimney is the way home — so killing him changes nothing about it.
    @Test func killingTheThiefDoesNotUnbarTheTrapDoor() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheHoard
                + Array(repeating: "attack thief with sword", count: 4)
                // Out by the Strange Passage, in again by the trap door, and
                // the bolt is exactly where it was.
                + ["down", "north", "east", "open trap door", "down", "open trap door"],
            seed: 120)

        expectInOrder(
            transcript,
            [
                "The thief takes a fatal blow",
                "Living Room",
                "Cellar",
                "The door is locked from above.",
            ])
    }

    /// He prowls, and what he prowls for is what the trophy case scores. Seed
    /// 36, recorded: the painting out of the Gallery is what puts him into
    /// play, and some forty turns later he walks into the crawlway, lifts it
    /// back out of your hands on the same turn, and is gone two turns later.
    ///
    /// The wait is long because he teleports among a hundred and eight rooms
    /// and only half the turns, which is roughly a one-in-two-hundred chance of
    /// finding you on any given turn — the roaming thief is a rumour you meet
    /// occasionally, not a pursuer.
    ///
    /// The seed was 18 until milestone 8 put the Tiny Room into the prowl set.
    /// One more room is one more draw from the same stream, so the walk this
    /// test is about happens on a different turn; 36 is the lowest seed under
    /// which it still happens inside the wait.
    @Test func theThiefProwlsAndLiftsWhatYouAreCarrying() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellar
                + ["south", "south", "take painting", "north", "north"]
                + Array(repeating: "wait", count: 52),
            seed: 36)

        expectInOrder(
            transcript,
            [
                "North-South Crawlway",
                "A shadowy figure slips into the room.",
                "You suddenly notice that the painting vanished.",
                "The shadowy figure melts away into the dark.",
            ])
    }

    /// **The ten points milestone 1 declared and could not reach.** The egg's
    /// mechanism is too fine for your fingers; his are the only careful pair in
    /// the game. Hand it over, leave him to it, come back four turns later and
    /// kill him, and the bird is still whole — six points for lifting it, two
    /// for the case, and the brass bauble the songbird trades for its song is
    /// one and one more.
    ///
    /// Seed 1, recorded: the troll falls to the third blow; the thief takes the
    /// egg, lifts the chalice off the floor for good measure, and dies to the
    /// first blow you land when you come back. Both come out of the bag when he
    /// does, and the egg is open, because the fuse ran while you were four
    /// turns away in the Cyclops Room.
    @Test func theThiefOpensTheEggAndTheBirdPaysItsTen() async throws {
        let transcript = try await play(
            Dungeon(),
            // The egg out of the tree, then in at the window and down.
            ["north", "north", "up", "take egg", "down"]
                + ["east", "southwest", "open window", "west"] + Self.downTheTrapDoor
                + ["east"] + Array(repeating: "attack troll with sword", count: 3)
                + Self.trollRoomToTheHoard
                // Hand it over, step out of his reach, and let him work.
                + ["give egg to thief", "down"] + Array(repeating: "wait", count: 4)
                + ["up"] + Array(repeating: "attack thief with sword", count: 6)
                + ["take egg", "take canary", "take chalice"]
                // Home by the Strange Passage, and the case takes three.
                + ["down", "north", "east", "open case", "put egg in case"]
                + ["put chalice in case", "score"]
                // And out to the wood, where the songbird answers the canary.
                + ["east", "east", "north", "north", "wind canary", "take bauble"]
                + ["west", "east", "west", "west", "put canary in case"]
                + ["put bauble in case", "score"],
            seed: 1)

        expectInOrder(
            transcript,
            [
                "The thief is taken aback by your unexpected generosity",
                "The thief takes a fatal blow",
                "reappear: the jewel-encrusted egg",
                "Your score is 106 of a possible 716",
                "a beautiful brass bauble drops from its mouth",
                "You put the golden clockwork canary in the trophy case.",
                "You put the beautiful brass bauble in the trophy case.",
                "Your score is 110 of a possible 716",
            ])
    }

    /// He takes what you hand him, and says so with a mocking little bow — but
    /// only what is actually in your hands. He lifts things off the floor and
    /// out of your pockets, so the thing you are offering him is often already
    /// in his bag, and the bow would be a lie. Found by playing: stage 4's
    /// answer to an unheld gift is that nobody here wants it, which with the
    /// thief standing over the hoard is the one thing that is certainly untrue.
    @Test func heTakesWhatYouHandHimAndNotWhatHeIsAlreadyHolding() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheHoard + ["give chalice to thief", "give sword to thief"],
            seed: 120)

        expectInOrder(
            transcript,
            [
                // Seed 120: he has the chalice in the bag by the time you offer it.
                "You suddenly notice that the silver chalice vanished.",
                "You aren't holding that.",
                "The thief takes it with a mocking little bow",
            ])
    }

    /// The prowl set is a hand-written list of a hundred and five rooms, and the
    /// hazard of a hand-written list is that a later milestone adds a region and
    /// nobody notices the thief has stopped going there. The count is pinned so
    /// the omission has to be deliberate: a milestone that builds rooms he
    /// should walk changes this number in the same commit, and one that builds
    /// rooms he should not — the volcano's water, another sealed vault — says so
    /// here by leaving it alone.
    ///
    /// The second assertion is the other half of the same worry: no room
    /// appears twice, which is the mistake the four regional lists invite when
    /// a milestone moves a room from one of them to another. A duplicate would
    /// not fail anything at runtime — it would just weight his wandering
    /// quietly toward one room.
    ///
    /// Read off the declarations rather than through a transcript, because
    /// `Location` resolves its `EntityID` only inside a live turn; comparing the
    /// values themselves needs no frame.
    /// Milestone 7 took it from 105 to 107: the Small Square Room and the
    /// Side Room, both plain two-way passages off his own lair. The third room
    /// of that region, the Room in a Puzzle, is deliberately not among them —
    /// the drop in is one-way and both ways out are earned, so a teleporting
    /// thief put on that floor is sealed in with the gold card. Same reasoning
    /// as the Small Room and the Vault.
    ///
    /// Milestone 8 took it to **108**, and added exactly one room out of seven:
    /// the Tiny Room, which is the one room of the palantir wing the source
    /// does not mark `RSACREDBIT`. The other six are a locked oak door and five
    /// rooms you reach by hanging on a rope.
    @Test func theThiefProwlsAHundredAndEightRoomsAndNoRoomTwice() throws {
        let game = Dungeon()
        let prowl = game.thiefProwl

        #expect(prowl.count == 108)
        #expect(prowl.contains(game.palantirWing.tinyRoom))
        for sacred in [
            game.palantirWing.drearyRoom, game.palantirWing.slideOne,
            game.palantirWing.slideLedge, game.palantirWing.sootyRoom,
        ] {
            #expect(!prowl.contains(sacred))
        }
        for (index, room) in prowl.enumerated() {
            #expect(!prowl[..<index].contains(room), "room \(index) is in the set twice")
        }
    }

    /// Every treasure the trophy case scores is one he covets, because both
    /// read the host's one `treasureRoster`. This is the test that keeps it
    /// that way: a milestone that declares a treasure and forgets the roster
    /// would score it, and he would never touch it.
    ///
    /// Milestone 6 is why it is worth pinning. The zorkmid, the crown and the
    /// stamp became stealable the moment they were declared, with no
    /// line of the thief's changed — that is the shared list doing its job, and
    /// it is only luck until something checks.
    @Test func heCovetsEveryTreasureTheCaseScores() throws {
        let (definition, _) = try Bootstrap.build(Dungeon())
        let valued = definition.items.values
            .filter { $0.customTraits["takeValue"] != nil || $0.customTraits["depositValue"] != nil }
            .compactMap(\.name)
            .sorted()
        // 32: the twenty-five of milestones 1 to 5, milestone 6's three,
        // milestone 7's gold card, and milestone 8's two spheres and the Don
        // Woods stamp. Thirty-two is also the number the mechanics contract
        // gives for the finished game, so this row is now the whole roster.
        #expect(valued.count == 32, "scored but not coveted: \(valued)")
        for volcanic in ["priceless zorkmid", "gaudy crown", "stamp"] {
            #expect(valued.contains { $0.contains(volcanic) }, "\(volcanic) is not scored")
        }
    }

    /// His blade is a blade and nothing more. Zork I makes the stiletto one of
    /// five sharp things that hole the river boat; this game carries no `sharp`
    /// trait at all, because milestone 4 found that the broken sharp stick is
    /// the only thing in the mainframe that punctures it.
    @Test func theStilettoIsNotOneOfTheThingsThatHolesTheBoat() throws {
        let (definition, _) = try Bootstrap.build(Dungeon())
        let sharp = definition.items.values.filter { $0.customTraits["sharp"] != nil }

        #expect(sharp.isEmpty, "\(sharp.compactMap(\.name))")
    }

    /// Every noun the lair prints while its owner is standing in it, which is
    /// the one room in the game whose description gains a second paragraph the
    /// moment a milestone lands.
    @Test func everyNounTheThiefAndHisHoardPrint() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheHoard
                + ["examine thief", "examine stiletto"]
                + Array(repeating: "attack thief with sword", count: 3)
                + ["examine bags", "examine granite wall", "examine chalice"],
            seed: 98)

        expectEveryNounAnswered(transcript, "the thief and his hoard")
    }

    // MARK: - Milestone 7: the road in

    /// Down the trap door, past the troll, through the maze to the cyclops,
    /// past him with his father's name, up into the Treasure Room and east
    /// through the passage milestone 4 left as a seam.
    ///
    /// Straight through, without stopping: the Treasure Room is the thief's,
    /// and he kills a visitor who loiters. Every test below that only passes
    /// *through* uses this; the two that come back the other way use
    /// ``toTheRoyalPuzzlePastTheThief`` and pay for the privilege.
    /// Not `private`, for ``toTheNarrowLedge``'s reason.
    static let toTheRoyalPuzzle =
        toMazeFive + mazeFiveToTheCyclops + ["odysseus", "up", "east"]

    /// The same road with the thief cut down on the way through, for the tests
    /// that need to stand in his room twice. Four blows at seed 120 is his own
    /// suite's recipe, recorded there because the fight can go either way.
    private static let toTheRoyalPuzzlePastTheThief =
        toMazeFive + mazeFiveToTheCyclops + ["odysseus", "up"]
        + Array(repeating: "attack thief with sword", count: 4)
        + ["east"]

    /// And down the hole, which is one-way.
    private static let intoThePuzzle = toTheRoyalPuzzle + ["down"]

    /// The shortest line that uncovers the gold card, from the moment the
    /// player lands in the puzzle. Found by exhaustive breadth-first search over
    /// the real grid, so it is not merely *a* route but the shortest one.
    private static let toTheGoldCard = [
        "push south", "east", "southeast", "east", "push south",
    ]

    /// The two spliced: standing on the card's square with it uncovered.
    /// Not `private`, for ``toTheNarrowLedge``'s reason: `DungeonProseTests`
    /// asks the anteroom's sand what it is once the hole has been sealed.
    static let toTheCardSquare = intoThePuzzle + toTheGoldCard

    /// And the shortest line from the card's square to standing under the
    /// ceiling opening with the good ladder beside it — the win. Thirty-seven
    /// moves, and it uses diagonals throughout, which is why the source gives
    /// `CP` nine exits and not four.
    private static let cardSquareToTheWayOut = [
        "north", "north", "north", "push east", "southwest", "southwest",
        "northwest", "northwest", "push east", "south", "southeast", "southeast",
        "push south", "east", "northeast", "north", "north", "push west",
        "northwest", "push south", "push south", "push south", "push east",
        "south", "south", "push west", "push north", "northeast", "push west",
        "push west", "southeast", "push west", "push west", "push north",
        "push north", "push north", "northwest",
    ]

    // MARK: - Milestone 7: the grid is the source's grid

    /// The transcription of `CPUVEC` (`dung.355:3120-3184`) is the one thing in
    /// this region that cannot be checked by reading the prose, because an
    /// off-by-one would leave a puzzle that still played and simply could not be
    /// solved. Every landmark the source names by number is checked here.
    ///
    /// The types are `RoyalPuzzleGrid` / `RoyalPuzzleCell`. The prefix dates
    /// from the spike, whose own `PuzzleGrid` / `PuzzleCell` shared this test
    /// target until #183 retired it; it is kept because the grid is one region's
    /// content and not a general sliding-block type.
    @Test func theGridIsTheSourcesGrid() throws {
        let grid = RoyalPuzzleGrid()
        let (width, height) = (RoyalPuzzleGrid.width, RoyalPuzzleGrid.height)

        // The source is 1-based and this array is 0-based.
        #expect(grid.cells.count == width * height)
        #expect(grid.cell(at: RoyalPuzzleGrid.entrySquare) == .floor)  // cell 10
        #expect(grid.cell(at: RoyalPuzzleGrid.ladderSquare) == .sandstone)  // cell 11
        #expect(grid.cell(at: 21) == .goodLadder)  // cell 22
        #expect(grid.cell(at: 33) == .badLadder)  // cell 34
        #expect(grid.cell(at: RoyalPuzzleGrid.cardSquare) == .sandstone)  // cell 37
        #expect(grid.cell(at: RoyalPuzzleGrid.doorSquare) == .floor)  // cell 52

        // The whole border is fixed marble, which is why the source's push code
        // needs no bounds check anywhere.
        for index in grid.cells.indices {
            let (row, column) = (index / width, index % width)
            if row == 0 || row == height - 1 || column == 0 || column == width - 1 {
                #expect(grid.cell(at: index) == .marble, "border cell \(index + 1)")
            }
        }
    }

    /// An independent check on the same transcription, from a different part of
    /// the source: `CP-ROOM` hardcodes the entry cell's geometry in prose
    /// (`act3.199:829`), and it has to agree with the vector.
    @Test func theEntryCellsProseAgreesWithTheVector() throws {
        let grid = RoyalPuzzleGrid()
        let square = RoyalPuzzleGrid.entrySquare

        #expect(grid.cell(at: grid.neighbour(of: square, .north)!) == .marble)
        #expect(grid.cell(at: grid.neighbour(of: square, .west)!) == .marble)
        #expect(grid.cell(at: grid.neighbour(of: square, .east)!) == .sandstone)
        #expect(grid.cell(at: grid.neighbour(of: square, .south)!) == .sandstone)
    }

    // MARK: - Milestone 7: the seam, and the way down

    /// **The Treasure Room's east passage is the Royal Puzzle's antechamber.**
    /// Milestone 4 built the room with its description already naming the
    /// passage and left the far side as its one open seam.
    @Test func theTreasureRoomOpensEastOnTheAntechamber() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheRoyalPuzzlePastTheThief + ["west", "east"], seed: 120)

        // Fragments chosen to sit inside one wrapped line: the prose is
        // hand-wrapped and nothing in the engine re-wraps it, so an assertion
        // spanning a line break never matches.
        expectInOrder(
            transcript,
            [
                "passage to the east",
                "Small Square Room",
                "There is a piece of paper on the ground here.",
                "Treasure Room",
                "Small Square Room",
            ])
    }

    /// The thief's note is the one warning the region gives, and it is the
    /// truth. Mainframe-only content, so the letter is this project's own.
    @Test func theThiefsNoteWarnsYouCannotGetOut() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheRoyalPuzzle + ["read note"], seed: 18)

        #expect(transcript.contains("will not be able to get out again"))
        #expect(transcript.contains("The Thief"))
    }

    /// The anteroom's hole is a one-way drop, and the room below is one
    /// `Location` standing for sixty-four squares.
    @Test func theDropIntoThePuzzleLandsUnderTheCeilingOpening() async throws {
        let transcript = try await play(
            Dungeon(), Self.intoThePuzzle + ["north", "east"], seed: 18)

        expectInOrder(
            transcript,
            [
                "You lower yourself through the hole",
                "Room in a Puzzle",
                "walled to the north and west in marble",
                "In the ceiling above you is a large circular opening.",
                // Marble north, sandstone east: the only move from the entry
                // square is a push, which is why the puzzle opens with one.
                "There is a wall there.",
                "There is a wall there.",
            ])
    }

    // MARK: - Milestone 7: the diagram, and pushing

    /// **The room stops describing itself in prose after the first push.** The
    /// source's `CPPUSH` flag: once a wall has moved, every look is a 3×3
    /// diagram of the squares around you.
    @Test func theFirstPushTurnsTheRoomIntoADiagram() async throws {
        let transcript = try await play(
            Dungeon(), Self.intoThePuzzle + ["push east", "look"], seed: 18)

        expectInOrder(
            transcript,
            [
                "walled to the north and west in marble",
                "The wall slides forward and you follow it.",
                "The architecture here is getting complicated",
                "SS  = sandstone wall",
                "West  |   .. SS|  East",
            ])
        // The legend is printed once, not on every look.
        #expect(transcript.components(separatedBy: "getting complicated").count == 2)
    }

    /// Every spelling of the push reaches the same code. Three of them are rows
    /// on `.pushWall` — the bare direction, the literal noun, and the object
    /// slot #151 added — and `push north wall` is the core `push <object>`,
    /// bought back through the compass-wall items rather than declared as a
    /// fourth row.
    @Test func aWallIsPushedByDirectionInEverySpelling() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheRoyalPuzzle
                + [
                    "down", "push", "push north", "push wall north", "push north wall",
                    "push marble wall",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Push which way? North, south, east or west.",
                "The wall does not budge.",
                "The wall does not budge.",
                "The wall does not budge.",
                "In here a wall is pushed by direction",
            ])
    }

    /// The object-slot row is what buys the wordier phrasings. Both of these
    /// used to die as "You can't see any such thing", because `north` and `west`
    /// are nouns of nothing — the literal row matches text and cannot reach an
    /// adjective the pattern never spelled out. Issue #151.
    @Test func namingTheWallByItsMaterialNowPushesIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheRoyalPuzzle
                + ["down", "push marble wall up", "push sandstone wall south"],
            seed: 18)

        #expect(!transcript.contains("You can't see any such thing"))
        expectInOrder(
            transcript,
            [
                "Push which way? North, south, east or west.",
                "The wall slides",
            ])
    }

    /// The row binds any noun, so the rule has to say which nouns it meant. A
    /// thing that is not a wall gets the syntax rather than a shove — and, since
    /// it never reaches the grid, nothing has moved when it says so.
    @Test func pushingSomethingThatIsNotAWallInADirectionTeachesTheSyntax() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheRoyalPuzzle + ["down", "push sand north", "push north"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Only a wall can be pushed in here.",
                "The wall does not budge.",
            ])
    }

    /// The ladder is square-local, so both what it looks like and whether you
    /// can climb it are questions about where you are standing. From the entry
    /// square there is no ladder at all, and `climb` says so rather than
    /// describing rungs that are four squares away.
    @Test func theLadderIsOnlyThereWhenYouAreBesideIt() async throws {
        let transcript = try await play(
            Dungeon(), Self.intoThePuzzle + ["examine ladder", "climb ladder"], seed: 18)

        expectInOrder(
            transcript,
            [
                "There is no ladder here.",
                "There is no ladder here.",
            ])
    }

    /// **And the ceiling opening is only overhead in the square it is over.**
    /// The room's own paragraph has always got this right — `puzzleDescription`
    /// names the opening only in the entry square — but the item carried a
    /// static `description(…)` saying "It is a long way above your head", read
    /// from every one of the sixty-four, including the sixty-three where `up`
    /// answers "There is no way up from here." The grid, the climb condition
    /// and the solution are untouched. (#233)
    @Test func theCeilingOpeningIsOnlyOverheadInTheSquareItIsOver() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoThePuzzle + ["x opening"] + Self.toTheGoldCard
                + ["up", "examine opening"],
            seed: 18)

        // The control: standing under it, it really is a long way overhead.
        let under = turnOutput(of: "x opening", in: transcript)
        #expect(under.contains("It is a long way above your head"))
        // Five squares off, where `up` says there is no way up at all.
        #expect(transcript.contains("There is no way up from here."))
        let away = turnOutput(of: "examine opening", in: transcript)
        #expect(away.contains("away across the room above the"))
        #expect(!away.contains("It is a long way above your head"))
    }

    /// A compass wall is the only thing in the region that names a direction,
    /// so it is the only thing that can say what is actually on that side.
    @Test func eachCompassWallReportsItsOwnSquare() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheRoyalPuzzle
                + ["down", "examine north wall", "examine east wall"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The wall to the north is marble",
                "The wall to the east is sandstone",
            ])
    }

    /// **Diagonals are legal, and that is why `CP` has nine exits.** What they
    /// cannot do is cut the corner between two walls.
    @Test func aDiagonalIsRefusedOnlyBetweenTwoWalls() async throws {
        let transcript = try await play(
            Dungeon(), Self.intoThePuzzle + ["southeast"], seed: 18)

        // From the entry square both flanking squares are walls.
        #expect(transcript.contains("cannot squeeze between them"))
    }

    // MARK: - Milestone 7: the gold card

    /// The card lies under a movable block, and the floor of its square is the
    /// only hint the source gives that anything is there.
    @Test func theGoldCardIsUnderTheBlockAndPaysTwentyFive() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheCardSquare
                + ["score", "take card", "score", "read card"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The middle of the floor here is noticeably depressed.",
                "There is a solid gold engraved card here.",
                "Your score is 60 of a possible 716",
                "Your score is 70 of a possible 716",
                "Door Pass",
            ])
    }

    /// Containment is room-granular and the puzzle is one room, so the card has
    /// to be told what a square means. Issue #150's `reach` rule.
    @Test func theCardCannotBeReachedFromAnotherSquare() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheCardSquare
                + ["north", "look", "take card"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "A solid gold card lies in one of the other squares of the puzzle.",
                "The card is squares away from you, across the sand.",
            ])
    }

    // MARK: - Milestone 7: the two ways out

    /// **The whole puzzle solved, and the card carried out of it.** Forty-five
    /// commands, every one of them found by exhaustive search over the real
    /// grid — so this test is also the proof that the region is winnable.
    @Test func theWholePuzzleIsSolvedAndTheCardCarriedOut() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheCardSquare + ["take card"]
                + Self.cardSquareToTheWayOut + ["up", "score", "inventory"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "There is a solid gold engraved card here.",
                "There is a ladder here, firmly attached to the east wall.",
                "With the ladder under you, you get a hand over the lip",
                "Small Square Room",
                "Your score is 70 of a possible 716",
                "a gold card",
            ])
    }

    /// The other way out costs the card, and there is no order that rescues it:
    /// the slit removes whatever it is given before it decides what to say.
    ///
    /// The sword rather than the lamp, deliberately. The slit really does eat
    /// the lamp, and the Side Room behind the door is dark — so feeding it your
    /// light source works exactly as it should and leaves you unable to read the
    /// room you just paid a treasure to open.
    @Test func theSteelDoorCostsTheCardAndTheSlitKeepsEverything() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheCardSquare
                + ["take card", "push south", "push west", "south"]
                + ["put sword in slit", "put card in slit", "west", "north", "inventory"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "GARBAGE IN, GARBAGE OUT",
                "CARD CONFISCATED",
                "Side Room",
                "Small Square Room",
            ])
        // Both went into the wall and neither came back.
        #expect(!transcript.contains("You are carrying a brass lantern, an elvish sword, and a gold card"))
    }

    /// **The entrance can be destroyed, and the source never gives it back.**
    /// Push any wall into the square under the opening and `CPBLOCK` latches:
    /// the ceiling exit is gone for the rest of the game, and the steel door —
    /// which costs the card — is the only way left.
    @Test func aWallPushedUnderTheOpeningSealsTheEntranceForGood() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheRoyalPuzzle
                + ["down", "push east", "south", "southwest", "push north", "up"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The wall grinds into the square below the opening",
                "way you came in is now a ceiling like any other.",
                "There is no way up from here.",
            ])
    }

    /// And the anteroom above says so, permanently, from the other side.
    @Test func theSealedEntranceIsVisibleFromTheRoomAbove() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheCardSquare + ["take card"]
                + ["north", "north", "northwest", "push west", "south"]
                + ["southeast", "southeast", "push south", "push west", "south"]
                + ["put card in slit", "west", "north", "examine hole", "down"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "way you came in is now a ceiling like any other.",
                "CARD CONFISCATED",
                "Side Room",
                "A face of smooth sandstone has",
                "a foot below the lip a face of",
                "The way down is blocked by sandstone.",
            ])
    }

    /// The Side Room is reachable from the anteroom without the puzzle at all,
    /// and its steel door is shut until the slit has been fed.
    @Test func theSideRoomIsReachedFromAboveAndItsDoorStartsShut() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheRoyalPuzzle + ["south", "east", "north"], seed: 18)

        expectInOrder(
            transcript,
            [
                "Side Room",
                "a steel door to the east",
                "The steel door bars the way.",
                "Small Square Room",
            ])
    }

    // MARK: - Milestone 7: every printed noun answers

    @Test func everyNounTheRoyalPuzzlePrints() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheRoyalPuzzle
                + ["examine hole", "examine note", "examine sand", "read note", "south"]
                + ["examine steel door", "north", "down"]
                + ["examine opening", "examine ceiling", "examine sand"]
                + ["examine marble wall", "examine sandstone wall", "examine ladder"]
                + ["examine north wall", "examine south wall", "examine east wall"]
                + ["examine west wall"]
                + Self.toTheGoldCard
                + ["examine card", "take card", "push south", "push west", "south"]
                + ["examine slit", "examine door"],
            seed: 18)

        expectEveryNounAnswered(transcript, "the Royal Puzzle")
    }

    /// **The thief can walk into the antechamber, and the gold card is his kind
    /// of thing.** Both rooms above the puzzle are on his prowl and the card is
    /// on the shared `treasureRoster`, so nothing here is special-cased — this
    /// pins that the two systems meet. He is woken by the first treasure lifted
    /// off the dungeon floor, which the chalice in his own lair provides on the
    /// way past.
    /// Read off the declarations, like the prowl-count test above and for the
    /// same reason: `Location` resolves its `EntityID` only inside a live turn,
    /// so the comparison has to be between values from **one** `Dungeon()`.
    /// Two calls to the initialiser are two different worlds.
    @Test func theThiefWalksIntoTheAntechamberAndWantsTheCard() throws {
        let game = Dungeon()
        let prowl = game.thiefProwl

        #expect(prowl.contains(game.royalPuzzle.anteroom))
        #expect(prowl.contains(game.royalPuzzle.sideRoom))
        #expect(!prowl.contains(game.royalPuzzle.puzzle))

        // And the card is on the roster both he and the trophy case read, so
        // wanting it needs no rule of its own.
        let (definition, _) = try Bootstrap.build(game)
        let card = definition.items.values.first { $0.name == "gold card" }
        #expect(card?.customTraits["takeValue"] != nil, "the card has to be worth stealing")
    }

    /// With milestone 7 in, the Royal Puzzle joins the graph at the one place
    /// the source joins it: east out of the Treasure Room.
    @Test func milestoneSevenJoinsTheRoyalPuzzleToTheGraph() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheRoyalPuzzlePastTheThief + ["south", "north", "west", "east", "down"],
            seed: 120)

        expectInOrder(
            transcript,
            [
                "Treasure Room",
                "Small Square Room",
                "Side Room",
                "Small Square Room",
                "Treasure Room",
                "Small Square Room",
                "Room in a Puzzle",
            ])
    }

    // MARK: - Milestone 8: the roads in

    /// From the Dam back to the Troll Room the long way round the crossroads,
    /// which is how anything fetched out of the Maintenance Room reaches the
    /// temple quarter: east into the Damp Cave, down to the Loud Room, west and
    /// north round the chasm, and south twice to the East-West Passage.
    private static let damRoomBackToTheTrollRoom = [
        "east", "south", "west", "north", "south", "south", "west",
    ]

    /// And out of Maze-5 the same way: north three times to Maze-1, then west.
    /// The maze is not symmetrical, so this is not `trollRoomToMazeFive`
    /// reversed — it is its own thread.
    private static let mazeFiveBackToTheTrollRoom = ["north", "north", "north", "west"]

    /// The whole road to the Tiny Room with the welcome mat and the screwdriver
    /// in hand — the two things the oak door's puzzle needs that are not in the
    /// room with it.
    ///
    /// Seed 18 throughout, recorded: the troll falls to the first blow.
    private static let toTheTinyRoom =
        ["take mat"] + intoTheCellarWithTheRope
        + ["east", "attack troll with sword", "drop sword"]
        + crossroadsToTheDam
        + ["north", "north", "push yellow button", "take screwdriver", "south", "south"]
        + damRoomBackToTheTrollRoom + trollRoomToTheDome
        + ["tie rope to railing", "down", "west"]

    /// The solve, from standing in the Tiny Room with the mat and a tool. The
    /// order of the last four commands is the whole puzzle: the key has to come
    /// off the mat before the mat is worth moving, and the near keyhole has to
    /// be empty before the lock will turn.
    private static let theOakDoorSolve = [
        "open lid", "put mat under door", "put screwdriver in keyhole",
        "take mat", "take key", "take screwdriver",
        "unlock door with key", "open door", "north",
    ]

    /// From the Timber Room back up out of the mine and round to the head of
    /// the chute: the ladder, the coal maze the other way about, the Wooden
    /// Tunnel, the Shaft Room and the Mine Entrance.
    private static let timberRoomToTheSlideRoom = [
        "north", "up", "up", "east", "east", "south", "west", "south",
    ]

    /// The whole road to the head of the coal chute with the rope in hand and
    /// the broken timber carried up out of the mine. Those two are what
    /// `SLIDE-EXIT` reads, and there is no other way to the red sphere.
    ///
    /// Seed 18 throughout, recorded: the troll falls to the first blow.
    private static let toTheChuteWithTheTimber =
        intoTheCellarWithTheRope
        + ["east", "attack troll with sword", "drop sword"]
        + crossroadsToTheDam + damToTheMirrors + mirrorsToTheShaft
        + coalMazeToTheLadderBottom + ["south", "take timber"]
        + timberRoomToTheSlideRoom

    /// Rig it and ride it. Four moves from the Slide Room to the ledge, and the
    /// grip clock is set to `100 / carried weight` — so the descent has to be
    /// walked rather than sightseen.
    private static let downTheChuteToTheLedge =
        ["drop timber", "tie rope to timber", "down", "down", "down", "east"]

    // MARK: - Milestone 8: the Tiny Room and the oak door

    /// **The Torch Room's west doorway is the Tiny Room.** Milestone 3 built
    /// the Torch Room with the doorway in its description and said at the
    /// declaration site that the room behind it belonged to a later milestone.
    /// This is that milestone, and the seam is the whole of what joins the
    /// palantir wing to the rest of the map on foot.
    @Test func theTorchRoomsWestDoorwayOpensOnTheTinyRoom() async throws {
        let transcript = try await play(Dungeon(), Self.toTheTinyRoom + ["east"], seed: 18)

        expectInOrder(
            transcript,
            ["Torch Room", "Tiny Room", "beside the door a small barred window", "Torch Room"])
    }

    /// The door starts locked with its key in the far keyhole, and the barred
    /// window is what tells you so — it shows the Dreary Room entire, table and
    /// sphere and all, long before either can be reached. It does **not** show
    /// what is inside the far keyhole: a window that reported the key would
    /// hand over the puzzle from the wrong side of the door.
    @Test func theBarredWindowShowsTheRoomYouCannotYetReach() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTinyRoom + ["look through window", "north", "enter window"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "This is a dreary room",
                "You can make out a blue crystal sphere in there.",
                // The engine's own answer for a shut door on an exit. The lock
                // is what `open door` reports.
                "The door made of oak is closed.",
                "Not unless somebody dices you first.",
            ])
        #expect(!transcript.contains("blue crystal sphere and a rusty iron key"))
    }

    /// The keyhole answers only when both lids are up and both keyholes empty,
    /// and even then only in the direction there is light to see in: the Dreary
    /// Room is lit and the Tiny Room is not.
    @Test func theKeyholeShowsALightedRoomOnlyWhenNothingIsInTheWay() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTinyRoom
                + [
                    "look through keyhole", "open lid", "look through keyhole",
                    "put mat under door", "put screwdriver in keyhole",
                    "take mat", "take key", "take screwdriver",
                    "look through keyhole", "open lid", "look through keyhole",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                // The lid is down, so there is nothing to look through at all.
                "The lid is over it.",
                // Lid up, but the key is still filling the far keyhole.
                "No light comes through the keyhole at all.",
                // The screwdriver punched the key out, and `PCHECK` shut the
                // lid on the second tool taken — so it has to go up again.
                "The lid is over it.",
                "The lid swings up.",
                // Both keyholes empty at last, and there is light on the far
                // side because the Dreary Room is lit and the Tiny Room is not.
                "You can just make out a lit room at the far end of it.",
            ])
    }

    /// **The whole solve, in the order the source insists on.** Slide the mat
    /// under the door first, then punch the key through; the key lands on the
    /// mat, the mat gives it up when it is lifted, and the near keyhole has to
    /// be emptied before the lock will turn.
    @Test func theOakDoorGivesUpItsKeyAndTheBlueSpherePaysTen() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTinyRoom + ["open lid", "put mat under door", "examine door"]
                + Array(Self.theOakDoorSolve.dropFirst(2))
                + ["take blue sphere", "score"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The lid swings up.",
                "The mat goes under the door with room to spare.",
                "The edge of a welcome mat",
                "There is a faint noise from the far side of the door",
                "As the mat comes up, a rusty iron key slides off it and onto the floor.",
                "Something turns over inside the door, and the lock gives.",
                "Dreary Room",
                "In the center of the table sits a blue crystal sphere.",
                // Forty for the road in, and ten for finding the sphere.
                "Your score is 50 of a possible 716",
            ])
    }

    /// **Punching the key out with no mat under the door loses it for good.**
    /// The source removes it from the game rather than dropping it, and nothing
    /// anywhere puts it back — so the wing is unwinnable from that turn on, and
    /// nothing says so at the time.
    @Test func punchingTheKeyThroughWithNoMatLosesItForever() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTinyRoom
                + [
                    "open lid", "put screwdriver in keyhole", "take screwdriver",
                    "take key", "unlock door with key", "open door",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "There is a faint noise from the far side of the door",
                // There is no key anywhere any more, and nothing says so.
                "You can't see any such thing.",
                "The door is locked.",
            ])
    }

    /// `PCHECK`, which the source runs every turn: the **second** time a
    /// keyhole tool is taken while the near lid stands open, the lid falls back
    /// over the keyhole. It is not fatal — the lid opens again — but it falls
    /// on exactly the turn a player has stopped watching the door.
    @Test func theLidFallsOnTheSecondToolTakenWhileItStandsOpen() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTinyRoom
                + [
                    "open lid", "put mat under door", "put screwdriver in keyhole",
                    "take mat", "take key", "take screwdriver", "examine lid",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "As the mat comes up, a rusty iron key slides off it",
                "The lid drops, and the keyhole is covered again.",
                "lying flat over the keyhole",
            ])
    }

    /// The four `PALOBJS` are the only things that go into a keyhole, and only
    /// one of them turns the lock afterwards.
    @Test func onlyFourThingsFitTheKeyholeAndOnlyOneTurnsIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTinyRoom
                + [
                    "put lamp in keyhole", "open lid", "put lamp in keyhole",
                    "put mat under door", "put mat under door",
                    "put screwdriver in keyhole",
                    "take mat", "take key", "unlock door with key",
                    "take screwdriver", "unlock door with lamp",
                    "unlock door with key",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The lid is over it.",
                "The brass lantern will not go in.",
                "The mat is already under the door.",
                // The screwdriver is still standing in the near keyhole.
                "There is something in the keyhole already.",
                "That will not turn the lock.",
                "Something turns over inside the door, and the lock gives.",
            ])
    }

    /// The skeleton keys punch the far key out perfectly well and will not turn
    /// this lock — in the same words the grating uses for a key that does not
    /// fit it, which is the whole of #263.
    @Test func theSkeletonKeysPunchTheKeyOutAndStillWillNotTurnTheLock() async throws {
        let transcript = try await play(
            Dungeon(),
            ["take mat"] + Self.intoTheCellarWithTheRope
                + ["east", "attack troll with sword", "drop sword"]
                + Self.trollRoomToMazeFive + ["take keys"]
                + Self.mazeFiveBackToTheTrollRoom + Self.trollRoomToTheDome
                + ["tie rope to railing", "down", "west"]
                + ["open lid", "put mat under door", "put skeleton keys in keyhole"]
                + ["take mat", "take skeleton keys", "unlock door with skeleton keys"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "There is a faint noise from the far side of the door",
                "As the mat comes up, a rusty iron key slides off it",
                "That will not turn the lock.",
            ])
    }

    /// **Both of the game's locks answer a lock already turned the way you are
    /// turning it in one voice.** The engine's stock pair is "That's already
    /// unlocked."/"That's already locked.", where this game's own neighbours
    /// are "It is already open." and "It is already closed." The Palantir used
    /// to paper over half the gap with a hand-typed constant for its oak door
    /// and nothing spoke for the grating, so which lock the player was standing
    /// at decided which register they heard. `expectInOrder` pins the wording
    /// rather than a negative on the stock line, because either engine line
    /// arriving in these slots displaces the sequence. (#260)
    @Test func bothOfTheGamesLocksAnswerAnAlreadyTurnedLockInOneVoice() async throws {
        let grating = try await play(
            Dungeon(),
            Self.toMazeFive + ["take keys"] + Self.mazeFiveToTheGrating
                + [
                    "unlock grating with keys", "unlock grating with keys",
                    "lock grating with keys", "lock grating with keys",
                ],
            seed: 18)

        expectInOrder(
            grating,
            ["The grate is unlocked.", "It is already unlocked.", "It is already locked."])

        // The solve up to the turn of the lock, then the same turn again.
        let oakDoor = try await play(
            Dungeon(),
            Self.toTheTinyRoom + Array(Self.theOakDoorSolve.dropLast(2))
                + ["unlock door with key"],
            seed: 18)

        expectInOrder(
            oakDoor,
            [
                "Something turns over inside the door, and the lock gives.",
                "It is already unlocked.",
            ])
    }

    /// **Both of the game's locks refuse a wrong key in one voice.** #260's
    /// neighbour, and the same defect one guard over: the grating fell to the
    /// engine's "That doesn't fit the lock." while the Palantir had written two
    /// lines of its own for the idea, so three registers answered it and which
    /// one the player heard depended on the lock and on the key. The line is
    /// direction-neutral because the engine's slot answers `lock` as well as
    /// `unlock`, which is what the second grating pair pins. (#263)
    @Test func bothOfTheGamesLocksRefuseAWrongKeyInOneVoice() async throws {
        let grating = try await play(
            Dungeon(),
            Self.toMazeFive + ["take keys"] + Self.mazeFiveToTheGrating
                + [
                    "unlock grating with lamp", "unlock grating with keys",
                    "lock grating with lamp",
                ],
            seed: 18)

        expectInOrder(
            grating,
            [
                "That will not turn the lock.",
                "The grate is unlocked.",
                "That will not turn the lock.",
            ])

        // The solve up to the turn of the lock, with the screwdriver offered
        // in place of the key it just punched out.
        let oakDoor = try await play(
            Dungeon(),
            Self.toTheTinyRoom + Array(Self.theOakDoorSolve.dropLast(3))
                + ["unlock door with screwdriver"],
            seed: 18)

        #expect(oakDoor.contains("That will not turn the lock."))
    }

    /// **The grating's own two lines say which side of it you are standing
    /// on.** `GRATE-FUNCTION` answers both turns of this lock itself, because
    /// the lock is on the underside: from the Clearing there is nothing to put
    /// a key into, and the two directions refuse there in different words.
    /// Before #263 nothing guarded `lock` at all, so the grating could be
    /// locked from the Clearing — from the wrong side of its own lock. (#263)
    @Test func theGratingsLockOnlyTurnsFromUnderneathIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toMazeFive + ["take keys"] + Self.mazeFiveToTheGrating
                + [
                    "unlock grating with keys", "lock grating with keys",
                    "unlock grating with keys", "open grating", "up",
                    "lock grating with keys", "unlock grating with keys",
                ],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The grate is unlocked.",
                "The grate is locked.",
                "The grate is unlocked.",
                "The grating opens to reveal trees above you.",
                "Clearing",
                "You cannot lock it from this side.",
                "You cannot reach the lock from up here.",
            ])
    }

    // MARK: - Milestone 8: the coal chute

    /// **Without a rope the chute is milestone 3's one-way drop into the
    /// Cellar**, which is the source's own unroped outcome and is why the
    /// shortcut was never wrong — only incomplete.
    @Test func theChuteWithoutARopeIsStillTheDropIntoTheCellar() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber + ["drop timber", "down"],
            seed: 18)

        expectInOrder(transcript, ["Slide Room", "Cellar"])
        #expect(!transcript.contains("You are hanging on a rope"))
    }

    /// With the rope tied to the timber — on the ground, not in your hands — it
    /// is a climb instead, and the ledge three stretches down is the only way
    /// to the Sooty Room. Reaching the ledge cancels the grip clock outright,
    /// so the climb back up is untimed.
    @Test func theRopeTurnsTheChuteIntoAClimbAndTheLedgeIsSafe() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber + Self.downTheChuteToTheLedge
                + ["south", "take red sphere", "north", "up", "up", "up", "score"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The rope is tied fast",
                "You are hanging on a rope",
                "Slide Ledge",
                "Sooty Room",
                "There is a beautiful red crystal sphere here.",
                // Back at the top, and the room now says what is hanging in it.
                "A rope is tied off at the head of the slide",
                "Your score is 50 of a possible 716",
            ])
        #expect(!transcript.contains("Your grip goes"))
    }

    /// The anchor has to be on the ground and it has to be one of two. A rope
    /// tied to something in your hands holds nothing, and the source insists.
    @Test func theChutesAnchorHasToBeOnTheGroundAndHasToBeOneOfTwo() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber
                + ["tie rope to timber", "tie rope to lamp", "tie rope"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You would have to put it down first",
                "That would not hold a bucket",
                "Tie it to what?",
            ])
    }

    /// `SLIDE-EXIT`'s grip clock: `100 / carried weight`, floored at two turns.
    /// Dawdle in the chute and it lets go, and where it lets you go is the
    /// Cellar — which is where the unroped drop would have put you anyway.
    @Test func dawdlingInTheChuteCostsYouYourGrip() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber
                + ["drop timber", "tie rope to timber", "down"]
                + Array(repeating: "listen", count: 8),
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You are hanging on a rope",
                "Your grip goes, and the chute takes the rest.",
                "Cellar",
            ])
    }

    /// Anything let go of in the chute is gone: it falls the rest of the way
    /// and turns up in the Cellar. The rope is the one exception, and letting
    /// go of that takes you with it.
    @Test func whatYouDropInTheChuteEndsUpInTheCellarAndSoDoYou() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber
                + ["drop timber", "tie rope to timber", "down", "take rope", "drop rope"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You are hanging on a rope",
                "And what do you imagine is holding you up?",
                "You let go, and the chute has you.",
                "Cellar",
            ])
    }

    /// **Lifting the anchor unties the knot.** `rigTheChute()` refuses to tie
    /// the rope to something in your hands, on the grounds that a rope tied to
    /// what you are carrying holds nothing; nothing re-checked it afterwards,
    /// so the 2026-08-11 round (#233) found the Slide Room still calling the
    /// rope "tied off at the head of the slide" while the player carried the
    /// timber it was tied to away.
    @Test func liftingTheChutesAnchorUntiesTheRope() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber
                + ["drop timber", "tie rope to timber", "look", "take timber", "look"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The rope is tied fast",
                "A rope is tied off at the head of the slide",
                "The rope goes slack as the weight comes off it",
            ])
        // And the room stops saying it: the paragraph appears once, before the
        // timber comes back up off the floor.
        #expect(
            transcript.components(separatedBy: "A rope is tied off at the head of the slide")
                .count == 2)
    }

    // MARK: - Milestone 8: the three palantirs, which do not combine

    /// **`look in <sphere>` shows the room the *next* sphere is in**, on a
    /// fixed one-way cycle blue → red → white → blue, and does nothing else.
    /// No teleport, no score, no third-sphere effect: the only routine in the
    /// source that touches more than one palantir is this one. Worth pinning
    /// because assembling them is the obvious guess and it is wrong.
    @Test func onePalantirShowsTheRoomTheNextOneIsIn() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTinyRoom + Self.theOakDoorSolve
                + ["take blue sphere", "look in blue sphere", "score"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "A room swims up in the depths of the crystal: Sooty Room.",
                "red crystal sphere",
                // And it is worth nothing: the score has not moved off the ten
                // the sphere itself paid for being found.
                "Your score is 50 of a possible 716",
            ])
    }

    /// And the cycle runs on. The red one shows the Dingy Closet, which is
    /// behind the robot's puzzle at the top of the well and a very long way
    /// from the bottom of the coal chute — so the second palantir is a
    /// signpost to the third long before there is any road to it.
    @Test func theCycleRunsOnFromTheRedSphereToTheWhiteOne() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber + Self.downTheChuteToTheLedge
                + ["south", "take red sphere", "look in red sphere"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Sooty Room",
                "A room swims up in the depths of the crystal: Dingy Closet.",
                "white crystal sphere",
            ])
    }

    // MARK: - Milestone 8: the free brochure and the Don Woods stamp

    /// **The leaflet is what tells you the brochure exists**, and `send for
    /// brochure` works from anywhere. Three answers, in the source's order: the
    /// order goes out, then it is on its way, then the clerk is sarcastic. What
    /// starts the postman is walking into the Kitchen, not the mailbox.
    @Test func theBrochureIsOrderedAnywhereAndArrivesAtTheHouse() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "open mailbox", "read leaflet", "send for brochure",
                "send for brochure",
            ]
                + Self.intoTheKitchen
                + [
                    "wait", "wait", "east", "north", "west", "look",
                    "send for brochure",
                ])

        expectInOrder(
            transcript,
            [
                "send for our free brochure",
                "Ordered. You know what the post is like, though.",
                "It is presumably on its way.",
                "Somebody knocks at the front of the house.",
                "In the small mailbox is a free brochure.",
                "Why? Has the first one worn out?",
            ])
    }

    /// The brochure is a prospectus for MIT whose curriculum is the Mock
    /// Turtle's, and the stamp affixed to it is worth **nothing to find and one
    /// to case** — the only treasure in the game that way round, and its own
    /// face says so.
    @Test func theDonWoodsStampIsWorthNothingToFindAndOneToCase() async throws {
        let transcript = try await play(
            Dungeon(),
            ["send for brochure"] + Self.intoTheKitchen
                + [
                    "wait", "wait", "east", "north", "west", "open mailbox",
                    "take brochure", "read brochure", "take stamp", "score",
                    "read brochure", "south", "east", "west", "west",
                    "open case", "put stamp in case", "score",
                ])

        expectInOrder(
            transcript,
            [
                "Distraction, Uglification and Derision",
                "Affixed loosely to the brochure is a small stamp.",
                // Ten for the Kitchen, and not a point for the stamp.
                "Your score is 10 of a possible 716",
                "Drawling, Stretching",
                // Cased, it pays its one lousy point.
                "Your score is 11 of a possible 716",
            ])
        // Once the stamp is out of it, the brochure stops saying it is there.
        #expect(occurrences(of: "Affixed loosely to the brochure", in: transcript) == 1)
    }

    // MARK: - Milestone 8: every printed noun answers

    @Test func everyNounThePalantirWingPrints() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTinyRoom
                + ["examine door", "examine window", "examine lid", "examine keyhole"]
                + Self.theOakDoorSolve
                + [
                    "examine table", "examine crack", "examine sphere", "examine window",
                    "examine lid", "examine keyhole", "examine key", "examine glow",
                ],
            seed: 18)

        expectEveryNounAnswered(transcript, "the Tiny Room and the Dreary Room")
    }

    @Test func everyNounTheChuteAndTheSootyRoomPrint() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber
                + ["examine slide", "examine granite wall"]
                + Self.downTheChuteToTheLedge
                + [
                    "examine chute", "examine rope", "examine opening",
                    "south", "examine stove", "examine crack", "examine sphere",
                ],
            seed: 18)

        expectEveryNounAnswered(transcript, "the chute, the ledge and the Sooty Room")
    }

    @Test func everyNounTheBrochureAndItsStampPrint() async throws {
        let transcript = try await play(
            Dungeon(),
            ["send for brochure"] + Self.intoTheKitchen
                + [
                    "wait", "wait", "east", "north", "west", "open mailbox",
                    "examine brochure", "examine stamp", "examine mailbox",
                    "examine leaflet", "read brochure", "examine pages",
                ])

        expectEveryNounAnswered(transcript, "the brochure and the stamp")
    }

    /// With milestone 8 in, the palantir wing joins the graph at the two places
    /// the source joins it: west out of the Torch Room, and down the Slide
    /// Room's chute on a rope. Neither half is reachable from the other without
    /// leaving the wing, which is why it takes two roads to walk it.
    @Test func milestoneEightJoinsThePalantirWingToTheGraph() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheChuteWithTheTimber + Self.downTheChuteToTheLedge
                + ["south", "north", "up", "up", "up"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Slide Room",
                "Slide",
                "Slide Ledge",
                "Sooty Room",
                "Slide Ledge",
                "Slide",
                "Slide Room",
            ])
    }

    /// The ceiling lands on **716**, which is `SCORE-MAX` plus `EG-SCORE-MAX`
    /// — the whole of the main dungeon and the whole of the endgame. Milestone
    /// 8's first two pieces closed the main dungeon at 616 with the last
    /// main-dungeon object values there are; milestone 9's hundred is all room
    /// value and finishes the ceiling.
    @Test func theMainDungeonCanNowPayItsWholeSixHundredAndSixteen() throws {
        let (definition, _) = try Bootstrap.build(Dungeon())

        #expect(definition.maxScore == 716)
        #expect(definition.warnings.isEmpty, "\(definition.warnings)")

        // The three objects that closed the gap, with the source's own values.
        for (name, find, deposit) in [
            ("blue crystal sphere", 10, 5),
            ("red crystal sphere", 10, 5),
            ("postage stamp", 0, 1),
        ] {
            let item = definition.items.values.first { $0.name == name }
            #expect(item?.customTraits["takeValue"] == .int(find), "\(name) find value")
            #expect(item?.customTraits["depositValue"] == .int(deposit), "\(name) case value")
        }
    }
}

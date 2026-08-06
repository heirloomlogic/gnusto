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
    /// Seed 11 throughout, recorded: the troll falls to the first blow, so the
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

    /// From the top of the dam: charge the panel, pick up the wrench, come
    /// back. Ends where it started.
    private static let fetchTheWrench = [
        "north", "north", "push yellow button", "take wrench", "south", "south",
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
                "Your score is 10 of a possible 116",
                "Cellar",
                "Your score is 35 of a possible 116",
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
            ])

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
                "Your score is 39 of a possible 116",
            ])
        #expect(!transcript.contains("nasty-looking troll"))
    }

    /// The Cellar's passage runs east, not north, and the troll stands at the
    /// end of it holding three of the four ways out of his room.
    @Test func theCellarRunsEastToTheTrollWhoGatesTheCrawlway() async throws {
        // Seed 39, recorded: the troll's swings all miss, so the transcript is
        // about the gate rather than about the fight.
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
    @Test func dyingToTheTrollCostsTenPointsAndYourHands() async throws {
        // Seed 7, recorded: the troll's first swing is the last word.
        let transcript = try await play(
            Dungeon(),
            ["diagnose"] + Self.intoTheCellar
                + [
                    "east",
                    "diagnose", "inventory", "score",
                ],
            seed: 7)

        expectInOrder(
            transcript,
            [
                "You have not been killed yet",
                "The troll neatly removes your head.",
                "you find yourself standing among the trees",
                "Forest",
                "You have been killed once.",
                // Thirty-five points earned, ten paid back to the troll.
                "Your score is 25 of a possible 116",
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

        #expect(definition.maxScore == 116)
        #expect(definition.warnings.isEmpty, "\(definition.warnings)")
    }

    /// Forcing the egg by hand wrecks the bird inside, as in the mainframe —
    /// which is why the canary's points wait on the thief, and why the bauble
    /// he makes possible does too.
    @Test func forcingTheEggWrecksTheCanaryAndForfeitsItsPoints() async throws {
        let transcript = try await play(
            Dungeon(),
            ["north", "north", "up", "take egg", "open egg", "examine canary", "score"])

        expectInOrder(
            transcript,
            [
                "Taken.",
                "The egg is now open, but the clumsiness of your attempt has",
                "the mainspring seems sprung",
                "Your score is 5 of a possible 116",
            ])
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
            ])

        expectInOrder(
            transcript,
            [
                "Up a Tree",
                "Kitchen",
                "Living Room",
                "Your score is 20 of a possible 116",
                "Cellar",
                "Gallery",
                "Studio",
                "Kitchen",
                "Living Room",
                "Your score is 56 of a possible 116",
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
                "north", "examine house", "examine windows",
                "north", "examine trees", "examine tree", "examine songbird",
                "up", "examine nest", "examine egg", "examine branches",
                "down", "east", "examine leaves", "push leaves", "examine grating",
                "examine forest",
                "south", "examine trees",
                "north", "examine house", "examine windows",
            ])

        expectEveryNounAnswered(transcript, "the house exterior, the wood, the clearing")
    }

    @Test func everyNounTheCanyonPrintsAnswers() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "south", "east", "east", "southeast", "examine trees",
                "southeast", "examine cliff", "examine rainbow", "examine falls",
                "examine cliffs", "examine dam", "examine river", "examine forest",
                "down", "examine cliff", "examine falls",
                "down", "examine cliff", "examine stream", "examine runoff",
            ])

        expectEveryNounAnswered(transcript, "the Great Canyon")
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
                "west", "examine rug", "examine case", "examine sword",
                "examine mantelpiece", "examine wooden door", "examine newspaper",
                "take lamp", "turn on lamp",
                "east", "up",
                "examine table", "examine rope", "examine knife", "examine brick",
                "down", "west",
                "push rug", "examine trap door", "open trap door", "down",
                "examine ramp",
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
        // Seed 19, recorded: four turns in his room without a fatal swing.
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellar
                + [
                    "east", "examine troll", "examine bloodstains", "examine walls",
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
        // Seed 11, recorded: the troll falls to the first blow.
        // The gate first, on its own short walk and its own seed: he kills too
        // readily to spend a spare turn in his room. Seed 39, recorded — the
        // same one milestone 1 uses for his eastward gate.
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
            seed: 11)

        expectInOrder(
            transcript,
            [
                "East-West Passage",
                "Your score is 40 of a possible 116",
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
        // Seed 11, recorded. Three attempts west, and the room is under no
        // obligation to answer any of them with the East-West Passage.
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll + ["north", "east", "examine machinery", "west", "west", "west"],
            seed: 11)

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
            seed: 11)

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
                "Your score is 52 of a possible 116",
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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
    /// bauble, which still wait on the thief.
    ///
    /// Four descents, because the trap door bars itself behind you and the
    /// chimney takes the lamp and one thing more. The troll has to be cut down
    /// on the second of them, and the crossroads and the dam are both behind
    /// him.
    @Test func aCompleteHaulThroughMilestoneTwoScoresOneHundredAndSix() async throws {
        // Seed 1, recorded: the troll needs two blows and lands one of his own.
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
            seed: 1)

        expectInOrder(
            transcript,
            [
                "Your score is 56 of a possible 116",
                "The troll takes a fatal blow",
                "Loud Room",
                "The acoustics of the room change subtly.",
                "You put the platinum bar in the trophy case.",
                "Your score is 83 of a possible 116",
                "The sluice gates open and water pours through the dam.",
                "Lying half buried in the mud is an old trunk",
                "You put the trunk of jewels in the trophy case.",
                "Your score is 106 of a possible 116",
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
                    // the Round Room's own noun is swept by the carousel test.
                    "east", "south", "examine canyon",
                ],
            seed: 11)

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
                    "examine chests", "examine tube", "examine wrench",
                    "examine screwdriver",
                    "south", "south", "down",
                    "examine dam", "examine river", "examine cliffs",
                ],
            seed: 11)

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
                    "east", "north", "examine mud", "examine trunk",
                    "north", "examine tunnel", "examine pump",
                    "south", "up", "examine beach", "examine walls",
                ],
            seed: 11)

        expectEveryNounAnswered(transcript, "the reservoir and the stream")
    }
}

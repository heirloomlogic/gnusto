import Foundation
import GnustoTestSupport
import Testing

@testable import Dungeon
@testable import Gnusto

/// Milestone 1 of the mainframe-Zork reconstruction: above ground, the white
/// house, and the cellar.
///
/// Most of these tests exist to pin the **map**, because the map is the one
/// thing `docs/games/dungeon.md`'s mechanics contract calls non-negotiable —
/// and because this region is where the mainframe and Zork I differ most. A
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
                "Your score is 10 of a possible 66",
                "Cellar",
                "Your score is 35 of a possible 66",
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
                "Your score is 39 of a possible 66",
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
                "Your score is 25 of a possible 66",
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

        #expect(definition.maxScore == 66)
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
                "Your score is 5 of a possible 66",
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
                "Your score is 20 of a possible 66",
                "Cellar",
                "Gallery",
                "Studio",
                "Kitchen",
                "Living Room",
                "Your score is 56 of a possible 66",
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
}

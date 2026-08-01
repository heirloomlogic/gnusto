import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import KindlyDeep

/// End-to-end play of the survival-and-companion demo: the win path lights the
/// lamp, lets Biscuit nose out the canteen, crawls the gap he cannot follow,
/// opens the air-door that reunites them, and hauls the beam clear to ring the
/// cage home — while the surrounding tests pin the two failing clocks (thirst
/// and fatigue), the companion's follow/park/rejoin contract, the scenery the
/// prose names, and every refusal.
///
/// The game draws no randomness, so nothing here is seeded.
struct KindlyDeepTests {
    /// Four turns: strike the lamp, walk into the stable, give Biscuit his turn
    /// to nose out the canteen, and pocket it.
    private static let withCanteen = ["light lamp", "west", "wait", "take canteen"]

    /// Four turns: strike the lamp and walk the entry, the forks, and the crawl
    /// to the shaft bottom. Biscuit is parked at the forks on arrival.
    private static let toShaftBottom = ["light lamp", "east", "east", "east"]

    // MARK: - The full walkthrough

    @Test func theFullWalkthroughRingsOutAtTwentyFive() async throws {
        // Golden path plus a rest-trip detour back through the opened air-door,
        // padded so thirst and fatigue each cross a warning threshold on the way.
        let transcript = try await play(
            KindlyDeep(),
            [
                "light lamp",  // beat 1: the striker; score lamp
                "west",  // stable; Biscuit is a step behind
                "examine biscuit",  // beat 2 noses out the canteen; score canteen
                "take canteen",
                "east",
                "east",  // the forks
                "north",  // beat 3: refused by Biscuit
                "east",  // the crawl; beat 4 parks him at the forks
                "east",  // shaft bottom (parked: no arrival)
                "open air-door",  // rejoin; score door
                "examine beam",
                "examine bell",  // thirst stage 1 fires here (turn 12)
                "examine tack",
                "wait", "wait", "wait",  // fatigue stage 1 fires (turn 16)
                "west",  // back west through the now-open air-door…
                "west",
                "down",  // …a step down to the shelter hole
                "rest",  // the rest scene; resets fatigue, snuffs the lamp
                "light lamp",  // and you wake in the dark needing the striker
                "up",
                "east",
                "east",  // the crawl re-parks him, silently
                "east",  // shaft bottom; he catches up through the door
                "drink canteen",  // the water, at last
                "harness biscuit",  // beam hauled; score beam
                "pull rope",  // the ending; score bell; win
            ])

        expectInOrder(
            transcript,
            [
                "the dark steps back to a respectful distance",  // the striker scene
                "Biscuit, of course, dusty to the knees",  // beat 1, first sight
                "puts his nose under the loose board",  // beat 2, the nose-out
                "the mule has seniority",  // beat 3, the north refusal
                "The bray that follows you into the crawl",  // beat 4, the crawl
                "the door swings wide with a groan of old hinges",  // the rejoin
                "Apology accepted, apparently. Provisionally.",
                "Your mouth has gone tacky",  // thirst, stage 1
                "A yawn ambushes you mid-step",  // fatigue, stage 1
                "You pinch the lamp out first",  // the rest scene
                "Thirst has stopped being an opinion",  // thirst, stage 2 (on the rest turn)
                "Flint, sparks, and the wick takes",  // the relight, waking in the dark
                "the beam grinds off the gate an inch at a time",  // the beam haul
                "the sound goes up the shaft like a bird out of a trap",  // the ending
                "it is raining — soft, gray, spring rain",
                "Your score is 25 of a possible 25",
            ])
    }

    // MARK: - Follow behavior

    @Test func theCompanionTrailsThePlayerIntoEachLitRoom() async throws {
        // Once the lamp is lit, the follow arrival line trails the room
        // description into every room the player walks into.
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "west", "east", "south"])
        // The arrival line cycles with the turn counter — each move draws the
        // next entry in the game's dozen, deterministically.
        #expect(turnOutput(of: "west", in: transcript).contains("A clatter of hooves behind you"))
        #expect(turnOutput(of: "east", in: transcript).contains("Biscuit comes up at his working pace"))
        #expect(turnOutput(of: "south", in: transcript).contains("breathing hay-warm air over your collar"))
    }

    @Test func theCompanionArrivesUnseenBeforeTheLampIsLit() async throws {
        // The game opens dark; a move made before the striker gets no arrival
        // line — his follow is silent behind the `isLit` guard — and the bespoke
        // pitch-black prose stands in for the room.
        let transcript = try await play(KindlyDeep(), ["west"])
        #expect(!turnOutput(of: "west", in: transcript).contains("Biscuit"))
        #expect(transcript.contains("Dark of the sort found only underground"))
    }

    @Test func theCompanionIsSilentWhileParkedInTheCrawlAndAtTheShaft() async throws {
        // Entering the crawl parks him at the forks; he stays silent there and at
        // the shaft bottom until the air-door reunites them. Before the rejoin,
        // the only arrival heard is the one at the forks.
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottom + ["open door"])
        let beforeRejoin = output(before: "the door swings wide", in: transcript)
        #expect(beforeRejoin.contains("Biscuit tries to follow"))  // he was parked at the crawl
        #expect(occurrences(of: "A clatter of hooves behind you", in: beforeRejoin) == 1)  // forks only
    }

    // MARK: - The thirst clock

    @Test func thirstWarnsInThreeStagesThenKillsYouInTheDark() async throws {
        // Never drink.
        let commands = ["light lamp"] + Array(repeating: "wait", count: 40)
        let transcript = try await play(KindlyDeep(), commands)
        expectInOrder(
            transcript,
            [
                "Your mouth has gone tacky",  // stage 1
                "Thirst has stopped being an opinion",  // stage 2
                "Your lips have split",  // stage 3, arms the fuse
                "You died of thirst in the dark, one swallow short of the cage",  // the fuse fires
                "*** You have died ***",
            ])
    }

    @Test func drinkingAfterTheThirdThirstWarningDefusesTheDehydration() async throws {
        // Reach stage 3 (the fuse armed), drink, and outlast the turn on which
        // the fuse would have fired.
        let commands =
            Self.withCanteen
            + Array(repeating: "wait", count: 24)  // to turn 28: stage 3
            + ["drink canteen"]
            + Array(repeating: "wait", count: 11)  // well past where death was due
        let transcript = try await play(KindlyDeep(), commands)
        expectInOrder(
            transcript,
            [
                "Your lips have split",  // stage 3, fuse armed
                "It goes down cold and tastes of tin",  // the swallow resets and defuses
            ])
        #expect(!transcript.contains("You died of thirst in the dark"))
        #expect(!transcript.contains("*** You have died ***"))
    }

    // MARK: - The fatigue clock

    @Test func fatigueWarnsInThreeStagesThenCollapsesYouInTheWrongPlace() async throws {
        // A single mid-way swallow keeps thirst from claiming the kill first, so
        // the clock that actually runs out is fatigue.
        let commands =
            Self.withCanteen
            + Array(repeating: "wait", count: 15)
            + ["drink canteen"]  // turn 20: suppress thirst
            + Array(repeating: "wait", count: 25)  // never rest
        let transcript = try await play(KindlyDeep(), commands)
        expectInOrder(
            transcript,
            [
                "A yawn ambushes you mid-step",  // stage 1
                "Your eyelids have taken on weight",  // stage 2
                "You are walking asleep, in the technical sense",  // stage 3, arms the fuse
                "You fell asleep in the wrong place",  // the fuse fires
                "*** You have died ***",
            ])
    }

    @Test func restingAfterTheThirdFatigueWarningDefusesTheCollapse() async throws {
        // Wait out all three fatigue stages down in the shelter hole, then rest
        // on the straw and outlast the turn the collapse was due.
        let commands =
            Self.withCanteen + ["east", "down"]
            + Array(repeating: "wait", count: 13)
            + ["drink canteen"]  // turn 20: keep thirst off the board
            + Array(repeating: "wait", count: 16)  // to turn 36: stage 3
            + ["rest"]
            + Array(repeating: "wait", count: 9)  // past where the collapse was due
        let transcript = try await play(KindlyDeep(), commands)
        expectInOrder(
            transcript,
            [
                "You are walking asleep, in the technical sense",  // stage 3, fuse armed
                "and lie down in the straw",  // the rest defuses it
            ])
        #expect(!transcript.contains("You fell asleep in the wrong place"))
        #expect(!transcript.contains("*** You have died ***"))
    }

    @Test func restIsRefusedAnywhereButTheStraw() async throws {
        let transcript = try await play(KindlyDeep(), ["light lamp", "rest"])
        #expect(transcript.contains("Not on bare stone, not in this cold"))
    }

    // MARK: - The lamp

    @Test func restingSnuffsTheLampAndYouWakeNeedingTheStriker() async throws {
        // Nobody sleeps beside an open flame: the rest scene puts the lamp out,
        // the shelter hole goes pitch black, and the relight is ordinary lamp
        // business — not a second helping of the striker scene.
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "down", "rest", "look", "light lamp"])
        #expect(turnOutput(of: "rest", in: transcript).contains("You pinch the lamp out first"))
        #expect(turnOutput(of: "look", in: transcript).contains("Dark of the sort found only underground"))

        let afterWaking = output(after: "The striker is on your belt", in: transcript)
        #expect(afterWaking.contains("Flint, sparks, and the wick takes"))
        #expect(!afterWaking.contains("The flame takes on the second strike"))
        // The relit room describes itself again, the way the default action does.
        #expect(afterWaking.contains("The Shelter Hole"))
    }

    @Test func theStrikerSceneScoresOnlyOnce() async throws {
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "down", "rest", "light lamp", "score"])
        #expect(transcript.contains("Your score is 5 of a possible 25"))
    }

    @Test func lightingTheLampWhenItAlreadyBurnsGetsItsLine() async throws {
        let transcript = try await play(KindlyDeep(), ["light lamp", "light lamp"])
        #expect(transcript.contains("It is lit. Try to stay ahead of the things that are actually wrong."))
    }

    // MARK: - Beats fire once, and in order

    @Test func theNoseOutWaitsForBiscuitToCatchUp() async throws {
        // The beat is his, so it holds until he is actually in the room: the
        // turn you walk in prints his arrival line and nothing else, and the
        // nose-out lands on the next turn rather than on top of it.
        let transcript = try await play(KindlyDeep(), ["light lamp", "west", "wait"])
        let arrival = turnOutput(of: "west", in: transcript)
        #expect(arrival.contains("A clatter of hooves behind you"))
        #expect(!arrival.contains("puts his nose under the loose board"))
        #expect(turnOutput(of: "wait", in: transcript).contains("puts his nose under the loose board"))
    }

    @Test func theNoseOutDoesNotRepeatOnStableReentry() async throws {
        // Beat 2 fires once, and not again on a return trip.
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "west", "wait", "east", "west", "wait"])
        #expect(occurrences(of: "puts his nose under the loose board", in: transcript) == 1)
    }

    @Test func theForksStayShutWhileBiscuitStandsAcrossThem() async throws {
        // North into the old works is refused with beat 3's prose — every time
        // it is tried, since the mule does not tire of the argument.
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "east", "north", "north"])
        #expect(occurrences(of: "puts himself across the mouth of the old works", in: transcript) == 2)
        #expect(transcript.contains("the mule has seniority"))
    }

    // MARK: - Reactions

    @Test func talkingAndPettingDrawTheirCannedReplies() async throws {
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "talk to biscuit", "pet biscuit"])
        expectInOrder(
            transcript,
            [
                "he breathes warm air down your collar",  // talk
                "keeping your feet becomes a genuine question of engineering",  // pet
            ])
    }

    @Test func sharingTheCanteenWithBiscuitReallyCostsYouASwallow() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.withCanteen + ["give canteen to biscuit", "x canteen"])
        #expect(transcript.contains("he takes it in one long pull"))
        #expect(turnOutput(of: "x canteen", in: transcript).contains("better than half of it left"))
    }

    @Test func biscuitDeclinesAnythingThatIsNotWater() async throws {
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "give lamp to biscuit"])
        #expect(transcript.contains("works out that it is not water"))
    }

    @Test func theCanteenHoldsThreeSwallowsAndNoMore() async throws {
        // The only water in the workings: three drinks, each the full scene and
        // each a thirst reset, and a fourth attempt finds dry tin.
        let transcript = try await play(
            KindlyDeep(),
            Self.withCanteen + Array(repeating: "drink canteen", count: 4))
        #expect(turnOutput(of: "take canteen", in: transcript).contains("Taken."))
        #expect(occurrences(of: "It goes down cold and tastes of tin", in: transcript) == 3)
        #expect(transcript.contains("The canteen is dry, and turning it over one more time"))
    }

    @Test func openingTheCanteenIsJustDrinkingFromIt() async throws {
        // There is nothing in a canteen but the drink, so `open` and `drink`
        // are the same act — and the stopper goes back in either way.
        let transcript = try await play(
            KindlyDeep(), Self.withCanteen + ["open canteen", "close canteen", "x canteen"])
        #expect(turnOutput(of: "open canteen", in: transcript).contains("The stopper goes back in"))
        #expect(turnOutput(of: "close canteen", in: transcript).contains("The stopper is in."))
        #expect(turnOutput(of: "x canteen", in: transcript).contains("better than half of it left"))
    }

    @Test func biscuitOnlySupervisesTheSwallowWhenHeIsThere() async throws {
        // He is parked at the forks while you are past the crawl, so the drink
        // scene must not have him watching from a room he cannot get into.
        let transcript = try await play(
            KindlyDeep(),
            Self.withCanteen
                + ["drink canteen"]  // together, in the stable
                + ["east", "east", "east", "east", "drink canteen"])  // past the crawl, alone
        let together = turnOutput(of: "drink canteen", in: transcript)
        #expect(together.contains("Biscuit watches every swallow"))

        let alone = output(after: "The bray that follows you into the crawl", in: transcript)
        #expect(alone.contains("The stopper goes back in"))
        #expect(!alone.contains("Biscuit watches every swallow"))
    }

    /// Nobody who has not driven a mule knows the word, so the collar takes all
    /// of them — and putting it on him by hand works too. The haul is once-only,
    /// so each phrasing needs its own game; as a parameterized test they run as
    /// nine independently scheduled cases rather than one serial loop.
    @Test(arguments: [
        "harness biscuit", "harness tack", "hitch biscuit", "saddle biscuit",
        "yoke mule", "rig biscuit", "put tack on mule", "put collar on mule",
        "give tack to biscuit",
    ])
    func theHaulAnswersToWhicheverWordYouReachFor(_ phrasing: String) async throws {
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottom + ["open door", phrasing])
        #expect(transcript.contains("the beam grinds off the gate an inch at a time"))
    }

    @Test func givingADrinkDoesNotResetTheThirstClock() async throws {
        // Unlike drinking, giving does not reset thirst: the first warning still
        // arrives on its ordinary schedule (turn 12), not delayed by the gift.
        let commands =
            Self.withCanteen + ["give canteen to biscuit"]
            + Array(repeating: "wait", count: 7)  // total 12 turns
        let transcript = try await play(KindlyDeep(), commands)
        #expect(transcript.contains("Your mouth has gone tacky"))
    }

    // MARK: - The scenery the prose names

    @Test func everyNounTheProseNamesAnswersToIt() async throws {
        // The rooms describe a fall, rails, a stall, a dry trough, a corn bin, a
        // bench, the old works, the shaft, and the cage gate. All of them are
        // examinable, and the air-door answers to its hyphenated name.
        let transcript = try await play(
            KindlyDeep(),
            [
                "light lamp", "x striker", "x fall", "x rails",
                "west", "x stall", "x trough", "x corn bin",
                "east", "down", "x bench", "sit on bench", "up",
                "east", "x air-door", "x old works", "x crawl",
                "east", "east", "x shaft", "x cage gate", "x rope", "x peg",
            ])
        #expect(!transcript.contains("You can't see any such thing"))
        #expect(!transcript.contains("I don't know the word"))
        #expect(transcript.contains("A plank bench worn smooth"))
        #expect(transcript.contains("sitting is not resting"))
    }

    @Test func theStrikerNeverLeavesYourBelt() async throws {
        // The intro and every pitch-black turn name it, so it is a real thing —
        // and dropping it in these workings is a way to die that the game
        // declines to offer.
        let transcript = try await play(KindlyDeep(), ["inventory", "drop striker", "light striker"])
        #expect(turnOutput(of: "inventory", in: transcript).contains("flint striker"))
        #expect(transcript.contains("It goes on your belt and it stays on your belt"))
        #expect(transcript.contains("The striker lights the lamp. Light the lamp."))
    }

    @Test func theAirDoorTellsYouWhichSideOfItYouAreOn() async throws {
        // From the forks it is a wall; from the shaft it is a bar waiting to be
        // lifted, and it must not read as hopeless from the side that works.
        let transcript = try await play(
            KindlyDeep(),
            ["light lamp", "east", "x air-door", "east", "east", "x air-door", "open door", "x air-door"])
        #expect(turnOutput(of: "x air-door", in: transcript).contains("jammed hard into it from this side"))

        let atTheShaft = output(after: "The Shaft Bottom", in: transcript)
        #expect(atTheShaft.contains("the bar is on this side, and a bar is a thing that lifts"))
        #expect(!atTheShaft.contains("jammed hard into it from this side"))

        let opened = output(after: "the door swings wide", in: transcript)
        #expect(opened.contains("The air-door stands wide on its hinges"))
    }

    @Test func theCornBinGivesUpTheCanteenToAnyoneWhoLooks() async throws {
        // The mule's beat is the intended route, but the only water in the
        // workings must not hang on the player happening to linger: the room's
        // own prose names a loose board, and searching it finds the same thing.
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "west", "search corn bin", "search bin", "score"])
        #expect(turnOutput(of: "search corn bin", in: transcript).contains("You get a hand under the loose board"))
        #expect(turnOutput(of: "search bin", in: transcript).contains("Nothing else under the board"))
        // Found the hard way, it scores exactly what the mule's beat scores.
        #expect(transcript.contains("Your score is 10 of a possible 25"))
        // And the mule does not then re-find what you already have.
        #expect(!transcript.contains("puts his nose under the loose board"))
    }

    @Test func theShelterHoleIsAlsoAStepDown() async throws {
        // The Fresh Fall calls it "a step down to the south", so `down` gets you
        // there and `up` gets you back.
        let transcript = try await play(KindlyDeep(), ["light lamp", "down", "up"])
        #expect(turnOutput(of: "down", in: transcript).contains("The Shelter Hole"))
        #expect(turnOutput(of: "up", in: transcript).contains("The Fresh Fall"))
    }

    @Test func theDryTroughHasNothingToOffer() async throws {
        let transcript = try await play(KindlyDeep(), ["light lamp", "west", "drink trough"])
        #expect(transcript.contains("Dry as a flue"))
    }

    @Test func theHaulTackStaysOnItsPeg() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottom + ["take tack"])
        #expect(transcript.contains("It goes on the mule, or it stays on the peg."))
    }

    // MARK: - Refusals

    @Test func theFreshFallCarriesItsPremiseProseNorthward() async throws {
        let transcript = try await play(KindlyDeep(), ["light lamp", "north"])
        #expect(transcript.contains("The roof has been down an hour and has no plans to get up"))
    }

    @Test func theAirDoorRefusesToOpenFromTheForksSide() async throws {
        let transcript = try await play(KindlyDeep(), ["light lamp", "east", "open air-door"])
        #expect(transcript.contains("the door declines, politely but with the whole weight of the racked frame"))
    }

    @Test func theBellWillNotRingWhileTheBeamBlocksTheGate() async throws {
        // The rope invites pulling as much as the bell invites ringing, and both
        // meet the same refusal while twelve feet of poplar lies across the gate.
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottom + ["ring bell", "pull rope"])
        #expect(occurrences(of: "Shift the beam first.", in: transcript) == 2)
    }

    @Test func theBeamWillNotBudgeByHand() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottom + ["push beam", "pull beam"])
        #expect(occurrences(of: "It wants hauling, not heroics", in: transcript) == 2)
    }
}

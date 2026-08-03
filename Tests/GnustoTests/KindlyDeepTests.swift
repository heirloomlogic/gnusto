import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Gnusto
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

    /// The same four turns plus the rejoin: the bar lifts, he comes through, and
    /// the two of you are at the shaft together.
    private static let toShaftBottomTogether = toShaftBottom + ["open air-door"]

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
        // it is tried, since the mule does not tire of the argument. Now that
        // the room beyond is reachable, this is also the guard that keeps it
        // reachable *only* by leaving him: the bad air stays behind him.
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "east", "north", "north"])
        #expect(occurrences(of: "puts himself across the mouth of the old works", in: transcript) == 2)
        #expect(transcript.contains("the mule has seniority"))
        #expect(!transcript.contains("syrup-thick"))
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

    @Test func theBeamWillNotBudgeByHand() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottomTogether + ["push beam", "pull beam"])
        #expect(occurrences(of: "It wants hauling, not heroics", in: transcript) == 2)
    }

    // MARK: - The game cannot be made unwinnable

    /// The blocking box of #126. Every room is dark, the cap-lamp is the only
    /// light in the game, and a doused lamp on the floor of a dark room cannot
    /// be seen, taken or relit — so dousing and dropping it ended the game on
    /// turn three, with no death and no warning. The striker has always had this
    /// guard; the lamp's doc comment claimed the invariant without enforcing it.
    @Test func theLampNeverLeavesYourCap() async throws {
        let transcript = try await play(
            KindlyDeep(),
            [
                "light lamp", "turn off lamp", "drop lamp", "light lamp", "west", "put lamp in corn bin",
                "inventory",
            ])
        #expect(occurrences(of: "It goes on your cap and it stays there", in: transcript) == 2)
        #expect(!transcript.contains("Dropped."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("cap-lamp"))
    }

    /// And the lamp being out is a recoverable state rather than a terminal
    /// one: you can still see it, take hold of it, and strike the striker.
    @Test func aDousedLampCanAlwaysBeRelit() async throws {
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "turn off lamp", "look", "light lamp", "look"])
        #expect(turnOutput(of: "look", in: transcript).contains("Dark of the sort found only underground"))
        #expect(output(after: "Flint, sparks, and the wick takes", in: transcript).contains("The Fresh Fall"))
    }

    // MARK: - The two endings

    /// Ring with the mule on the wrong side of a crawl he cannot use and the
    /// game does not congratulate you for a rescue you did not perform. It is a
    /// legal ending, it is not scolded, and it costs exactly the two awards he
    /// earns — `door` and `beam` — which is why `maxScore` never moves.
    @Test func ringingAloneIsTheOtherEndingAndCostsTenPoints() async throws {
        let transcript = try await play(
            KindlyDeep(),
            [
                "light lamp", "west", "search corn bin", "take canteen", "east", "east", "east", "east",
                "ring bell",
            ])
        expectInOrder(
            transcript,
            [
                "the sound goes up the shaft like a bird out of a trap",
                "three men and a chain and a good deal of shouted advice",
                "there is no version of it that is about the beam",
                "goes on waiting to hear what the two of you do next",
                "Your score is 15 of a possible 25",
            ])
        // Not one line of the ending he is not in.
        #expect(!transcript.contains("Biscuit has stepped forward to inspect the cage"))
        #expect(!transcript.contains("the sling goes on him first"))
    }

    /// The bleak ending's own state check. Haul the beam, walk back west through
    /// the door, close it behind you, and take the crawl: the shaft's `onEnter`
    /// only restarts his daemon while the door is open, so you arrive alone with
    /// the gate already clear. An ending that narrated three men working the
    /// beam off there would be the very defect this PR exists to retire.
    @Test func theBleakEndingKnowsWhoMovedTheBeam() async throws {
        let transcript = try await play(
            KindlyDeep(),
            Self.toShaftBottomTogether
                + ["harness biscuit", "west", "close air-door", "east", "east", "ring bell"])
        #expect(transcript.contains("lands behind a gate with nothing across it"))
        #expect(transcript.contains("no version of it that does not begin with the beam he moved for you"))
        #expect(!transcript.contains("three men and a chain"))
        #expect(transcript.contains("Your score is 20 of a possible 25"))
    }

    /// The haul is a gate rather than a branch: the scene is four sentences
    /// about his shoulders and his hooves, and there is no honest version of it
    /// performed by a man alone. The refusal is also the game's last chance to
    /// say plainly what the player has done.
    @Test func theHaulRefusesWithoutHim() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottom + ["harness tack", "x beam", "score"])
        #expect(transcript.contains("this is a two-body problem. He is not here."))
        #expect(!transcript.contains("the beam grinds off the gate"))
        // Unhauled, so the beam still reads as lying across the gate…
        #expect(turnOutput(of: "x beam", in: transcript).contains("now lying across the cage gate"))
        // …and `beam` went unawarded.
        #expect(transcript.contains("Your score is 5 of a possible 25"))
    }

    // MARK: - No sentence asserts where he is without asking

    /// The central invariant, and the class ten of the round's sixty-four
    /// findings belonged to. Each of these prints with him parked two rooms west
    /// behind a crawl he cannot enter, and each used to put him at your elbow.
    @Test func everyLineAboutTheMuleAsksWhereHeIsFirst() async throws {
        let transcript = try await play(
            KindlyDeep(),
            Self.toShaftBottom + ["turn off lamp", "look", "light lamp", "push beam", "harness tack"])
        let alone = output(after: "The bray that follows you into the crawl", in: transcript)

        // The pitch-black line, which used to put his hooves nearby in the same
        // turn's output as the beat saying the stone had shut his bray out.
        #expect(alone.contains("Nothing shifts in it and nothing breathes but you"))
        #expect(!alone.contains("hooves shift on stone"))
        // The beam refusal, which located a professional eight feet away.
        #expect(alone.contains("the professional is two rooms back the way you came"))
        #expect(!alone.contains("a professional standing eight feet away"))
        // And the haul.
        #expect(alone.contains("You left him on the other side of a crawl he cannot use."))
    }

    /// With him actually there, every one of those lines is the shipped one
    /// again — the guard adds a branch, it does not replace the good version.
    @Test func thoseSameLinesAreUnchangedWhenHeIsThere() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottomTogether + ["turn off lamp", "look", "light lamp", "push beam"])
        let together = output(after: "the door swings wide with a groan of old hinges", in: transcript)
        #expect(together.contains("Somewhere near, hooves shift on stone."))
        #expect(together.contains("hauling is a trade with a professional standing eight feet away"))
    }

    @Test func thirstKillsYouAloneInItsOwnWords() async throws {
        // Parked at the forks by the crawl beat, and never a drop to drink.
        let commands = Self.toShaftBottom + Array(repeating: "wait", count: 33)
        let transcript = try await play(KindlyDeep(), commands)
        #expect(transcript.contains("the last thing you hear is nothing at all, which is worse"))
        #expect(!transcript.contains("hooves on stone, coming near, too late"))
        #expect(transcript.contains("*** You have died ***"))
    }

    @Test func thirstKillsYouWithHimThereInTheOtherWords() async throws {
        let commands = ["light lamp"] + Array(repeating: "wait", count: 40)
        let transcript = try await play(KindlyDeep(), commands)
        #expect(transcript.contains("hooves on stone, coming near, too late"))
        #expect(!transcript.contains("the last thing you hear is nothing at all"))
    }

    /// The rest scene has two guards, not one: the watch is his, and the lamp
    /// clause only prints for a lamp that is burning. A second rest used to
    /// re-pinch a lamp the first rest had put out and nothing had relit.
    @Test func theRestSceneAsksAboutBothTheLampAndTheMule() async throws {
        let transcript = try await play(KindlyDeep(), ["light lamp", "down", "rest", "rest"])
        #expect(turnOutput(of: "rest", in: transcript).contains("You pinch the lamp out first"))
        #expect(occurrences(of: "You pinch the lamp out first", in: transcript) == 1)
        #expect(transcript.contains("The lamp is already out, which saves you the argument"))
        // He followed you down, so the watch is his both times.
        #expect(occurrences(of: "Biscuit stands over you in the dark", in: transcript) == 2)
    }

    @Test func restingAloneHasNobodyStandingOverYou() async throws {
        // Park him at the shaft, come back west through the open door, and go
        // down to the straw by way of the crawl so he cannot follow.
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottomTogether + ["down", "west", "west", "down", "rest"])
        let alone = turnOutput(of: "rest", in: transcript)
        #expect(alone.contains("Nobody stands over you; there is nobody down here to do it"))
        #expect(!alone.contains("Biscuit stands over you"))
    }

    /// The hard route to the canteen ends on a reaction shot from a mule who may
    /// be three rooms east.
    @Test func theCornBinFindWaitsForSomebodyToBeSmugAtYou() async throws {
        let withHim = try await play(
            KindlyDeep(), ["light lamp", "west", "search corn bin"])
        #expect(withHim.contains("the expression of an animal who was about to mention it"))

        // Leave him at the shaft, then walk back for the bin the long way.
        let alone = try await play(
            KindlyDeep(),
            Self.toShaftBottomTogether + ["down", "west", "west", "west", "search corn bin"])
        let find = turnOutput(of: "search corn bin", in: alone)
        #expect(find.contains("wishing briefly and uselessly that there were somebody here"))
        #expect(!find.contains("about to mention it"))
    }

    // MARK: - Descriptions that re-read their own state

    /// Three sites went on putting twelve feet of poplar across the gate one
    /// turn after the game narrated it being dragged off.
    @Test func theShaftBottomRereadsTheBeamAfterTheHaul() async throws {
        let transcript = try await play(
            KindlyDeep(),
            Self.toShaftBottomTogether
                + ["look", "x beam", "x cage gate", "harness biscuit", "look", "x beam", "x cage gate"])
        let after = output(after: "the beam grinds off the gate an inch at a time", in: transcript)
        #expect(after.contains("The cage gate stands clear in its frame"))
        #expect(after.contains("now lying off to one side"))
        #expect(after.contains("good for exactly the one thing it was built for"))
        #expect(!after.contains("twelve-foot beam lying square across it"))
        #expect(!after.contains("perfectly useless"))
    }

    /// The Forks' paragraph was the last thing in the game insisting the route
    /// was shut, and it contradicted `x air-door` in the adjacent turn. The
    /// round's own reproducer, kept as one transcript so the two lines have to
    /// agree with each other.
    @Test func theForksParagraphAndTheDoorAgreeInEveryState() async throws {
        let transcript = try await play(
            KindlyDeep(),
            [
                "light lamp", "east", "look", "x air-door", "east", "east", "open air-door", "west", "look",
                "x air-door",
            ])
        let shut = output(before: "The Low Crawl", in: transcript)
        #expect(shut.contains("jammed it fast from this side"))
        #expect(shut.contains("jammed hard into it from this side"))

        let open = output(after: "the door swings wide with a groan of old hinges", in: transcript)
        #expect(open.contains("The air-door stands open at the far side"))
        #expect(open.contains("The air-door stands wide on its hinges"))
        #expect(!open.contains("jammed it fast from this side"))
    }

    /// The paragraph used to assign "East" to the door, when `east` from the
    /// Forks has always been the crawl. The door swings one way and the map was
    /// right; the prose was wrong.
    @Test func theForksSendYouEastByTheCrawlInEveryState() async throws {
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "east", "east", "east", "open air-door", "west", "look", "east"])
        let open = output(after: "the door swings wide", in: transcript)
        #expect(open.contains("It will not take you east — it opens toward you and always will."))
        #expect(open.contains("The crawl still runs east at floor level"))
        // And east is still the crawl, exactly as the corrected paragraph says.
        #expect(turnOutput(of: "east", in: open).contains("The Low Crawl"))
    }

    // MARK: - The Old Works

    /// Dead content until this round: no description, unreachable in 237 probes,
    /// and an `onEnter` death that could not fire. One map line — the crawl's
    /// eastern mouth — makes it the price of having left him behind, because
    /// entering the crawl from the shaft parks him at the shaft and drops you
    /// into the Forks alone.
    @Test func theOldWorksOpenOnlyOnceHeIsParkedBehindYou() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottomTogether + ["down", "west", "north"])
        #expect(transcript.contains("the sweetness in the air turns syrup-thick"))
        #expect(transcript.contains("The mule would have stopped you; the mule was not there to."))
        #expect(transcript.contains("*** You have died ***"))
    }

    @Test func theOldWorksReadPleasantAndAnswerTheirOwnNouns() async throws {
        // Consume the death so the room's own turn can be inspected: the gas
        // kills on entry, so the description prints in the same output.
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottomTogether + ["down", "west", "north"])
        let arrival = turnOutput(of: "north", in: transcript)
        #expect(arrival.contains("the most restful room in these workings"))
        #expect(arrival.contains("the props still stand"))
    }

    // MARK: - The warnings that used to stare at a flame that was not lit

    /// Both rungs fire off a turn counter, so both are reachable having never
    /// struck the striker at all — by doing nothing but waiting from turn one.
    @Test func theSurvivalWarningsDoNotDescribeALampThatIsNotLit() async throws {
        let transcript = try await play(KindlyDeep(), Array(repeating: "wait", count: 29))
        #expect(!transcript.contains("lamp-flame"))
        #expect(transcript.contains("standing still in the dark, thinking nothing at all"))
        #expect(transcript.contains("an ache setting up behind your eyes that the dark does nothing to help"))
    }

    @Test func theSameWarningsDoDescribeItWhenItIsBurning() async throws {
        let transcript = try await play(
            KindlyDeep(), ["light lamp"] + Array(repeating: "wait", count: 29))
        #expect(transcript.contains("staring at the lamp-flame"))
        #expect(transcript.contains("the lamp-flame doubles when you look at it too long"))
    }

    // MARK: - The last swallow

    /// All three swallows used to print one line, so the one that emptied the
    /// only water in the workings still said he stopped "while there is still
    /// something to stop for."
    @Test func theLastSwallowKnowsThatItIsTheLast() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.withCanteen + Array(repeating: "drink canteen", count: 3))
        #expect(occurrences(of: "still something to stop for", in: transcript) == 2)
        #expect(transcript.contains("nothing to count and no reason to stop early, so you finish it"))
        #expect(occurrences(of: "It goes down cold and tastes of tin", in: transcript) == 3)
    }

    // MARK: - The stock lines the mine was getting wrong about itself

    /// Every "shipped" line here was the *engine's*, left standing where it is
    /// false. Each assertion checks the stock line is **gone** as well as that
    /// the replacement is present, because a rule written with `say` instead of
    /// `reply` prints both — the correction and the line it meant to replace.
    @Test func theStockLinesThatWereFalseAreGoneAndNotMerelyPrefixed() async throws {
        let transcript = try await play(
            KindlyDeep(),
            [
                "light lamp", "smell", "listen",  // the Fresh Fall: register, not truth
                "west", "smell", "search corn bin", "take canteen", "search canteen",
                "east", "down", "sit", "burn straw",
                "up", "east", "smell", "listen",
                "east", "stand", "kneel",
                "east", "climb",
            ])
        // The room whose first line names a smell, and the room whose smell kills.
        #expect(turnOutput(of: "smell", in: transcript).contains("air that has stopped moving"))
        #expect(transcript.contains("Hay, brick, and mule."))
        #expect(transcript.contains("a faint sweetness off the north heading"))
        #expect(!transcript.contains("You smell nothing out of the ordinary"))
        // Listening at the Forks, thirty feet from a mule the game just narrated.
        #expect(transcript.contains("Hooves shifting, a mule breathing"))
        #expect(!transcript.contains("You hear nothing out of the ordinary"))
        // The bench the room has, found by a bare `sit`.
        #expect(turnOutput(of: "sit", in: transcript).contains("It is a good bench"))
        #expect(!transcript.contains("There is nothing here built for sitting"))
        // Two ignition sources and a room full of straw.
        #expect(transcript.contains("the single worst idea available to you down here"))
        #expect(!transcript.contains("You have no way to set fire to"))
        // A body the crawl forbids.
        #expect(occurrences(of: "the rock has strong opinions about alternatives", in: transcript) == 2)
        #expect(!transcript.contains("You're already standing"))
        // A completed, fruitless search of the only water in the workings.
        #expect(transcript.contains("There is water in it, which is the entire point of it"))
        #expect(!transcript.contains("You find nothing of interest in the canteen"))
        // Four hundred feet of shaft, and one thing worth doing at the bottom.
        #expect(transcript.contains("Men who try it are found at the bottom of it"))
    }

    /// Three default actions denied the actor standing in the room, in a game
    /// whose entire cast is one mule at your elbow for the whole running time.
    @Test func theMeShapedCommandsFindTheMuleWhoIsStandingThere() async throws {
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "pet me", "give lamp to me", "eat biscuit"])
        #expect(turnOutput(of: "pet me", in: transcript).contains("You scratch the spot under his forelock"))
        #expect(!transcript.contains("There is nothing here that would care to be petted"))
        #expect(transcript.contains("works out that it is not water"))
        #expect(!transcript.contains("There is no one here to give it to but yourself"))
        // He is a mule. The stock actor-directed stub had no way to know that.
        #expect(transcript.contains("He is a colleague, and a thin one at that."))
        #expect(!transcript.contains("is a person, and people are not for eating"))
    }

    @Test func theSameCommandsKeepTheirStockAnswersWhenHeIsGone() async throws {
        let transcript = try await play(
            KindlyDeep(), Self.toShaftBottom + ["pet me", "give lamp to me"])
        #expect(transcript.contains("There is nothing down here that would care to be petted, including you."))
        #expect(transcript.contains("There is no one here to give it to but yourself"))
    }

    // MARK: - Biscuit is a proper name, and the rails are plural

    /// The bootstrap has been printing this warning on stderr at every launch
    /// since the game shipped, naming the entity, the trait and the consequence.
    @Test func biscuitIsDeclaredAProperNameAndTheGameBootsClean() async throws {
        let (definition, _) = try Bootstrap.build(KindlyDeep())
        #expect(definition.warnings.isEmpty, "\(definition.warningReport ?? "no report")")

        let transcript = try await play(KindlyDeep(), ["light lamp", "take biscuit", "search biscuit"])
        #expect(transcript.contains("Biscuit would take exception to that."))
        #expect(!transcript.contains("The Biscuit"))
    }

    /// A mine has rails, not a rails, and the noun is not going to be renamed to
    /// suit a stub line's copula. The engine agrees with it now instead.
    @Test func theRailsArePluralAndTheStockLinesAgreeWithThem() async throws {
        let transcript = try await play(KindlyDeep(), ["light lamp", "eat rails", "break rails"])
        #expect(transcript.contains("The rails are not food."))
        #expect(transcript.contains("The rails are sturdier than that."))
        #expect(!transcript.contains("The rails is"))
    }

    // MARK: - The nouns the mine prints

    /// Per CLAUDE.md, every noun a room description prints must be answerable; a
    /// named thing the parser doesn't know reads as a bug. The round counted 286
    /// occurrences over about sixty words, and this walks the ones the rooms say
    /// are *present* — the referents (the stable boss, the trip, the cager, the
    /// dinner bucket under the rock) are correctly unanswerable and not here.
    @Test func everyNounTheMinesRoomsPrintAnswersInTheRoomThatPrintsIt() async throws {
        let transcript = try await play(
            KindlyDeep(),
            [
                "light lamp", "x entry", "x wall", "x dust", "x props", "x gauge", "x belt", "x wick",
                "west", "x entry", "x walls", "x whitewash", "x floor", "x brick", "x stall", "x trough",
                "x hooves", "x animal", "search corn bin", "take canteen", "x stopper",
                "east", "down", "x entry", "x rib", "x shelter", "x timbers", "x initials",
                "up", "east", "x entry", "x fall", "x mouth", "x frame", "x hinges", "x crawl", "x gap",
                "east", "x rock", "x stone", "x sides", "x shadow", "x crawl",
                "east", "x wall", "x crawl", "x ladderway", "x bracket", "x collar", "x chains",
            ])
        #expect(!transcript.contains("You can't see any such thing"))
        #expect(!transcript.contains("I don't know the word"))
    }

    /// `entry` is the single most-printed noun in the game — four of the six
    /// room descriptions plus the intro twice — and answered in none of them.
    /// Each stretch of it has something of its own to say.
    @Test func theEntryAnswersInEveryRoomThatNamesIt() async throws {
        let transcript = try await play(
            KindlyDeep(), ["light lamp", "x entry", "west", "x entry", "east", "down", "x entry"])
        #expect(transcript.contains("The main entry, which stops here now."))
        #expect(transcript.contains("The stable entry, running back east toward the fall."))
        #expect(transcript.contains("The entry runs past above you, back up to the north."))
    }

    /// At the Shaft Bottom two things have frames and the room says so, so `x
    /// frame` asks which. That is the right answer to an ambiguous noun, and it
    /// is worth pinning: it is not the same thing as the parser not knowing the
    /// word.
    @Test func theShaftBottomAsksWhichFrameYouMeant() async throws {
        let transcript = try await play(KindlyDeep(), Self.toShaftBottom + ["x frame"])
        let asked = turnOutput(of: "x frame", in: transcript)
        #expect(asked.contains("Which do you mean"))
        #expect(!asked.contains("I don't know the word"))
    }
}

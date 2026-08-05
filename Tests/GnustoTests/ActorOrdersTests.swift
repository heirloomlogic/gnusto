import GnustoTestSupport
import Testing

@testable import Gnusto

/// `robot, push the button` — an order somebody actually carries out.
///
/// The sentence has always parsed; what it lacked was dispatch. An actor
/// declared ``takesOrders`` gets the words after the comma parsed **where it is
/// standing** and handed to the rules with itself named as the agent. Nothing
/// else changes: a person who never opted in is still refused by the parser,
/// and the engine's own default actions — every one of them written for the
/// player — never run for somebody else.
struct ActorOrdersTests {
    // MARK: - The order arrives

    /// The addressee's own rules see the order, even though the addressee is
    /// in no object slot.
    @Test func anOrderReachesTheAddresseesOwnRules() async throws {
        let transcript = try await play(MachineRoom(), ["robot, wait"])
        #expect(transcript.contains("The robot idles, ticking."))
    }

    @Test func aRuleCanTellTheRobotFromThePlayer() async throws {
        let transcript = try await play(
            MachineRoom(), ["push the lever", "robot, push the lever"])
        #expect(
            turnOutput(of: "push the lever", in: transcript)
                .contains("The lever does not budge for you."))
        #expect(
            turnOutput(of: "robot, push the lever", in: transcript)
                .contains("The robot hauls the lever down with a servo whine."))
    }

    @Test func addressingAnOrderTakerWithAGreetingStillGreetsThem() async throws {
        let transcript = try await play(MachineRoom(), ["robot, hello"])
        #expect(!transcript.contains("does not know how"))
        #expect(!transcript.contains("no intention of taking orders"))
    }

    // MARK: - Where the words are resolved

    /// The point of the whole feature: the robot walks into the dark closet,
    /// and from the Low Room you can still name — through it — the button
    /// standing next to it. The player's own `push` of the same words can't
    /// see any such thing, which is what proves the words after the comma are
    /// read where the robot stands and not where you do.
    ///
    /// The closet is unlit, so this also pins the darkness policy: the dark is
    /// the player's problem, and an ordered actor's walk isn't gated by it —
    /// the same rule an NPC's reach has always followed.
    @Test func anOrderResolvesNounsWhereTheActorStands() async throws {
        let transcript = try await play(
            MachineRoom(),
            [
                "robot, go north",
                "push the triangular button",
                "robot, push the triangular button",
            ])
        #expect(
            turnOutput(of: "robot, go north", in: transcript)
                .contains("The robot clanks north through the doorway."))
        #expect(
            turnOutput(of: "push the triangular button", in: transcript)
                .contains("You can't see any such thing."))
        #expect(
            turnOutput(of: "robot, push the triangular button", in: transcript)
                .contains("Whirr, click."))
    }

    /// An incomplete order asks its question as an *order*: the answer
    /// completes `robot, push …`, not the player's own next move.
    @Test func anIncompleteOrderAsksItsQuestionOfTheSamePerson() async throws {
        let transcript = try await play(MachineRoom(), ["robot, push", "the lever"])
        #expect(transcript.contains("What do you want to push?"))
        #expect(
            turnOutput(of: "the lever", in: transcript)
                .contains("The robot hauls the lever down with a servo whine."))
    }

    /// An order-taker is nameable out of sight, but only in the address slot
    /// and only for an order. Everything else stays room-scoped, so
    /// `examine robot` is still honest — and so is a hello.
    @Test func theWideningReachesTheAddressSlotOnly() async throws {
        let transcript = try await play(
            MachineRoom(), ["robot, go north", "examine the robot", "robot, hello"])
        #expect(
            turnOutput(of: "examine the robot", in: transcript)
                .contains("You can't see any such thing."))
        #expect(
            turnOutput(of: "robot, hello", in: transcript)
                .contains("You can't see any such thing."))
    }

    // MARK: - What the engine will not do for you

    /// The safety property this whole design turns on: an ordered command
    /// never reaches stage 4, so no default action runs — the alternative most
    /// parsers reach for, running the command as the player, is exactly what
    /// `AddressingTests.anOrderIsDeclinedRatherThanObeyed` was written against.
    ///
    /// The order is free too, exactly like a custom verb nothing answers: the
    /// player was told nothing happened, so nothing may happen.
    @Test func theEnginesOwnDefaultsNeverRunForSomebodyElse() async throws {
        let transcript = try await play(
            // SCORE before INVENTORY: taking stock is a turn, and the point
            // here is that the order before it wasn't.
            MachineRoom(), ["robot, take the wrench", "score", "inventory"])
        #expect(!transcript.contains("Taken."))
        #expect(transcript.contains("The robot does not know how to do that."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("You are empty-handed."))
        #expect(transcript.contains("in 0 turns"))
    }

    /// An order somebody carries out is an ordinary turn.
    @Test func anObeyedOrderCostsATurn() async throws {
        let transcript = try await play(MachineRoom(), ["robot, wait", "score"])
        #expect(transcript.contains("in 1 turn"))
    }

    @Test func orderingSomebodyToTakeEverythingIsRefused() async throws {
        let transcript = try await play(MachineRoom(), ["robot, take all", "score"])
        #expect(!transcript.contains("Taken."))
        #expect(transcript.contains("in 0 turns"))
    }

    // MARK: - Opting in is what changed, and only that

    @Test func anActorThatNeverOptedInStillDeclines() async throws {
        let transcript = try await play(MachineRoom(), ["clerk, push the lever"])
        #expect(transcript.contains("The clerk has no intention of taking orders from you."))
        #expect(!transcript.contains("does not budge"))
    }

    @Test func takesOrdersOnSomethingThatIsNotAPersonWarns() async throws {
        let (definition, _) = try Bootstrap.build(OrderTakingKettle())
        #expect(
            definition.warnings.contains {
                $0.contains("kettle") && $0.contains("takesOrders")
            })
    }
}

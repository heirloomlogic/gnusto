import GnustoTestSupport
import Testing

@testable import Gnusto

/// How far away a person can be and still be *named*.
///
/// Two engine paths reach an actor who is not in the player's room, and
/// neither of them is visibility. `.follow` is the one far-sighted intent —
/// "You can't see any such thing" is the wrong answer to `follow him` on the
/// turn after he walked out. And `takesOrders` makes somebody nameable out of
/// sight, which is how you call after the robot through the doorway.
///
/// Until #332 **neither asked how far away he was**. Both sets were built from
/// every cast member standing in every reachable room, so on a map the size of
/// Dungeon `follow troll` on turn one, in an open field, answered with a
/// departure that never happened, and `master, stay` was answered at West of
/// House about a man two hundred rooms and one whole game away.
///
/// The reach is now **met, or next door**, and this suite is the pair of
/// walls: `FollowTests` and `ActorOrdersTests` pin what must still work, and
/// what is here pins what must not.
struct ActorReachTests {
    // MARK: - FOLLOW

    /// The headline. Two rooms off and never laid eyes on, so the verb has
    /// nobody to lose — and says so, rather than inventing a departure.
    @Test func followingSomebodyNeverMetFindsNobody() async throws {
        let transcript = try await play(FollowLab(), ["follow stranger"])
        let followed = turnOutput(of: "follow stranger", in: transcript)
        #expect(followed.contains("can't see any such thing"))
        #expect(!followed.contains("You have no idea which way"))
    }

    /// And the wall on the other side: having *met* somebody survives their
    /// walking any distance away. The walker starts in the hall, so one look
    /// is all the acquaintance the reach needs.
    @Test func somebodyMetIsStillNameableTwoRoomsLater() async throws {
        let transcript = try await play(FollowLab(), ["send attic marker", "follow walker"])
        let followed = turnOutput(of: "follow walker", in: transcript)
        #expect(followed.contains("You have no idea which way the walker went."))
        #expect(!followed.contains("can't see any such thing"))
    }

    /// The second term of the union, and the reason acquaintance alone will
    /// not do: the porter has never been seen, but he is one room off, and
    /// going after somebody through the door you watched them use is the
    /// ordinary case.
    @Test func somebodyNextDoorIsNameableBeforeYouHaveMetThem() async throws {
        let transcript = try await play(FollowLab(), ["follow porter"])
        #expect(!transcript.contains("can't see any such thing"))
        #expect(transcript.contains("The porter turns a corner you did not know was there."))
    }

    /// Acquaintance is not undone by walking away from it: met once, met for
    /// good. The stranger is met by walking up to the attic, and is still
    /// nameable from the hall two moves later.
    @Test func meetingSomebodyOnceIsEnoughForever() async throws {
        let transcript = try await play(
            FollowLab(), ["north", "north", "south", "south", "follow stranger"])
        let followed = turnOutput(of: "follow stranger", in: transcript)
        #expect(followed.contains("You have no idea which way the stranger went."))
        #expect(!followed.contains("can't see any such thing"))
    }

    /// **The reach narrows who can be *answered*, not who the phrase is judged
    /// against.** With the walker off the map, `person` picks out exactly one
    /// man within reach — the porter, next door — and one beyond it, the
    /// stranger upstairs. Judging over the reach alone would have made a
    /// description into a name, and named somebody never introduced. (#332)
    @Test func anAmbiguousNameIsJudgedOverEverybodyAndAnsweredFromThoseInReach() async throws {
        let transcript = try await play(FollowLab(), ["send limbo marker", "follow person"])
        let followed = turnOutput(of: "follow person", in: transcript)
        #expect(followed.contains("can't see any such thing"))
        #expect(!followed.contains("Which do you mean"))
        #expect(!followed.contains("porter"))
    }

    // MARK: - Orders

    /// The order-taking half of the same defect. The stoker is two rooms off
    /// and unmet, and `takesOrders` is not a licence to be shouted at from
    /// anywhere on the map.
    @Test func anOrderTakerNeverMetIsNotAddressable() async throws {
        let transcript = try await play(SignalRoom(), ["stoker, wait"])
        #expect(!transcript.contains("The stoker leans on his shovel."))
    }

    /// And once met, he answers from two rooms away, which is the widening
    /// the feature exists for.
    @Test func anOrderTakerYouHaveMetAnswersFromOutOfSight() async throws {
        let transcript = try await play(
            SignalRoom(), ["north", "north", "south", "south", "stoker, wait"])
        #expect(
            turnOutput(of: "stoker, wait", in: transcript)
                .contains("The stoker leans on his shovel."))
    }

    /// The reach is state, and a game can read it: ``Actor/hasBeenMet`` is the
    /// same fact the engine bounds FOLLOW with, so a game that wants a guard to
    /// recognize the player asks rather than keeping a second copy. (#332)
    @Test func aGameCanAskWhetherSomebodyHasBeenMet() async throws {
        let transcript = try await play(
            SignalRoom(), ["recall", "north", "north", "south", "south", "recall"])
        #expect(transcript.contains("Nobody comes to mind."))
        #expect(transcript.contains("You remember the stoker."))
    }

    // MARK: - A name is a person, and nothing else

    /// Symptom (c). The plaque in the control room answers to `hoist`, and the
    /// hoist has rolled next door. Resolving the address against every visible
    /// item and *then* asking whether the winner is a person meant the plaque
    /// won the match, failed the test, and silently took the whole addressing
    /// reading down with it — both passes of it.
    @Test func aSceneryNounDoesNotShadowTheAddressee() async throws {
        let transcript = try await play(
            SignalRoom(), ["hoist, go north", "hoist, wait"])
        #expect(
            turnOutput(of: "hoist, go north", in: transcript)
                .contains("The hoist rolls north along its rail."))
        #expect(
            turnOutput(of: "hoist, wait", in: transcript)
                .contains("The hoist hums where it stands."))
    }

    /// The shadowing item is still a perfectly good noun for every other verb;
    /// only the address slot stopped consulting it.
    @Test func theShadowingItemIsStillExaminable() async throws {
        let transcript = try await play(SignalRoom(), ["hoist, go north", "x plaque"])
        #expect(turnOutput(of: "x plaque", in: transcript).contains("A brass plaque reading HOIST."))
    }
}

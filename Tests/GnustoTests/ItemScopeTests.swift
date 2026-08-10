import GnustoTestSupport
import Testing

@testable import Gnusto

/// ``Item/isReachable``, ``Item/isVisible``, ``Item/isReachable(from:)`` and
/// ``Actor/possesses(_:)`` — the author-facing half of `Visibility`, exercised
/// through a live turn rather than the set functions `VisibilityTests` covers.
/// The point of them is that games stop reassembling the answer out of
/// `isHeld`, `isIn(_:)` and `holds(_:)`, so these are the cases a one-level
/// hand-rolled version gets wrong.
struct ItemScopeTests {
    /// One reporting turn, as ``ScopeLab`` prints it.
    private static func turn(_ verb: String, after commands: [String] = []) async throws -> String {
        let transcript = try await play(ScopeLab(), commands + [verb], seed: 1)
        return turnOutput(of: verb, in: transcript)
    }

    private static func probe(after commands: [String] = []) async throws -> String {
        try await turn("probe", after: commands)
    }

    private static func reach(after commands: [String] = []) async throws -> String {
        try await turn("reach", after: commands)
    }

    private static func owns(after commands: [String] = []) async throws -> String {
        try await turn("owns", after: commands)
    }

    private static func locate(after commands: [String] = []) async throws -> String {
        try await turn("locate", after: commands)
    }

    /// Every containment shape, from the lit workshop, in one turn. The rows
    /// that no hand-rolled predicate ever got right are the mug (a `surface` is
    /// not a `container`, so it is never `isOpen`) and the bead (`holds(_:)`
    /// tests one level, and the bead is two down).
    @Test(
        arguments: [
            "spanner: reachable, visible",  // held
            "tin mug: reachable, visible",  // on a surface in the room
            "bead: reachable, visible",  // two containers deep
            "walnut: out of reach, unseen",  // closed opaque container
            "pearl: out of reach, visible",  // closed transparent container
            "baton: out of reach, visible",  // in another actor's hands
            "clinker: out of reach, unseen",  // another room, and dark
            "barrow: out of reach, unseen",  // another room, and lit
            "warden: reachable, visible",  // and `Actor` forwards the pair
        ])
    func theWorkshopMatrix(row: String) async throws {
        #expect(try await Self.probe().contains(row))
    }

    /// Live state, not the declaration: opening the crate brings what it holds
    /// into both sets.
    @Test func openingAContainerBringsItsContentsWithinReach() async throws {
        #expect(try await Self.probe(after: ["open crate"]).contains("walnut: reachable, visible"))
    }

    /// In the dark the walk stops after held items, so the floor at your feet is
    /// as good as another room.
    @Test func darknessLeavesOnlyWhatYouAreCarrying() async throws {
        let output = try await Self.probe(after: ["down"])
        #expect(output.contains("spanner: reachable, visible"))
        #expect(output.contains("clinker: out of reach, unseen"))
    }

    /// ``Item/isReachable(from:)`` from the warden, standing in the same lit
    /// workshop as the player. Same walk, a different pair of hands: he gets the
    /// room to any depth and none of the player's pockets.
    @Test(
        arguments: [
            "warden reaches spanner: no",  // in the player's hands — that's stealing
            "warden reaches baton: yes",  // his own hands
            "warden reaches tin mug: yes",  // on a surface here
            "warden reaches bead: yes",  // two containers deep
            "warden reaches walnut: no",  // closed opaque container
            "warden reaches pearl: no",  // closed transparent container
            "warden reaches barrow: no",  // another room, and lit
            "warden reaches clinker: no",  // another room, and dark
            "warden reaches truncheon: no",  // in the sentry's hands, a room away
            "warden reaches the player: yes",  // standing right in front of him
            "warden reaches sentry: no",  // a room away
        ])
    func theWardensReach(row: String) async throws {
        #expect(try await Self.reach().contains(row))
    }

    /// The decision #119 recorded: darkness gates the player's eyes, not an
    /// NPC's arm. The sentry stands in the pitch-dark cellar and picks the
    /// clinker off the floor of it; the player, standing in the same dark,
    /// cannot.
    @Test func darknessDoesNotStopSomebodyElsesArm() async throws {
        #expect(try await Self.reach().contains("sentry reaches clinker: yes"))
        #expect(try await Self.probe(after: ["down"]).contains("clinker: out of reach"))
    }

    /// Live state from the other anchor too: the crate opens and the warden's
    /// reach opens with it.
    @Test func openingAContainerBringsItsContentsWithinTheWardensReach() async throws {
        #expect(try await Self.reach(after: ["open crate"]).contains("warden reaches walnut: yes"))
    }

    /// An actor who is standing in no room at all reaches what he is holding and
    /// nothing else — including the floor he was on a moment ago.
    @Test func anActorNowhereReachesOnlyHisOwnHands() async throws {
        let output = try await Self.reach(after: ["banish"])
        #expect(output.contains("sentry reaches truncheon: yes"))
        #expect(output.contains("sentry reaches clinker: no"))
        #expect(output.contains("sentry reaches barrow: no"))
    }

    /// ``Actor/possesses(_:)`` against ``Actor/holds(_:)``, which is the one
    /// level the pair disagree on: the flask is in a holster on the warden's
    /// belt, so it is his, and `holds` says no.
    @Test(
        arguments: [
            "warden owns baton: yes, holds: yes",  // straight in his hand
            "warden owns holster: yes, holds: yes",  // the bag itself
            "warden owns flask: yes, holds: no",  // one level down, and still his
            "warden owns spanner: no, holds: no",  // the player's
            "warden owns tin mug: no, holds: no",  // the room's
            "sentry owns truncheon: yes, holds: yes",  // in the dark, and still his
        ])
    func possessionWalksAllTheWayUp(row: String) async throws {
        #expect(try await Self.owns().contains(row))
    }

    /// Possession is not a scope question: an actor sent nowhere at all still
    /// owns what he was carrying, though he is standing in no room to reach
    /// from.
    @Test func possessionSurvivesGoingNowhere() async throws {
        #expect(
            try await Self.owns(after: ["banish"]).contains("sentry owns truncheon: yes"))
    }

    // MARK: - Which room it is in

    /// ``Item/location`` walks up to the room at the top of the chain, whatever
    /// the chain is made of. Every row here is a link the one-level answers
    /// stop at: the mug is on a surface, the nut is shut in a crate, the bead
    /// is two containers down, and the flask is inside a holster inside
    /// somebody else's hands.
    @Test(
        arguments: [
            "spanner: Workshop",  // in the player's own hands
            "tin mug: Workshop",  // on a surface
            "walnut: Workshop",  // shut in a crate nobody has opened
            "bead: Workshop",  // two containers down
            "baton: Workshop",  // in the warden's hands
            "flask: Workshop",  // in a holster in the warden's hands
            "warden: Workshop",  // the actor himself, one step
            "me: Workshop",  // the player's own item
        ])
    func locationWalksUpToTheRoom(row: String) async throws {
        #expect(try await Self.locate().contains(row))
    }

    /// Having a room is not the same question as being seen or touched. The
    /// clinker is in the pitch-dark cellar and the barrow in a room the player
    /// has never entered — neither is visible or reachable, and both answer
    /// with a room. The truncheon adds the case ``Player/location`` cannot
    /// stand in for: it is in the cellar because the sentry is, not because
    /// the player is anywhere near it.
    @Test(
        arguments: [
            "clinker: Cellar",
            "barrow: Yard",
            "truncheon: Cellar",
        ])
    func aRoomIsAnsweredWhereverTheItemIsUnseen(row: String) async throws {
        #expect(try await Self.locate().contains(row))
    }

    /// Nothing at the top of the chain, and the walk says so rather than
    /// guessing. Banishing the sentry takes the truncheon in his hands out of
    /// any room with him, though the item itself was never touched — which is
    /// the same walk `possessionSurvivesGoingNowhere` reads the other way.
    @Test func anItemHasNoRoomOnceItsChainRunsOffstage() async throws {
        let rows = try await Self.locate(after: ["banish"])
        #expect(rows.contains("truncheon: nowhere"))
        // The sentry's own accessor agrees, and the rest of the world has not
        // moved with him.
        #expect(rows.contains("clinker: Cellar"))
    }

    /// The held row follows the player and the room's rows do not — the
    /// distinction a `player.location` substitute cannot make.
    @Test func aHeldItemsRoomFollowsThePlayer() async throws {
        let rows = try await Self.locate(after: ["down"])
        #expect(rows.contains("spanner: Cellar"))
        #expect(rows.contains("me: Cellar"))
        #expect(rows.contains("tin mug: Workshop"))
    }
}

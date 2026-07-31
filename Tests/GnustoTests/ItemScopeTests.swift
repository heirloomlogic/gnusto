import GnustoTestSupport
import Testing

@testable import Gnusto

/// ``Item/isReachable`` and ``Item/isVisible`` — the author-facing half of
/// `Visibility`, exercised through a live turn rather than the set functions
/// `VisibilityTests` covers. The point of the pair is that games stop
/// reassembling the answer out of `isHeld`, `isIn(_:)` and `holds(_:)`, so
/// these are the cases a one-level hand-rolled version gets wrong.
struct ItemScopeTests {
    /// One `probe` turn, as ``ScopeLab`` prints it.
    private static func probe(after commands: [String] = []) async throws -> String {
        let transcript = try await play(ScopeLab(), commands + ["probe"], seed: 1)
        return turnOutput(of: "probe", in: transcript)
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
}

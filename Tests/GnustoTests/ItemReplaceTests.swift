import GnustoTestSupport
import Testing

@testable import Gnusto

/// ``Item/replace(with:)``: the swap that puts one thing exactly where another
/// was and takes the other out of play. The point of the primitive is the three
/// placements a game could not reach before it — inside a container, on a
/// surface, and offstage — so those are the cases that matter most here.
///
/// Driven by ``SalvageYardGame``, whose `survey` turn prints where everything is.
struct ItemReplaceTests {
    /// One `survey`, as ``SalvageYardGame`` prints it. Each call plays a fresh
    /// game, so the one `survey` turn is always the first occurrence.
    private static func survey(after commands: [String]) async throws -> String {
        let transcript = try await play(SalvageYardGame(), commands + ["survey"])
        return turnOutput(of: "survey", in: transcript)
    }

    // MARK: - The five placements

    @Test func aThingOnTheFloorIsReplacedOnTheFloor() async throws {
        let turn = try await Self.survey(after: ["wreck vase"])
        #expect(turn.contains("vase=gone"))
        #expect(turn.contains("shards=room"))
    }

    @Test func aThingInYourHandsIsReplacedInYourHands() async throws {
        let turn = try await Self.survey(after: ["wreck flask"])
        #expect(turn.contains("flask=gone"))
        #expect(turn.contains("dents=held"))
    }

    /// The case the two-branch `isHeld` approximation loses: a thing swapped
    /// while it sits inside a container stays inside that container.
    @Test func aThingInsideAContainerIsReplacedInsideIt() async throws {
        let turn = try await Self.survey(after: ["wreck bulb"])
        #expect(turn.contains("bulb=gone"))
        #expect(turn.contains("filament=sack"))
    }

    /// The other case it loses: a thing on a surface stays on the surface.
    @Test func aThingOnASurfaceIsReplacedOnIt() async throws {
        let turn = try await Self.survey(after: ["wreck dish"])
        #expect(turn.contains("dish=gone"))
        #expect(turn.contains("chips=bench"))
    }

    /// Replacing something that was never in play leaves the replacement out of
    /// play too — "exactly where this item is" is still an answer when the
    /// answer is nowhere.
    @Test func replacingAnOffstageThingLeavesItsReplacementOffstage() async throws {
        let turn = try await Self.survey(after: ["haunt"])
        #expect(turn.contains("ghost=gone"))
        #expect(turn.contains("echo=gone"))
        #expect(!turn.contains("faint echo"))
    }

    // MARK: - What leaves, and what it takes with it

    @Test func theReplacedThingIsOutOfPlay() async throws {
        let transcript = try await play(
            SalvageYardGame(),
            ["wreck vase", "survey", "examine vase", "take vase"])
        #expect(turnOutput(of: "survey", in: transcript).contains("vase=gone"))
        #expect(turnOutput(of: "examine vase", in: transcript).contains("can't see any such thing"))
        #expect(turnOutput(of: "take vase", in: transcript).contains("can't see any such thing"))
    }

    /// Contents are not carried over. The nail is inside the crate when the
    /// crate becomes splinters, and it goes out of play with the crate rather
    /// than following the splinters onto the floor — which is why the river's
    /// `puncture()` tips the boat's cargo out before bursting it.
    @Test func contentsLeavePlayWithTheReplacedThing() async throws {
        let before = try await Self.survey(after: [])
        #expect(before.contains("nailReachable=true"))

        let after = try await Self.survey(after: ["wreck crate"])
        #expect(after.contains("crate=gone"))
        #expect(after.contains("splinters=room"))
        #expect(after.contains("nailReachable=false"))
        #expect(!after.contains("bent nail"))
    }

    /// A worn thing's replacement is held, not worn: `replace` drops the old
    /// item from `wornItems` the way ``Item/vanish()`` does, and hands the new
    /// one the placement only — the same call ``Item/moveToPlayer()`` makes when
    /// it says a held item isn't a worn one.
    @Test func aWornThingIsReplacedHeldRatherThanWorn() async throws {
        let turn = try await Self.survey(after: ["wreck cloak"])
        #expect(turn.contains("cloak=gone"))
        #expect(turn.contains("rags=held"))
        #expect(!turn.contains("rags=worn"))
    }

    // MARK: - The edges

    /// Replacing a thing with itself must not destroy it. Without the guard the
    /// second `place` overwrites the first and the vase leaves play.
    @Test func replacingAThingWithItselfIsANoOp() async throws {
        let turn = try await Self.survey(after: ["negate"])
        #expect(turn.contains("vase=room"))
        #expect(turn.contains("glass vase"))
    }

    /// Like ``Item/vanish()`` and unlike ``Item/move(to:)``, `replace` does not
    /// carry a boarded player: the hull is gone, so there is nothing left to
    /// ride, and the player is standing in the room they were floating in.
    @Test func replacingABoardedVehicleStrandsThePassenger() async throws {
        let boarded = try await Self.survey(after: ["board raft"])
        #expect(boarded.contains("aboard=cork raft"))

        let wrecked = try await Self.survey(after: ["board raft", "wreck raft"])
        #expect(wrecked.contains("aboard=none"))
        #expect(wrecked.contains("raft=gone"))
        #expect(wrecked.contains("flotsam=room"))
    }

    /// A rule that swaps and then reads the container in the same body sees the
    /// swap immediately: `replace` goes through `place`, which invalidates the
    /// containment cache the earlier read populated. The bench's examine rule
    /// reads the sack on both sides of one `replace` to prove it.
    @Test func theSwapIsVisibleToTheRestOfTheSameTurn() async throws {
        let transcript = try await play(SalvageYardGame(), ["examine bench"])
        #expect(
            turnOutput(of: "examine bench", in: transcript)
                .contains("before=[clear bulb] after=[burnt filament]"))
    }
}

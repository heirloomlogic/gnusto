import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import Lighthouse

/// `GNUSTO_SEED` pins a built binary's random stream, so a transcript a tester
/// records by hand replays as a `play(_:_:seed:)` regression test.
///
/// The parsing is unit-tested here; that a pinned seed reaches `rngState` is
/// checked against Lighthouse, whose keeper roams through `ActorBehaviors` and
/// so takes a visibly different walk under every seed.
struct SeedRequestTests {
    // MARK: - Absent

    @Test func anAbsentVariableLeavesTheSeedUnset() {
        #expect(SeedRequest(environment: [:]) == .unset)
    }

    /// Empty means unset, matching `GNUSTO_TRANSCRIPT`'s `!value.isEmpty`
    /// guard: `GNUSTO_SEED= swift run` should behave as if it were never typed.
    @Test(arguments: ["", "  \n", "\t"])
    func aBlankValueLeavesTheSeedUnset(value: String) {
        #expect(SeedRequest(environment: ["GNUSTO_SEED": value]) == .unset)
    }

    // MARK: - Pinned

    @Test func aWholeNumberPinsTheStream() {
        #expect(SeedRequest(environment: ["GNUSTO_SEED": "7"]) == .pinned(7))
    }

    /// Zero is a seed, not an absence — Lighthouse's own walkthrough test pins
    /// `seed: 0`, so treating it as unset would silently unpin the one value
    /// most likely to be typed.
    @Test func zeroIsAPinnedSeedAndNotAnAbsentOne() {
        #expect(SeedRequest(environment: ["GNUSTO_SEED": "0"]) == .pinned(0))
    }

    @Test func theWholeUInt64RangeIsAvailable() {
        #expect(
            SeedRequest(environment: ["GNUSTO_SEED": "18446744073709551615"])
                == .pinned(UInt64.max))
    }

    /// A shell wrapper or a copied value tends to bring whitespace with it, and
    /// trimming can only ever turn a rejection into the seed the operator meant.
    @Test func surroundingWhitespaceIsTolerated() {
        #expect(SeedRequest(environment: ["GNUSTO_SEED": " 42\n"]) == .pinned(42))
    }

    // MARK: - Invalid

    /// The last of these is one past `UInt64.max`: too large is rejected the
    /// same way as not-a-number, so a seed can never silently wrap.
    @Test(arguments: [
        "banana", "-1", "1.5", "0x10", "7seven", "1_000", "١٢٣", "18446744073709551616",
    ])
    func aValueThatIsNotAWholeNumberIsRejected(value: String) {
        #expect(SeedRequest(environment: ["GNUSTO_SEED": value]) == .invalid(value))
    }

    /// The complaint quotes what was typed, not the trimmed form, so an
    /// operator who pasted a stray character can see it.
    @Test func aRejectedValueIsQuotedVerbatimInTheComplaint() throws {
        let request = SeedRequest(environment: ["GNUSTO_SEED": " 12three "])
        #expect(request == .invalid(" 12three "))
        let complaint = try #require(request.complaint)
        #expect(complaint.contains("GNUSTO_SEED= 12three "))
        #expect(complaint.contains("18446744073709551615"))
    }

    // MARK: - What `main()` reads off it

    @Test func onlyAPinnedRequestYieldsASeed() {
        #expect(SeedRequest.pinned(3).value == 3)
        #expect(SeedRequest.unset.value == nil)
        #expect(SeedRequest.invalid("banana").value == nil)
    }

    /// Silence is the wrong answer for a typo, but it is the right answer for
    /// the two cases where the operator asked for nothing or asked correctly.
    @Test func onlyAnInvalidRequestComplains() {
        #expect(SeedRequest.unset.complaint == nil)
        #expect(SeedRequest.pinned(3).complaint == nil)
        #expect(SeedRequest.invalid("banana").complaint != nil)
    }

    // MARK: - The seed reaches the stream

    /// A walk long enough for the keeper to take several roaming steps.
    private static let roam = [
        "north", "wait", "wait", "wait", "wait", "south", "wait", "wait", "look",
    ]

    private func lighthouse(pinning value: String) async throws -> String {
        let seed = try #require(SeedRequest(environment: ["GNUSTO_SEED": value]).value)
        return try await play(Lighthouse(), Self.roam, seed: seed)
    }

    /// Both halves in one test, because proving the seed *matters* needs a
    /// second seed to differ from and would otherwise replay seed 0 a third
    /// time for nothing.
    @Test func aPinnedSeedReplaysIdenticallyAndADifferentOneDoesNot() async throws {
        let zero = try await lighthouse(pinning: "0")
        #expect(zero == (try await lighthouse(pinning: "0")))
        #expect(zero != (try await lighthouse(pinning: "1")))
    }

    /// The value parsed out of the environment is the stream's state itself,
    /// not something hashed or folded on the way in — which is what makes a
    /// seed printed in a bug report mean the same thing to the next reader.
    @Test func aPinnedSeedBecomesTheStreamsState() async throws {
        let seed = try #require(SeedRequest(environment: ["GNUSTO_SEED": "12345"]).value)
        let world = try cachedWorld(Lighthouse(), seed: seed)
        #expect(await world.state.rngState == 12345)
    }
}

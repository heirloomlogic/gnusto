import GnustoTestSupport
import Testing

@testable import Gnusto

struct BurdenCycleTests {
    @Test func cyclicContentsContributeOnceEach() async throws {
        let transcript = try await play(BurdenCycleGame(), ["weigh"])
        #expect(turnOutput(of: "weigh", in: transcript).contains("The boxes weigh 18."))
    }

    @Test func burdenGatedTakeDefersToReachabilityOnCyclicContents() async throws {
        let transcript = try await play(BurdenCycleGame(), ["take outer box"])
        #expect(
            turnOutput(of: "take outer box", in: transcript)
                .contains("You can't reach the outer box."))
    }
}

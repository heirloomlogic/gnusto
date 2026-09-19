import GnustoTestSupport
import Testing

@testable import Gnusto

struct BurdenCycleTests {
    @Test func cyclicContentsContributeOnceEach() async throws {
        let transcript = try await play(BurdenCycleGame(), ["weigh"])
        #expect(turnOutput(of: "weigh", in: transcript).contains("The boxes weigh 18."))
    }

    @Test func burdenGatedTakeTerminatesOnCyclicContents() async throws {
        let transcript = try await play(BurdenCycleGame(), ["take outer box"])
        #expect(
            turnOutput(of: "take outer box", in: transcript)
                .contains("You're carrying too much already."))
    }
}

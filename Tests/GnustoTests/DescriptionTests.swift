import GnustoTestSupport
import Testing

@testable import Gnusto

struct DescriptionTests {
    @Test("empty and whitespace-only location names are fatal")
    func blankLocationNamesAreFatal() throws {
        let diagnostics = try blankProseDiagnostics(BlankLocationNameGame())

        #expect(diagnostics.contains(#"location "emptyName" declares an empty name(…) trait."#))
        #expect(diagnostics.contains(#"location "whitespaceName" declares a whitespace-only name(…) trait."#))
    }

    @Test("empty and whitespace-only static descriptions are fatal")
    func blankStaticDescriptionsAreFatal() throws {
        let diagnostics = try blankProseDiagnostics(BlankStaticProseGame())

        for expected in [
            #"location "emptyRoom" declares an empty description(…) trait."#,
            #"location "whitespaceRoom" declares a whitespace-only description(…) trait."#,
            #"location "emptyAlwaysDescribedRoom" declares an empty description(…) trait."#,
            #"item "emptyDescription" declares an empty description(…) trait."#,
            #"item "whitespaceDescription" declares a whitespace-only description(…) trait."#,
            #"item "emptyFirstSight" declares an empty firstSight(…) trait."#,
            #"actor "whitespaceFirstSight" declares a whitespace-only firstSight(…) trait."#,
            #"item "conditionalDescription" declares an empty description(when:_:otherwise:) text."#,
            #"item "conditionalDescription" declares a whitespace-only description(when:_:otherwise:) otherwise text."#,
            #"item "conditionalFirstSight" declares a whitespace-only firstSight(when:_:otherwise:) text."#,
            #"item "conditionalFirstSight" declares an empty firstSight(when:_:otherwise:) otherwise text."#,
        ] {
            #expect(diagnostics.contains(expected), "missing diagnostic: \(expected)")
        }
    }

    @Test("omitted optional prose and nonblank prose remain valid")
    func omittedAndNonblankProseRemainValid() async throws {
        _ = try Bootstrap.build(OptionalAndNonblankProseGame())
        let transcript = try await play(
            OptionalAndNonblankProseGame(), ["look", "examine plain stone", "examine described stone"])

        #expect(transcript.contains("There is a plain stone here."))
        #expect(transcript.contains("You see nothing special about the plain stone."))
        #expect(transcript.contains("A described stone lies here."))
        #expect(transcript.contains("A described stone."))
    }

    #if GNUSTO_EXIT_TESTS

    @Test("a calculated description that becomes empty traps when evaluated")
    func calculatedDescriptionThatBecomesEmptyTraps() async {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(
                BlankDescribeAfterChangeGame(), ["examine relic", "touch relic", "examine relic"])
        }
        expectTrap(result, says: #"item "relic""#, "describe { … } rule", "empty text")
    }

    @Test("a calculated presence line that becomes whitespace traps when evaluated")
    func calculatedPresenceThatBecomesWhitespaceTraps() async {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(BlankPresenceAfterChangeGame(), ["wait", "look"])
        }
        expectTrap(result, says: #"actor "sentry""#, "presence { … } rule", "whitespace-only text")
    }

    #endif
}

private func blankProseDiagnostics(_ game: some Game) throws -> [String] {
    do {
        _ = try Bootstrap.build(game)
        Issue.record("expected a BootstrapError")
        return []
    } catch let error as BootstrapError {
        return error.diagnostics
    }
}

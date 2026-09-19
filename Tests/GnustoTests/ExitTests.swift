import Testing

@testable import Gnusto

struct ExitTests {
    @Test("blocked and conditional exits reject blank refusal text")
    func blankExitRefusalsAreFatal() throws {
        let diagnostics = try exitDiagnostics(BlankExitProseGame())

        #expect(diagnostics.contains(#"location "hall" declares an empty blocked north exit message."#))
        #expect(diagnostics.contains(#"location "hall" declares a whitespace-only blocked south exit message."#))
        #expect(diagnostics.contains(#"location "hall" declares an empty conditional east exit otherwise message."#))
        #expect(
            diagnostics.contains(
                #"location "hall" declares a whitespace-only conditional west exit otherwise message."#))
    }

    @Test("nonblank blocked and conditional exit messages remain valid")
    func nonblankExitRefusalsRemainValid() throws {
        _ = try Bootstrap.build(OptionalAndNonblankProseGame())
    }
}

private func exitDiagnostics(_ game: some Game) throws -> [String] {
    do {
        _ = try Bootstrap.build(game)
        Issue.record("expected a BootstrapError")
        return []
    } catch let error as BootstrapError {
        return error.diagnostics
    }
}

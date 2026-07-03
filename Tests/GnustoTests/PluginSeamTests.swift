import Testing

@testable import Gnusto

/// The Phase-8 plugin seams: plugin-shipped timers spliced by the host,
/// `describeSurroundings()` from rule bodies, and the attack path riding
/// the ordinary intent tables with no engine involvement.
struct PluginSeamTests {
    @Test func pluginDaemonsRideTheHostsTimersBlock() async throws {
        let transcript = try await play(
            BrawlGame(),
            ["look", "xyzzy nonsense", "quit"])
        // Autostart: the pulse beats on the look turn. A parse error is not
        // a turn: no extra pulse on the nonsense line.
        #expect(turnOutput(of: "look", in: transcript).contains("[pulse]"))
        #expect(!turnOutput(of: "xyzzy nonsense", in: transcript).contains("[pulse]"))
    }

    @Test func timerNamesStayGlobalAcrossPluginAndHost() {
        #expect {
            try Bootstrap.build(ClashingTimersGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains(
                "two timers are both named \"brawl.pulse\"")
        }
    }

    @Test func attackRidesTheOrdinaryTables() async throws {
        let transcript = try await play(
            BrawlGame(),
            ["attack dummy", "attack bruiser", "quit"])
        // Plugin stage-4 default for the unclaimed target; host actor rule
        // wins for the claimed one.
        expectInOrder(
            transcript,
            [
                "Violence gets you nowhere here.",
                "The bruiser catches your fist like a thrown apple.",
            ])
    }

    @Test func describeSurroundingsSpeaksMidTurn() async throws {
        let transcript = try await play(
            BrawlGame(),
            ["slide", "slip", "quit"])
        // A lit destination gets the full LOOK treatment...
        expectInOrder(
            turnOutput(of: "slide", in: transcript),
            [
                "The floor tilts and deposits you elsewhere.",
                "Gymnasium",
                "Mats everywhere.",
            ])
        // ...and a dark one gets the pitch-black line.
        expectInOrder(
            turnOutput(of: "slip", in: transcript),
            [
                "The floor tilts and deposits you elsewhere.",
                "It is pitch black. You can't see a thing.",
            ])
    }
}

import GnustoTestSupport
import Testing

@testable import Gnusto

/// The `GnustoDangerousDark` plugin: lethal darkness as a droppable-in
/// content bundle. The Zork 1 grue transcripts in `Zork1Tests` are the
/// lift-don't-rewrite acceptance bar; these cover the knobs.
struct DangerousDarkTests {
    @Test func defaultCadenceWarnsThenKills() async throws {
        let transcript = try await play(
            NightfallGame(),
            ["north", "look", "look", "quit"])
        // The arrival turn ends in darkness: pitch black, then the warning.
        expectInOrder(
            turnOutput(of: "north", in: transcript),
            [
                "It is pitch black. You can't see a thing.",
                "The darkness is absolute, and something in it is breathing.",
            ])
        let looks = transcript.components(separatedBy: "> look")
        // One silent turn of grace, then the end.
        #expect(!looks[1].contains("breathing"))
        expectInOrder(
            looks[2],
            [
                "Something in the dark finds you before you find it.",
                "*** You have died ***",
                "Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?",
            ])
    }

    @Test func steppingIntoLightResetsTheCount() async throws {
        let transcript = try await play(
            NightfallGame(),
            ["north", "south", "north", "look", "look", "quit"])
        // Two separate descents each get their own warning; the reset means
        // death lands on the *second* dark stretch's third turn, not earlier.
        let warnings =
            transcript.components(
                separatedBy: "The darkness is absolute"
            ).count - 1
        #expect(warnings == 2)
        let looks = transcript.components(separatedBy: "> look")
        #expect(!looks[1].contains("finds you"))
        expectInOrder(looks[2], ["finds you", "*** You have died ***"])
    }

    @Test func aCarriedLitLampKeepsTheDarkHarmless() async throws {
        let transcript = try await play(
            NightfallGame(),
            ["take lamp", "north", "look", "look", "look", "look", "south", "quit"])
        #expect(!transcript.contains("breathing"))
        #expect(!transcript.contains("*** You have died ***"))
    }

    @Test func theGrueRollsTheDice() async throws {
        // Lethality 40, no grace: after the warning the grue rolls every dark
        // turn. Under this pinned seed the player survives at least one roll
        // before it lands — proof the schedule is a dice roll, not a clock.
        let transcript = try await play(
            FickleDarkGame(),
            ["north", "look", "look", "look", "look", "look", "look", "quit"],
            seed: 7)
        // The warning still fires on the first dark turn (the kept guard).
        #expect(transcript.contains("something in it is breathing"))
        // At least one dice turn is survived before death: the first `look`
        // (dark turn 2, the first roll) does not kill.
        let looks = transcript.components(separatedBy: "> look")
        #expect(!looks[1].contains("finds you"))
        // But the grue does get you in the end.
        #expect(transcript.contains("Something in the dark finds you"))
        #expect(transcript.contains("*** You have died ***"))
    }

    @Test func graceTurnsIsAKnob() async throws {
        let transcript = try await play(
            PatientDarkGame(),
            ["north", "look", "look", "look", "look", "quit"])
        // graceTurns 3: warn on dark turn 1, silence on 2-4, death on 5.
        expectInOrder(turnOutput(of: "north", in: transcript), ["W."])
        let looks = transcript.components(separatedBy: "> look")
        #expect(!looks[1].contains("W."))
        #expect(!looks[2].contains("D."))
        #expect(!looks[3].contains("D."))
        expectInOrder(looks[4], ["D.", "*** You have died ***"])
    }

    @Test func suspendingTheDarkSilencesIt() async throws {
        // Straight into the warded room and stay there. The Shrine is as dark
        // as the Cave — `dark` is declared on both — so anything that speaks
        // here is the grue speaking through a shut gate.
        let transcript = try await play(
            WardedDarkGame(),
            ["east", "look", "look", "look", "look", "look", "quit"])
        #expect(transcript.contains("It is pitch black."))
        #expect(!transcript.contains("something in it is breathing"))
        #expect(!transcript.contains("*** You have died ***"))
    }

    @Test func resumingAfterASuspensionStillWarnsFirst() async throws {
        // The regression. Take the warning in the Cave, cross into the Shrine
        // for three turns, then come back to the dark that bites.
        //
        // A suspension that merely *froze* the counter would leave it at 1, so
        // the returning turn would be dark turn 2 — a dice turn at lethality
        // 100 — and the player would die without a second warning. The count
        // resets while the gate is shut, so the warning turn is a guarantee
        // across a suspension, which is what the plugin's own doc promises.
        let transcript = try await play(
            WardedDarkGame(),
            ["north", "north", "look", "look", "south", "quit"])
        expectInOrder(
            turnOutput(of: "north", in: transcript),
            ["It is pitch black.", "something in it is breathing"])
        // Back in the Cave, and it is dark turn 1 again: the warning, not the
        // dice.
        let back = turnOutput(of: "south", in: transcript)
        #expect(back.contains("something in it is breathing"))
        #expect(!back.contains("finds you before you find it"))
        #expect(!transcript.contains("*** You have died ***"))
        // Exactly two warnings, so the three Shrine turns in between said
        // nothing: two dark stretches, each of which began at the beginning.
        let warnings =
            transcript.components(
                separatedBy: "something in it is breathing"
            ).count - 1
        #expect(warnings == 2)
    }

    @Test func aSuspendedCountStartsCleanFromTheLight() async throws {
        // Suspended, then released in the *light*: nothing was counting and
        // nothing resumes. The next descent is an ordinary first dark turn.
        let transcript = try await play(
            WardedDarkGame(),
            ["east", "look", "west", "look", "north", "quit"])
        #expect(!turnOutput(of: "west", in: transcript).contains("breathing"))
        expectInOrder(
            turnOutput(of: "north", in: transcript),
            ["It is pitch black.", "something in it is breathing"])
        #expect(!transcript.contains("*** You have died ***"))
    }
}

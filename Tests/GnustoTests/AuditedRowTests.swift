import GnustoTestSupport
import Testing

@testable import Gnusto

/// The rows the 2026-09 parser audit found missing (#445, "Missing rows"): eight
/// sentences an Infocom-era player types that the standard table had no pattern
/// for, and the two default actions that answered the wrong question.
///
/// One test per bullet, each opening with the sentence the audit typed and the
/// answer it got.
struct AuditedRowTests {
    // MARK: - look under / behind / through

    /// `look under X` was "I didn't understand that sentence." All three are
    /// stubs now, so a game answers the rug with a rule and everything else
    /// gets a sentence.
    @Test func lookingUnderBehindAndThroughAreAnswered() async throws {
        let transcript = try await play(
            AuditLab(),
            ["look under rug", "look behind bench", "look through sack", "peer through sack"])
        #expect(
            turnOutput(of: "look under rug", in: transcript)
                .contains("You find nothing under the woven rug."))
        #expect(
            turnOutput(of: "look behind bench", in: transcript)
                .contains("You find nothing behind the long bench."))
        #expect(
            turnOutput(of: "look through sack", in: transcript)
                .contains("You can't see anything through the canvas sack."))
        #expect(
            turnOutput(of: "peer through sack", in: transcript)
                .contains("You can't see anything through the canvas sack."))
        #expect(!transcript.contains("I didn't understand"))
    }

    /// `underneath` is a spelling of `under`, the way `into` is one of `in`.
    @Test func lookingUnderneathIsLookingUnder() async throws {
        let turn = turnOutput(
            of: "look underneath rug", in: try await play(AuditLab(), ["look underneath rug"]))
        #expect(turn.contains("You find nothing under the woven rug."))
    }

    // MARK: - sit in / stand on / lie on

    /// Three postures the stub table knew the bare form of and not the form
    /// with something to do it on.
    @Test func sittingInStandingOnAndLyingOnAreAnswered() async throws {
        let transcript = try await play(
            AuditLab(),
            ["sit in sack", "stand on bench", "lie on bench", "lie down on bench"])
        #expect(
            turnOutput(of: "sit in sack", in: transcript)
                .contains("There's nothing comfortable to sit on."))
        #expect(
            turnOutput(of: "stand on bench", in: transcript)
                .contains("You can't stand on the long bench."))
        #expect(
            turnOutput(of: "lie on bench", in: transcript)
                .contains("You can't lie down on the long bench."))
        #expect(
            turnOutput(of: "lie down on bench", in: transcript)
                .contains("You can't lie down on the long bench."))
        #expect(!transcript.contains("I didn't understand"))
    }

    /// The bare halves keep their own sentences, which is what
    /// `naming(orBare:)` is for: `stand` is not a failed `stand on`.
    @Test func theBarePosturesKeepTheirOwnSentences() async throws {
        let transcript = try await play(AuditLab(), ["stand", "stand up", "lie", "lie down"])
        #expect(turnOutput(of: "stand", in: transcript).contains("You're already standing."))
        #expect(turnOutput(of: "stand up", in: transcript).contains("You're already standing."))
        #expect(turnOutput(of: "lie", in: transcript).contains("The floor doesn't look inviting."))
        #expect(
            turnOutput(of: "lie down", in: transcript)
                .contains("The floor doesn't look inviting."))
    }

    // MARK: - climb up / climb down

    /// `climb up` asked "What do you want to climb up?" and meant nothing by
    /// it. It is a walk.
    @Test func climbingUpAndDownWalksTheExit() async throws {
        let transcript = try await play(AuditLab(), ["climb up", "climb down"])
        #expect(turnOutput(of: "climb up", in: transcript).contains("Gallery"))
        #expect(turnOutput(of: "climb down", in: transcript).contains("Hall"))
        #expect(!transcript.contains("What do you want to climb"))
    }

    /// **The row that makes it work must not eat the bare verb.** A direction
    /// slot with nothing to fill it is the weakest kind of match, so `climb`
    /// alone still reaches the stub verb three shipped games have voiced for
    /// themselves — and `climb <object>` still reaches it too.
    @Test func bareClimbStillReachesTheStubVerb() async throws {
        let transcript = try await play(AuditLab(), ["climb", "climb bench"])
        #expect(turnOutput(of: "climb", in: transcript).contains("You can't climb that."))
        #expect(turnOutput(of: "climb bench", in: transcript).contains("You can't climb that."))
        #expect(!transcript.contains("Which way?"))
    }

    /// And bare `go` still asks, which is the branch the deferral had to keep.
    @Test func bareGoStillAsksWhichWay() async throws {
        let turn = turnOutput(of: "go", in: try await play(AuditLab(), ["go"]))
        #expect(turn.contains("Which way?"))
    }

    // MARK: - leave, insert, kick

    /// Three words the parser did not know. `lift` is deliberately not among
    /// them — see the PR.
    @Test func leaveInsertAndKickAreWords() async throws {
        let transcript = try await play(
            AuditLab(), ["insert coin in sack", "kick bench", "leave"])
        #expect(
            turnOutput(of: "insert coin in sack", in: transcript)
                .contains("You put the gold coin in the canvas sack."))
        #expect(
            turnOutput(of: "kick bench", in: transcript)
                .contains("Attacking the long bench rarely improves matters."))
        #expect(turnOutput(of: "leave", in: transcript).contains("Yard"))
        #expect(!transcript.contains("I don't know the word"))
    }

    // MARK: - put X on

    /// `put cloak on` asked "What do you want to put the velvet cloak on?" and
    /// there was no answer that would have worked. It is WEAR.
    @Test func putSomethingOnWithNothingAfterItIsWear() async throws {
        let transcript = try await play(AuditLab(), ["put cloak on"])
        #expect(transcript.contains("You put on the velvet cloak."))
    }

    /// **And the surface reading has to keep winning.** `put X on Y` carries a
    /// second object slot and so outscores the new row; only the sentence with
    /// nothing after the particle reaches WEAR.
    @Test func putSomethingOnSomethingIsStillTheSurface() async throws {
        let transcript = try await play(AuditLab(), ["put coin on bench"])
        #expect(
            turnOutput(of: "put coin on bench", in: transcript)
                .contains("You put the gold coin on the long bench."))
    }

    // MARK: - give

    /// `give warden coin` was "I didn't understand that sentence." Two noun
    /// phrases with no preposition between them is the one shape the table had
    /// no way to spell.
    @Test func givingTheRecipientFirstIsUnderstood() async throws {
        let transcript = try await play(AuditLab(), ["give warden coin", "hand warden coin"])
        let expected = "The night warden doesn't want the gold coin."
        #expect(turnOutput(of: "give warden coin", in: transcript).contains(expected))
        #expect(turnOutput(of: "hand warden coin", in: transcript).contains(expected))
        #expect(!transcript.contains("I didn't understand"))
    }

    /// The gift half goes through the direct slot's own resolver, so a list
    /// there is read as a list — and answered in the words the TO spelling
    /// answers it in, rather than as a sentence nobody recognizes.
    @Test func aListOfGiftsReadsTheSameInBothSpellings() async throws {
        let transcript = try await play(
            AuditLab(), ["give warden coin and cloak", "give coin and cloak to warden"])
        let expected = "You can't use multiple objects with"
        #expect(turnOutput(of: "give warden coin and cloak", in: transcript).contains(expected))
        #expect(turnOutput(of: "give coin and cloak to warden", in: transcript).contains(expected))
    }

    /// The TO row is more specific and still wins — including the question an
    /// incomplete GIVE asks, which the recipient-first row must not answer.
    @Test func theToSpellingAndItsQuestionAreUnchanged() async throws {
        let transcript = try await play(AuditLab(), ["give coin to warden", "give coin"])
        #expect(
            turnOutput(of: "give coin to warden", in: transcript)
                .contains("The night warden doesn't want the gold coin."))
        #expect(
            turnOutput(of: "give coin", in: transcript)
                .contains("What do you want to give the gold coin to?"))
    }

    /// `give coin to bench` reported a refusal the furniture is in no position
    /// to make.
    @Test func givingSomethingToAThingIsRefusedRatherThanDeclined() async throws {
        let turn = turnOutput(
            of: "give coin to bench", in: try await play(AuditLab(), ["give coin to bench"]))
        #expect(turn.contains("You can't give the gold coin to the long bench."))
        #expect(!turn.contains("doesn't want"))
    }

    // MARK: - exit on foot

    /// `exit` on foot said "You aren't in anything." to somebody standing in a
    /// doorway. It is a walk OUT.
    @Test func exitOnFootWalksTheOutExit() async throws {
        let transcript = try await play(AuditLab(), ["exit"])
        #expect(transcript.contains("Yard"))
    }

    /// Where there is no `out`, the old line stays: borrowing GO's would name a
    /// direction the player never typed. ``StubLab`` is the one-room fixture.
    @Test func exitOnFootWithNoWayOutKeepsItsOldLine() async throws {
        let turn = turnOutput(of: "exit", in: try await play(StubLab(), ["exit"]))
        #expect(turn.contains("You aren't in anything."))
    }

    /// Naming something while on foot still says which thing you aren't in.
    @Test func exitingSomethingNamedWhileOnFootNamesIt() async throws {
        let turn = turnOutput(
            of: "exit sack", in: try await play(AuditLab(), ["exit sack"]))
        #expect(turn.contains("You aren't in the canvas sack."))
    }

    // MARK: - find / look for a person

    /// `find warden` with the warden right there answered the question SEARCH
    /// asks, which is a different question.
    @Test func findingSomebodyPresentSaysSo() async throws {
        let transcript = try await play(
            AuditLab(), ["find warden", "look for warden", "search for warden"])
        let expected = "The night warden is right here."
        #expect(turnOutput(of: "find warden", in: transcript).contains(expected))
        #expect(turnOutput(of: "look for warden", in: transcript).contains(expected))
        #expect(turnOutput(of: "search for warden", in: transcript).contains(expected))
    }

    /// And SEARCH keeps its own answer: frisking somebody is still refused.
    @Test func searchingSomebodyIsStillRefused() async throws {
        let transcript = try await play(AuditLab(), ["search warden", "look in warden"])
        let expected = "The night warden would have something to say about that."
        #expect(turnOutput(of: "search warden", in: transcript).contains(expected))
        #expect(turnOutput(of: "look in warden", in: transcript).contains(expected))
    }

    /// FIND on a thing is unchanged — it is still LOOK IN, which is what the
    /// row's own comment promises.
    @Test func findingAThingStillSearchesIt() async throws {
        let turn = turnOutput(of: "find sack", in: try await play(AuditLab(), ["find sack"]))
        #expect(turn.contains("The canvas sack is empty."))
    }
}

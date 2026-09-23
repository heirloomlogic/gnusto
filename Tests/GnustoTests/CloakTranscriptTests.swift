import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import CloakOfDarkness

/// End-to-end playthroughs of the canonical Cloak of Darkness paths.
struct CloakTranscriptTests {
    @Test func winningPath() async throws {
        let transcript = try await play(
            OperaHouse(),
            ["south", "north", "west", "hang cloak on hook", "east", "south", "read message"])

        expectInOrder(
            transcript,
            [
                "Hurrying through the rainswept November night",
                "Foyer of the Opera House",
                "It is pitch black. You can't see a thing.",
                "Foyer of the Opera House",
                "Cloakroom",
                "A small brass hook is on the wall.",
                "(first taking off the velvet cloak)",
                "You put the velvet cloak on the small brass hook.",
                "Foyer of the Opera House",
                "Foyer Bar",
                "message scrawled in the sawdust",
                "The message, neatly marked in the sawdust, reads...",
                "You win.",
                "Your score is 2 of a possible 2",
            ])
    }

    @Test func alternateWinViaDrop() async throws {
        let transcript = try await play(
            OperaHouse(),
            ["west", "drop cloak", "east", "south", "read message"])
        expectInOrder(
            transcript,
            [
                "Cloakroom",
                "Dropped.",
                "Foyer Bar",
                "You win.",
                "Your score is 2 of a possible 2",
            ])
    }

    @Test func losingPath() async throws {
        let transcript = try await play(
            OperaHouse(),
            [
                "south", "east", "north",
                "west", "hang cloak on hook", "east",
                "south", "read message",
            ])

        expectInOrder(
            transcript,
            [
                "It is pitch black.",
                "Blundering around in the dark isn't a good idea!",
                "Foyer of the Opera House",
                "You put the velvet cloak on the small brass hook.",
                "Foyer Bar",
                "The message has been carelessly trampled",
                "You lose.",
                "Your score is 1 of a possible 2",
            ])
        #expect(!transcript.contains("You win."))
    }

    @Test func nonMovementBlundersAlsoDisturb() async throws {
        let transcript = try await play(
            OperaHouse(),
            [
                "south", "i", "i", "north",
                "west", "hang cloak on hook", "east",
                "south", "read message",
            ])
        let blunders = transcript.components(
            separatedBy: "In the dark? You could easily disturb something!")
        #expect(blunders.count == 3)  // two refusals
        #expect(transcript.contains("You lose."))
    }

    @Test func cloakCannotBeLeftOutsideTheCloakroom() async throws {
        let transcript = try await play(OperaHouse(), ["drop cloak", "i"])
        expectInOrder(
            transcript,
            [
                "This isn't the best place to leave a smart cloak lying around.",
                "a velvet cloak (being worn)",
            ])
    }

    @Test func barStaysDarkUntilCloakIsHungAndDarkensAgainWhenTaken() async throws {
        let transcript = try await play(
            OperaHouse(),
            [
                "west", "drop cloak", "take cloak", "drop cloak",
                "east", "south",
            ])
        // take after drop re-darkens the bar; the second drop lights it again,
        // so the final visit to the bar shows its description.
        expectInOrder(
            transcript,
            ["Dropped.", "Taken.", "Dropped.", "Foyer Bar", "much rougher than you'd have guessed"])
    }

    @Test func examineHookReflectsTheCloak() async throws {
        let transcript = try await play(
            OperaHouse(),
            ["west", "x hook", "hang cloak on hook", "x hook"])
        expectInOrder(
            transcript,
            [
                "It's just a small brass hook, screwed to the wall.",
                "It's just a small brass hook, with a cloak hanging on it.",
            ])
    }

    /// Every noun the foyer's description prints must answer an `x` — the
    /// defect class #407 was filed for. The bar's `opulence` is deliberately
    /// left unanswerable: it is an abstract, and the coverage queue's stop
    /// list exists so no tester ever spends a turn on it.
    @Test func theFoyerAnswersEveryNounItPrints() async throws {
        let transcript = try await play(
            OperaHouse(),
            [
                "x hall", "x street", "x chandeliers", "x gold", "x red", "x doorways",
                "west", "x hooks", "x peg",
            ])
        #expect(!transcript.contains("You can't see any such thing."))
        expectInOrder(
            transcript,
            [
                "glittering chandeliers",
                "splendidly decorated",
                "doorways south and west",
                "just a small brass hook",
            ])
    }

    /// The cloakroom and the lit bar, held to the foyer's rule (#616). The bar
    /// is asked only once the cloak is hung, because in the dark nothing in
    /// the bar is in scope.
    @Test func theCloakroomAndTheBarAnswerEveryNounTheyPrint() async throws {
        let transcript = try await play(
            OperaHouse(),
            [
                "west", "x walls", "x wall", "x room", "x holes", "x door", "x exit",
                "search walls", "search door",
                "hang cloak on hook", "east", "south", "x bar", "search bar",
            ])
        expectEveryNounAnswered(transcript)
        #expect(turnOutput(of: "x walls", in: transcript).contains("Only one hook remains."))
        #expect(turnOutput(of: "x exit", in: transcript).contains("the only way out"))
        #expect(turnOutput(of: "x bar", in: transcript).contains("completely empty"))
    }

    /// The rooms' own nouns name the rooms, so LEAVE and EXIT with one of them
    /// walk out to the foyer rather than answering "You aren't in the walls."
    /// The walls are plural, and in the dark `x bar` finds nothing.
    @Test func leavingARoomByItsOwnNounWalksOut() async throws {
        let transcript = try await play(
            OperaHouse(),
            [
                "south", "x bar", "north",
                "west", "break walls", "leave cloakroom", "west", "go through door",
                "west", "hang cloak on hook", "east", "south", "leave bar",
            ])
        #expect(!transcript.contains("You aren't in"))
        #expect(turnOutput(of: "x bar", in: transcript).contains("You can't see any such thing."))
        #expect(turnOutput(of: "break walls", in: transcript).contains("The walls are sturdier"))
        for command in ["leave cloakroom", "go through door", "leave bar"] {
            #expect(turnOutput(of: command, in: transcript).contains("Foyer of the Opera House"), "\(command)")
        }
    }

    @Test func quitReportsTheScore() async throws {
        let transcript = try await play(OperaHouse(), ["quit"])
        #expect(transcript.contains("Your score is 0 of a possible 2, in 0 turns."))
    }
}

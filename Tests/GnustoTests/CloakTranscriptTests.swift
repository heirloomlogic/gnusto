import CloakOfDarkness
import Foundation
import Gnusto
import Testing

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

    @Test func quitReportsTheScore() async throws {
        let transcript = try await play(OperaHouse(), ["quit"])
        #expect(transcript.contains("Your score is 0 of a possible 2, in 0 turns."))
    }
}

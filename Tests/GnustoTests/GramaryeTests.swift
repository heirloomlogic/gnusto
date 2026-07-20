import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Gramarye

/// End-to-end play of the spellcasting demo: the win path threads all four
/// casting paradigms — cantrip (glow), memorized (unbar), scroll (passwall),
/// and energy (firebolt) — and the surrounding tests pin each paradigm's
/// refusal and consumption behavior in the real game.
struct GramaryeTests {
    @Test func theFullWalkthroughRecoversTheAmulet() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook",
                "cast glow",  // cantrip reveals the hidden scroll
                "take passwall scroll",
                "memorize unbar",  // prepared, needs the spellbook in hand
                "cast unbar",  // opens the warded door
                "west",
                "cast passwall",  // scroll opens the granite wall
                "north",
                "cast firebolt at golem",  // energy destroys the guardian
                "take amulet",
            ])

        expectInOrder(
            transcript,
            [
                "in the niche it finds a rolled parchment",
                "You fix the unbar spell in your memory.",
                "the door drifts open",
                "The Long Gallery",
                "the granite before you turns to a soft grey mist",
                "The Undercroft",
                "it slumps to rubble, and behind it the amulet gleams",
                "You lift the master's amulet",
                "Your score is 10 of a possible 10",
            ])
    }

    @Test func glowIsAnAtWillCantripThatFindsNothingOnceTheNicheIsEmpty() async throws {
        let transcript = try await play(Gramarye(), ["cast glow", "cast glow"])
        expectInOrder(
            transcript,
            [
                "in the niche it finds a rolled parchment",
                "there is nothing hidden here to find",  // free to recast, but nothing left
            ])
    }

    @Test func castingUnbarBeforeMemorizingItIsRefused() async throws {
        let transcript = try await play(Gramarye(), ["cast unbar"])
        #expect(transcript.contains("You don't have the unbar spell prepared."))
    }

    @Test func memorizingUnbarNeedsTheSpellbookInHand() async throws {
        // The spellbook starts in the room, not held.
        let transcript = try await play(Gramarye(), ["memorize unbar", "take spellbook", "memorize unbar"])
        expectInOrder(
            transcript,
            [
                "You need your spellbook in hand to memorize unbar.",
                "You fix the unbar spell in your memory.",
            ])
    }

    @Test func fireboltWashesOffAnIncombustibleTarget() async throws {
        let transcript = try await play(Gramarye(), ["take spellbook", "cast firebolt at spellbook"])
        #expect(transcript.contains("The firebolt washes over the spellbook and leaves it untouched."))
    }

    @Test func theWardedDoorResistsAnOrdinaryOpen() async throws {
        let transcript = try await play(Gramarye(), ["open warded door"])
        #expect(transcript.contains("The warding-marks hold the door fast"))
    }
}

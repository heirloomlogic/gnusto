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
        // The door starts open with its wards dormant; it only resists an
        // ordinary hand once the draught has sealed it a couple of turns in.
        let transcript = try await play(
            Gramarye(), ["examine window", "examine niche", "open warded door"])
        #expect(transcript.contains("The warding-marks hold the door fast"))
    }

    // MARK: - Clueing and dynamic descriptions

    @Test func theSpellbookOffersOneAccidentPerObstacle() async throws {
        // Each read serves the current obstacle: the apprentice looks for
        // what he thinks he needs and stumbles on what the player needs.
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook",
                "examine niche",  // let the draught seal the door first
                "read spellbook",  // doors? no — a nightlight
                "cast glow", "take scroll",
                "read spellbook",  // doors again — unbar, with small print
                "memorize unbar", "cast unbar", "west",
                "read spellbook",  // walls — nothing but a receipt
                "cast passwall", "north",
                "read spellbook",  // golems — pottery
                "cast firebolt at golem",
                "read spellbook",  // nothing left
                "take amulet",
            ])
        expectInOrder(
            transcript,
            [
                "a cantrip called glow",
                "unbar, the unbinding",
                "one parchment, best quality",
                "a spell related to pottery",
                "nothing to teach you",
            ])
    }

    @Test func theSpellbookNeverReadsAhead() async throws {
        // Once the door has sealed, the first read gives away only the
        // finding-light — nothing about the spells further down the chain.
        let transcript = try await play(
            Gramarye(), ["examine window", "examine niche", "read spellbook"])
        #expect(transcript.contains("a cantrip called glow"))
        #expect(!transcript.contains("unbar"))
        #expect(!transcript.contains("firebolt"))
        #expect(!transcript.contains("pottery"))
    }

    @Test func theNicheKeepsItsSecretUntilGlow() async throws {
        let transcript = try await play(
            Gramarye(),
            ["examine niche", "cast glow", "examine niche", "take scroll", "examine niche"])
        expectInOrder(
            transcript,
            [
                "no unaided eye will find it",
                "in the niche it finds a rolled parchment",
                "a rolled parchment rests in the niche",
                "What it kept, you carry now",
            ])
    }

    @Test func theDoorAndStudyShowTheUnbarringWhenItIsDone() async throws {
        let transcript = try await play(
            Gramarye(),
            ["take spellbook", "memorize unbar", "cast unbar", "examine door", "look"])
        expectInOrder(
            transcript,
            [
                "the door drifts open",
                "The warding-marks are dark and dead.",
                "stands open, its warding-marks dark",
            ])
    }

    @Test func theGalleryShowsTheMistArchAfterPasswall() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook", "cast glow", "take scroll",
                "memorize unbar", "cast unbar", "west",
                "cast passwall", "look",
            ])
        expectInOrder(
            transcript,
            [
                "the passage is stopped by a blank wall of dressed granite",
                "an archway of grey mist breathes cellar-cold air",
            ])
        // Both gallery states point the way home correctly.
        #expect(transcript.contains("The way east runs back to the study"))
    }

    @Test func failedOpensPointTowardTheMagic() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "examine window", "examine niche",  // let the door seal first
                "open door",
                "take spellbook", "memorize unbar", "cast unbar", "west",
                "open wall",
            ])
        expectInOrder(
            transcript,
            [
                "the master's book would know the word",
                "stone keeps other laws than doors do",
            ])
    }

    @Test func spellIsFillerInACastingCommand() async throws {
        // The spellcasting layer adds "spell" to the noise words, so natural
        // phrasings parse the same as the bare verbs.
        let transcript = try await play(
            Gramarye(),
            ["cast the glow spell", "take spellbook", "memorize the unbar spell"])
        expectInOrder(
            transcript,
            [
                "in the niche it finds a rolled parchment",
                "You fix the unbar spell in your memory.",
            ])
    }

    @Test func passwallAwayFromTheWallRefusesAndKeepsTheScroll() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook", "cast glow", "take scroll",
                "cast passwall",  // in the study: no stone here — scroll kept
                "memorize unbar", "cast unbar", "west",
                "cast passwall",  // the kept scroll still works at the wall
            ])
        expectInOrder(
            transcript,
            [
                "the working wants a wall of stone before you, and there is none here",
                "the granite before you turns to a soft grey mist",
            ])
    }

    @Test func glowFindsNothingOutsideTheStudy() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook", "memorize unbar", "cast unbar", "west",
                "cast glow",  // the scroll hides in the study, not here
                "east", "examine niche",
            ])
        expectInOrder(
            transcript,
            [
                "there is nothing hidden here to find",
                "no unaided eye will find it",  // still unrevealed back home
            ])
    }

    // MARK: - The new premise: a door that seals itself

    @Test func theDoorSealsItselfAFewTurnsIn() async throws {
        // The door starts open and dormant; a draught seals it a couple of
        // turns in, and that slam is the moment the puzzle actually begins.
        let transcript = try await play(
            Gramarye(), ["examine window", "examine niche", "look"])
        #expect(transcript.contains("meets its frame with a boom"))
        // Before the slam the study shows the open, dormant door; after it,
        // the shut one.
        expectInOrder(
            transcript,
            [
                "stands open, its warding-marks dark",  // opening look
                "meets its frame with a boom",  // the seal
                "stands shut in the west wall",  // the look after
            ])
    }

    @Test func theSpellbookHasNothingToSayBeforeTheSeal() async throws {
        // Read before the draught catches the door and the book agrees that
        // nothing is wrong — no spell clue is handed out yet.
        let transcript = try await play(Gramarye(), ["take spellbook", "read spellbook"])
        #expect(transcript.contains("Nothing is currently wrong"))
        #expect(!transcript.contains("a cantrip called glow"))
    }

    @Test func mindingTheTowerMeansNotLeavingIt() async throws {
        // The apprentice was left to mind the tower; the road is refused.
        let transcript = try await play(Gramarye(), ["out", "down"])
        #expect(transcript.contains("A tower cannot be minded from the road"))
    }

    @Test func theStudyWindowIsTheQuietCulprit() async throws {
        // Hiding in plain sight for replayers: the open window whose draught
        // does the sealing.
        let transcript = try await play(Gramarye(), ["examine window"])
        #expect(transcript.contains("the least suspicious thing in the tower"))
    }

    @Test func theMasterReturnsAndLaughsWhenTheAmuletIsTaken() async throws {
        // The win is a scene: the master steps through his own dispersed wall,
        // names the window as the culprit, and — to your relief — laughs.
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook",
                "cast glow", "take passwall scroll",
                "memorize unbar", "cast unbar", "west",
                "cast passwall", "north",
                "cast firebolt at golem", "take amulet",
            ])
        expectInOrder(
            transcript,
            [
                "You lift the master's amulet",
                "\"The window,\" he says",
                "he begins — quite helplessly — to laugh",
                "Your score is 10 of a possible 10",
            ])
    }
}

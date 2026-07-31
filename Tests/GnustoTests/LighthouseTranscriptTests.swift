import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Lighthouse

/// End-to-end playthroughs of *The Lighthouse*, the feature-tour example. Each
/// test drives one idiom the game exists to demonstrate — the full winning
/// route, then the locked door, the container, the dark lamp room, the
/// cross-bundle fuel gate, the lamp fuse, the tide daemon, the keeper (actor +
/// custom verb + `@Global`), and save/restore.
struct LighthouseTranscriptTests {
    /// The whole game, start to scored win: key off the shelf, through the
    /// locked door, oil and lamp from the chest, up the dark stairs, beacon
    /// relit. Seeded so the keeper's roaming is reproducible.
    @Test func winningPath() async throws {
        let transcript = try await play(
            Lighthouse(),
            [
                "north", "take key", "unlock door with key", "open door", "east",
                "open chest", "take lamp", "take can", "light lamp", "west", "up",
                "light beacon",
            ],
            seed: 0)

        expectInOrder(
            transcript,
            [
                "The keeper's boat brought you out",
                "The Lighthouse",
                "The tide is low, the boards dry underfoot.",
                "Base of the Lighthouse",
                "A brass key lies on the stone shelf.",
                "Unlocked.",
                "Opened.",
                "Storeroom",
                "Opening the heavy chest reveals an oil can and an oil lamp.",
                "The oil lamp is now on.",
                "Lamp Room",
                "beacon roars alight",
                "Your score is 25 of a possible 25",
            ])
    }

    /// Doors and locks: the storeroom door refuses to open, and reads as closed
    /// on a walk-through, until the brass key unlocks it.
    @Test func lockedDoorRefusesUntilUnlocked() async throws {
        let transcript = try await play(
            Lighthouse(),
            [
                "north", "open door", "east", "take key",
                "unlock door with key", "open door", "east",
            ])

        expectInOrder(
            transcript,
            [
                "> open door", "The storeroom door is locked.",
                "> east", "The storeroom door is closed.",
                "> unlock door with key", "Unlocked.",
                "> open door", "Opened.",
                "Storeroom",
            ])
    }

    /// Containers: the chest starts closed (its contents unreachable) and opening
    /// it reveals and yields the lamp and the oil.
    @Test func chestStartsClosedThenYieldsContents() async throws {
        let transcript = try await play(
            Lighthouse(),
            [
                "north", "take key", "unlock door with key", "open door", "east",
                "look in chest", "open chest", "take lamp", "take can",
            ])

        expectInOrder(
            transcript,
            [
                "The heavy chest is closed.",
                "Opening the heavy chest reveals an oil can and an oil lamp.",
                "Taken.",
                "Taken.",
            ])
    }

    /// Darkness: the Lamp Room has no light of its own — the beacon in it is out
    /// — so climbing the stairs without a lit lamp reaches the room and sees
    /// nothing. This is what makes the portable light load-bearing rather than
    /// scenery, per the game's mechanics contract.
    @Test func theLampRoomIsDarkWithoutTheLamp() async throws {
        let transcript = try await play(Lighthouse(), ["north", "up"])

        expectInOrder(transcript, ["> up", "It is pitch black. You can't see a thing."])
    }

    /// The cross-bundle seam: the beacon belongs to the `Tower` bundle, the oil
    /// belongs to the host, and the winning rule is the host's because it checks
    /// for one while acting on the other. Reaching the beacon with a lit lamp and
    /// no oil can is refused, and the refusal names where the oil is.
    @Test func theBeaconRefusesToLightWithoutTheOil() async throws {
        let transcript = try await play(
            Lighthouse(),
            [
                "north", "take key", "unlock door with key", "open door", "east",
                "open chest", "take lamp", "light lamp", "west", "up",
                "light beacon",
            ])

        expectInOrder(
            transcript,
            [
                "Lamp Room",
                "The beacon's reservoir is dry. You'll want the oil from the storeroom.",
            ])
        #expect(!transcript.contains("beacon roars alight"))
    }

    /// A fuse: a lit lamp burns down — a warning flicker, then out — and
    /// relighting it restarts the burn from full.
    @Test func lampBurnsDownAndRelights() async throws {
        let transcript = try await play(
            Lighthouse(),
            [
                "north", "take key", "unlock door with key", "open door", "east",
                "open chest", "take lamp", "light lamp",
                // Burn down: flicker at 6 turns, out at 9.
                "wait", "wait", "wait", "wait", "wait", "wait",
                "wait", "wait", "wait",
                // Relight, and burn again to the flicker.
                "light lamp",
                "wait", "wait", "wait", "wait", "wait", "wait",
            ])

        expectInOrder(
            transcript,
            [
                "The oil lamp is now on.",
                "The oil lamp's flame sinks to a sullen flicker.",
                "The oil lamp gutters, and goes out.",
                "The oil lamp is now on.",
                "The oil lamp's flame sinks to a sullen flicker.",
            ])
    }

    /// A daemon: the tide rises every turn and, on the jetty, warns and then
    /// floods — killing a player who lingers.
    @Test func risingTideWarnsThenFloods() async throws {
        let transcript = try await play(
            Lighthouse(),
            ["wait", "wait", "wait", "wait"])

        expectInOrder(
            transcript,
            [
                "Cold water sluices between the planks of the jetty.",
                "The tide is coming in fast now — the jetty is awash to your ankles.",
                "The sea closes over the jetty, and over you.",
                "*** You have died ***",
            ])
    }

    /// An actor, a custom verb, and `@Global` state: the keeper answers when
    /// talked to, and her one-time briefing (tracked by `keeperGreeted`) gives
    /// way to a shorter reminder.
    @Test func keeperBriefsOnceThenReminds() async throws {
        // Seeded so the keeper stays in the base across both turns (her roaming
        // could otherwise carry her off before the second question).
        let transcript = try await play(
            Lighthouse(),
            ["north", "talk to keeper", "talk to keeper"],
            seed: 3)

        expectInOrder(
            transcript,
            [
                "The old keeper stands by the window",
                "Storm doused the beacon",
                "patient as tide",
            ])
    }

    /// The jetty is a three-turn room, and `.talk` is answered by a rule on the
    /// keeper and by nothing else. Talking to yourself there used to spend all
    /// three turns while insisting the parser had failed — the first play-test
    /// round's drowning. Nothing answers the command, so nothing happens: the
    /// tide does not move.
    @Test func talkingToNobodyOnTheJettyCostsNoTurn() async throws {
        let transcript = try await play(
            Lighthouse(),
            ["talk to me", "talk to me", "talk to me", "score"],
            seed: 0)

        #expect(transcript.contains("You can't do that."))
        #expect(!transcript.contains("I didn't understand that sentence."))
        // The tide never gets a turn to rise in, so it never gets to drown you.
        #expect(!transcript.contains("Cold water sluices between the planks of the jetty."))
        #expect(!transcript.contains("The sea closes over the jetty, and over you."))
        #expect(turnOutput(of: "score", in: transcript).contains("in 0 turns."))
    }

    /// Save and restore round-trip the whole world: the brass key, dropped after
    /// saving, is back in hand once the save is restored.
    @Test func saveAndRestoreRoundTrip() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("lighthouse-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        let transcript = try await play(
            Lighthouse(),
            [
                "north", "take key", "save", path,
                "drop key", "inventory",
                "restore", path, "inventory",
            ])

        expectInOrder(
            transcript,
            [
                "Save to what file?", "Saved.",
                "Dropped.", "You are empty-handed.",
                "Restore from what file?", "Restored.",
                "You are carrying:", "brass key",
            ])
    }
}

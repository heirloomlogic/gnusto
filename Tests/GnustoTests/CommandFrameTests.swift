import GnustoTestSupport
import Testing

@testable import Gnusto

/// The command a frame hands its rule bodies when no player command names the
/// moment: the multi-object upkeep pass (`take all`) runs `beforeEachTurn`
/// before any object's command exists, and the opening, UNDO and RESTORE
/// looks describe the world with nothing typed at all. #395.
///
/// Before the fix, every one of these rules read `command.intent` on a frame
/// that had none and trapped — `take all` in any game whose each-turn rule
/// asked what the player had typed.
struct CommandFrameTests {
    /// One room whose description and each-turn rule both read `command`
    /// — the two rule shapes the doc calls the most natural.
    struct CommandFrameProbeGame: Game {
        let title = "CommandFrameProbe"
        let intro = "Probe."

        let den = Location {
            name("Den")
        }

        let hall = Location {
            name("Hall")
            description("A hall.")
        }

        let coin = Item {
            name("gold coin")
            description("A coin.")
        }

        let orb = Item {
            name("glass orb")
            description("An orb.")
        }

        var map: WorldMap {
            player.starts(in: den)
            coin.starts(in: den)
            orb.starts(in: den)
            den.north(hall)
        }

        var rules: Rules {
            den.describe { "A den. Seeing \(command.intent.raw)." }
            orb.presence { "[seen \(command.intent.raw)]" }
            // The per-object stages, unlike the upkeep pass, run with the
            // object's own command — asserted by the marker below.
            orb.before(.take) { say("[orb \(command.intent.raw)]") }
            world.beforeEachTurn { say("[each \(command.intent.raw)]") }
        }
    }

    // MARK: - The multi-object upkeep pass

    @Test func takeAllHandsBeforeEachTurnTheGroupsIntent() async throws {
        let transcript = try await play(CommandFrameProbeGame(), ["take all"])
        let turn = turnOutput(of: "take all", in: transcript)
        // The upkeep pass runs once, before any object's command exists.
        #expect(turn.contains("[each take]"))
        #expect(occurrences(of: "[each", in: turn) == 1)
        #expect(turn.contains("gold coin: Taken."))
        #expect(turn.contains("glass orb: [orb take] Taken."))
    }

    @Test func dropAllHandsBeforeEachTurnTheGroupsIntent() async throws {
        let transcript = try await play(
            CommandFrameProbeGame(), ["take all", "drop all"])
        let turn = turnOutput(of: "drop all", in: transcript)
        #expect(turn.contains("[each drop]"))
        #expect(turn.contains("gold coin: Dropped."))
    }

    @Test func eachTurnRulesStillSeeEachObjectsOwnCommand() async throws {
        // The upkeep pass ran once with the group's command; the object
        // stages run once per object with that object's own command, marked
        // by the orb's `before` rule.
        let transcript = try await play(CommandFrameProbeGame(), ["take all"])
        let turn = turnOutput(of: "take all", in: transcript)
        #expect(occurrences(of: "[each take]", in: turn) == 1)
        #expect(occurrences(of: "[orb take]", in: turn) == 1)
        #expect(turn.contains("glass orb: [orb take] Taken."))
    }

    @Test func aSingleObjectTurnIsUnchanged() async throws {
        let transcript = try await play(CommandFrameProbeGame(), ["take coin"])
        let turn = turnOutput(of: "take coin", in: transcript)
        #expect(turn.contains("[each take]"))
        #expect(turn.contains("Taken."))
    }

    @Test func aMoveIsStillSeenAsGo() async throws {
        let transcript = try await play(CommandFrameProbeGame(), ["north"])
        let turn = turnOutput(of: "north", in: transcript)
        #expect(turn.contains("[each go]"))
    }

    // MARK: - The describing passes

    // An entry (opening look, UNDO, RESTORE) prints the room name and item
    // paragraphs; a `describe { }` closure is the examine text and is skipped
    // on re-entries. The closure that every describing pass really runs is a
    // `presence { }` — that is where a rule reading `command` is reachable
    // from `begin`, UNDO and RESTORE alike.

    @Test func theOpeningLookReadsAsALook() async throws {
        let transcript = try await play(CommandFrameProbeGame(), [])
        #expect(transcript.contains("[seen look]"))
    }

    @Test func undoDescribesAsALook() async throws {
        let transcript = try await play(
            CommandFrameProbeGame(), ["take coin", "undo"])
        let undo = turnOutput(of: "undo", in: transcript)
        #expect(undo.contains("[seen look]"))
    }

    @Test func restoreDescribesAsALook() async throws {
        let transcript = try await play(
            CommandFrameProbeGame(),
            ["save", "slot", "take coin", "restore", "slot"])
        expectInOrder(transcript, ["Restored.", "[seen look]"])
    }
}

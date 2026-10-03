import GnustoTestSupport
import Testing

@testable import Gnusto

struct RedirectTests {
    static let relay = "relay rod at dummy"

    @Test func redirectRestartsCommandStagesButFinishesAndUndoesOneTurn() async throws {
        let world = try GameWorld(game: RedirectProbeGame(mode: .normal))
        _ = await world.begin()
        let before = await world.snapshot()
        let result = await world.perform(Self.relay)
        expectInOrder(
            result.output,
            [
                "[upkeep]", "[relay-world]", "[relay-room]", "[relay-indirect]", "[relay-direct]", "[relay-default]",
                "[hit-world]", "[hit-room]", "[hit-indirect]", "[hit-direct]", "[hit-default]",
                "slots=true:true:with", "typed=relay:relay rod at dummy",
                "[hit-direct-after]", "[hit-indirect-after]", "[hit-room-after]", "[hit-world-after]",
                "[epilogue=true]", "[tick]",
            ])
        #expect(!result.output.contains("relay-after-must-not-run"))
        #expect(result.output.components(separatedBy: "[upkeep]").count == 2)
        #expect(result.output.components(separatedBy: "[tick]").count == 2)
        let after = await world.snapshot()
        #expect(after.moves == before.moves + 1)
        #expect(after.pronounIt == EntityID("dummy"))
        #expect(after.lastCommand == ["relay", "rod", "at", "dummy"])
        _ = await world.perform("undo")
        let restored = await world.snapshot()
        #expect(restored.globals == before.globals)
        #expect(restored.moves == before.moves)
        #expect(restored.pronounIt == before.pronounIt)
        #expect(restored.activeDaemons == before.activeDaemons)
    }

    @Test(arguments: [RedirectProbeGame.Mode.refused, .unreachable])
    func redirectedRefusalsRunOneTickAndSkipLaterStages(mode: RedirectProbeGame.Mode) async throws {
        let world = try GameWorld(game: RedirectProbeGame(mode: mode))
        _ = await world.begin()
        let result = await world.perform(Self.relay)
        #expect(result.output.contains(mode == .refused ? "[hit-refused]" : "[hit-unreachable]"))
        #expect(!result.output.contains("[hit-direct-after]"))
        #expect(result.output.components(separatedBy: "[tick]").count == 2)
        #expect((await world.snapshot()).moves == 1)
        if mode == .unreachable { #expect(!result.output.contains("[hit-world]")) }
    }

    @Test func aRedirectedBeforeReplyPreemptsTheDefaultAndAfterRules() async throws {
        let world = try GameWorld(game: RedirectProbeGame(mode: .replied))
        _ = await world.begin()
        let result = await world.perform(Self.relay)
        #expect(result.output.contains("[hit-replied]"))
        #expect(!result.output.contains("[hit-default]"))
        #expect(!result.output.contains("[hit-direct-after]"))
        #expect(result.output.components(separatedBy: "[tick]").count == 2)
    }

    @Test(arguments: ["relay north", "relay about distant stars"])
    func redirectsRetainDirectionAndTopicFromTheTypedCommand(command: String) async throws {
        let world = try GameWorld(game: RedirectProbeGame(mode: .normal))
        _ = await world.begin()
        let result = await world.perform(command)
        #expect(
            result.output.contains(
                command == "relay north" ? "direction=true;topic=nil" : "direction=false;topic=distant stars"))
    }

    @Test func anUnhandledRedirectRollsBackTheEntireTypedCommandForFree() async throws {
        let world = try GameWorld(game: RedirectProbeGame(mode: .unhandled))
        _ = await world.begin()
        let before = await world.snapshot()
        let result = await world.perform(Self.relay)
        #expect(!result.output.contains("[tick]"))
        let after = await world.snapshot()
        #expect(after.globals == before.globals)
        #expect(after.moves == before.moves)
        #expect(after.pronounIt == before.pronounIt)
        #expect(after.lastCommand == before.lastCommand)
    }

    @Test func chainedRedirectsStillHaveOneUpkeepAndTimerTick() async throws {
        let world = try GameWorld(game: RedirectProbeGame(mode: .chained))
        _ = await world.begin()
        let result = await world.perform(Self.relay)
        expectInOrder(result.output, ["[relay-default]", "[bridge-default]", "[hit-default]", "[tick]"])
        #expect(result.output.components(separatedBy: "[upkeep]").count == 2)
        #expect(result.output.components(separatedBy: "[tick]").count == 2)
        #expect((await world.snapshot()).moves == 1)
    }

    @Test func groupedMembersRedirectInsideOneOuterTurn() async throws {
        let world = try GameWorld(game: RedirectProbeGame(mode: .grouped))
        _ = await world.begin()
        let before = await world.snapshot()
        let result = await world.perform("put rod and dummy in box")
        #expect(result.output.components(separatedBy: "[put-default]").count == 3)
        #expect(result.output.components(separatedBy: "[upkeep]").count == 2)
        #expect(result.output.components(separatedBy: "[tick]").count == 2)
        #expect((await world.snapshot()).moves == before.moves + 1)
        _ = await world.perform("undo")
        #expect((await world.snapshot()).globals == before.globals)
    }

    @Test(arguments: [RedirectProbeGame.Mode.unhandled, .laterUnhandled])
    func anUnhandledGroupedRedirectRollsBackAllMembersAndUpkeep(mode: RedirectProbeGame.Mode) async throws {
        let world = try GameWorld(game: RedirectProbeGame(mode: mode))
        _ = await world.begin()
        let initial = await world.snapshot()
        _ = await world.perform("wait")
        let before = await world.snapshot()
        let result = await world.perform("put rod and dummy in box")
        #expect(!result.output.contains("[tick]"))
        #expect(result.output.components(separatedBy: "[put-default]").count == (mode == .unhandled ? 2 : 3))
        #expect(result.output.contains("[hit-default]") == (mode == .laterUnhandled))
        let after = await world.snapshot()
        #expect(after.moves == before.moves)
        #expect(after.globals == before.globals)
        #expect(after.placements == before.placements)
        #expect(after.pronounIt == before.pronounIt)
        _ = await world.perform("undo")
        #expect((await world.snapshot()).globals == initial.globals)
        #expect((await world.snapshot()).moves == initial.moves)
    }

    #if GNUSTO_EXIT_TESTS
    @Test func redirectCycleTrapsInsteadOfHanging() async throws {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = try await play(RedirectProbeGame(mode: .cycle), ["relay rod at dummy"])
        }
        expectTrap(result, says: "redirect() exceeded 32 redirects in one command")
    }

    @Test func redirectFromBeforeTraps() async throws {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = try await play(RedirectProbeGame(mode: .before), ["relay rod at dummy"])
        }
        expectTrap(result, says: "redirect() requires the pipeline's stage-4 default action")
    }

    @Test func redirectFromAfterTraps() async throws {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = try await play(RedirectProbeGame(mode: .after), ["relay rod at dummy"])
        }
        expectTrap(result, says: "redirect() requires the pipeline's stage-4 default action")
    }

    @Test func redirectFromEarlyDefaultTraps() async throws {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = try await play(RedirectProbeGame(mode: .earlyDefault), ["relay rod at dummy"])
        }
        expectTrap(result, says: "redirect() requires the pipeline's stage-4 default action")
    }

    @Test func redirectToAnEngineCommandTraps() async throws {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = try await play(RedirectProbeGame(mode: .meta), ["relay rod at dummy"])
        }
        expectTrap(result, says: "redirect() cannot dispatch a meta or engine command")
    }

    @Test func redirectToAgainTraps() async throws {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = try await play(RedirectProbeGame(mode: .engine), ["relay rod at dummy"])
        }
        expectTrap(result, says: "redirect() cannot dispatch a meta or engine command")
    }
    #endif
}

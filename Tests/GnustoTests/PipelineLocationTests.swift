import GnustoTestSupport
import Testing

@testable import Gnusto

struct PipelineLocationTests {
    @Test func locationUpkeepRedirectsOrdinaryLocationRules() async throws {
        let transcript = try await play(LocationUpkeepGame(), ["wait"])
        let turn = turnOutput(of: "wait", in: transcript)
        expectInOrder(turn, ["[upkeep]", "[destination-before]", "[destination-after]"])
        #expect(!turn.contains("[origin-before]"))
        #expect(!turn.contains("[origin-after]"))
        #expect(!turn.contains("[destination-upkeep]"))
    }

    @Test func proceedDuringLocationUpkeepSelectsTheDestinationForAfterRules() async throws {
        let transcript = try await play(fresh: LocationUpkeepGame(wrappedWalk: true), ["go north"])
        let turn = turnOutput(of: "go north", in: transcript)
        expectInOrder(turn, ["[upkeep]", "Destination", "[destination-after]"])
        #expect(!turn.contains("[origin-after]"))
        #expect(!turn.contains("[origin-before]"))
        #expect(!turn.contains("[destination-before]"))
    }

    @Test(arguments: [false, true])
    func locationUpkeepRefreshesTheAddressee(remove: Bool) async throws {
        let transcript = try await play(
            fresh: LocationUpkeepGame(removeActor: remove), ["robot, wait", "score", "robot, wait"])
        let turn = turnOutput(of: "robot, wait", in: transcript)
        #expect(!turn.contains("[origin-before]"))
        if remove {
            #expect(!turn.contains("[robot-answer]"))
            #expect(turn.contains("does not know how"))
            #expect(turnOutput(of: "score", in: transcript).contains("in 0 turns"))
            #expect(turnOutput(ofLast: "robot, wait", in: transcript).contains("[upkeep]"))
        } else {
            expectInOrder(turn, ["[upkeep]", "[destination-before]", "[robot-answer]"])
        }
    }

    @Test(arguments: [false, true])
    func allUsesTheRoomAfterUpkeep(locationPhase: Bool) async throws {
        let transcript = try await play(
            fresh: GroupUpkeepGame(locationPhase: locationPhase), ["take all", "inventory"])
        let turn = turnOutput(of: "take all", in: transcript)
        #expect(turn.contains("new coin: Taken."))
        #expect(!turn.contains("old coin:"))
        #expect(turnOutput(of: "inventory", in: transcript).contains("new coin"))
    }

    @Test func upkeepCanEmptyAGroupAndStillConsumeOneTurn() async throws {
        let transcript = try await play(
            fresh: GroupUpkeepGame(emptyDestination: true), ["take all", "score", "undo", "look"])
        let turn = turnOutput(of: "take all", in: transcript)
        #expect(turn.contains("There is nothing here to take."))
        #expect(!turn.contains("old coin:"))
        #expect(occurrences(of: "[tick]", in: turn) == 1)
        #expect(turnOutput(of: "score", in: transcript).contains("in 1 turn"))
        #expect(turnOutput(of: "undo", in: transcript).contains("Origin"))
    }

    @Test func anInitiallyEmptyGroupDoesNotRunUpkeep() async throws {
        let transcript = try await play(
            fresh: GroupUpkeepGame(emptyOrigin: true), ["take all", "score"])
        #expect(!transcript.contains("[upkeep]"))
        #expect(!transcript.contains("[tick]"))
        #expect(turnOutput(of: "score", in: transcript).contains("in 0 turns"))
    }

    @Test func anExplicitListKeepsItsNamedObjectsAfterUpkeep() async throws {
        let transcript = try await play(GroupUpkeepGame(), ["take old coin and pebble"])
        let turn = turnOutput(of: "take old coin and pebble", in: transcript)
        #expect(turn.contains("old coin: You can't reach"))
        #expect(turn.contains("pebble: You can't reach"))
        #expect(!turn.contains("new coin:"))
    }

    @Test(arguments: [false, true])
    func interruptedUpkeepStillBindsTheNamedGroup(replyInstead: Bool) async throws {
        let transcript = try await play(
            fresh: InterruptedGroupGame(replyInstead: replyInstead), ["take coin and pebble", "drop them"])
        #expect(turnOutput(of: "take coin and pebble", in: transcript).contains("Not now."))
        let turn = turnOutput(of: "drop them", in: transcript)
        #expect(turn.contains("coin:"))
        #expect(turn.contains("pebble:"))
        #expect(!turn.contains("refer"))
    }

    @Test(arguments: ["drop all", "put all in sack", "put all on table"])
    func allUsesInventoryAfterUpkeep(input: String) async throws {
        let transcript = try await play(InventoryUpkeepGame(), [input])
        let turn = turnOutput(of: input, in: transcript)
        #expect(turn.contains("new coin:"))
        #expect(turn.contains("pebble:"))
        #expect(!turn.contains("old coin:"))
        #expect(!turn.contains("not carrying"))
        if input == "put all in sack" { #expect(!turn.contains("sack:")) }
    }

    @Test func exclusionsStillApplyToObjectsIntroducedByUpkeep() async throws {
        let transcript = try await play(InventoryUpkeepGame(), ["drop all but new coin"])
        let turn = turnOutput(of: "drop all but new coin", in: transcript)
        #expect(turn.contains("pebble: Dropped."))
        #expect(!turn.contains("new coin:"))
        #expect(!turn.contains("old coin:"))
    }

    @Test func themRefreshesVisibilityWithoutReplacingItsReferents() async throws {
        let transcript = try await play(
            InventoryUpkeepGame(), ["take old coin and pebble", "drop them"])
        let turn = turnOutput(of: "drop them", in: transcript)
        #expect(turn.contains("pebble: Dropped."))
        #expect(!turn.contains("old coin:"))
        #expect(!turn.contains("new coin:"))
        #expect(!turn.contains("sack:"))
    }

    @Test(arguments: [false, true])
    func locationAfterEachTurnUsesTheRoomAtStageSixEntry(timerMove: Bool) async throws {
        let transcript = try await play(fresh: LateMoveGame(timerMove: timerMove), ["wait", "look"])
        let turn = turnOutput(of: "wait", in: transcript)
        expectInOrder(turn, ["[origin-after-each]", "[late-move]", "Destination"])
        #expect(!turn.contains("[destination-after-each]"))
        #expect(turnOutput(of: "look", in: transcript).contains("[destination-after-each]"))
    }
}

private struct LocationUpkeepGame: Game {
    var removeActor = false
    var wrappedWalk = false
    let title = "Location upkeep"
    let intro = "A test."
    let origin = Location { name("Origin") }
    let destination = Location { name("Destination") }
    let robot = Actor {
        name("robot")
        takesOrders
    }
    var map: WorldMap {
        player.starts(in: origin)
        robot.starts(in: origin)
        origin.north(destination)
    }
    var rules: Rules {
        origin.beforeEachTurn {
            say("[upkeep]")
            if wrappedWalk {
                try proceed()
            } else if command.actor != nil {
                if removeActor { robot.vanish() } else { robot.move(to: destination) }
            } else {
                arrive(at: destination)
            }
        }
        origin.before(.wait, .go) { say("[origin-before]") }
        origin.after(.wait, .go) { say("[origin-after]") }
        destination.beforeEachTurn { say("[destination-upkeep]") }
        destination.before(.wait, .go) { say("[destination-before]") }
        destination.after(.wait, .go) { say("[destination-after]") }
        robot.before(.wait) { try reply("[robot-answer]") }
    }
}

private struct GroupUpkeepGame: Game {
    var locationPhase = false
    var emptyOrigin = false
    var emptyDestination = false
    let title = "Group upkeep"
    let intro = "A test."
    let origin = Location { name("Origin") }
    let destination = Location { name("Destination") }
    let oldCoin = Item { name("old coin") }
    let newCoin = Item { name("new coin") }
    let pebble = Item { name("pebble") }
    @Latch var moved
    var map: WorldMap {
        player.starts(in: origin)
        if !emptyOrigin {
            oldCoin.starts(in: origin)
            pebble.starts(in: origin)
        }
        if !emptyDestination { newCoin.starts(in: destination) }
    }
    func drift() {
        guard $moved.trips() else { return }
        say("[upkeep]")
        arrive(at: destination)
    }
    var rules: Rules {
        world.beforeEachTurn { if !locationPhase { drift() } }
        origin.beforeEachTurn { if locationPhase { drift() } }
        world.afterEachTurn { say("[tick]") }
    }
}

private struct LateMoveGame: Game {
    var timerMove = false
    let title = "Late move"
    let intro = "A test."
    let origin = Location { name("Origin") }
    let destination = Location { name("Destination") }
    @Latch var moved
    var map: WorldMap { player.starts(in: origin) }
    func drift() {
        guard $moved.trips() else { return }
        say("[late-move]")
        arrive(at: destination)
    }
    var rules: Rules {
        origin.afterEachTurn { say("[origin-after-each]") }
        destination.afterEachTurn { say("[destination-after-each]") }
        world.afterEachTurn { if !timerMove { drift() } }
    }
    var timers: [TimedEvent] {
        fuse("drift", after: 1, autostart: true) { if timerMove { drift() } }
    }
}

private struct InventoryUpkeepGame: Game {
    let title = "Inventory upkeep"
    let intro = "A test."
    let room = Location { name("Room") }
    let oldCoin = Item { name("old coin") }
    let newCoin = Item { name("new coin") }
    let pebble = Item { name("pebble") }
    let sack = Item {
        name("sack")
        container
    }
    let table = Item {
        name("table")
        surface
        scenery
    }
    var map: WorldMap {
        player.starts(in: room)
        oldCoin.startsHeld
        pebble.startsHeld
        sack.startsHeld
        newCoin.starts(in: room)
        table.starts(in: room)
    }
    var rules: Rules {
        world.beforeEachTurn {
            guard command.intent == .drop || command.intent == .putIn || command.intent == .putOn else { return }
            oldCoin.vanish()
            newCoin.moveToPlayer()
        }
    }
}

private struct InterruptedGroupGame: Game {
    var replyInstead = false
    let title = "Interrupted group"
    let intro = "A test."
    let room = Location { name("Room") }
    let coin = Item { name("coin") }
    let pebble = Item { name("pebble") }
    var map: WorldMap {
        player.starts(in: room)
        coin.starts(in: room)
        pebble.starts(in: room)
    }
    var rules: Rules {
        world.beforeEachTurn {
            guard command.intent == .take else { return }
            if replyInstead { try reply("Not now.") }
            try refuse("Not now.")
        }
    }
}

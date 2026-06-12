/// The built-in behavior of each intent, running under the same frame and
/// with the same helpers as author rules — no privileged path.
enum DefaultActions {
    /// Runs the default action for a command. Returns the rules-pipeline
    /// continuation: `onEnter` rules to run when the player moved.
    static func run(_ command: Command, frame: TurnFrame) throws {
        switch command.intent {
        case .take: try take(command, frame: frame)
        case .drop: try drop(command, frame: frame)
        case .wear: try wear(command, frame: frame)
        case .doff: try doff(command, frame: frame)
        case .putOn: try putOn(command, frame: frame)
        case .go: try go(command, frame: frame)
        case .look: RoomDescriber.describeCurrentLocation(mode: .look, frame: frame)
        case .examine: try examine(command, frame: frame)
        case .read: try read(command, frame: frame)
        case .inventory: inventory(frame)
        case .score: score(frame)
        case .version: version(frame)
        case .quit: quit(frame)
        default:
            frame.say(Messages.didntUnderstand)
        }
    }

    // MARK: - Manipulation

    private static func take(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        if item.isHeld {
            try refuse(item.isWorn ? Messages.alreadyWearing : Messages.alreadyHave)
        }
        guard frame.definition.items[id]?.isTakable == true else {
            try refuse(Messages.cantTake)
        }
        frame.with { scratch in
            scratch.state.placements[id] = .held
            scratch.state.touched.insert(id)
        }
        frame.say(Messages.taken)
    }

    private static func drop(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard item.isHeld else {
            try refuse(Messages.notCarrying)
        }
        if item.isWorn {
            frame.say(Messages.firstTakingOff(item.name))
            frame.with { _ = $0.state.wornItems.remove(id) }
        }
        frame.with { scratch in
            scratch.state.placements[id] = .room(scratch.state.playerLocation)
            scratch.state.touched.insert(id)
        }
        frame.say(Messages.dropped)
    }

    private static func wear(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        if item.isWorn {
            try refuse(Messages.alreadyWearing)
        }
        guard item.isHeld else {
            try refuse(Messages.notHolding)
        }
        guard frame.definition.items[item.id]?.isWearable == true else {
            try refuse(Messages.cantWear)
        }
        let id = item.id
        frame.with { _ = $0.state.wornItems.insert(id) }
        frame.say(Messages.putOn(item.name))
    }

    private static func doff(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard item.isWorn else {
            try refuse(Messages.notWearing)
        }
        let id = item.id
        frame.with { _ = $0.state.wornItems.remove(id) }
        frame.say(Messages.takeOff(item.name))
    }

    private static func putOn(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard let surface = command.indirectObject else {
            try refuse(Messages.didntUnderstand)
        }
        guard item.isHeld else {
            try refuse(Messages.notHolding)
        }
        if item == surface {
            try refuse(Messages.cantPutOnItself)
        }
        guard frame.definition.items[surface.id]?.isSurface == true else {
            try refuse(Messages.cantPutOnThat)
        }
        if item.isWorn {
            frame.say(Messages.firstTakingOff(item.name))
            let id = item.id
            frame.with { _ = $0.state.wornItems.remove(id) }
        }
        let id = item.id
        let surfaceID = surface.id
        frame.with { scratch in
            scratch.state.placements[id] = .on(surfaceID)
            scratch.state.touched.insert(id)
        }
        frame.say(Messages.putItemOn(item.name, surface.name))
    }

    // MARK: - Movement & perception

    private static func go(_ command: Command, frame: TurnFrame) throws {
        guard let direction = command.direction else {
            try refuse(Messages.whichWay)
        }
        let here = frame.with { $0.state.playerLocation }
        switch frame.definition.exits[here]?[direction] {
        case nil:
            try refuse(Messages.cantGoThatWay)
        case .blocked(let message):
            try refuse(message)
        case .to(let destination):
            frame.with { $0.state.playerLocation = destination }
            for rule in frame.definition.rules.locationOnEnter[destination] ?? [] {
                try rule.body()
            }
            RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
        }
    }

    private static func examine(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let text = item.description
        if text.isEmpty {
            frame.say(Messages.nothingSpecial(item.name))
        } else {
            frame.say(text)
        }
    }

    private static func read(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let text = item.description
        if text.isEmpty {
            frame.say(Messages.nothingWritten)
        } else {
            frame.say(text)
        }
    }

    private static func inventory(_ frame: TurnFrame) {
        let held = frame.with { scratch in
            frame.definition.items.keys
                .filter { scratch.state.placements[$0] == .held }
                .sorted { $0.raw < $1.raw }
                .map { id -> String in
                    let name = frame.definition.items[id]?.name ?? id.raw
                    let worn = scratch.state.wornItems.contains(id) ? " (being worn)" : ""
                    return "  a \(name)\(worn)"
                }
        }
        if held.isEmpty {
            frame.say(Messages.emptyHanded)
        } else {
            frame.say(([Messages.carrying] + held).joined(separator: "\n"))
        }
    }

    // MARK: - Meta

    private static func score(_ frame: TurnFrame) {
        let line = frame.with { scratch in
            Messages.scoreLine(
                score: scratch.state.score,
                maxScore: frame.definition.maxScore,
                moves: scratch.state.moves)
        }
        frame.say(line)
    }

    private static func version(_ frame: TurnFrame) {
        let definition = frame.definition
        let tagline = definition.tagline.isEmpty ? "" : "\n\(definition.tagline)"
        frame.say("\(definition.title)\(tagline)")
    }

    private static func quit(_ frame: TurnFrame) {
        score(frame)
        frame.with { $0.state.status = .quit }
    }

    private static func requireDirectObject(_ command: Command) throws -> Item {
        guard let item = command.directObject else {
            // The parser supplies objects for object-bearing rules; this is a
            // safety net, not a player-facing path.
            try refuse(Messages.didntUnderstand)
        }
        return item
    }
}

/// The built-in behavior of each intent, running under the same frame and
/// with the same helpers as author rules — no privileged path.
enum DefaultActions {
    /// Every intent the built-in switch below handles itself. Used by
    /// Bootstrap to decide whether a game/bundle/plugin action row is
    /// overriding a built-in (warning) or giving a fresh intent its first
    /// default behavior (no warning).
    static let builtInIntents: Set<Intent> = [
        .take, .drop, .wear, .doff, .putOn, .putIn, .open, .close, .lock, .unlock,
        .lookIn, .push, .go, .look, .examine, .read, .inventory, .score, .version, .quit,
    ]

    /// Runs the default action for a command: a game/bundle/plugin override
    /// if one is registered for this intent, else the built-in switch.
    static func run(_ command: Command, frame: TurnFrame) throws {
        if let override = frame.definition.actionOverrides[command.intent] {
            try override.body()
            return
        }
        switch command.intent {
        case .take: try take(command, frame: frame)
        case .drop: try drop(command, frame: frame)
        case .wear: try wear(command, frame: frame)
        case .doff: try doff(command, frame: frame)
        case .putOn: try putOn(command, frame: frame)
        case .putIn: try putIn(command, frame: frame)
        case .open: try open(command, frame: frame)
        case .close: try close(command, frame: frame)
        case .lock: try lock(command, frame: frame)
        case .unlock: try unlock(command, frame: frame)
        case .lookIn: try lookIn(command, frame: frame)
        case .push: try push(command, frame: frame)
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
        // The parser's scope is *visible* items, which also admits a closed
        // transparent container's contents (seen through the glass but not
        // touchable) — take needs the stricter reachable set to refuse those.
        guard isReachable(id, frame: frame) else {
            try refuse(Messages.cantSeeAnySuchThing)
        }
        frame.with { scratch in
            scratch.state.placements[id] = .heldBy(.player)
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

    private static func putIn(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard let container = command.indirectObject else {
            try refuse(Messages.didntUnderstand)
        }
        guard item.isHeld else {
            try refuse(Messages.notHolding)
        }
        if item == container {
            try refuse(Messages.cantPutInItself)
        }
        guard frame.definition.items[container.id]?.isContainer == true,
            isReachable(container.id, frame: frame)
        else {
            try refuse(Messages.cantPutInThat)
        }
        guard container.isOpen else {
            try refuse(Messages.closedContainer(container.name))
        }
        let id = item.id
        let containerID = container.id
        if frame.with({ isOrContains($0.state, containerID, id) }) {
            try refuse(Messages.cantPutInItself)
        }
        if let capacity = frame.definition.items[containerID]?.capacity {
            let occupants = frame.with { scratch in
                scratch.state.placements.values.filter { $0 == .inside(containerID) }.count
            }
            guard occupants < capacity else {
                try refuse(Messages.noRoom)
            }
        }
        if item.isWorn {
            frame.say(Messages.firstTakingOff(item.name))
            frame.with { _ = $0.state.wornItems.remove(id) }
        }
        frame.with { scratch in
            scratch.state.placements[id] = .inside(containerID)
            scratch.state.touched.insert(id)
        }
        frame.say(Messages.putItemIn(item.name, container.name))
    }

    /// True if `candidate` is `target` itself, or sits somewhere inside
    /// `target`'s containment subtree (on a surface or inside a container,
    /// to any depth) — the shape a `putIn` cycle would take. Guards against
    /// putting a container into itself or into one of its own contents.
    private static func isOrContains(_ state: WorldState, _ candidate: EntityID, _ target: EntityID) -> Bool {
        if candidate == target { return true }
        var frontier = [target]
        var seen: Set<EntityID> = []
        while let id = frontier.popLast() {
            guard seen.insert(id).inserted else { continue }
            for (childID, placement) in state.placements {
                switch placement {
                case .on(id), .inside(id):
                    if childID == candidate { return true }
                    frontier.append(childID)
                default:
                    break
                }
            }
        }
        return false
    }

    private static func open(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard frame.definition.items[id]?.isOpenable == true, isReachable(id, frame: frame) else {
            try refuse(Messages.cantOpenThat)
        }
        if item.isLocked {
            try refuse(Messages.locked(item.name))
        }
        if item.isOpen {
            try refuse(Messages.alreadyOpen)
        }
        let contents = frame.with { scratch -> [String] in
            scratch.state.openItems.insert(id)
            return scratch.state.placements.keys
                .filter { scratch.state.placements[$0] == .inside(id) }
                .filter { Visibility.isPerceivable($0, definition: frame.definition, state: scratch.state) }
                .sorted()
                .map { frame.definition.items[$0]?.name ?? $0.raw }
        }
        if contents.isEmpty {
            frame.say(Messages.opened)
        } else {
            frame.say(Messages.openingReveals(item.name, contents))
        }
    }

    private static func close(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard frame.definition.items[id]?.isOpenable == true, isReachable(id, frame: frame) else {
            try refuse(Messages.cantCloseThat)
        }
        guard item.isOpen else {
            try refuse(Messages.alreadyClosed)
        }
        frame.with { _ = $0.state.openItems.remove(id) }
        frame.say(Messages.closed)
    }

    private static func lock(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard let key = command.indirectObject else {
            try refuse(Messages.didntUnderstand)
        }
        let id = item.id
        guard frame.definition.items[id]?.isLockable == true, isReachable(id, frame: frame) else {
            try refuse(Messages.cantLockThat)
        }
        if item.isLocked {
            try refuse(Messages.alreadyLocked)
        }
        guard key.isHeld else {
            try refuse(Messages.keyNotHeld(key.name))
        }
        guard frame.definition.items[id]?.lockKey == key.id else {
            try refuse(Messages.wrongKey)
        }
        frame.with { _ = $0.state.lockedItems.insert(id) }
        frame.say(Messages.lockedMessage)
    }

    private static func unlock(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard let key = command.indirectObject else {
            try refuse(Messages.didntUnderstand)
        }
        let id = item.id
        guard frame.definition.items[id]?.isLockable == true, isReachable(id, frame: frame) else {
            try refuse(Messages.cantUnlockThat)
        }
        guard item.isLocked else {
            try refuse(Messages.alreadyUnlocked)
        }
        guard key.isHeld else {
            try refuse(Messages.keyNotHeld(key.name))
        }
        guard frame.definition.items[id]?.lockKey == key.id else {
            try refuse(Messages.wrongKey)
        }
        frame.with { _ = $0.state.lockedItems.remove(id) }
        frame.say(Messages.unlockedMessage)
    }

    private static func lookIn(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard frame.definition.items[id]?.isContainer == true, isReachable(id, frame: frame) else {
            try refuse(Messages.cantSeeAnySuchThing)
        }
        if frame.definition.items[id]?.isOpenable == true, !item.isOpen,
            frame.definition.items[id]?.isTransparent != true
        {
            try refuse(Messages.closedContainer(item.name))
        }
        let contents = frame.with { scratch -> [String] in
            scratch.state.placements.keys
                .filter { scratch.state.placements[$0] == .inside(id) }
                .filter { Visibility.isPerceivable($0, definition: frame.definition, state: scratch.state) }
                .sorted()
                .map { frame.definition.items[$0]?.name ?? $0.raw }
        }
        if contents.isEmpty {
            frame.say(Messages.emptyContainer(item.name))
        } else {
            frame.say(Messages.inTheContainer(item.name, contents))
        }
    }

    private static func push(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard isReachable(item.id, frame: frame) else {
            try refuse(Messages.cantSeeAnySuchThing)
        }
        frame.say(Messages.cantMoveThat)
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
        try describeItem(command, frame: frame) { Messages.nothingSpecial($0.name) }
    }

    private static func read(_ command: Command, frame: TurnFrame) throws {
        try describeItem(command, frame: frame) { _ in Messages.nothingWritten }
    }

    private static func describeItem(
        _ command: Command,
        frame: TurnFrame,
        fallback: (Item) -> String
    ) throws {
        let item = try requireDirectObject(command)
        let text = item.description
        frame.say(text.isEmpty ? fallback(item) : text)
    }

    private static func inventory(_ frame: TurnFrame) {
        let held = frame.with { scratch in
            frame.definition.items.keys
                .filter { scratch.state.placements[$0] == .heldBy(.player) }
                .sorted()
                .map { id in
                    Messages.inventoryLine(
                        frame.definition.items[id]?.name ?? id.raw,
                        isWorn: scratch.state.wornItems.contains(id))
                }
        }
        if held.isEmpty {
            frame.say(Messages.emptyHanded)
        } else {
            frame.say(([Messages.carrying] + held).joined(separator: "\n"))
        }
    }

    // MARK: - Meta

    /// Also used by the pipeline's end-of-game epilogue, so the score-report
    /// format lives in exactly one place.
    static func score(_ frame: TurnFrame) {
        let line = frame.with { scratch in
            Messages.scoreLine(
                score: scratch.state.score,
                maxScore: frame.definition.maxScore,
                moves: scratch.state.moves)
        }
        frame.say(line)
    }

    private static func version(_ frame: TurnFrame) {
        frame.say(Messages.banner(title: frame.definition.title, tagline: frame.definition.tagline))
    }

    private static func quit(_ frame: TurnFrame) {
        // The pipeline's end-of-game epilogue reports the score.
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

    /// Whether `id` is currently reachable by the player — the stricter set
    /// than parser scope (which is *visible* items, and so also admits a
    /// closed transparent container's contents).
    private static func isReachable(_ id: EntityID, frame: TurnFrame) -> Bool {
        let (here, state) = frame.with { ($0.state.playerLocation, $0.state) }
        return Visibility.reachableItems(at: here, definition: frame.definition, state: state)
            .contains(id)
    }
}

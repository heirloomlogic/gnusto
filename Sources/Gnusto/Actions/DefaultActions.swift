/// The built-in behavior of each intent, running under the same frame and
/// with the same helpers as author rules — no privileged path.
enum DefaultActions {
    /// Every intent the built-in switch below handles itself. Used by
    /// Bootstrap to decide whether a game/bundle/plugin action row is
    /// overriding a built-in (warning) or giving a fresh intent its first
    /// default behavior (no warning).
    static let builtInIntents: Set<Intent> = [
        .take, .drop, .wear, .doff, .putOn, .putIn, .open, .close, .lock, .unlock,
        .lookIn, .push, .turnOn, .turnOff, .go, .board, .disembark, .look, .examine,
        .read, .inventory, .score, .version, .quit, .wait,
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
        case .turnOn: try turnOn(command, frame: frame)
        case .turnOff: try turnOff(command, frame: frame)
        case .go: try go(command, frame: frame)
        case .board: try board(command, frame: frame)
        case .disembark: try disembark(command, frame: frame)
        case .wait: frame.say(frame.definition.text.timePasses)
        case .look: RoomDescriber.describeCurrentLocation(mode: .look, frame: frame)
        case .examine: try examine(command, frame: frame)
        case .read: try read(command, frame: frame)
        case .inventory: inventory(frame)
        case .score: score(frame)
        case .version: version(frame)
        case .quit: quit(frame)
        default:
            frame.say(frame.definition.text.didntUnderstand)
        }
    }

    // MARK: - Manipulation

    private static func take(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        // People get the person-specific refusal, not scenery's.
        if frame.definition.items[id]?.isActor == true {
            try refuse(frame.definition.text.cantTakeActor(item.name))
        }
        // The one default that could relocate the thing the player is
        // sitting in.
        let boarded = frame.with {
            Visibility.boardedVehicle(definition: frame.definition, state: $0.state)
        }
        if id == boarded {
            try refuse(frame.definition.text.notWhileInside(item.name))
        }
        if item.isHeld {
            try refuse(item.isWorn ? frame.definition.text.alreadyWearing : frame.definition.text.alreadyHave)
        }
        guard frame.definition.items[id]?.isTakable == true else {
            try refuse(frame.definition.text.cantTake)
        }
        // The parser's scope is *visible* items, which also admits a closed
        // transparent container's contents (seen through the glass but not
        // touchable) — take needs the stricter reachable set to refuse those.
        // The item resolved, so it's visible: refuse with "can't reach", not
        // "can't see".
        guard isReachable(id, frame: frame) else {
            try refuse(frame.definition.text.cantReach(item.name))
        }
        frame.with { scratch in
            scratch.state.place(id, .heldBy(.player))
            scratch.state.touched.insert(id)
        }
        frame.say(frame.definition.text.taken)
    }

    private static func drop(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard item.isHeld else {
            try refuse(frame.definition.text.notCarrying)
        }
        if item.isWorn {
            frame.say(frame.definition.text.firstTakingOff(item.name))
            frame.with { _ = $0.state.wornItems.remove(id) }
        }
        frame.with { scratch in
            // Dropped while boarded in a cargo vehicle, things land in the
            // hull, not on the ground sliding past below. Capacity is not
            // enforced on this implicit path — `putIn` remains the gate.
            let vehicle = Visibility.boardedVehicle(
                definition: frame.definition, state: scratch.state)
            if let vehicle, frame.definition.items[vehicle]?.isContainer == true {
                scratch.state.place(id, .inside(vehicle))
            } else {
                scratch.state.place(id, .room(scratch.state.playerLocation))
            }
            scratch.state.touched.insert(id)
        }
        frame.say(frame.definition.text.dropped)
    }

    private static func wear(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        if item.isWorn {
            try refuse(frame.definition.text.alreadyWearing)
        }
        guard item.isHeld else {
            try refuse(frame.definition.text.notHolding)
        }
        guard frame.definition.items[item.id]?.isWearable == true else {
            try refuse(frame.definition.text.cantWear)
        }
        let id = item.id
        frame.with { _ = $0.state.wornItems.insert(id) }
        frame.say(frame.definition.text.putOn(item.name))
    }

    private static func doff(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard item.isWorn else {
            try refuse(frame.definition.text.notWearing)
        }
        let id = item.id
        frame.with { _ = $0.state.wornItems.remove(id) }
        frame.say(frame.definition.text.takeOff(item.name))
    }

    private static func putOn(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard let surface = command.indirectObject else {
            try refuse(frame.definition.text.didntUnderstand)
        }
        guard item.isHeld else {
            try refuse(frame.definition.text.notHolding)
        }
        if item == surface {
            try refuse(frame.definition.text.cantPutOnItself)
        }
        guard frame.definition.items[surface.id]?.isSurface == true else {
            try refuse(frame.definition.text.cantPutOnThat)
        }
        guard isReachable(surface.id, frame: frame) else {
            try refuse(frame.definition.text.cantReach(surface.name))
        }
        let id = item.id
        let surfaceID = surface.id
        if frame.with({ isOrContains($0.state.containment(), surfaceID, id) }) {
            try refuse(frame.definition.text.cantPutOntoOwnContents(item.name))
        }
        if item.isWorn {
            frame.say(frame.definition.text.firstTakingOff(item.name))
            frame.with { _ = $0.state.wornItems.remove(id) }
        }
        frame.with { scratch in
            scratch.state.place(id, .on(surfaceID))
            scratch.state.touched.insert(id)
        }
        frame.say(frame.definition.text.putItemOn(item.name, surface.name))
    }

    private static func putIn(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard let container = command.indirectObject else {
            try refuse(frame.definition.text.didntUnderstand)
        }
        guard item.isHeld else {
            try refuse(frame.definition.text.notHolding)
        }
        if item == container {
            try refuse(frame.definition.text.cantPutInItself)
        }
        guard frame.definition.items[container.id]?.isContainer == true else {
            try refuse(frame.definition.text.cantPutInThat)
        }
        guard isReachable(container.id, frame: frame) else {
            try refuse(frame.definition.text.cantReach(container.name))
        }
        guard container.isOpen else {
            try refuse(frame.definition.text.closedContainer(container.name))
        }
        let id = item.id
        let containerID = container.id
        if frame.with({ isOrContains($0.state.containment(), containerID, id) }) {
            try refuse(frame.definition.text.cantPutInsideOwnContents(item.name))
        }
        if let capacity = frame.definition.items[containerID]?.capacity {
            let occupants = frame.with { scratch in
                scratch.state.containment().inContainer[containerID]?.count ?? 0
            }
            guard occupants < capacity else {
                try refuse(frame.definition.text.noRoom)
            }
        }
        if item.isWorn {
            frame.say(frame.definition.text.firstTakingOff(item.name))
            frame.with { _ = $0.state.wornItems.remove(id) }
        }
        frame.with { scratch in
            scratch.state.place(id, .inside(containerID))
            scratch.state.touched.insert(id)
        }
        frame.say(frame.definition.text.putItemIn(item.name, container.name))
    }

    /// True if `candidate` is `target` itself, or sits somewhere inside
    /// `target`'s containment subtree (on a surface or inside a container,
    /// to any depth) — the shape a `putIn` cycle would take. Guards against
    /// putting a container into itself or into one of its own contents.
    private static func isOrContains(
        _ index: ContainmentIndex, _ candidate: EntityID, _ target: EntityID
    ) -> Bool {
        if candidate == target { return true }
        var frontier = [target]
        var seen: Set<EntityID> = []
        while let id = frontier.popLast() {
            guard seen.insert(id).inserted else { continue }
            for childID in index.children(of: id) {
                if childID == candidate { return true }
                frontier.append(childID)
            }
        }
        return false
    }

    /// Names of the perceivable items directly inside `container`, sorted for
    /// stable listings — the one query behind both `open`'s reveal line and
    /// `lookIn`'s contents report.
    private static func perceivableContents(
        of container: EntityID, in scratch: inout Scratch, frame: TurnFrame
    ) -> [String] {
        (scratch.state.containment().inContainer[container] ?? [])
            .filter { Visibility.isPerceivable($0, definition: frame.definition, state: scratch.state) }
            .map { frame.definition.items[$0]?.name ?? $0.raw }
    }

    private static func open(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard frame.definition.items[id]?.isOpenable == true else {
            try refuse(frame.definition.text.cantOpenThat)
        }
        guard isReachable(id, frame: frame) else {
            try refuse(frame.definition.text.cantReach(item.name))
        }
        if item.isLocked {
            try refuse(frame.definition.text.locked(item.name))
        }
        if item.isOpen {
            try refuse(frame.definition.text.alreadyOpen)
        }
        let contents = frame.with { scratch -> [String] in
            scratch.state.openItems.insert(id)
            return perceivableContents(of: id, in: &scratch, frame: frame)
        }
        if contents.isEmpty {
            frame.say(frame.definition.text.opened)
        } else {
            frame.say(frame.definition.text.openingReveals(item.name, contents))
        }
    }

    private static func close(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard frame.definition.items[id]?.isOpenable == true else {
            try refuse(frame.definition.text.cantCloseThat)
        }
        guard isReachable(id, frame: frame) else {
            try refuse(frame.definition.text.cantReach(item.name))
        }
        guard item.isOpen else {
            try refuse(frame.definition.text.alreadyClosed)
        }
        frame.with { _ = $0.state.openItems.remove(id) }
        frame.say(frame.definition.text.closed)
    }

    private static func lock(_ command: Command, frame: TurnFrame) throws {
        try setLocked(command, frame: frame, to: true)
    }

    private static func unlock(_ command: Command, frame: TurnFrame) throws {
        try setLocked(command, frame: frame, to: false)
    }

    /// Shared body of `lock`/`unlock`: the guards are identical, only the
    /// polarity, refusal texts, and set operation differ.
    private static func setLocked(_ command: Command, frame: TurnFrame, to locked: Bool) throws {
        let item = try requireDirectObject(command)
        guard let key = command.indirectObject else {
            try refuse(frame.definition.text.didntUnderstand)
        }
        let id = item.id
        guard frame.definition.items[id]?.isLockable == true else {
            try refuse(locked ? frame.definition.text.cantLockThat : frame.definition.text.cantUnlockThat)
        }
        guard isReachable(id, frame: frame) else {
            try refuse(frame.definition.text.cantReach(item.name))
        }
        guard item.isLocked != locked else {
            try refuse(locked ? frame.definition.text.alreadyLocked : frame.definition.text.alreadyUnlocked)
        }
        guard key.isHeld else {
            try refuse(frame.definition.text.keyNotHeld(key.name))
        }
        guard frame.definition.items[id]?.lockKey == key.id else {
            try refuse(frame.definition.text.wrongKey)
        }
        frame.with { scratch in
            if locked {
                _ = scratch.state.lockedItems.insert(id)
            } else {
                _ = scratch.state.lockedItems.remove(id)
            }
        }
        frame.say(locked ? frame.definition.text.lockedMessage : frame.definition.text.unlockedMessage)
    }

    private static func lookIn(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard frame.definition.items[id]?.isContainer == true else {
            try refuse(frame.definition.text.cantSeeAnySuchThing)
        }
        guard isReachable(id, frame: frame) else {
            try refuse(frame.definition.text.cantReach(item.name))
        }
        if frame.definition.items[id]?.isOpenable == true, !item.isOpen,
            frame.definition.items[id]?.isTransparent != true
        {
            try refuse(frame.definition.text.closedContainer(item.name))
        }
        let contents = frame.with { perceivableContents(of: id, in: &$0, frame: frame) }
        if contents.isEmpty {
            frame.say(frame.definition.text.emptyContainer(item.name))
        } else {
            frame.say(frame.definition.text.inTheContainer(item.name, contents))
        }
    }

    private static func push(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        guard isReachable(item.id, frame: frame) else {
            try refuse(frame.definition.text.cantReach(item.name))
        }
        frame.say(frame.definition.text.cantMoveThat)
    }

    // MARK: - Light

    private static func turnOn(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        let definition = frame.definition
        guard definition.items[id]?.isLightSource == true else {
            try refuse(definition.text.cantTurnOnThat)
        }
        guard isReachable(id, frame: frame) else {
            try refuse(definition.text.cantReach(item.name))
        }
        if item.isLit {
            try refuse(definition.text.alreadyOn)
        }
        // Capture darkness before the light changes: lighting up a dark room
        // is the classic "the room is revealed" moment and earns a full
        // description in the same turn.
        let wasDark = frame.with {
            Visibility.isDark(
                at: $0.state.playerLocation, definition: definition, state: $0.state)
        }
        frame.with { scratch in
            scratch.state.litItems.insert(id)
            scratch.state.touched.insert(id)
        }
        frame.say(definition.text.nowOn(item.name))
        let isDarkNow = frame.with {
            Visibility.isDark(
                at: $0.state.playerLocation, definition: definition, state: $0.state)
        }
        if wasDark && !isDarkNow {
            RoomDescriber.describeCurrentLocation(mode: .look, frame: frame)
        }
    }

    private static func turnOff(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        let definition = frame.definition
        guard definition.items[id]?.isLightSource == true else {
            try refuse(definition.text.cantTurnOffThat)
        }
        guard isReachable(id, frame: frame) else {
            try refuse(definition.text.cantReach(item.name))
        }
        guard item.isLit else {
            try refuse(definition.text.alreadyOff)
        }
        frame.with { scratch in
            scratch.state.litItems.remove(id)
            scratch.state.touched.insert(id)
        }
        frame.say(definition.text.nowOff(item.name))
        // Announce sudden darkness — the counterpart of the reveal above.
        let isDarkNow = frame.with {
            Visibility.isDark(
                at: $0.state.playerLocation, definition: definition, state: $0.state)
        }
        if isDarkNow {
            frame.say(definition.text.nowDark)
        }
    }

    // MARK: - Movement & perception

    private static func go(_ command: Command, frame: TurnFrame) throws {
        guard let direction = command.direction else {
            try refuse(frame.definition.text.whichWay)
        }
        let here = frame.with { $0.state.playerLocation }
        switch frame.definition.exits[here]?[direction] {
        case nil:
            try refuse(frame.definition.text.cantGoThatWay)
        case .blocked(let message):
            try refuse(message)
        case .to(let destination):
            try enter(destination, frame: frame)
        case .door(let destination, let doorID):
            // A hidden door isn't there yet: behave as if the exit doesn't
            // exist until it's revealed. Once revealed, a closed door blocks
            // (its locked state only surfaces when the player tries to OPEN it).
            let (revealed, isOpen, name) = frame.with { scratch -> (Bool, Bool, String) in
                (
                    Visibility.isPerceivable(doorID, definition: frame.definition, state: scratch.state),
                    Visibility.isOpen(doorID, definition: frame.definition, state: scratch.state),
                    frame.definition.items[doorID]?.name ?? doorID.raw
                )
            }
            guard revealed else { try refuse(frame.definition.text.cantGoThatWay) }
            guard isOpen else { try refuse(frame.definition.text.closedContainer(name)) }
            try enter(destination, frame: frame)
        case .conditional(let destination, let condition, let blocked):
            // Evaluate the gate inside the live frame so its closure sees the
            // current turn's state (globals, proxies) via `Ctx.current`.
            guard condition() else { try refuse(blocked) }
            try enter(destination, frame: frame)
        }
    }

    /// Moves the player into `destination`, running its onEnter rules and then
    /// describing the room. Shared by every passable exit kind. A boarded
    /// vehicle rides along in the same mutation — and its cargo with it,
    /// since cargo placements (`.inside(vehicle)`) never mention the room.
    private static func enter(_ destination: EntityID, frame: TurnFrame) throws {
        frame.with { scratch in
            let vehicle = Visibility.boardedVehicle(
                definition: frame.definition, state: scratch.state)
            scratch.state.playerLocation = destination
            if let vehicle {
                scratch.state.place(vehicle, .room(destination))
            }
        }
        for rule in frame.definition.rules.locationOnEnter[destination] ?? [] {
            try rule.body()
        }
        RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
    }

    private static func board(_ command: Command, frame: TurnFrame) throws {
        let item = try requireDirectObject(command)
        let id = item.id
        guard frame.definition.items[id]?.isEnterable == true else {
            try refuse(frame.definition.text.cantEnterThat)
        }
        let (currentVehicle, placement, here) = frame.with {
            scratch -> (EntityID?, Placement?, EntityID) in
            (
                Visibility.boardedVehicle(definition: frame.definition, state: scratch.state),
                scratch.state.placements[id],
                scratch.state.playerLocation
            )
        }
        if currentVehicle == id {
            try refuse(frame.definition.text.alreadyInVehicle(item.name))
        }
        if let currentVehicle {
            try refuse(frame.definition.text.mustExitFirst(frame.displayName(of: currentVehicle)))
        }
        if placement == .heldBy(.player) {
            try refuse(frame.definition.text.cantEnterCarried)
        }
        guard placement == .room(here) else {
            try refuse(frame.definition.text.cantReach(item.name))
        }
        frame.with { scratch in
            scratch.state.playerVehicle = id
            scratch.state.touched.insert(id)
        }
        frame.say(frame.definition.text.boarded(item.name))
    }

    private static func disembark(_ command: Command, frame: TurnFrame) throws {
        let vehicle = frame.with {
            Visibility.boardedVehicle(definition: frame.definition, state: $0.state)
        }
        guard let vehicle else {
            try refuse(frame.definition.text.notInVehicle)
        }
        if let named = command.directObject, named.id != vehicle {
            try refuse(frame.definition.text.notInThat(named.name))
        }
        frame.with { $0.state.playerVehicle = nil }
        frame.say(frame.definition.text.disembarked(frame.displayName(of: vehicle)))
    }

    private static func examine(_ command: Command, frame: TurnFrame) throws {
        try describeItem(command, frame: frame) { frame.definition.text.nothingSpecial($0.name) }
    }

    private static func read(_ command: Command, frame: TurnFrame) throws {
        try describeItem(command, frame: frame) { _ in frame.definition.text.nothingWritten }
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
            (scratch.state.containment().held[.player] ?? [])
                .map { id in
                    frame.definition.text.inventoryLine(
                        frame.definition.items[id]?.name ?? id.raw,
                        scratch.state.wornItems.contains(id))
                }
        }
        if held.isEmpty {
            frame.say(frame.definition.text.emptyHanded)
        } else {
            frame.say(([frame.definition.text.carrying] + held).joined(separator: "\n"))
        }
    }

    // MARK: - Meta

    /// Also used by the pipeline's end-of-game epilogue, so the score-report
    /// format lives in exactly one place.
    static func score(_ frame: TurnFrame) {
        let line = frame.with { scratch in
            frame.definition.text.scoreLine(
                scratch.state.score,
                frame.definition.maxScore,
                scratch.state.moves)
        }
        frame.say(line)
    }

    private static func version(_ frame: TurnFrame) {
        frame.say(
            frame.definition.text.banner(frame.definition.title, frame.definition.tagline))
    }

    private static func quit(_ frame: TurnFrame) {
        // The pipeline's end-of-game epilogue reports the score.
        frame.with { $0.state.status = .quit }
    }

    private static func requireDirectObject(_ command: Command) throws -> Item {
        guard let item = command.directObject else {
            // The parser supplies objects for object-bearing rules; this is a
            // safety net, not a player-facing path.
            try refuse(Ctx.current.definition.text.didntUnderstand)
        }
        return item
    }

    /// Whether `id` is currently reachable by the player — the stricter set
    /// than parser scope (which is *visible* items, and so also admits a
    /// closed transparent container's contents).
    private static func isReachable(_ id: EntityID, frame: TurnFrame) -> Bool {
        let (here, index, state) = frame.with {
            ($0.state.playerLocation, $0.state.containment(), $0.state)
        }
        return Visibility.reachableItems(
            at: here, definition: frame.definition, state: state, index: index
        )
        .contains(id)
    }
}

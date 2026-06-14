import Synchronization

/// The mutable surface of one turn.
struct Scratch: Sendable {
    var state: WorldState
    var output: [String] = []
    var command: Command?
    var isLive = true
}

/// The per-turn context every proxy reads and writes through.
///
/// Created inside `GameWorld.perform`, bound via `@TaskLocal`, and killed
/// before the turn commits. The `Mutex` exists to satisfy `TaskLocal`'s
/// `Sendable` requirement without `@unchecked`; all access is serialized by
/// the actor, so it is uncontended in practice.
final class TurnFrame: Sendable {
    let definition: GameDefinition
    private let box: Mutex<Scratch>

    init(definition: GameDefinition, state: WorldState, command: Command? = nil) {
        self.definition = definition
        self.box = Mutex(Scratch(state: state, command: command))
    }

    var isAlive: Bool {
        box.withLock { $0.isLive }
    }

    /// Flips the frame dead and returns its final contents for committing.
    func retire() -> Scratch {
        box.withLock { scratch in
            scratch.isLive = false
            return scratch
        }
    }

    func with<R: Sendable>(_ body: (inout Scratch) -> R) -> R {
        box.withLock { scratch in
            body(&scratch)
        }
    }

    // MARK: - Proxy support

    func id(for token: RefToken, describing kind: String) -> EntityID {
        guard let id = definition.registry.id(for: token) else {
            fatalError(
                """
                Gnusto: this \(kind) is not part of the running game. Entities \
                must be declared as stored properties of your Game type so the \
                bootstrap can discover them; a \(kind) constructed inline has \
                no identity in the world.
                """)
        }
        return id
    }

    func location(for id: EntityID) -> Location {
        guard let location = definition.registry.locations[id] else {
            fatalError("Gnusto: no location named \"\(id)\" exists in this game.")
        }
        return location
    }

    /// The declared display name of any entity.
    func displayName(of id: EntityID) -> String {
        definition.items[id]?.name
            ?? definition.locations[id]?.name
            ?? id.raw
    }

    /// The current description of any entity: the runtime override if one
    /// has been assigned, else the declared text.
    func describedText(of id: EntityID) -> String {
        with { $0.state.descriptionOverrides[id] }
            ?? definition.items[id]?.description
            ?? definition.locations[id]?.description
            ?? ""
    }

    var command: Command {
        guard let command = with({ $0.command }) else {
            fatalError(
                """
                Gnusto: `command` is only available inside rule bodies while \
                the engine is performing a player command.
                """)
        }
        return command
    }

    func say(_ text: String) {
        with { $0.output.append(text) }
    }
}

enum Ctx {
    @TaskLocal static var frame: TurnFrame?

    /// The live frame, or a clear diagnostic about why there isn't one.
    static var current: TurnFrame {
        guard let frame else {
            fatalError(
                """
                Gnusto: live world state was accessed outside a game turn. \
                Properties like `isLit`, `score`, and @Global values are only \
                available inside rule bodies while the engine is running a \
                command.
                """)
        }
        guard frame.isAlive else {
            fatalError(
                """
                Gnusto: a rule closure outlived its turn. World state was \
                accessed after the turn committed — typically from a Task or \
                escaping closure spawned inside a rule body. Rule bodies must \
                do all their work synchronously.
                """)
        }
        return frame
    }
}

import Synchronization

/// The mutable surface of one turn.
struct Scratch: Sendable {
    var state: WorldState
    var output: [String] = []
    var command: Command?
    var isLive = true
    /// True while a stage 1–3 `before` rule body is executing — the only
    /// context `proceed()` may be called from.
    var inBeforeRule = false
    /// Set once the stage-4 default action has run, whether via the
    /// pipeline itself or a `proceed()` call from a `before` rule. Guards
    /// against running it twice and tells the pipeline to skip its own
    /// stage-4 step after a `proceed()`.
    var defaultRan = false
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

    /// A declared custom trait of any entity, or `nil` if it has none by that
    /// key. Custom traits are immutable definition data, so no lock is taken.
    func customTrait(_ key: String, of id: EntityID) -> StateValue? {
        definition.items[id]?.customTraits[key]
            ?? definition.locations[id]?.customTraits[key]
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

    /// Runs the stage-4 default action for the current command immediately,
    /// on behalf of `proceed()`. Only valid from inside a `before` rule body,
    /// and only once per turn; both are programmer errors, not player-facing
    /// conditions, so they trap.
    func proceedToDefaultAction() throws {
        let (inBeforeRule, alreadyRan) = with { scratch in
            (scratch.inBeforeRule, scratch.defaultRan)
        }
        guard inBeforeRule else {
            fatalError(
                """
                Gnusto: proceed() was called outside a `before` rule. It runs \
                the stage-4 default action early, so it only makes sense from \
                a rule that runs ahead of that stage — not from an `after` or \
                each-turn rule, and not from the default action itself.
                """)
        }
        guard !alreadyRan else {
            fatalError(
                """
                Gnusto: proceed() was called twice in the same turn. The \
                stage-4 default action already ran; calling it again would run \
                it a second time.
                """)
        }
        with { $0.defaultRan = true }
        try DefaultActions.run(command, frame: self)
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

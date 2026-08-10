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
    /// Set when stage 4 found nothing to answer the command with. The turn
    /// prints a line that says nothing happened, so it costs what nothing
    /// costs: no each-turn rules, no timers, no move.
    var unhandled = false
    /// How many `describe { }` / `presence { }` closures are on the stack —
    /// see ``Reentry/liveText``. Nesting, not calls per turn: a room described
    /// once a turn for twenty turns never leaves 1.
    var liveTextDepth = 0
    /// How many ``enter(_:)`` moves are on the stack — see ``Reentry/walk``.
    var walkDepth = 0
}

/// The two seams at which the engine calls code the author wrote, and so the
/// two at which that code can call back into the engine calling it.
///
/// They are counted apart because a level of one costs twenty times a level of
/// the other, and one cap covering both would have to be the smaller — see
/// ``Reentry/cap``.
enum Reentry: Sendable {
    /// A `describe { }` or `presence { }` closure, called from inside the room
    /// describer. Anything the closure calls that describes — including
    /// `describeSurroundings()`, `arrive(at:)`, or simply reading the entity's
    /// own `description` — lands back here.
    case liveText
    /// ``enter(_:)`` and the `onEnter` rules it runs, one of which may enter
    /// again.
    case walk

    /// Where this seam keeps its count on the turn's ``Scratch``.
    var depth: WritableKeyPath<Scratch, Int> {
        switch self {
        case .liveText: \.liveTextDepth
        case .walk: \.walkDepth
        }
    }

    /// How far the engine may re-enter itself here before it stops believing
    /// the author meant it.
    ///
    /// Both numbers are bracketed by measurement, because a guard against a
    /// stack overflow is worth nothing if the stack gets there first. The
    /// ceiling is what a Swift Testing cooperative thread's 512 KB affords in a
    /// debug build on macOS arm64 — the tightest case the engine runs in, and
    /// the one issue #223 was reported from. A shipped game's 8 MB main thread
    /// and any release build reach far deeper.
    ///
    /// | Seam | Real content | Overflows at | Cap |
    /// |---|---|---|---|
    /// | ``liveText`` | 1–2 | 10 | 8 |
    /// | ``walk`` | 1 | 216 | 32 |
    ///
    /// The floor comes from instrumenting every ``TurnFrame/nested(_:within:_:)``
    /// call across the whole suite — 1,479 tests over seven games, Dungeon and
    /// Zork 1 included — which found nothing deeper than 2, and that only in the
    /// describer. The gap between 10 and 216 is why these are two numbers rather
    /// than one: a single cap would have to be the smaller, and would ration the
    /// cheap seam by the expensive seam's ceiling.
    ///
    /// Why a ``liveText`` level costs twenty times a ``walk`` one is *not*
    /// established here — 512 KB over ten levels is some 50 KB a level, which is
    /// more than the describer's own locals plausibly account for, so the cost
    /// is somewhere in the cycle rather than in any line this comment could
    /// name. Both figures are measurements, not derivations. Raising
    /// ``liveText`` past 9 restores the original crash under `swift test`;
    /// whoever wants more headroom should find and cut that per-level cost
    /// first, then re-measure and move this.
    var cap: Int {
        switch self {
        case .liveText: 8
        case .walk: 32
        }
    }

    /// The complaint for a re-entry past ``cap``, or nil while there is nothing
    /// to complain about.
    ///
    /// Split out from the trap so the threshold and the wording can be asserted
    /// in-process: a `fatalError` cannot be caught, and the suite has no
    /// exit-code harness. Same shape as ``StackReport/line(for:game:)``.
    ///
    /// - Parameters:
    ///   - depth: the nesting level just entered.
    ///   - entity: what is being described or entered, evaluated only past the
    ///     cap so the ordinary case pays nothing to name it.
    /// - Returns: the message to trap with, or nil when the depth is allowed.
    func diagnostic(depth: Int, entity: @autoclosure () -> String) -> String? {
        guard depth > cap else { return nil }
        let shape =
            switch self {
            case .liveText:
                """
                A `describe { }` or `presence { }` closure called back into the \
                describer that is running it — by calling \
                `describeSurroundings()` or `arrive(at:)`, or by reading the \
                entity's own `description`. The closure's job is to return the \
                text; printing it is the describer's, and it is already doing it.
                """
            case .walk:
                """
                An `onEnter` rule called `enter(_:)` on the room it is already \
                entering. Move the player *out* of a room from its rules, never \
                into it.
                """
            }
        return "Gnusto: \(entity()) re-entered the engine \(depth) levels deep. \(shape)"
    }
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

    /// The entity's name behind its definite article — "the troll", or
    /// "Mrs. Vane" for a `properName`. What every stock line that names one
    /// thing is handed.
    func definiteName(of id: EntityID) -> String {
        GameText.definite(displayName(of: id), proper: isProperName(id))
    }

    /// The entity's name behind its indefinite article — "a troll", or
    /// "Mrs. Vane" for a `properName`. What the room and inventory listings
    /// are handed.
    func indefiniteName(of id: EntityID) -> String {
        GameText.indefinite(
            displayName(of: id), proper: isProperName(id), plural: isPlural(id))
    }

    /// The entity behind its definite article *and* its number — what the stock
    /// lines whose verb has to agree with it are handed.
    func definiteNoun(of id: EntityID) -> GameText.Noun {
        GameText.Noun(definiteName(of: id), plural: isPlural(id))
    }

    /// Whether the entity's name is a proper name. Locations are never
    /// articled by the engine, so only items carry the trait.
    func isProperName(_ id: EntityID) -> Bool {
        definition.items[id]?.isProperName == true
    }

    /// Whether the entity's name is grammatically plural.
    func isPlural(_ id: EntityID) -> Bool {
        definition.items[id]?.isPlural == true
    }

    /// A declared custom trait of any entity, or `nil` if it has none by that
    /// key. Custom traits are immutable definition data, so no lock is taken.
    func customTrait(_ key: String, of id: EntityID) -> StateValue? {
        definition.items[id]?.customTraits[key]
            ?? definition.locations[id]?.customTraits[key]
    }

    /// The current description of any entity: the runtime override if one
    /// has been assigned, else the live `describe { … }` rule result if one
    /// was declared, else the static declared text.
    ///
    /// The closure is called outside `with { … }` — it typically captures
    /// proxies or `@Global`s that resolve via `Ctx.current`, which takes the
    /// frame lock itself, so calling it while already holding the lock would
    /// deadlock.
    func describedText(of id: EntityID) -> String {
        if let override = with({ $0.state.descriptionOverrides[id] }) {
            return override
        }
        if let dynamic = definition.rules.itemDescribe[id]
            ?? definition.rules.locationDescribe[id]
        {
            // Guarded here rather than in the describer, because this is the
            // seam: the closure runs from inside the call that is producing the
            // text, so `describeSurroundings()`, `arrive(at:)` and a plain read
            // of `description` all land back on this line. See `Reentry`.
            return nested(.liveText, within: id) { dynamic() }
        }
        return definition.items[id]?.description
            ?? definition.locations[id]?.description
            ?? ""
    }

    /// The current standing-presence line of an entity: the live
    /// `presence { … }` rule result if one was declared, else the static
    /// `firstSight(…)` trait, else nil.
    ///
    /// Called outside `with { … }` for the same reason as `describedText`.
    func presenceText(of id: EntityID) -> String? {
        // Asked of every listed thing, its nested contents included, so the
        // empty-table skip is worth the line: most games declare no `presence`
        // rule at all, and hashing the key costs the same either way. Same
        // shape as `Visibility.reachRuleAllows`.
        if !definition.rules.itemPresence.isEmpty,
            let dynamic = definition.rules.itemPresence[id]
        {
            // The same seam as `describedText`, for the same reason.
            return nested(.liveText, within: id) { dynamic() }
        }
        return definition.items[id]?.firstSight
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
    /// conditions, so they trap. Setting `defaultRan` here is also what tells
    /// the pipeline's stage 1–3 sequence (see `GameWorld.runBefore`) to skip
    /// every before-phase still ahead of the calling rule — see `proceed()`'s
    /// doc comment for the full behavior.
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

    // MARK: - Re-entry

    /// Runs `body` one level deeper into `seam`, trapping rather than
    /// overflowing the stack if the author's code has re-entered the engine
    /// that is calling it.
    ///
    /// Depth is the only thing to count here. The engine's other runaway guard,
    /// `Visibility.collect`, carries a `visited` set against a containment
    /// *data* cycle — but describing the same room twice, or leaving it and
    /// walking back, is legitimate. There is no identity to dedupe on.
    ///
    /// - Parameters:
    ///   - seam: which re-entrant seam this is, and so which cap applies.
    ///   - entity: what is being described or entered, named in the trap.
    ///   - body: the work to run one level down.
    /// - Returns: whatever `body` returned.
    func nested<R>(_ seam: Reentry, within entity: EntityID, _ body: () throws -> R) rethrows -> R {
        let depth = with { scratch -> Int in
            scratch[keyPath: seam.depth] += 1
            return scratch[keyPath: seam.depth]
        }
        // Outside any `with { … }`, and a `defer` rather than a trailing line:
        // `body` may throw — an `onEnter` that dies or refuses is ordinary — and
        // a depth left raised would trap a later turn for a turn that ended.
        // The lock is not held across `body` either, since `frame.with { }`
        // wraps a non-recursive `Mutex` and rule bodies re-enter it freely; see
        // `Location.resolved` for the same note about id resolution.
        defer { with { $0[keyPath: seam.depth] -= 1 } }
        // `displayName` is inside the autoclosure, so naming the entity is paid
        // for only by the turn that traps.
        if let diagnostic = seam.diagnostic(depth: depth, entity: displayName(of: entity)) {
            fatalError(diagnostic)
        }
        return try body()
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

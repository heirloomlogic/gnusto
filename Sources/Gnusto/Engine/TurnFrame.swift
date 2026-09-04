import Synchronization

/// The mutable surface of one turn.
struct Scratch: Sendable {
    var state: WorldState
    var output: [String] = []
    /// Every sentence this turn has said, for ``TurnFrame/sayOnceThisTurn(_:)``
    /// to check itself against. A separate ledger because `output` is a render
    /// buffer and not a record: ``GameWorld/label(outputFrom:as:frame:)``
    /// rewrites a multi-object run's entries into one joined line, and a
    /// sentence folded into that line would stop being findable.
    var said: Set<String> = []
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
    /// The world as it stood at the close of this turn, *before* the move
    /// counter advanced — or nil on a turn that never advanced it.
    ///
    /// The status footer's four standard fields are read *after* the counter
    /// moves, and that is right: `moves=` is the count the turn left behind
    /// and `turn=cost` is the delta that says so. A **contributed** field is
    /// the opposite kind of fact. `Clock.now` is a function of `moves`, so
    /// every rule, `describe` block, action and timer in the turn read the
    /// hour one tick below the committed count — and a field sampled after
    /// the increment named a minute in which not one word of the turn was
    /// written. Issue #280: the footer said `time=5:32 pm` over a wristwatch
    /// that said 5:30, on every cost turn, all evening.
    ///
    /// It lives here rather than on the actor so that it cannot outlive the
    /// turn that took it. ``GameWorld/commit(_:)`` adopts whatever the
    /// retiring frame carries, which means a frame that never ran
    /// `finishTurn` — the opening, UNDO, RESTART, RESTORE — carries nil and
    /// *clears the previous sample by committing*. There is no list of entry
    /// points for a later turn path to fall off the end of.
    var statusFieldState: WorldState?

    /// Every room this turn put the player in, in the order it put them there.
    ///
    /// A turn is free to stand the player in a room and move them out of it
    /// again before the status line is next read, and the status line is what
    /// the play-test session records — so a room occupied only *inside* a turn
    /// was invisible to coverage. ``GameWorld/roomsOccupied`` is where this is
    /// merged, in ``GameWorld/commit(_:)``, and carries the account of why the
    /// tally exists and why it does not live on `WorldState`.
    ///
    /// Filled only by ``walkPlayer(to:)`` and ``teleportPlayer(to:)`` below,
    /// which are the two moves a turn has, and not deduped: a turn's list runs
    /// to a couple of entries and `commit` dedupes against the session-long
    /// tally anyway, so a second check here would only be the same check twice.
    /// A turn that never moved the player leaves this empty rather than naming
    /// the room they stood in throughout; that room is on every status line the
    /// session already reads.
    var roomsOccupied: [EntityID] = []

    /// The player walks into `room` — ``WorldState/setPlayerLocation(walkingTo:)``,
    /// with the occupancy noted.
    ///
    /// Turn-scoped code moves the player through this pair rather than through
    /// the state's own funnels, which is what lets ``roomsOccupied`` be
    /// complete without `WorldState` carrying anything it would then have to
    /// serialize.
    ///
    /// - Parameter room: the room the player ends up in.
    mutating func walkPlayer(to room: EntityID) {
        state.setPlayerLocation(walkingTo: room)
        roomsOccupied.append(room)
    }

    /// The player is put down in `room` —
    /// ``WorldState/setPlayerLocation(placingAt:)``, with the occupancy noted.
    /// The walk's twin; see ``walkPlayer(to:)``.
    ///
    /// - Parameter room: the room the player ends up in.
    mutating func teleportPlayer(to room: EntityID) {
        state.setPlayerLocation(placingAt: room)
        roomsOccupied.append(room)
    }
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
    ///
    /// The "overflows at" column is the *recorded* ceiling; the *enforced* one
    /// is `ReentryGuardTests.liveTextCapFiresBeforeTheStackDoes` and its walk
    /// twin, which run each runaway for real in a child process and fail if the
    /// stack arrives before the cap. Move a number here and they are what tells
    /// you whether the margin survived.
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
    /// in-process, a `fatalError` being uncatchable. Same shape as
    /// ``StackReport/line(for:game:)``. That the trap it feeds is actually
    /// reached — and reached before the stack runs out — is asserted separately,
    /// by running the runaway in a child process; see `ReentryGuardTests`.
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

    /// No exit test, deliberately: this is a registry invariant, not an
    /// authoring mistake. Every id reaching it came from the registry that would
    /// have to have lost it, so no fixture arranges the failure without first
    /// breaking the bootstrap — and an author never reads this message. #229.
    func location(for id: EntityID) -> Location {
        guard let location = definition.registry.locations[id] else {
            fatalError("Gnusto: no location named \"\(id)\" exists in this game.")
        }
        return location
    }

    /// The declared display name of any entity.
    func displayName(of id: EntityID) -> String {
        definition.items[id]?.name ?? definition.locationName(of: id)
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

    /// The entity behind its *indefinite* article and its number, for a line
    /// whose joke is the generality — `V-ATTACK`'s "but fighting a rubber
    /// raft?" reads as an appraisal of raft-fighting where the definite article
    /// just repeats the command back.
    func indefiniteNoun(of id: EntityID) -> GameText.Noun {
        GameText.Noun(indefiniteName(of: id), plural: isPlural(id))
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
        with { scratch in
            scratch.output.append(text)
            scratch.said.insert(text)
        }
    }

    /// ``say(_:)``, unless this turn has already said exactly `text`.
    func sayOnceThisTurn(_ text: String) {
        with { scratch in
            guard scratch.said.insert(text).inserted else { return }
            scratch.output.append(text)
        }
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

    /// The content bundle whose rule body, action body or timer body is
    /// currently running — `nil` for the game's own. Bound by `Bootstrap`
    /// around every body it files for a bundle, so a timer helper inside
    /// resolves a bare timer name against its owner's declarations first.
    @TaskLocal static var namespace: String?

    /// Runs `body` with `namespace` bound as the owning bundle. A `nil`
    /// namespace (the game's own bodies) binds nothing.
    static func owned<T>(_ namespace: String?, _ body: () throws -> T) rethrows -> T {
        guard let namespace else { return try body() }
        return try $namespace.withValue(namespace, operation: body)
    }

    /// The live frame, or a clear diagnostic about why there isn't one.
    ///
    /// Two ways to arrive with no frame to hand, and they want different
    /// sentences: there was never one bound, or there was and it has since been
    /// retired. The second names a `Task` specifically, because a `Task` is the
    /// only thing that reaches it. ``frame`` is a `@TaskLocal`, so an
    /// unstructured `Task { }` copies the binding at creation and still holds a
    /// turn the parent has long since committed; `Task.detached` and a dispatch
    /// queue inherit nothing and land on the first guard instead.
    ///
    /// An escaping closure stashed in one turn and called in the next reaches
    /// **neither** — every proxy re-reads `Ctx.current` at use time, so the
    /// closure resolves against the turn that calls it, reads live state, and
    /// quietly reports the wrong turn's world. That is a real mistake the engine
    /// cannot see, and naming it here would only send an author looking for it
    /// in the one case where it isn't what happened. `StashGame` pins the
    /// behavior down instead.
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
                Gnusto: a Task spawned inside a rule body outlived its turn — \
                it read world state after the turn committed. An unstructured \
                `Task { }` carries the turn it was created in, and that turn is \
                over. Rule bodies must do all their work synchronously.
                """)
        }
        return frame
    }
}

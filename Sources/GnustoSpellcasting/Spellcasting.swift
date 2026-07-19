import Gnusto

extension Intent {
    /// Recover spent magical energy: `rest` (or `meditate`) restores the pool
    /// to full. Owned by the spellcasting system so any game that adds it gets
    /// the verb for free.
    #verb("rest", ["rest"], ["meditate"])
}

/// A reusable spellcasting layer covering the common RPG magic paradigms —
/// at-will cantrips, memorized ("Vancian") spells, an energy/points pool, and
/// one-shot scrolls — over a single, uniform notion of a spell.
///
/// A spell's identity is its own `Intent` (declared with `#verb`, like Zork's
/// magic words); the game writes each spell's *effect* as an ordinary rule body
/// and registers it with a ``SpellCost`` that decides availability and cost.
/// The system owns only the mutable, save-safe state the paradigms need — the
/// finite spell memory and the energy pool — as `@Global`s, so both survive
/// save/restore and undo automatically.
///
/// ```swift
/// let magic = Spellcasting(memorySlots: 3, maxMana: 12)
///
/// extension Intent {
///     #verb("spark",  ["spark"],  ["cast", "spark"])
///     #verb("ignite", ["ignite"], ["cast", "ignite"], ["cast", "ignite", "at", .directObject])
/// }
///
/// var content: GameContents { magic }              // seeds the pools, adds `rest`
/// var verbs: [SyntaxRule] { [.spark, .ignite] }    // teach the parser the words
/// var actions: [IntentAction] {
///     magic.spell(.spark, cost: .cantrip) { say("A harmless spark leaps from your hand.") }
///     magic.spell(.ignite, cost: .energy(4)) { … the effect … }
/// }
/// ```
///
/// Casting order is **gate → effect → pay**: availability is checked, then the
/// effect runs (and may itself refuse, via `require`/`reply`), and only a
/// successful effect pays the cost — so a refused cast never consumes a
/// memorized spell, energy, or scroll.
public struct Spellcasting: GameContent {
    /// The spells currently held in memory. A wrapper struct so the
    /// `GlobalValue` conformance is owned here rather than declared on a
    /// standard-library type.
    struct Prepared: Codable, Sendable, GlobalValue {
        var names: Set<String> = []
    }

    /// The finite spell memory: which spells are prepared right now.
    @Global var prepared = Prepared()
    /// The magical-energy pool, seeded to `maxMana` and refilled by `rest`.
    @Global var mana: Int

    /// How many spells can be held in memory at once.
    public let memorySlots: Int
    /// The full magical-energy pool `rest` restores to.
    public let maxMana: Int

    /// Creates a spellcasting layer.
    ///
    /// - Parameters:
    ///   - memorySlots: how many spells can be memorized at once (default 3).
    ///   - maxMana: the full magical-energy pool, and the starting amount
    ///     (default 12).
    public init(memorySlots: Int = 3, maxMana: Int = 12) {
        self.memorySlots = memorySlots
        self.maxMana = maxMana
        self._mana = Global(wrappedValue: maxMana)
    }

    public var verbs: [SyntaxRule] { [.rest] }

    public var actions: [IntentAction] {
        action(.rest) {
            try require(
                mana < maxMana,
                else: "Your magical energy is already at its peak.")
            mana = maxMana
            say("You still your thoughts, and your magical energy wells back up to full.")
        }
    }

    /// Registers one spell: the stage-4 behavior that casting its `intent`
    /// performs, and — for a ``SpellCost/prepared(book:)`` spell — the behavior
    /// of memorizing it via `prepareIntent`. Splice the result into the game's
    /// `actions` block.
    ///
    /// - Parameters:
    ///   - intent: the spell's own intent (its castable identity).
    ///   - cost: how the spell becomes available and what casting it costs. A
    ///     `.prepared` cost carries its own memorize intent, so the memorize
    ///     behavior is registered automatically.
    ///   - effect: the spell's world-effect, run after the availability gate
    ///     passes. It may refuse with `require`/`reply`; a refusal aborts the
    ///     cast before any cost is paid.
    /// - Returns: the spell's cast action, plus its memorize action when
    ///   prepared.
    public func spell(
        _ intent: Intent,
        cost: SpellCost,
        effect: @escaping @Sendable () throws -> Void
    ) -> [IntentAction] {
        var built = [castAction(intent, cost: cost, effect: effect)]
        if case .prepared(let book, let learnVia) = cost {
            built.append(prepareAction(learnVia, spell: intent, book: book))
        }
        return built
    }

    /// The cast handler: gate on availability, run the effect, then pay.
    private func castAction(
        _ intent: Intent,
        cost: SpellCost,
        effect: @escaping @Sendable () throws -> Void
    ) -> IntentAction {
        let name = intent.raw
        return action(intent) {
            switch cost {
            case .cantrip:
                break
            case .prepared:
                try require(
                    prepared.names.contains(name),
                    else: "You don't have the \(name) spell prepared.")
            case .energy(let amount):
                try require(
                    mana >= amount,
                    else: "You lack the magical energy to cast \(name).")
            case .scroll(let scroll):
                try require(
                    scroll.isHeld,
                    else: "You have no scroll of \(name) to read from.")
            }

            try effect()

            switch cost {
            case .cantrip:
                break
            case .prepared:
                prepared.names.remove(name)
            case .energy(let amount):
                mana -= amount
            case .scroll(let scroll):
                scroll.vanish()
            }
        }
    }

    /// The memorize handler for a prepared spell: gate on free memory (and the
    /// spellbook, when required), then commit the spell to memory.
    private func prepareAction(_ prepareIntent: Intent, spell: Intent, book: Item?) -> IntentAction {
        let name = spell.raw
        return action(prepareIntent) {
            try require(
                !prepared.names.contains(name),
                else: "You already have \(name) firmly in mind.")
            try require(
                prepared.names.count < memorySlots,
                else: "Your mind can hold no more spells; cast one before learning another.")
            if let book {
                try require(
                    book.isHeld,
                    else: "You need your spellbook in hand to memorize \(name).")
            }
            prepared.names.insert(name)
            say("You fix the \(name) spell in your memory.")
        }
    }
}

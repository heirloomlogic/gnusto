import Gnusto

extension Intent {
    /// Report the caster's state: `spells` (or `magic`) lists what is held in
    /// memory and how much magical energy remains.
    #verb("spells", ["spells"], ["magic"])
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
/// var content: GameContents { magic }              // seeds the pools, claims `rest`
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

    /// The system's own voice — every line the mechanics print, from the
    /// refusals at the availability gate to the `spells` report. A spell's
    /// *effect* is the game's prose and never passes through here. Override
    /// lines at init to re-skin.
    ///
    /// The lines about one spell take its name as a ``GameText/Word``, and the
    /// two report lines take a ``SpellList`` and an ``Energy``, so a line whose
    /// whole content is what it was handed cannot be written as a sentence that
    /// leaves it out.
    public struct Text: Sendable {
        /// `rest` with the pool already full.
        public var alreadyRested: GameText.Line<GameText.Nothing> =
            "Your magical energy is already at its peak."
        /// `rest` refilling the pool.
        public var rested: GameText.Line<GameText.Nothing> =
            "You still your thoughts, and your magical energy wells back up to full."
        /// The `spells` report when nothing is held in mind.
        public var noSpellsHeld: GameText.Line<GameText.Nothing> = "You hold no spells in mind."
        /// The `spells` report's list of what is held in mind.
        public var spellsHeld: GameText.Line<SpellList> = .naming { "You hold in mind: \($0)." }
        /// The `spells` report's energy line.
        public var energy: GameText.Line<Energy> = .naming {
            "Your magical energy stands at \($0.current) of \($0.maximum)."
        }
        /// Casting a prepared spell that is not in memory.
        public var notPrepared: GameText.Line<GameText.Word> = .naming {
            "You don't have the \($0.word) spell prepared."
        }
        /// Casting an energy spell the pool cannot pay for.
        public var noEnergy: GameText.Line<GameText.Word> = .naming {
            "You lack the magical energy to cast \($0)."
        }
        /// Casting a scroll spell with no scroll in hand.
        public var noScroll: GameText.Line<GameText.Word> = .naming {
            "You have no scroll of \($0) to read from."
        }
        /// Memorizing a spell already held in mind.
        public var alreadyMemorized: GameText.Line<GameText.Word> = .naming {
            "You already have \($0) firmly in mind."
        }
        /// Memorizing with every slot full.
        public var memoryFull: GameText.Line<GameText.Nothing> =
            "Your mind can hold no more spells; cast one before learning another."
        /// Memorizing a book spell without the book.
        public var spellbookNeeded: GameText.Line<GameText.Word> = .naming {
            "You need your spellbook in hand to memorize \($0)."
        }
        /// Memorizing a spell.
        public var memorized: GameText.Line<GameText.Word> = .naming {
            "You fix the \($0.word) spell in your memory."
        }

        /// Creates the table in the library's own voice; a game re-skins the
        /// lines it cares about and leaves the rest.
        public init() {}
    }

    /// What ``Text/spellsHeld`` is about: the names held in mind, sorted.
    /// Interpolating one prints them as an English list.
    public struct SpellList: NamedSubject, CustomStringConvertible {
        /// The names, sorted.
        public let names: [String]

        init(_ names: some Sequence<String>) { self.names = names.sorted() }

        /// The names as an English list, so interpolating one prints them.
        public var description: String { GameText.list(names) }

        /// Two names, enough to render the line with its separator.
        public static var samples: [Self] { [Self(["glow", "seal"])] }
    }

    /// What ``Text/energy`` is about: the pool's level against its ceiling.
    public struct Energy: NamedSubject {
        /// Energy in the pool now.
        public let current: Int
        /// The full pool.
        public let maximum: Int

        /// One reading, enough to render the line.
        public static var samples: [Self] { [Self(current: 8, maximum: 12)] }
    }

    /// How many spells can be held in memory at once.
    public let memorySlots: Int
    /// The full magical-energy pool `rest` restores to.
    public let maxMana: Int
    /// This layer's lines.
    let text: Text

    /// Creates a spellcasting layer.
    ///
    /// - Parameters:
    ///   - memorySlots: how many spells can be memorized at once (default 3).
    ///   - maxMana: the full magical-energy pool, and the starting amount
    ///     (default 12).
    ///   - text: the system-voice lines, if the game re-voices any of them.
    public init(memorySlots: Int = 3, maxMana: Int = 12, text: Text = Text()) {
        self.memorySlots = memorySlots
        self.maxMana = maxMana
        self.text = text
        self._mana = Global(wrappedValue: maxMana)
    }

    /// The verbs the spellcasting layer contributes: `spells`/`magic`, which
    /// reports the caster's state, and `meditate` as a second word for the
    /// engine's own `rest`, which ``actions`` promotes to refilling the pool.
    public var verbs: [SyntaxRule] {
        .spells
        SyntaxRule("meditate", intent: .rest)
    }

    /// "spell" is filler in a casting game — `cast the glow spell` should
    /// parse as `cast glow` — so the layer adds it to the parser's noise set.
    public var noiseWords: [String] { ["spell"] }

    /// The default actions the spellcasting layer contributes: the `rest`
    /// handler that restores the energy pool to full, and the `spells` status
    /// report of memorized spells and remaining energy.
    public var actions: [IntentAction] {
        action(.rest) {
            try require(mana < maxMana, else: text.alreadyRested())
            mana = maxMana
            say(text.rested())
        }

        action(.spells) {
            let held = prepared.names
            say(held.isEmpty ? text.noSpellsHeld() : text.spellsHeld(SpellList(held)))
            say(text.energy(Energy(current: mana, maximum: maxMana)))
        }
    }

    /// Registers one spell: the stage-4 behavior that casting its `intent`
    /// performs, and — for a ``SpellCost/prepared(book:learnVia:)`` spell — the behavior
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
                try require(prepared.names.contains(name), else: text.notPrepared(GameText.Word(name)))
            case .energy(let amount):
                try require(mana >= amount, else: text.noEnergy(GameText.Word(name)))
            case .scroll(let scroll):
                try require(scroll.isHeld, else: text.noScroll(GameText.Word(name)))
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
            try require(!prepared.names.contains(name), else: text.alreadyMemorized(GameText.Word(name)))
            try require(prepared.names.count < memorySlots, else: text.memoryFull())
            if let book {
                try require(book.isHeld, else: text.spellbookNeeded(GameText.Word(name)))
            }
            prepared.names.insert(name)
            say(text.memorized(GameText.Word(name)))
        }
    }
}

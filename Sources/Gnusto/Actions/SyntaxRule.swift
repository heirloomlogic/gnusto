/// One row of the verb table: a verb token sequence, the sentence shape it
/// accepts, and the intent it produces. Data, not code — games can add rows
/// through their `verbs` block to teach the parser new player-typeable verbs.
public struct SyntaxRule: Sendable {
    /// The sentence shape a verb accepts after its verb tokens.
    public enum Slots: Sendable, Hashable {
        /// `look`, `inventory`, `score`
        case none
        /// `go north`
        case direction
        /// `take cloak`
        case direct
        /// `pick cloak up`, `take cloak off` — direct object then a trailing particle
        case directThenParticle(String)
        /// `put cloak on hook`, `hang cloak on hook`
        case directPrepIndirect(String)
    }

    let verb: [String]
    let slots: Slots
    let intent: Intent

    /// Builds a verb row: one or more verb tokens, the sentence shape that
    /// follows them, and the intent the parser emits on a match.
    public init(_ verb: String..., slots: Slots, intent: Intent) {
        self.verb = verb
        self.slots = slots
        self.intent = intent
    }

    /// Identifies a row by what the player types — verb tokens plus slot
    /// shape — so the merged table can dedupe and a game can reclaim a
    /// built-in verb (last-wins). Independent of the intent produced.
    struct Key: Hashable {
        let verb: [String]
        let slots: Slots
    }

    var key: Key { Key(verb: verb, slots: slots) }

    /// The structural word (particle or preposition) this rule's shape
    /// consumes, if any — vocabulary the parser must recognize.
    var extraWord: String? {
        switch slots {
        case .directThenParticle(let word), .directPrepIndirect(let word): word
        case .none, .direction, .direct: nil
        }
    }

    /// Specificity for rule-selection order: shapes that consume more
    /// structure are tried first.
    var specificity: Int {
        let slotWeight: Int
        switch slots {
        case .directPrepIndirect: slotWeight = 3
        case .directThenParticle: slotWeight = 2
        case .direct, .direction: slotWeight = 1
        case .none: slotWeight = 0
        }
        return verb.count * 10 + slotWeight
    }
}

extension SyntaxRule {
    /// The default verb table. Ordering within the table doesn't matter;
    /// the parser sorts candidate rules by specificity.
    static let standardTable: [SyntaxRule] = [
        // take
        .init("take", slots: .direct, intent: .take),
        .init("get", slots: .direct, intent: .take),
        .init("grab", slots: .direct, intent: .take),
        .init("hold", slots: .direct, intent: .take),
        .init("carry", slots: .direct, intent: .take),
        .init("pick", "up", slots: .direct, intent: .take),
        .init("pick", slots: .directThenParticle("up"), intent: .take),

        // drop
        .init("drop", slots: .direct, intent: .drop),
        .init("discard", slots: .direct, intent: .drop),
        .init("put", "down", slots: .direct, intent: .drop),
        .init("put", slots: .directThenParticle("down"), intent: .drop),

        // examine
        .init("examine", slots: .direct, intent: .examine),
        .init("x", slots: .direct, intent: .examine),
        .init("inspect", slots: .direct, intent: .examine),
        .init("look", "at", slots: .direct, intent: .examine),
        .init("l", "at", slots: .direct, intent: .examine),

        // read
        .init("read", slots: .direct, intent: .read),

        // wear
        .init("wear", slots: .direct, intent: .wear),
        .init("don", slots: .direct, intent: .wear),
        .init("put", "on", slots: .direct, intent: .wear),

        // doff
        .init("remove", slots: .direct, intent: .doff),
        .init("doff", slots: .direct, intent: .doff),
        .init("take", "off", slots: .direct, intent: .doff),
        .init("take", slots: .directThenParticle("off"), intent: .doff),

        // putOn
        .init("put", slots: .directPrepIndirect("on"), intent: .putOn),
        .init("put", slots: .directPrepIndirect("onto"), intent: .putOn),
        .init("hang", slots: .directPrepIndirect("on"), intent: .putOn),
        .init("place", slots: .directPrepIndirect("on"), intent: .putOn),

        // movement
        .init("go", slots: .direction, intent: .go),
        .init("walk", slots: .direction, intent: .go),
        .init("run", slots: .direction, intent: .go),

        // perception & meta
        .init("look", slots: .none, intent: .look),
        .init("l", slots: .none, intent: .look),
        .init("inventory", slots: .none, intent: .inventory),
        .init("inv", slots: .none, intent: .inventory),
        .init("i", slots: .none, intent: .inventory),
        .init("score", slots: .none, intent: .score),
        .init("quit", slots: .none, intent: .quit),
        .init("q", slots: .none, intent: .quit),
        .init("version", slots: .none, intent: .version),
    ]
}

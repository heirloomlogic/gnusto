import Gnusto

/// One row of an actor's topic table: what it answers to, what it needs, what
/// it teaches, and what the actor says.
///
/// Rows are tried in declaration order and the **first match wins**, so put
/// the more specific ones first — and, for a subject whose answer changes,
/// put the gated version above the ungated one.
public struct TopicEntry: Sendable {
    /// Each keyword as a set of normalized words; a row matches when *any*
    /// keyword's words are all present.
    let keywords: [[String]]
    /// Which of the table's intents this row answers, or `nil` for all.
    let intents: Set<Intent>?
    /// A fact the player must have learned for this row to fire.
    let required: Fact?
    /// A fact that retires this row once learned.
    let barred: Fact?
    /// A fact the player learns by hearing this row.
    let taught: Fact?
    /// What the row does.
    let body: @Sendable () throws -> Void
}

/// The result builder for a ``Conversation/topics(of:for:fallback:_:)`` block.
public typealias TopicBuilder = GnustoBuilder<TopicEntry>

/// A topic the actor answers with one line.
///
/// Matching is by keyword rather than by whole phrase: a keyword matches when
/// every word in it appears somewhere in what the player typed. So
/// `topic("murder", "body")` answers `ask butler about the murder`, `… about
/// that dreadful murder` and `… about the body` alike, while
/// `topic("murder weapon")` needs both words present.
///
/// - Parameters:
///   - keywords: the subjects this row answers to. Each is normalized exactly
///     as the parser normalizes player input, so articles, capitals and
///     punctuation don't matter.
///   - intents: restrict the row to some of the table's intents — `only:
///     [.tell]` for something the player can volunteer but not ask about.
///     Defaults to the whole table.
///   - required: a fact the player must already have learned. A row they
///     haven't earned is skipped, so a later row — or the fallback — answers
///     instead.
///   - barred: a fact that *retires* this row once learned. This is the lie
///     the actor stops telling.
///   - taught: a fact the player learns by hearing this answer.
///   - line: what the actor says. Ends the turn.
/// - Returns: the topic row.
public func topic(
    _ keywords: String...,
    only intents: [Intent]? = nil,
    knowing required: Fact? = nil,
    unless barred: Fact? = nil,
    learning taught: Fact? = nil,
    reply line: String
) -> TopicEntry {
    TopicEntry(
        keywords: keywords.map(Topic.normalize),
        intents: intents.map(Set.init),
        required: required,
        barred: barred,
        taught: taught,
        body: { try reply(line) })
}

/// A topic whose answer is a rule body — for a reply that also moves the
/// world: reveals a hidden thing, starts a fuse, changes a description.
///
/// The body runs like any rule body, so `say`, `reply`, `refuse` and world
/// mutation all behave normally. Unlike the `reply:` form it does **not** end
/// the turn unless the body says so.
///
/// - Parameters:
///   - keywords: the subjects this row answers to.
///   - intents: restrict the row to some of the table's intents.
///   - required: a fact the player must already have learned.
///   - barred: a fact that retires this row once learned.
///   - taught: a fact the player learns by reaching this row.
///   - body: what happens.
/// - Returns: the topic row.
public func topic(
    _ keywords: String...,
    only intents: [Intent]? = nil,
    knowing required: Fact? = nil,
    unless barred: Fact? = nil,
    learning taught: Fact? = nil,
    perform body: @escaping @Sendable () throws -> Void
) -> TopicEntry {
    TopicEntry(
        keywords: keywords.map(Topic.normalize),
        intents: intents.map(Set.init),
        required: required,
        barred: barred,
        taught: taught,
        body: body)
}

extension TopicEntry {
    /// Whether this row answers `topic` for `intent`, given what the player
    /// knows. Keyword matching is order-insensitive: every word of some
    /// keyword must appear among the words typed.
    ///
    /// - Parameters:
    ///   - topic: what the player asked about.
    ///   - intent: the conversation intent in play.
    ///   - known: the facts learned so far.
    /// - Returns: whether the row should answer.
    func answers(_ topic: Topic, for intent: Intent, knowing known: Set<String>) -> Bool {
        if let intents, !intents.contains(intent) { return false }
        if let required, !known.contains(required.raw) { return false }
        if let barred, known.contains(barred.raw) { return false }
        let spoken = Set(topic.words)
        return keywords.contains { keyword in
            !keyword.isEmpty && keyword.allSatisfy(spoken.contains)
        }
    }
}

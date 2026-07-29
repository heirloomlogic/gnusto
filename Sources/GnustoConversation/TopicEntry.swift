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
    /// A live condition on the world, checked at the moment the player asks.
    /// Facts are what the player has *worked out*; this is for the rest — a
    /// row that should only answer after the storm, or while the lamp is lit.
    let when: (@Sendable () -> Bool)?
    /// What the actor says when this row is raised a second time, overriding
    /// the table's own `again:`.
    let again: String?
    /// An author-chosen stable key for the heard set, or `nil` to derive one
    /// from the row's content.
    let identity: String?
    /// Whether a table-level `again:` retires this row. True for the `reply:`
    /// form, whose body only speaks; false for `perform:`, whose body can move
    /// the world and so opts in only by naming a line of its own.
    let inheritsTableAgain: Bool
    /// What the row does.
    let body: @Sendable () throws -> Void
}

/// The result builder for a ``Conversation/topics(of:for:fallback:again:_:)`` block.
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
///   - condition: a live condition on the world, checked when the player asks.
///     Use this where `knowing:`/`unless:` don't fit — those are for what the
///     player has worked out, this is for what is currently true.
///   - again: what the actor says when this is raised a second time,
///     overriding the table's own `again:`. See
///     ``Conversation/topics(of:for:fallback:again:_:)`` for the rules.
///   - id: a stable key for the heard set. Give one to a row whose keywords or
///     gates you expect to edit after release, to a row on an actor who shares
///     a display name with another, or to two rows that should retire
///     together. Also the only way to name a row for
///     ``Conversation/hasHeard(_:from:)`` and ``Conversation/unhear(_:from:)``.
///   - line: what the actor says. Ends the turn.
/// - Returns: the topic row.
public func topic(
    _ keywords: String...,
    only intents: [Intent]? = nil,
    knowing required: Fact? = nil,
    unless barred: Fact? = nil,
    learning taught: Fact? = nil,
    when condition: (@Sendable () -> Bool)? = nil,
    again: String? = nil,
    id: String? = nil,
    reply line: String
) -> TopicEntry {
    TopicEntry(
        keywords: keywords.map(Topic.normalize),
        intents: intents.map(Set.init),
        required: required,
        barred: barred,
        taught: taught,
        when: condition,
        again: again,
        identity: id,
        inheritsTableAgain: true,
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
///   - condition: a live condition on the world, checked when the player asks.
///   - again: what the actor says when this is raised a second time. Unlike
///     the `reply:` form, a `perform:` row does **not** inherit the table's
///     `again:` — its body can move the world, and a table default must never
///     be able to change what the world *does*, only what is *said*. Naming a
///     line here opts in, and on a repeat the body does not run.
///   - id: a stable key for the heard set.
///   - body: what happens.
/// - Returns: the topic row.
public func topic(
    _ keywords: String...,
    only intents: [Intent]? = nil,
    knowing required: Fact? = nil,
    unless barred: Fact? = nil,
    learning taught: Fact? = nil,
    when condition: (@Sendable () -> Bool)? = nil,
    again: String? = nil,
    id: String? = nil,
    perform body: @escaping @Sendable () throws -> Void
) -> TopicEntry {
    TopicEntry(
        keywords: keywords.map(Topic.normalize),
        intents: intents.map(Set.init),
        required: required,
        barred: barred,
        taught: taught,
        when: condition,
        again: again,
        identity: id,
        inheritsTableAgain: false,
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
        if let when, !when() { return false }
        let spoken = Set(topic.words)
        return keywords.contains { keyword in
            !keyword.isEmpty && keyword.allSatisfy(spoken.contains)
        }
    }

    /// This row's key in the heard set, scoped to the actor whose table it is
    /// in.
    ///
    /// Derived from the row's *content* — keywords, intents, gate facts —
    /// rather than its position, because the two fail in opposite directions.
    /// A position-derived key that shifts when an author inserts a row above
    /// makes a never-before-seen answer come out as "I already told you that":
    /// content lost, no diagnostic. A content-derived key that changes when an
    /// author edits a keyword makes the row look unheard, so the line plays
    /// once more — which is exactly the behaviour before this feature existed.
    /// It fails toward repeating, never toward swallowing. And reordering has
    /// to stay free, because reorder-by-specificity is how this layer is
    /// authored.
    ///
    /// The gate facts are in the key for a concrete reason: a lie and the
    /// confession that replaces it routinely share a keyword set and differ
    /// only by `unless:`/`knowing:`. Keying on keywords alone would collide,
    /// and hearing the lie would retire the confession before it was spoken.
    /// The reply text is deliberately *not* in the key, so fixing a typo in a
    /// shipped game doesn't un-retire every line in it.
    ///
    /// **The one thing content-keying cannot see is a `when:` closure.** The
    /// key records only whether a row *has* one, which is enough to tell a
    /// gated row from the ungated one that backs it up — the shape this is
    /// nearly always used in. Two rows on the same keywords that differ *only*
    /// in which condition they carry would share a flag; give one of them an
    /// `id:`.
    ///
    /// - Parameter actorName: the display name of the actor whose table this
    ///   row belongs to.
    /// - Returns: the heard-set key.
    func key(inTableOf actorName: String) -> String {
        // `\u{1F}`, `\u{1E}` and `\u{1D}` are the unit, record and group
        // separators — characters `Topic.normalize` strips and a display name
        // will not contain, so no field can bleed into the next. The keyword
        // list needs its own separator rather than a space: joining on a space
        // would make `topic("break in")` and `topic("break", "in")` the same
        // key, and the first of them heard would retire the other's answer
        // unspoken.
        if let identity {
            return "\(actorName)\u{1F}#\(identity)"
        }
        let subjects = keywords.map { $0.joined(separator: " ") }.sorted()
        let fields = [
            subjects.joined(separator: "\u{1D}"),
            intents.map { $0.map(\.raw).sorted().joined(separator: " ") } ?? "",
            required?.raw ?? "",
            barred?.raw ?? "",
            taught?.raw ?? "",
            when == nil ? "" : "when",
        ]
        return "\(actorName)\u{1F}\(fields.joined(separator: "\u{1E}"))"
    }
}

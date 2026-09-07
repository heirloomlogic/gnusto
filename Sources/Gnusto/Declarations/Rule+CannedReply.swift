// The per-entity stub line: one canned sentence, one verb, one thing.
//
// `GameText.StubReplies` re-skins a verb for a whole game — `text.stubs.burn`
// answers `burn` everywhere. This is the other half of that: the sentence *this
// lamp* says when *this verb* is tried on it, which every game before now wrote
// as a rule whose entire body was one `try reply(…)`.
//
// It is that rule, and nothing more. The factory assembles the same `.before`
// rule the closure spelling assembles, so it runs where a `before` rule runs
// (stage 3, ahead of the default action) and inherits exactly what a `before`
// rule inherits — including what it does *not* get, which is everything stage 4
// would have supplied: the reach guard, the `yourself`/`somebodyElse` guards
// and the object's rendered name. A game that wants those wants
// `text.stubs.<verb>` instead, and `StubVerbs.md` is where that choice is
// written down.
//
// `reply` and `refuse` throw the same interrupt; the two spellings exist so the
// declaration reads correctly, exactly as the free functions do. Neither is
// `say`, and that is the point: stage 4 *says* its stock line, so a rule that
// only said its own would print both.

extension Item {
    /// Answers the named intents on this item with one canned sentence.
    ///
    /// ```swift
    /// oilLamp.before(.burn, reply: "That is what it is for. Light it.")
    /// ladder.before(.climb, reply: .naming { "You can't climb onto \($0)." })
    /// basket.before(.take, reply: .init(Prose.basketFastened))
    /// ```
    ///
    /// The shorthand for `before(.burn) { try reply("…") }`, and the same rule:
    /// declared in a `rules` block, matched when the item is the direct object,
    /// the indirect object or the addressee, and stacked with any other rule on
    /// the same intent in declaration order.
    ///
    /// Use this spelling when the answer is *what happens instead*, and
    /// ``before(_:refuse:)-(Intent...,_)`` when it is *no, you can't*.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule answers. Name none to answer every
    ///     action targeting the item.
    ///   - line: the sentence. A string literal is a fixed line;
    ///     ``GameText/Line/naming(_:)`` builds one around the item's rendered
    ///     name, article and number.
    /// - Returns: the assembled rule.
    public func before(
        _ intents: Intent...,
        reply line: GameText.Line<GameText.Noun>
    ) -> Rule {
        before(intents, reply: line)
    }

    /// Blocks the named intents on this item with one canned complaint.
    ///
    /// ```swift
    /// chest.before(.take, refuse: "Brine-swollen, full of oil, and going nowhere.")
    /// oilCan.before(.pour, .empty, refuse: .init(Prose.oilHasOnePlaceToGo))
    /// ```
    ///
    /// ``before(_:reply:)-(Intent...,_)`` in every mechanical respect — see it
    /// for what the rule does and does not inherit. Two names, so that "no, you
    /// can't" and "here's what happens instead" read differently on the page.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule blocks. Name none to block every
    ///     action targeting the item.
    ///   - line: the complaint. A string literal is a fixed line;
    ///     ``GameText/Line/naming(_:)`` builds one around the item's rendered
    ///     name, article and number.
    /// - Returns: the assembled rule.
    public func before(
        _ intents: Intent...,
        refuse line: GameText.Line<GameText.Noun>
    ) -> Rule {
        before(intents, refuse: line)
    }

    /// The array-taking form the variadic factories and ``Actor``'s forwarders
    /// both come through, so an actor's intent list survives the hop.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule answers.
    ///   - line: the sentence.
    /// - Returns: the assembled rule.
    func before(_ intents: [Intent], reply line: GameText.Line<GameText.Noun>) -> Rule {
        Rule(
            scope: .item(token), phase: .before, intents: Set(intents),
            body: { try Gnusto.reply(line(self.definiteNoun)) })
    }

    /// The array-taking form the variadic factories and ``Actor``'s forwarders
    /// both come through, so an actor's intent list survives the hop.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule blocks.
    ///   - line: the complaint.
    /// - Returns: the assembled rule.
    func before(_ intents: [Intent], refuse line: GameText.Line<GameText.Noun>) -> Rule {
        Rule(
            scope: .item(token), phase: .before, intents: Set(intents),
            body: { try Gnusto.refuse(line(self.definiteNoun)) })
    }
}

extension Actor {
    /// Answers the named intents on this person with one canned sentence —
    /// ``Item/before(_:reply:)-(Intent...,_)``, asked of an actor.
    ///
    /// ```swift
    /// dungeonMaster.before(.greet, .give, reply: .init(Prose.masterSaysNothing))
    /// ```
    ///
    /// - Parameters:
    ///   - intents: the intents this rule answers. Name none to answer every
    ///     action targeting the actor.
    ///   - line: the sentence, fixed or built around the actor's rendered name.
    /// - Returns: the assembled rule.
    public func before(
        _ intents: Intent...,
        reply line: GameText.Line<GameText.Noun>
    ) -> Rule {
        asItem.before(intents, reply: line)
    }

    /// Blocks the named intents on this person with one canned complaint —
    /// ``Item/before(_:refuse:)-(Intent...,_)``, asked of an actor.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule blocks. Name none to block every
    ///     action targeting the actor.
    ///   - line: the complaint, fixed or built around the actor's rendered name.
    /// - Returns: the assembled rule.
    public func before(
        _ intents: Intent...,
        refuse line: GameText.Line<GameText.Noun>
    ) -> Rule {
        asItem.before(intents, refuse: line)
    }
}

extension Location {
    /// Answers the named intents attempted in this room with one canned
    /// sentence.
    ///
    /// ```swift
    /// stable.before(.smell, reply: "Hay, horse, and the ghost of a horse.")
    /// ```
    ///
    /// ``Item/before(_:reply:)-(Intent...,_)``, asked of a room, with one
    /// difference: the line is handed nothing. A room has no rendered name to
    /// build a sentence around — the engine articles items and never locations —
    /// so the choice here is between a fixed sentence and
    /// ``GameText/Line/live(_:)``, which assembles one at the moment it prints.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule answers. Name none to answer every
    ///     action attempted in the room.
    ///   - line: the sentence.
    /// - Returns: the assembled rule.
    public func before(
        _ intents: Intent...,
        reply line: GameText.Line<GameText.Nothing>
    ) -> Rule {
        Rule(
            scope: .location(token), phase: .before, intents: Set(intents),
            body: { try Gnusto.reply(line()) })
    }

    /// Blocks the named intents attempted in this room with one canned
    /// complaint.
    ///
    /// ```swift
    /// jetty.before(.swim, .dive, refuse: "The sea is coming to you anyway.")
    /// ```
    ///
    /// ``before(_:reply:)-(Intent...,_)`` in every mechanical respect, including
    /// that the line is handed nothing.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule blocks. Name none to block every
    ///     action attempted in the room.
    ///   - line: the complaint.
    /// - Returns: the assembled rule.
    public func before(
        _ intents: Intent...,
        refuse line: GameText.Line<GameText.Nothing>
    ) -> Rule {
        Rule(
            scope: .location(token), phase: .before, intents: Set(intents),
            body: { try Gnusto.refuse(line()) })
    }
}

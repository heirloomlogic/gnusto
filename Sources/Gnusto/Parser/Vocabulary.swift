/// The words an item answers to.
struct ItemLexicon: Sendable {
    var nouns: Set<String> = []
    var adjectives: Set<String> = []

    /// True when `tokens` is a valid way to refer to this item: every token
    /// is one of its words, and the final token is a noun.
    func matches(_ tokens: [String]) -> Bool {
        guard let last = tokens.last, nouns.contains(last) else { return false }
        return describes(tokens)
    }

    /// True when every token is one of this item's words, whether or not the
    /// phrase ends in a noun: `velvet` for the velvet cloak.
    ///
    /// The weaker question, and it is asked only once ``matches(_:)`` has
    /// found nothing anywhere in scope — a description is never allowed to
    /// beat a name. It is also why the two are separate rather than one
    /// relaxed test: `x velvet` should mean the velvet cloak in a cloakroom
    /// holding one velvet thing, and should ask which in a cloakroom holding
    /// two. Issue #445.
    func describes(_ tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return false }
        return tokens.allSatisfy { nouns.contains($0) || adjectives.contains($0) }
    }
}

/// Every word the game understands, assembled once at bootstrap from item
/// declarations and the verb table.
struct Vocabulary: Sendable {
    var itemLexicons: [EntityID: ItemLexicon] = [:]
    var displayNames: [EntityID: String] = [:]
    /// The items whose display name is a proper name. The parser's own lines
    /// name entities too — "Which do you mean: Mrs. Vane or Dr. Pike?" — and
    /// it has no frame to ask, so the article rule travels with the lexicon.
    var properNames: Set<EntityID> = []
    /// The items whose display name is grammatically plural, carried for the
    /// same reason and by the same argument as ``properNames``: the parser
    /// writes ``GameText/notTakingOrders``, that line's verb has to agree with
    /// the person it names, and the parser has no frame to ask. The number
    /// rule travels with the lexicon or it does not travel at all.
    var plurals: Set<EntityID> = []
    var verbWords: Set<String> = []
    var directions: [String: Direction] = [:]
    var prepositions: Set<String> = []
    var noiseWords: Set<String> = Vocabulary.defaultNoiseWords

    /// Filler the parser drops from every input line. Hoisted to a static so
    /// that anything normalizing author-written text the same way the parser
    /// normalizes player input — ``Topic/normalize(_:)`` — reads the one list
    /// rather than keeping a copy of it that can drift.
    ///
    /// `please` is here and `of` deliberately is not. Filler is stripped from
    /// the whole line before anything is matched, so a word the tables spell
    /// would become untypeable — and two core rows spell `of` (`get out of the
    /// car`, `take the coin out of the box`), while an item may own it outright
    /// (`cup of tea`, `Book of Spells`). The one place the word gets in the
    /// way is `take all of them`, and that is read where the multi-object
    /// keyword is read; see ``ParsedCommand/MultiObject/keyword(phrase:excluding:)``.
    static let defaultNoiseWords: Set<String> = [
        "the", "a", "an", "my", "that", "this", "some", "please",
    ]

    /// Words the parser claims for itself — pronouns and the multi-object
    /// keywords. They resolve before any item lexicon is consulted, so an
    /// item using one as a noun or synonym could never be referred to by it
    /// (the bootstrap warns).
    ///
    /// `him` and `her` are here for that last reason above all: a game used to
    /// have to spend a synonym on the word, which made the pronoun name that
    /// one person forever, whoever the player had spoken of since. What binds
    /// them now is the ``pronoun(_:)`` trait.
    static let reservedWords: Set<String> = ["it", "them", "him", "her", "all", "everything"]

    /// The words that join two object phrases: `take the bottle and the sack`.
    ///
    /// Deliberately neither noise nor reserved. Not noise, because dropping the
    /// word would *join* the two phrases rather than separate them. Not
    /// reserved, because an item is free to use it among its own words — the
    /// parser reads a phrase as a name before it ever reads it as a list, so
    /// `name("cup and saucer")` keeps answering to every word of itself.
    ///
    /// A `static let` rather than a per-game `var`, the way ``reservedWords``
    /// is and ``noiseWords`` isn't: filler varies by game and the bootstrap
    /// collects it, but nothing in the engine or the DSL lets a game name a
    /// conjunction of its own, and a settable property nobody sets is a lie
    /// about the surface.
    static let conjunctions: Set<String> = ["and"]

    /// The words that except objects from a group: `take all but the sword`.
    ///
    /// Claimed the way ``conjunctions`` are, and neither noise nor reserved for
    /// the same two reasons. Not noise, because dropping the word would fold
    /// the exception back into the group it was meant to leave out. Not
    /// reserved, because the parser only reads one as punctuation *behind a
    /// multi-object keyword* — and a keyword is itself a reserved word no item
    /// can answer to — so `name("last but one ticket")` keeps answering to
    /// every word of itself without needing a second pass to rescue it.
    static let exclusions: Set<String> = ["but", "except"]

    /// The words that claim the noun behind them: `x her leg`, `take his lamp`.
    ///
    /// Claimed the way ``conjunctions`` and ``exclusions`` are, and for the
    /// reason that keeps a word out of ``noiseWords``: noise is stripped from
    /// the whole line before anything is matched, and `her` stripped that way
    /// would take the pronoun down with the possessive. So the drop happens
    /// inside noun resolution instead, only in front of *more words*, and only
    /// once the phrase has failed to name anything on its own — a game is free
    /// to call something `his lordship`, and the name wins.
    ///
    /// The engine stores no possession, so the word is dropped rather than
    /// read: `take her lamp` in a room with one lamp means that lamp, whoever
    /// the player believes owns it. (`my` is a noise word already, which is the
    /// older half of the same idea; it is safe there because nothing means "my"
    /// on its own.)
    static let possessives: Set<String> = ["her", "his", "its", "their", "your", "our"]

    /// Spellings of a pattern's preposition that mean the same thing, mapped to
    /// the one the tables are written in.
    ///
    /// A preposition in a verb row is a bare ``SyntaxElement/word(_:)``, so
    /// `["look", "in", .directObject]` used to answer to `look in sack` and to
    /// nothing else — `look inside sack` died at candidate selection, before any
    /// of the parser's forgiving machinery ran. This table buys every row
    /// containing `in` or `on` its synonyms at once, which is what the
    /// alternative — a row per spelling — cannot do for a verb a game declares
    /// itself. Issue #269.
    ///
    /// It is consulted **only** where a pattern literal is compared to a token.
    /// Noun resolution never reads it, so a game may still name a thing
    /// `inside pocket`; the direction table never reads it, so a bare `inside`
    /// still travels. `out`/`outside` is deliberately absent — no row wants it,
    /// and every pair costs the candidate filter another word to canonicalize.
    static let literalSynonyms: [String: String] = [
        "inside": "in",
        "into": "in",
        "onto": "on",
        "upon": "on",
        "underneath": "under",
    ]

    /// The one spelling of `word` the tables are written in — itself, for
    /// everything that isn't a preposition with synonyms.
    ///
    /// Comparing canonical forms rather than asking "is either of these a
    /// synonym of the other" is what makes the table symmetric: a row written
    /// `into` accepts `in` exactly as one written `in` accepts `into`, because
    /// the table says which words mean the same thing and not which spelling an
    /// author happened to pick.
    ///
    /// - Parameter word: any literal or typed word.
    /// - Returns: its canonical spelling.
    static func canonical(_ word: String) -> String {
        literalSynonyms[word] ?? word
    }

    /// Whether a token is a way of typing a pattern's literal word.
    ///
    /// For the candidate filter, which asks this of every row on the table
    /// every turn, both sides are canonicalized in advance instead — see
    /// ``SyntaxRule/canonicalLeadingWords``.
    ///
    /// - Parameters:
    ///   - word: the literal as the pattern spells it.
    ///   - token: the word the player typed.
    /// - Returns: whether the two are the same preposition.
    static func literal(_ word: String, matches token: String) -> Bool {
        token == word || canonical(token) == canonical(word)
    }

    /// Every way of typing `word`, itself included — `in` yields `in`,
    /// `inside`, `into`.
    ///
    /// The bootstrap registers these alongside the literals a verb row actually
    /// spells, so that a word the parser will match is a word the parser admits
    /// to knowing, and a noise word that would make one untypeable is caught by
    /// the same diagnostic that catches the spelling the row was written in.
    ///
    /// - Parameter word: a literal from a verb pattern.
    /// - Returns: it and its synonyms.
    static func spellings(of word: String) -> Set<String> {
        let canonical = canonical(word)
        return Set(literalSynonyms.filter { $0.value == canonical }.keys)
            .union([word, canonical])
    }

    /// Every word in the game, flattened once at bootstrap so `knows` is a
    /// single set lookup (it runs per token on parse-failure paths).
    var allKnownWords: Set<String> = []

    /// Every word some item answers to as a *noun*, flattened in the same
    /// bootstrap pass. Separate from ``allKnownWords``, which also holds the
    /// adjectives — and the difference between the two is the whole question
    /// "does this phrase name something, or only describe it?", which the
    /// parser asks when it decides where a clarifying answer belongs.
    var itemNouns: Set<String> = []

    /// The verb words, sorted once at bootstrap — Tab-completion offers them
    /// every turn and the order never changes, so the sort is cached here
    /// rather than repeated per turn.
    var sortedVerbWords: [String] = []

    /// The direction words, sorted once at bootstrap — same rationale as
    /// `sortedVerbWords`.
    var sortedDirectionWords: [String] = []

    /// True if the word appears anywhere in the game's vocabulary.
    func knows(_ word: String) -> Bool {
        allKnownWords.contains(word)
    }

    /// The entity's display name, or its raw id when nothing declared one.
    ///
    /// - Parameter id: the entity to name.
    /// - Returns: the bare name, no article.
    func displayName(of id: EntityID) -> String {
        displayNames[id] ?? id.raw
    }

    /// The entity's name behind its definite article, or bare if it is a proper
    /// name — "the troll", "Mrs. Vane".
    ///
    /// Here rather than on each caller for the reason ``properNames`` gives:
    /// the article rule travels with the lexicon or it does not travel at all.
    /// The parser writes lines that name entities and has no frame to ask, and
    /// so does the play-test seam that reports which entity answered.
    ///
    /// - Parameter id: the entity to name.
    /// - Returns: the rendered noun phrase.
    func definiteName(of id: EntityID) -> String {
        GameText.definite(displayName(of: id), proper: properNames.contains(id))
    }

    /// Splits a phrase into words, the one way this engine splits anything:
    /// lowercased, a trailing possessive dropped, every other non-alphanumeric
    /// character a separator. `"Master's Spellbook"` yields
    /// `["master", "spellbook"]` and `"half-moon"` yields `["half", "moon"]`.
    ///
    /// Both sides go through here — the author's declarations at bootstrap and
    /// the player's typing in ``StandardParser/tokenize(_:)`` — because they
    /// have to agree on where one word ends and the next begins. When they
    /// didn't, a declared `master's` was a string no token could ever equal.
    ///
    /// The possessive is the one mark that carries a word rather than
    /// separating two, so it is dropped rather than split on. Only a `'s`
    /// ending a word: `don't` is still `["don", "t"]`.
    ///
    /// **The typographic apostrophe is folded to the ASCII one first**, because
    /// it is the same mark and only the keyboard disagrees: macOS substitutes
    /// `’` as you type, so `master’s` reached here as a word ending in a
    /// character this splitter treated as punctuation — `["master", "s"]`, with
    /// `s` then read as *south*. Folding here rather than at the tokenizer is
    /// what keeps both sides of the splitter in step: a declared `master’s` and
    /// a typed `master's` are the same word, and so are the other way round.
    ///
    /// Filler is *not* stripped here — the tokenizer drops noise words from
    /// what the player types, and a declaration made of nothing but filler is a
    /// bootstrap error rather than a silent nothing.
    ///
    /// - Parameter phrase: any text, author-written or player-typed.
    /// - Returns: its words, in order, possibly none.
    static func words(in phrase: String) -> [String] {
        String(phrase.lowercased().map { $0 == "\u{2019}" ? "'" : $0 })
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "'") })
            .flatMap { chunk in
                (chunk.hasSuffix("'s") ? chunk.dropLast(2) : chunk[...])
                    .split(separator: "'")
            }
            .map(String.init)
    }

    /// Called once at bootstrap, after all words are registered.
    ///
    /// Every set it fills is *reassigned* rather than added to, so calling it a
    /// second time answers for the lexicons as they stand rather than for their
    /// union with whatever they used to hold.
    mutating func finalize() {
        itemNouns = []
        allKnownWords =
            verbWords
            .union(directions.keys)
            .union(prepositions)
            .union(noiseWords)
            .union(Self.conjunctions)
            .union(Self.exclusions)
            .union(Self.possessives)
            .union(Self.reservedWords)
        for lexicon in itemLexicons.values {
            allKnownWords.formUnion(lexicon.nouns)
            allKnownWords.formUnion(lexicon.adjectives)
            itemNouns.formUnion(lexicon.nouns)
        }
        sortedVerbWords = verbWords.sorted()
        sortedDirectionWords = directions.keys.sorted()
    }

    static let standardDirections: [String: Direction] = [
        "north": .north, "n": .north,
        "south": .south, "s": .south,
        "east": .east, "e": .east,
        "west": .west, "w": .west,
        "northeast": .northeast, "ne": .northeast,
        "northwest": .northwest, "nw": .northwest,
        "southeast": .southeast, "se": .southeast,
        "southwest": .southwest, "sw": .southwest,
        "up": .up, "u": .up,
        "down": .down, "d": .down,
        "in": .in, "inside": .in,
        "out": .out, "outside": .out,
    ]
}

/// The words an item answers to.
struct ItemLexicon: Sendable {
    var nouns: Set<String> = []
    var adjectives: Set<String> = []

    /// True when `tokens` is a valid way to refer to this item: every token
    /// is one of its words, and the final token is a noun.
    func matches(_ tokens: [String]) -> Bool {
        guard let last = tokens.last, nouns.contains(last) else { return false }
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
    static let defaultNoiseWords: Set<String> = ["the", "a", "an", "my", "that", "this", "some"]

    /// Words the parser claims for itself — pronouns and the multi-object
    /// keywords. They resolve before any item lexicon is consulted, so an
    /// item using one as a noun or synonym could never be referred to by it
    /// (the bootstrap warns).
    static let reservedWords: Set<String> = ["it", "them", "all", "everything"]

    /// Every word in the game, flattened once at bootstrap so `knows` is a
    /// single set lookup (it runs per token on parse-failure paths).
    var allKnownWords: Set<String> = []

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
    /// Filler is *not* stripped here — the tokenizer drops noise words from
    /// what the player types, and a declaration made of nothing but filler is a
    /// bootstrap error rather than a silent nothing.
    ///
    /// - Parameter phrase: any text, author-written or player-typed.
    /// - Returns: its words, in order, possibly none.
    static func words(in phrase: String) -> [String] {
        phrase.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "'") })
            .flatMap { chunk in
                (chunk.hasSuffix("'s") ? chunk.dropLast(2) : chunk[...])
                    .split(separator: "'")
            }
            .map(String.init)
    }

    /// Called once at bootstrap, after all words are registered.
    mutating func finalize() {
        allKnownWords =
            verbWords
            .union(directions.keys)
            .union(prepositions)
            .union(noiseWords)
            .union(Self.reservedWords)
        for lexicon in itemLexicons.values {
            allKnownWords.formUnion(lexicon.nouns)
            allKnownWords.formUnion(lexicon.adjectives)
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

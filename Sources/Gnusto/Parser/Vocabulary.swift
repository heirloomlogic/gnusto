/// The words an item answers to.
struct ItemLexicon: Sendable {
    var nouns: Set<String> = []
    var adjectives: Set<String> = []

    init(nouns: Set<String> = [], adjectives: Set<String> = []) {
        self.nouns = nouns
        self.adjectives = adjectives
    }

    /// Decomposes an item's declarations into the words a player can type.
    ///
    /// A name or synonym is a *phrase*: its last word is the noun and the
    /// words ahead of it qualify that noun, so `"air-door"` answers to `door`
    /// and `air door`, and `"old works"` to `works` and `old works`. Declared
    /// adjectives are phrases too, and every word in one stands alone.
    ///
    /// Every phrase is split by `Vocabulary.words(in:)` — the parser's own
    /// splitter — which is what makes punctuation harmless here.
    init(name: String?, synonyms: [String], adjectives: [String]) {
        self.init()
        for phrase in synonyms {
            learn(phrase)
        }
        if let name {
            learn(name)
        }
        for phrase in adjectives {
            self.adjectives.formUnion(Vocabulary.words(in: phrase))
        }
    }

    /// Files one name-or-synonym phrase: last word noun, the rest adjectives.
    private mutating func learn(_ phrase: String) {
        let words = Vocabulary.words(in: phrase)
        guard let noun = words.last else { return }
        nouns.insert(noun)
        adjectives.formUnion(words.dropLast())
    }

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
    var verbWords: Set<String> = []
    var directions: [String: Direction] = [:]
    var prepositions: Set<String> = []
    var noiseWords: Set<String> = ["the", "a", "an", "my", "that", "this", "some"]

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

    /// The one rule for what counts as a word: any run of letters or digits,
    /// with every other character a separator.
    ///
    /// Both halves of the parser go through it — `StandardParser.tokenize`
    /// splitting the player's line, and `ItemLexicon.init(name:synonyms:adjectives:)`
    /// splitting what the game declared — so the two can never disagree about
    /// where a word ends. That shared rule is why `name("air-door")` answers to
    /// something: split identically on both sides, it registers `air` and
    /// `door`, and not a hyphenated token the tokenizer could never produce.
    static func words(in phrase: String) -> [String] {
        phrase.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
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

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
    var verbWords: Set<String> = []
    var directions: [String: Direction] = [:]
    var prepositions: Set<String> = []
    var noiseWords: Set<String> = ["the", "a", "an", "my", "that", "this", "some"]

    /// Every word in the game, flattened once at bootstrap so `knows` is a
    /// single set lookup (it runs per token on parse-failure paths).
    var allKnownWords: Set<String> = []

    /// True if the word appears anywhere in the game's vocabulary.
    func knows(_ word: String) -> Bool {
        allKnownWords.contains(word)
    }

    /// Called once at bootstrap, after all words are registered.
    mutating func finalize() {
        allKnownWords = verbWords
            .union(directions.keys)
            .union(prepositions)
            .union(noiseWords)
        for lexicon in itemLexicons.values {
            allKnownWords.formUnion(lexicon.nouns)
            allKnownWords.formUnion(lexicon.adjectives)
        }
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

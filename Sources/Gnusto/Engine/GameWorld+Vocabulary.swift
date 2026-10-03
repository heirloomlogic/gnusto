/// Every word the parser accepts at one moment, sorted by the job it does in a sentence.
///
/// A superset of ``CompletionCandidates``. Tab completion offers the words a player starts or ends a command with; a listener correcting a misheard line has to know that `the`, `with` and `under` are words too, or it will "correct" them. Built by ``GameWorld/vocabulary()``.
public struct WordsInScope: Sendable, Equatable {
    /// Whether the engine is waiting for a save or restore filename. While it is, the next line is a name, so consumers should ignore the word lists.
    public let expectsFilename: Bool
    /// Every verb the game knows, the engine-level ones (`undo`, `save`, `again`) included.
    public let verbs: [String]
    /// The nouns of everything the player can see now: things, people, and the doors on this room's exits.
    public let nouns: [String]
    /// The adjectives of the same things.
    public let adjectives: [String]
    /// Every direction word: `north`, `n`, `up`, `in`.
    public let directions: [String]
    /// The words that place a verb's second object: `in`, `on`, `with`, `under`.
    public let prepositions: [String]
    /// The words the parser drops or reads as grammar rather than as names: articles, `and`, `but`, `except`, pronouns, possessives, `all`.
    public let filler: [String]
}

extension GameWorld {
    /// Every word the parser accepts right now.
    ///
    /// It reads the world and changes nothing, so a front end may ask after every turn. The query runs inside a throwaway frame that it retires without committing. The shared visibility scope walk reads its state snapshot directly and remains pure.
    ///
    /// - Returns: the words, each list sorted and duplicate-free.
    public func vocabulary() -> WordsInScope {
        let scratch = TurnFrame(
            definition: definition, state: state, descriptionMode: .brief)
        defer { _ = scratch.retire() }

        return Ctx.$frame.withValue(scratch) {
            let vocabulary = definition.vocabulary
            var nouns: Set<String> = []
            var adjectives: Set<String> = []
            for id in currentScope(orders: false).visibleItems {
                guard let lexicon = vocabulary.itemLexicons[id] else { continue }
                nouns.formUnion(lexicon.nouns)
                adjectives.formUnion(lexicon.adjectives)
            }
            let filler = vocabulary.noiseWords
                .union(Vocabulary.reservedWords)
                .union(Vocabulary.conjunctions)
                .union(Vocabulary.exclusions)
                .union(Vocabulary.possessives)
            let expectsFilename: Bool
            switch pendingPrompt {
            case .saveFilename, .restoreFilename:
                expectsFilename = true
            default:
                expectsFilename = false
            }
            return WordsInScope(
                expectsFilename: expectsFilename,
                verbs: vocabulary.sortedVerbWords,
                nouns: nouns.sorted(),
                adjectives: adjectives.sorted(),
                directions: vocabulary.sortedDirectionWords,
                prepositions: vocabulary.prepositions.sorted(),
                filler: filler.sorted())
        }
    }
}

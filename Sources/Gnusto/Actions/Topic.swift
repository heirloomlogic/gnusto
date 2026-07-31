/// What the player wants to talk about: the words after "about", normalized
/// the way the parser normalizes everything else — lowercased, punctuation
/// dropped, filler stripped.
///
/// A topic is deliberately abstract. It names no entity, is never checked
/// against what is in the room, and may be something the game has never heard
/// of — which is the point: `ask the butler about zeppelins` reaches the
/// butler's rules and lets him shrug, rather than dying in the parser as
/// "You can't see any such thing."
///
/// ```swift
/// butler.before(.ask) {
///     guard let topic = command.topic else { return }
///     if topic.words.contains("murder") {
///         try reply("\"A dreadful business, sir.\"")
///     }
/// }
/// ```
///
/// The line as actually typed, punctuation and all, is still on
/// ``Command/rawInput`` for a game that wants to quote it back.
public struct Topic: Sendable, Hashable, CustomStringConvertible {
    /// The normalized words of the subject, in the order they were typed.
    public let words: [String]

    /// The words rejoined with single spaces: "the DEAD body!" reads back as
    /// "dead body".
    public var text: String { words.joined(separator: " ") }

    /// The subject as text, for interpolation and diagnostics.
    public var description: String { text }

    /// Builds a topic from already-normalized words. The parser does this;
    /// games rarely need to, though it is useful in tests and when a rule
    /// synthesizes a subject of its own.
    ///
    /// - Parameter words: the normalized words of the subject.
    public init(_ words: [String]) {
        self.words = words
    }

    /// Normalizes an author-written keyword exactly as the parser normalizes
    /// what the player typed, so a topic table can match the two word for
    /// word.
    ///
    /// Note this applies the parser's *default* filler list. A game that adds
    /// its own `noiseWords` will have them stripped from the player's input
    /// but not from a keyword here, so don't build one out of a word the game
    /// has declared as filler.
    ///
    /// - Parameter phrase: the keyword as the author wrote it.
    /// - Returns: its normalized words.
    public static func normalize(_ phrase: String) -> [String] {
        Vocabulary.words(in: phrase)
            .filter { !Vocabulary.defaultNoiseWords.contains($0) }
    }
}

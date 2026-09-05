/// What the parser made of one line, alongside what the turn printed.
///
/// It exists because the transcript is not a complete record of a turn. Two
/// facts in particular cannot be recovered from the text:
///
/// - **What was examined.** `examine` does not touch its object — the default
///   action calls `describeItem`, which only `say`s — so `isTouched` never
///   learns that the player looked. "Have I looked at this yet?" is otherwise
///   answerable only by re-reading the transcript and guessing which noun a
///   description belonged to.
/// - **Which words the game has never heard of.** The parse-failure line names
///   at most one word, and only on some paths. Matching the reply against
///   "You can't see any such thing" is a string-match on prose the game is
///   free to re-skin; asking the vocabulary is exact, and it answers for lines
///   that parsed as well as lines that didn't.
///
/// Built by `GameWorld.performAudited(_:)`, which is where the parse result is
/// still in hand.
struct TurnAudit: Sendable {
    /// True when the parser produced a command. False for a parse error, an
    /// open clarifying question, and for the line that answered an engine
    /// prompt — none of which named a verb.
    var understood: Bool = false

    /// The intent the line resolved to, or `nil` when it didn't resolve.
    var intent: Intent?

    /// The direct object the parser bound, as the parser bound it. A bare
    /// `hello` in a room with one person in it is *later* addressed to them by
    /// `GameWorld.run`; that fill-in happens after the parse and is not
    /// recorded here, because this is a record of what the player's words
    /// picked out.
    var directObject: EntityID?

    /// The indirect object the parser bound, if the pattern had one.
    var indirectObject: EntityID?

    /// The direction the line asked for, for a movement command.
    ///
    /// Here for the same reason as the rest of this record: which way somebody
    /// went is not recoverable from the prose. `n`, `north` and `go north` are
    /// one move and three spellings, an exit refused by a shut door prints text
    /// that names no direction at all, and a room description that mentions
    /// three ways out has to be matched against the ones actually taken. The
    /// parse knows; the transcript does not.
    var direction: Direction?

    /// Every token of the input the game's vocabulary does not know, in the
    /// order typed. Normally empty on a line that parsed, since the parser
    /// requires every token to be consumed.
    var unknownWords: [String] = []

    /// True when the line was consumed as the answer to an open engine prompt
    /// — a save/restore filename, or the post-death choice — rather than
    /// parsed as a command. Nothing else in the record is filled in.
    var answeredPrompt: Bool = false

    /// A line the parser never got a command out of.
    init(unknownWords: [String] = [], answeredPrompt: Bool = false) {
        self.unknownWords = unknownWords
        self.answeredPrompt = answeredPrompt
    }

    /// A line the parser did get a command out of.
    init(_ parsed: ParsedCommand, unknownWords: [String]) {
        self.understood = true
        self.intent = parsed.intent
        self.directObject = parsed.directObject
        self.indirectObject = parsed.indirectObject
        self.direction = parsed.direction
        self.unknownWords = unknownWords
    }
}

/// A canonical action the player can attempt. Games can mint their own
/// (`Intent("ring")`) and register verbs and default behavior for them.
public struct Intent: Hashable, Sendable {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public static let take = Intent("take")
    public static let drop = Intent("drop")
    public static let examine = Intent("examine")
    public static let read = Intent("read")
    public static let wear = Intent("wear")
    public static let doff = Intent("doff")
    public static let putOn = Intent("putOn")
    public static let go = Intent("go")
    public static let look = Intent("look")
    public static let inventory = Intent("inventory")
    public static let score = Intent("score")
    public static let quit = Intent("quit")
    public static let version = Intent("version")

    /// Meta intents talk to the game program, not the world: they skip all
    /// rules and don't consume a turn.
    static let metaIntents: Set<Intent> = [.score, .quit, .version]

    var isMeta: Bool { Intent.metaIntents.contains(self) }
}

/// A parsed player command, available inside rule bodies as `command`.
public struct Command: Sendable {
    public let intent: Intent
    public let directObject: Item?
    public let indirectObject: Item?
    public let preposition: String?
    public let direction: Direction?
    /// The verb word as typed ("hang"), for use in messages.
    public let verbPhrase: String
    public let rawInput: String

    init(
        intent: Intent,
        directObject: Item? = nil,
        indirectObject: Item? = nil,
        preposition: String? = nil,
        direction: Direction? = nil,
        verbPhrase: String,
        rawInput: String
    ) {
        self.intent = intent
        self.directObject = directObject
        self.indirectObject = indirectObject
        self.preposition = preposition
        self.direction = direction
        self.verbPhrase = verbPhrase
        self.rawInput = rawInput
    }
}

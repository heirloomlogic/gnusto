/// A canonical action the player can attempt. Games can mint their own
/// (`Intent("ring")`) and register verbs and default behavior for them.
public struct Intent: Hashable, Sendable {
    /// The intent's stable identifier.
    public let raw: String

    /// Creates an intent with the given identifier.
    public init(_ raw: String) {
        self.raw = raw
    }

    /// Take an item.
    public static let take = Intent("take")
    /// Drop an item.
    public static let drop = Intent("drop")
    /// Examine an item.
    public static let examine = Intent("examine")
    /// Read an item.
    public static let read = Intent("read")
    /// Wear an item.
    public static let wear = Intent("wear")
    /// Take off a worn item.
    public static let doff = Intent("doff")
    /// Put an item onto a surface.
    public static let putOn = Intent("putOn")
    /// Move in a direction.
    public static let go = Intent("go")
    /// Look at the current location.
    public static let look = Intent("look")
    /// List carried items.
    public static let inventory = Intent("inventory")
    /// Report the current score.
    public static let score = Intent("score")
    /// Quit the game.
    public static let quit = Intent("quit")
    /// Report the engine version.
    public static let version = Intent("version")

    /// Meta intents talk to the game program, not the world: they skip all
    /// rules and don't consume a turn.
    static let metaIntents: Set<Intent> = [.score, .quit, .version]

    var isMeta: Bool { Intent.metaIntents.contains(self) }
}

/// A parsed player command, available inside rule bodies as `command`.
public struct Command: Sendable {
    /// The action the player is attempting.
    public let intent: Intent
    /// The primary item the command acts on, if any.
    public let directObject: Item?
    /// The secondary item the command acts on, if any.
    public let indirectObject: Item?
    /// The preposition the player used, if any.
    public let preposition: String?
    /// The direction the player named, if any.
    public let direction: Direction?
    /// The verb word as typed ("hang"), for use in messages.
    public let verbPhrase: String
    /// The full line the player typed.
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

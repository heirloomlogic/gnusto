/// A canonical action the player can attempt. Games can mint their own —
/// most readably with `#verb`, or directly (`Intent("ring")`) — and register
/// verbs and default behavior for them.
public struct Intent: Hashable, Sendable {
    /// The intent's stable identifier.
    public let raw: String

    /// The verb rows that produce this intent, carried by `#verb`-declared
    /// intents so a `verbs` block can list the intent itself (`.ring`)
    /// instead of re-spelling its rows. Not part of the intent's identity:
    /// `Intent("ring")` in a rule matches a `#verb`-minted `.ring`.
    public let syntax: [SyntaxRule]

    /// Creates an intent with the given identifier. `#verb` expands to the
    /// form that carries verb rows; pass `syntax` directly only when building
    /// rows dynamically.
    ///
    /// - Parameters:
    ///   - raw: the intent's stable identifier.
    ///   - syntax: the verb rows that produce this intent, if any.
    public init(_ raw: String, syntax: [SyntaxRule] = []) {
        self.raw = raw
        self.syntax = syntax
    }

    /// Identity is the `raw` name alone — see `syntax`.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.raw == rhs.raw
    }

    /// Hashes the `raw` name alone, matching `==`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw)
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
    /// Put an item inside a container.
    public static let putIn = Intent("putIn")
    /// Open a container or door.
    public static let open = Intent("open")
    /// Close a container or door.
    public static let close = Intent("close")
    /// Lock an item with a key.
    public static let lock = Intent("lock")
    /// Unlock an item with a key.
    public static let unlock = Intent("unlock")
    /// Look inside a container.
    public static let lookIn = Intent("lookIn")
    /// Push an item.
    public static let push = Intent("push")
    /// Light a light source ("turn on", "light").
    public static let turnOn = Intent("turnOn")
    /// Extinguish a light source ("turn off", "extinguish", "blow out").
    public static let turnOff = Intent("turnOff")
    /// Move in a direction.
    public static let go = Intent("go")
    /// Get into an `enterable` item ("enter", "board", "get in").
    public static let board = Intent("board")
    /// Get out of the boarded item ("exit", "disembark", "get out").
    public static let disembark = Intent("disembark")
    /// Let a turn pass without acting ("wait", "z"). A normal turn: rules run
    /// and fuses/daemons tick — that's its whole point.
    public static let wait = Intent("wait")
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
    /// Reverse the last turn (engine-level; not overridable).
    public static let undo = Intent("undo")
    /// Rewind to the opening (engine-level; not overridable).
    public static let restart = Intent("restart")
    /// Write the world state to a file (engine-level; not overridable).
    public static let save = Intent("save")
    /// Read the world state back from a file (engine-level; not overridable).
    public static let restore = Intent("restore")

    /// Meta intents talk to the game program, not the world: they skip all
    /// rules and don't consume a turn.
    static let metaIntents: Set<Intent> = [
        .score, .quit, .version, .undo, .restart, .save, .restore,
    ]

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

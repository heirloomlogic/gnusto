/// The destination of an exit.
enum ExitTarget: Sendable {
    case to(EntityID)
    case blocked(String)
    /// An exit through a shared door item; passable only while the door is open.
    case door(to: EntityID, door: EntityID)
    /// An exit gated by a live condition evaluated at `go` time; when the
    /// condition is false the player is refused with `blocked`.
    case conditional(to: EntityID, condition: @Sendable () -> Bool, blocked: String)
}

/// The immutable, declared facts about a location.
struct LocationDefinition: Sendable {
    var name: String?
    var description: String?
    var inherentlyLit = true
    var customTraits: [String: StateValue] = [:]

    init(traits: [LocationTrait]) {
        for trait in traits {
            switch trait.kind {
            case .name(let text): name = text
            case .description(let text): description = text
            case .dark: inherentlyLit = false
            case .custom(let key, let value): customTraits[key] = value
            }
        }
    }
}

/// The immutable, declared facts about an item.
struct ItemDefinition: Sendable {
    var name: String?
    var description: String?
    var adjectives: [String] = []
    var synonyms: [String] = []
    var firstSight: String?
    var isWearable = false
    var isScenery = false
    var isSurface = false
    var isContainer = false
    var isOpenable = false
    var startsOpen = false
    var isTransparent = false
    var isLockable = false
    var startsUnlocked = false
    var capacity: Int?
    /// The resolved lock key, filled in by Bootstrap from the item's
    /// `lockedBy(_:)` map entry. `nil` for non-lockable items. That same entry
    /// also sets `isLockable`.
    var lockKey: EntityID?
    var isHidden = false
    var isLightSource = false
    var startsLit = false
    var isEnterable = false
    var customTraits: [String: StateValue] = [:]
    /// True when this entity was declared as an `Actor`. Set by Bootstrap
    /// after trait evaluation — actors share the item trait vocabulary, so
    /// there is no trait to switch on.
    var isActor = false

    /// Items are takable unless they're scenery — or people.
    var isTakable: Bool { !isScenery && !isActor }

    init(traits: [ItemTrait]) {
        for trait in traits {
            switch trait.kind {
            case .name(let text): name = text
            case .description(let text): description = text
            case .adjectives(let words): adjectives += words
            case .synonyms(let words): synonyms += words
            case .firstSight(let text): firstSight = text
            case .wearable: isWearable = true
            case .scenery: isScenery = true
            case .surface: isSurface = true
            case .container: isContainer = true
            case .openable: isOpenable = true
            case .startsOpen: startsOpen = true
            case .transparent: isTransparent = true
            case .startsUnlocked: startsUnlocked = true
            case .capacity(let n): capacity = n
            case .hidden: isHidden = true
            case .lightSource: isLightSource = true
            case .startsLit: startsLit = true
            case .enterable: isEnterable = true
            case .custom(let key, let value): customTraits[key] = value
            }
        }
    }
}

/// Maps tokens to the entity IDs inferred from property names, and back to
/// canonical proxies.
struct Registry: Sendable {
    var ids: [ObjectIdentifier: EntityID] = [:]
    var locations: [EntityID: Location] = [:]
    var items: [EntityID: Item] = [:]

    func id(for token: RefToken) -> EntityID? {
        ids[ObjectIdentifier(token)]
    }
}

/// Rules grouped by scope and phase for fast pipeline lookup.
struct RuleTable: Sendable {
    var itemBefore: [EntityID: [Rule]] = [:]
    var itemAfter: [EntityID: [Rule]] = [:]
    var locationBefore: [EntityID: [Rule]] = [:]
    var locationAfter: [EntityID: [Rule]] = [:]
    var locationBeforeEachTurn: [EntityID: [Rule]] = [:]
    var locationAfterEachTurn: [EntityID: [Rule]] = [:]
    var locationOnEnter: [EntityID: [Rule]] = [:]
    var worldBefore: [Rule] = []
    var worldAfter: [Rule] = []
    /// Live description closures declared via `item.describe { … }`. Consulted
    /// by `TurnFrame.describedText(of:)` after a runtime override and before a
    /// static `description(…)` trait.
    var itemDescribe: [EntityID: @Sendable () -> String] = [:]
    var locationDescribe: [EntityID: @Sendable () -> String] = [:]
}

/// Everything about a game that never changes during play. Built once at
/// bootstrap; the changing side lives in `WorldState`.
struct GameDefinition: Sendable {
    let title: String
    let tagline: String
    let intro: String
    let maxScore: Int
    /// The stock player-facing lines, as the game re-skinned them.
    let text: GameText
    let locations: [EntityID: LocationDefinition]
    let items: [EntityID: ItemDefinition]
    let exits: [EntityID: [Direction: ExitTarget]]
    let globalDefaults: [EntityID: StateValue]
    let playerStart: EntityID
    /// `var` so the bootstrap can install the rule table after evaluating the
    /// `rules` block inside a registration frame (which needs the rest of the
    /// definition to exist first).
    var rules: RuleTable
    /// Declared fuses and daemons by name; installed alongside `rules` for
    /// the same registration-frame reason. Schedule state (what's running,
    /// counts) lives in `WorldState`.
    var timers: [String: TimedEvent] = [:]
    let registry: Registry
    let vocabulary: Vocabulary
    let syntaxRules: [SyntaxRule]
    /// Stage-4 default actions supplied by the game and its bundles/plugins,
    /// keyed by intent. Consulted before the built-in switch in
    /// `DefaultActions.run`; an intent absent here falls through to the
    /// built-in behavior (or "I didn't understand" for an unknown intent).
    let actionOverrides: [Intent: IntentAction]
    /// Non-fatal bootstrap notes — e.g. a custom verb shadowing a built-in.
    /// Surfaced for tooling and tests; play proceeds regardless. `var` so the
    /// bootstrap can add the dead-intent check after evaluating the `rules`
    /// block (which happens after the definition exists — see `rules`).
    var warnings: [String]
    /// The game's death handler, run inside the live turn frame when the
    /// player dies — before the standard banner and prompt. Defaults to the
    /// fall-through handler, so games that don't implement `onDeath` behave
    /// exactly as before.
    let onDeath: @Sendable () -> DeathOutcome
}

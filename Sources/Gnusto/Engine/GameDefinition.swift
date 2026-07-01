/// The destination of an exit.
enum ExitTarget: Sendable {
    case to(EntityID)
    case blocked(String)
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
    /// The lock key's reference token, captured at declaration time. Bootstrap
    /// resolves it into `lockKey` once the registry exists.
    var lockKeyToken: RefToken?
    /// The resolved lock key, filled in by Bootstrap. `nil` until then (and for
    /// non-lockable items).
    var lockKey: EntityID?
    var isHidden = false
    var customTraits: [String: StateValue] = [:]

    /// Items are takable unless they're scenery.
    var isTakable: Bool { !isScenery }

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
            case .lockable(let key):
                isLockable = true
                lockKeyToken = key
            case .startsUnlocked: startsUnlocked = true
            case .capacity(let n): capacity = n
            case .hidden: isHidden = true
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
}

/// Everything about a game that never changes during play. Built once at
/// bootstrap; the changing side lives in `WorldState`.
struct GameDefinition: Sendable {
    let title: String
    let tagline: String
    let intro: String
    let maxScore: Int
    let locations: [EntityID: LocationDefinition]
    let items: [EntityID: ItemDefinition]
    let exits: [EntityID: [Direction: ExitTarget]]
    let globalDefaults: [EntityID: StateValue]
    let playerStart: EntityID
    /// `var` so the bootstrap can install the rule table after evaluating the
    /// `rules` block inside a registration frame (which needs the rest of the
    /// definition to exist first).
    var rules: RuleTable
    let registry: Registry
    let vocabulary: Vocabulary
    let syntaxRules: [SyntaxRule]
    /// Non-fatal bootstrap notes — e.g. a custom verb shadowing a built-in.
    /// Surfaced for tooling and tests; play proceeds regardless.
    let warnings: [String]
}

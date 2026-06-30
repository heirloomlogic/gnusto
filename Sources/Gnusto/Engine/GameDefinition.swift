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

    init(traits: [LocationTrait]) {
        for trait in traits {
            switch trait.kind {
            case .name(let text): name = text
            case .description(let text): description = text
            case .dark: inherentlyLit = false
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

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
    /// A live description supplied via `description { … }`. Mutually
    /// exclusive with `description` (a static string); Bootstrap reports a
    /// diagnostic if both are declared. `hasDynamicDescriptionConflict`
    /// records that conflict without losing which trait won.
    var dynamicDescription: (@Sendable () -> String)?
    var hasDynamicDescriptionConflict = false
    var inherentlyLit = true
    var customTraits: [String: StateValue] = [:]

    init(traits: [LocationTrait]) {
        for trait in traits {
            switch trait.kind {
            case .name(let text): name = text
            case .description(let text):
                if dynamicDescription != nil { hasDynamicDescriptionConflict = true }
                description = text
            case .dynamicDescription(let closure):
                if description != nil { hasDynamicDescriptionConflict = true }
                dynamicDescription = closure
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
    /// A live description supplied via `description { … }`. Mutually
    /// exclusive with `description` (a static string); Bootstrap reports a
    /// diagnostic if both are declared. `hasDynamicDescriptionConflict`
    /// records that conflict without losing which trait won.
    var dynamicDescription: (@Sendable () -> String)?
    var hasDynamicDescriptionConflict = false
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
    var isLightSource = false
    var startsLit = false
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
            case .description(let text):
                if dynamicDescription != nil { hasDynamicDescriptionConflict = true }
                description = text
            case .dynamicDescription(let closure):
                if description != nil { hasDynamicDescriptionConflict = true }
                dynamicDescription = closure
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
            case .lightSource: isLightSource = true
            case .startsLit: startsLit = true
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
    /// Surfaced for tooling and tests; play proceeds regardless.
    let warnings: [String]
}

/// The destination of an exit.
enum ExitTarget: Sendable {
    case to(EntityID)
    case blocked(String)
    /// An exit through a shared door item; passable only while the door is open.
    case door(to: EntityID, door: EntityID)
    /// An exit gated by a live condition evaluated at `go` time; when the
    /// condition is false the player is refused with `blocked`.
    case conditional(to: EntityID, condition: @Sendable () -> Bool, blocked: String)
    /// An exit whose destination is resolved at `go` time rather than declared
    /// — the non-Euclidean passage. The other cases carry an `EntityID` the
    /// bootstrap resolved; this one carries the closure that produces one, so
    /// it can answer differently on different turns.
    case dynamic(destination: @Sendable () -> EntityID)
}

/// The immutable, declared facts about a location.
struct LocationDefinition: Sendable {
    var name: String?
    var description: String?
    var inherentlyLit = true
    /// The description is state the player is changing, so it prints on every
    /// description rather than only the first. See the `alwaysDescribed` trait.
    var isAlwaysDescribed = false
    var customTraits: [String: StateValue] = [:]

    init(traits: [LocationTrait]) {
        for trait in traits {
            switch trait.kind {
            case .name(let text): name = text
            case .description(let text): description = text
            case .dark: inherentlyLit = false
            case .alwaysDescribed: isAlwaysDescribed = true
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
    /// The name is a proper name: the stock lines render it bare rather than
    /// behind "the" or "a". See `GameText.definite(_:proper:)`.
    var isProperName = false
    /// The name is grammatically plural: the stock lines agree with it, and the
    /// indefinite article becomes "some". See `GameText.Noun`.
    var isPlural = false
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
    /// This character carries out orders — `robot, push the button` reaches the
    /// rules instead of the parser's stock refusal. Only meaningful on an
    /// actor; the bootstrap warns about it anywhere else.
    var takesOrders = false
    /// The listing paragraph survives the first touch. See ``alwaysListed``.
    var isAlwaysListed = false
    var customTraits: [String: StateValue] = [:]
    /// True when this entity was declared as an `Actor`. Set by Bootstrap
    /// after trait evaluation — actors share the item trait vocabulary, so
    /// there is no trait to switch on.
    var isActor = false

    /// Set by Bootstrap where an exit hangs on this item, or by the `door`
    /// trait. See ``Item/isDoor``.
    var isDoor = false

    /// Items are takable unless they're scenery — or people.
    var isTakable: Bool { !isScenery && !isActor }

    init(traits: [ItemTrait]) {
        for trait in traits {
            switch trait.kind {
            case .name(let text): name = text
            case .description(let text): description = text
            case .adjectives(let words): adjectives += words
            case .synonyms(let words): synonyms += words
            case .properName: isProperName = true
            case .plural: isPlural = true
            case .firstSight(let text): firstSight = text
            case .wearable: isWearable = true
            case .scenery: isScenery = true
            case .surface: isSurface = true
            case .container: isContainer = true
            case .openable: isOpenable = true
            case .door: isDoor = true
            case .startsOpen: startsOpen = true
            case .transparent: isTransparent = true
            case .startsUnlocked: startsUnlocked = true
            case .capacity(let n): capacity = n
            case .hidden: isHidden = true
            case .lightSource: isLightSource = true
            case .startsLit: startsLit = true
            case .enterable: isEnterable = true
            case .takesOrders: takesOrders = true
            case .alwaysListed: isAlwaysListed = true
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
    /// Live room-listing paragraphs declared via `item.presence { … }` or
    /// `actor.presence { … }`. Consulted by `TurnFrame.presenceText(of:)`
    /// before a static `firstSight(…)` trait.
    var itemPresence: [EntityID: @Sendable () -> String] = [:]
    /// Live reach rules declared via `item.reach { … }` or `actor.reach { … }`.
    /// Consulted by `Visibility` on top of containment and by the stage-0 gate
    /// in `GameWorld.performStages`. Empty for a game that declares none, which
    /// is what makes the whole feature opt-in.
    var itemReach: [EntityID: Reach.Rule] = [:]
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
    /// The cast: the `actor` entries of ``items``, minus the player's own item.
    /// Every consumer of this set means *somebody else* — who a command can be
    /// addressed to, who a bare HELLO must have meant, who FOLLOW may name — so
    /// the player is excluded even though `items[.player].isActor` is true and
    /// the person-shaped refusals depend on it.
    ///
    /// Precomputed because `currentScope()` runs every turn *and* again for Tab
    /// completion: rescanning the item table twice a turn to rediscover a set
    /// that never changes is work for nothing.
    let castIDs: Set<EntityID>
    /// The cast members declared ``takesOrders``: who `<name>, <words>` can be
    /// an order to rather than a greeting. Empty for almost every game, which
    /// is what lets `currentScope()` skip the extra scope walk entirely.
    let orderTakerIDs: Set<EntityID>
    let exits: [EntityID: [Direction: ExitTarget]]
    /// Every room some exit leads to. A game's off-map holding pens — the
    /// street a character is "out on", the limbo an actor waits in before their
    /// entrance — are exactly the rooms missing from this set, and FOLLOW uses
    /// it to keep from naming somebody the player has no business knowing
    /// about yet.
    let reachableRooms: Set<EntityID>
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
    /// The extra status-line fields the game's content bundles and plugins
    /// contribute, held as closures because a field is *read at display time*:
    /// `Clock`'s hour is a function of the live `moves` counter, so a value
    /// computed here at bootstrap would say half past five forever.
    ///
    /// Each closure is `GameContent/statusFields` or `GamePlugin/statusFields`,
    /// in declaration order, and must be evaluated inside a live turn frame —
    /// see `GameWorld.statusFields()`, which builds a throwaway one. Empty for
    /// almost every game, which is what keeps the footer free when nobody
    /// asked for it.
    let statusFields: [@Sendable () -> [(String, String)]]
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

extension GameDefinition {
    /// A human-readable summary of every non-fatal ``warnings`` note, or `nil`
    /// when there are none. Mirrors `BootstrapError.description` so a warning
    /// and a fatal error read the same; surfaced on the runtime `@main` path
    /// (see `GameMain.main()`) so an author actually sees these instead of the
    /// bootstrap silently dropping them.
    var warningReport: String? {
        guard !warnings.isEmpty else { return nil }
        return """
            Gnusto: the game definition has \(warnings.count) warning(s) (play continues):
            \(warnings.map { "  • \($0)" }.joined(separator: "\n"))
            """
    }
}

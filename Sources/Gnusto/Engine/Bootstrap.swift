/// All problems with a game definition, reported at once.
public struct BootstrapError: Error, CustomStringConvertible {
    /// Every problem found in the game definition.
    public let diagnostics: [String]

    /// A human-readable summary listing every diagnostic.
    public var description: String {
        """
        Gnusto: the game definition is invalid (\(diagnostics.count) problem(s)):
        \(diagnostics.map { "  • \($0)" }.joined(separator: "\n"))
        """
    }
}

/// Builds the immutable `GameDefinition` and initial `WorldState` from a
/// `Game` instance: Mirror discovery, map and rules registration, and
/// validation.
enum Bootstrap {
    static func build(_ game: some Game) throws -> (GameDefinition, WorldState) {
        var diagnostics: [String] = []
        var registry = Registry()
        var locations: [EntityID: LocationDefinition] = [:]
        var items: [EntityID: ItemDefinition] = [:]
        var globalDefaults: [EntityID: StateValue] = [:]
        var declaredBy: [EntityID: String] = [:]

        // The game's content bundles, read once so every phase below sees the
        // same bundle instances — and therefore the same reference tokens the
        // bundles' own map/rules reference.
        let modules = game.content.modules

        // Phase 1 — discover stored declarations by reflection, over the game
        // itself and each of its content bundles. The property name is the
        // entity's ID; a name claimed by two declarations is a fatal collision.
        // A bundle passes its `namespace`, which prefixes its entity IDs so a
        // reusable bundle can't collide with the host; the game passes `nil` and
        // keeps bare IDs.
        func register(_ subject: Any, namespace: String?) {
            let owner = namespace ?? "\(type(of: subject))"

            // Claims `id` for this owner, or records a collision and returns
            // false if another declaration already took it. The bare `player`
            // ID is reserved for the player's own placements (`Placement.heldBy`),
            // so a host declaration (never namespaced) can't claim it.
            func claim(_ id: EntityID) -> Bool {
                if id == .player {
                    diagnostics.append(Self.reservedPlayerID(owner))
                    return false
                }
                if let prior = declaredBy[id] {
                    diagnostics.append(Self.collision(id, prior, owner))
                    return false
                }
                declaredBy[id] = owner
                return true
            }

            for child in Mirror(reflecting: subject).children {
                guard var label = child.label else { continue }
                if label.hasPrefix("_") { label.removeFirst() }  // property wrappers
                let id = namespace.map { EntityID("\($0).\(label)") } ?? EntityID(label)

                switch child.value {
                case let location as Location:
                    guard claim(id) else { continue }
                    if let existing = registry.id(for: location.token) {
                        diagnostics.append(
                            "\"\(id)\" and \"\(existing)\" are the same Location value; "
                                + "each location must be its own declaration.")
                        continue
                    }
                    registry.ids[ObjectIdentifier(location.token)] = id
                    registry.locations[id] = location
                    locations[id] = LocationDefinition(traits: location.traits)

                case let item as Item:
                    guard claim(id) else { continue }
                    if let existing = registry.id(for: item.token) {
                        diagnostics.append(
                            "\"\(id)\" and \"\(existing)\" are the same Item value; "
                                + "each item must be its own declaration.")
                        continue
                    }
                    registry.ids[ObjectIdentifier(item.token)] = id
                    registry.items[id] = item
                    items[id] = ItemDefinition(traits: item.traits)

                case let global as AnyGlobal:
                    guard claim(id) else { continue }
                    registry.ids[ObjectIdentifier(global.token)] = id
                    globalDefaults[id] = global.defaultStateValue

                default:
                    continue
                }
            }
        }

        register(game, namespace: nil)
        for module in modules {
            register(module, namespace: module.namespace)
        }

        // Custom verb rows are validated up front: a malformed pattern is a
        // wiring error, reported alongside every other fatal diagnostic. The
        // rows themselves are merged into the table in phase 3 below.
        let customVerbs = modules.flatMap { $0.verbs } + game.verbs
        for rule in customVerbs {
            diagnostics.append(contentsOf: rule.patternProblems)
        }

        for (id, definition) in locations where definition.name == nil {
            diagnostics.append("location \"\(id)\" has no name(…) trait.")
        }
        for (id, definition) in items where definition.name == nil {
            diagnostics.append("item \"\(id)\" has no name(…) trait.")
        }
        for (id, definition) in locations where definition.hasDynamicDescriptionConflict {
            diagnostics.append(
                "location \"\(id)\" declares both a static description(…) and a "
                    + "closure description { … }; a location may have only one.")
        }
        for (id, definition) in items where definition.hasDynamicDescriptionConflict {
            diagnostics.append(
                "item \"\(id)\" declares both a static description(…) and a "
                    + "closure description { … }; an item may have only one.")
        }

        // Phase 2 — evaluate the map block.
        var exits: [EntityID: [Direction: ExitTarget]] = [:]
        var placements: [EntityID: Placement] = [:]
        var wornItems: Set<EntityID> = []
        var playerStart: EntityID?

        func resolveLocation(_ token: RefToken, role: String) -> EntityID? {
            guard let id = registry.id(for: token), registry.locations[id] != nil else {
                diagnostics.append(
                    "\(role) references a location that is not a stored property "
                        + "of the game or any of its content bundles.")
                return nil
            }
            return id
        }

        func resolveItem(_ token: RefToken, role: String) -> EntityID? {
            guard let id = registry.id(for: token), registry.items[id] != nil else {
                diagnostics.append(
                    "\(role) references an item that is not a stored property "
                        + "of the game or any of its content bundles.")
                return nil
            }
            return id
        }

        let mapEntries = game.map.entries + modules.flatMap { $0.map.entries }
        for entry in mapEntries {
            switch entry.kind {
            case .exit(let from, let direction, let to):
                guard let fromID = resolveLocation(from, role: "an exit"),
                    let toID = resolveLocation(to, role: "the \(direction) exit")
                else { continue }
                if exits[fromID]?[direction] != nil {
                    diagnostics.append(
                        "\"\(fromID)\" declares its \(direction) exit more than once.")
                }
                exits[fromID, default: [:]][direction] = .to(toID)

            case .blockedExit(let from, let direction, let message):
                guard let fromID = resolveLocation(from, role: "a blocked exit") else {
                    continue
                }
                if exits[fromID]?[direction] != nil {
                    diagnostics.append(
                        "\"\(fromID)\" declares its \(direction) exit more than once.")
                }
                exits[fromID, default: [:]][direction] = .blocked(message)

            case .doorExit(let from, let direction, let to, let doorToken):
                guard let fromID = resolveLocation(from, role: "a door exit"),
                    let toID = resolveLocation(to, role: "the \(direction) exit")
                else { continue }
                guard let doorID = resolveItem(doorToken, role: "the \(direction) door") else {
                    continue
                }
                // A door must be openable — otherwise `go` has no open state to
                // gate on and the closed/open refusal is meaningless.
                if items[doorID]?.isOpenable != true {
                    diagnostics.append(
                        "\"\(fromID)\"'s \(direction) exit uses \"\(doorID)\" as a door, "
                            + "which is not declared openable.")
                }
                if exits[fromID]?[direction] != nil {
                    diagnostics.append(
                        "\"\(fromID)\" declares its \(direction) exit more than once.")
                }
                exits[fromID, default: [:]][direction] = .door(to: toID, door: doorID)

            case .conditionalExit(let from, let direction, let to, let condition, let blocked):
                guard let fromID = resolveLocation(from, role: "a conditional exit"),
                    let toID = resolveLocation(to, role: "the \(direction) exit")
                else { continue }
                if exits[fromID]?[direction] != nil {
                    diagnostics.append(
                        "\"\(fromID)\" declares its \(direction) exit more than once.")
                }
                exits[fromID, default: [:]][direction] = .conditional(
                    to: toID, condition: condition, blocked: blocked)

            case .placement(let itemToken, let target):
                guard let itemID = resolveItem(itemToken, role: "a placement") else {
                    continue
                }
                switch target {
                case .location(let token):
                    guard
                        let locationID = resolveLocation(
                            token, role: "the placement of \"\(itemID)\"")
                    else { continue }
                    placements[itemID] = .room(locationID)
                case .on(let token):
                    guard
                        let surfaceID = resolveItem(
                            token, role: "the placement of \"\(itemID)\"")
                    else { continue }
                    if items[surfaceID]?.isSurface != true {
                        diagnostics.append(
                            "\"\(itemID)\" is placed on \"\(surfaceID)\", which is "
                                + "not declared as a surface.")
                    }
                    placements[itemID] = .on(surfaceID)
                case .inside(let token):
                    guard
                        let containerID = resolveItem(
                            token, role: "the placement of \"\(itemID)\"")
                    else { continue }
                    if items[containerID]?.isContainer != true {
                        diagnostics.append(
                            "\"\(itemID)\" is placed inside \"\(containerID)\", which is "
                                + "not declared as a container.")
                    }
                    placements[itemID] = .inside(containerID)
                case .worn:
                    placements[itemID] = .heldBy(.player)
                    wornItems.insert(itemID)
                case .held:
                    placements[itemID] = .heldBy(.player)
                }

            case .playerStart(let token):
                if playerStart != nil {
                    diagnostics.append("the map block declares player.starts(in:) more than once.")
                }
                playerStart = resolveLocation(token, role: "player.starts(in:)")
            }
        }

        if playerStart == nil {
            diagnostics.append("the map block never declares player.starts(in:).")
        }

        // Resolve each lockable item's key token → EntityID onto its
        // definition, mirroring how exit targets resolve their tokens. A key
        // that is not a declared item is a fatal diagnostic.
        for (id, definition) in items {
            guard let keyToken = definition.lockKeyToken else { continue }
            guard let keyID = registry.id(for: keyToken), registry.items[keyID] != nil else {
                diagnostics.append(
                    "\"\(id)\" is lockable with a key that is not a stored property "
                        + "of the game or any of its content bundles.")
                continue
            }
            items[id]?.lockKey = keyID
        }

        guard diagnostics.isEmpty, let playerStart else {
            throw BootstrapError(diagnostics: diagnostics)
        }

        for id in items.keys where placements[id] == nil {
            placements[id] = .nowhere
        }

        var state = WorldState(playerLocation: playerStart)
        state.placements = placements
        state.wornItems = wornItems
        state.litRooms = Set(locations.filter(\.value.inherentlyLit).keys)
        // Openable containers start open only with `startsOpen`; lockable items
        // start locked unless `startsUnlocked`. Non-openable containers are
        // implicitly open and never tracked in `openItems`.
        state.openItems = Set(
            items.filter { $0.value.isOpenable && $0.value.startsOpen }.keys)
        state.lockedItems = Set(
            items.filter { $0.value.isLockable && !$0.value.startsUnlocked }.keys)

        // Phase 3 — assemble the verb table and vocabulary. Built-ins first,
        // then bundle verbs, then the host game's — so precedence runs
        // built-ins < bundles/plugins < host game, and with last-wins the host
        // beats a bundle that claims the same shape. A custom row whose verb
        // and shape match a built-in reclaims it (last-wins) with a non-fatal
        // warning, so an author can override a verb while keeping it visible.
        var verbWarnings: [String] = []
        let builtInKeys = Set(SyntaxRule.standardTable.map(\.key))
        for verb in customVerbs where builtInKeys.contains(verb.key) {
            verbWarnings.append(
                "custom verb \"\(verb.patternDescription)\" overrides a "
                    + "built-in verb of the same shape.")
        }
        let syntaxRules = Self.dedupedLastWins(SyntaxRule.standardTable + customVerbs)
        var vocabulary = Vocabulary()
        vocabulary.directions = Vocabulary.standardDirections
        for rule in syntaxRules {
            // Leading words identify the verb; literals deeper in the pattern
            // (particles, prepositions) are structural words the parser must
            // still recognize as known.
            vocabulary.verbWords.formUnion(rule.leadingWords)
            vocabulary.prepositions.formUnion(
                rule.literalWords.dropFirst(rule.leadingWords.count))
        }
        var vocabularyWarnings: [String] = []
        for (id, item) in items {
            var lexicon = ItemLexicon()
            let nameWords = (item.name ?? "").lowercased().split(separator: " ").map(String.init)
            if let noun = nameWords.last {
                lexicon.nouns.insert(noun)
            }
            lexicon.adjectives.formUnion(nameWords.dropLast())
            lexicon.adjectives.formUnion(item.adjectives.map { $0.lowercased() })
            lexicon.nouns.formUnion(item.synonyms.map { $0.lowercased() })
            // Pronouns and multi-object keywords resolve before any lexicon,
            // so a word claimed here would never reach this item.
            for word in lexicon.nouns.union(lexicon.adjectives)
            where Vocabulary.reservedWords.contains(word) {
                vocabularyWarnings.append(
                    "item \"\(id)\" answers to \"\(word)\", a reserved parser word "
                        + "(pronoun or multi-object keyword); the parser will never "
                        + "match it to this item.")
            }
            vocabulary.itemLexicons[id] = lexicon
            vocabulary.displayNames[id] = item.name ?? id.raw
        }
        vocabulary.finalize()

        // Phase 3b — assemble the stage-4 default-action overrides. Bundle
        // actions are auto-collected like bundle verbs; a plugin's actions
        // reach here only if the host splices them into its own `actions`
        // block. Bundle actions come first, then the host game's — so
        // precedence runs built-ins < bundles/plugins < host game, and a host
        // action for the same intent beats a bundle's (last-wins), matching
        // the verb merge. A row whose intent matches a built-in reclaims it,
        // with the same non-fatal warning policy as verbs.
        let customActions = modules.flatMap { $0.actions } + game.actions
        var actionWarnings: [String] = []
        var actionOverrides: [Intent: IntentAction] = [:]
        for action in customActions {
            if DefaultActions.builtInIntents.contains(action.intent) {
                actionWarnings.append(
                    "custom action for intent \"\(action.intent.raw)\" overrides the "
                        + "built-in default of the same intent.")
            } else if actionOverrides[action.intent] != nil {
                actionWarnings.append(
                    "custom action for intent \"\(action.intent.raw)\" overrides an "
                        + "earlier custom action of the same intent.")
            }
            actionOverrides[action.intent] = action
        }

        // Phase 4 — evaluate the rules block inside a registration frame, so
        // any stray live reads see the initial state rather than trapping.
        var definition = GameDefinition(
            title: game.title,
            tagline: game.tagline,
            intro: game.intro,
            maxScore: game.maxScore,
            text: game.text,
            locations: locations,
            items: items,
            exits: exits,
            globalDefaults: globalDefaults,
            playerStart: playerStart,
            rules: RuleTable(),
            registry: registry,
            vocabulary: vocabulary,
            syntaxRules: syntaxRules,
            actionOverrides: actionOverrides,
            warnings: verbWarnings + vocabularyWarnings + actionWarnings)

        let registrationFrame = TurnFrame(definition: definition, state: state)
        let declaredRules = Ctx.$frame.withValue(registrationFrame) {
            game.rules.rules + modules.flatMap { $0.rules.rules }
        }
        _ = registrationFrame.retire()  // discard any stray writes

        var table = RuleTable()
        var ruleDiagnostics: [String] = []
        for rule in declaredRules {
            switch rule.scope {
            case .item(let token):
                guard let id = registry.id(for: token), registry.items[id] != nil else {
                    ruleDiagnostics.append(
                        "a rule is attached to an item that is not a stored property "
                            + "of the game or any of its content bundles.")
                    continue
                }
                switch rule.phase {
                case .before: table.itemBefore[id, default: []].append(rule)
                case .after: table.itemAfter[id, default: []].append(rule)
                default:
                    ruleDiagnostics.append(
                        "item \"\(id)\" has a \(rule.phase) rule, which only "
                            + "locations support.")
                }
            case .location(let token):
                guard let id = registry.id(for: token), registry.locations[id] != nil else {
                    ruleDiagnostics.append(
                        "a rule is attached to a location that is not a stored "
                            + "property of the game or any of its content bundles.")
                    continue
                }
                switch rule.phase {
                case .before: table.locationBefore[id, default: []].append(rule)
                case .after: table.locationAfter[id, default: []].append(rule)
                case .beforeEachTurn: table.locationBeforeEachTurn[id, default: []].append(rule)
                case .afterEachTurn: table.locationAfterEachTurn[id, default: []].append(rule)
                case .onEnter: table.locationOnEnter[id, default: []].append(rule)
                }
            case .world:
                switch rule.phase {
                case .before, .beforeEachTurn: table.worldBefore.append(rule)
                case .after, .afterEachTurn: table.worldAfter.append(rule)
                case .onEnter:
                    ruleDiagnostics.append("a world-level onEnter rule is not supported.")
                }
            }
        }

        guard ruleDiagnostics.isEmpty else {
            throw BootstrapError(diagnostics: ruleDiagnostics)
        }

        definition.rules = table
        return (definition, state)
    }

    /// The diagnostic for an `EntityID` claimed by two declarations — the
    /// game and a bundle, or two different bundles.
    private static func collision(_ id: EntityID, _ first: String, _ second: String) -> String {
        "entity \"\(id)\" is declared by both \(first) and \(second)."
    }

    /// The diagnostic for a declaration that claims the reserved `"player"`
    /// ID, which `Placement.heldBy(.player)` needs for itself.
    private static func reservedPlayerID(_ owner: String) -> String {
        "\"player\" is a reserved entity ID (declared by \(owner)); rename this declaration."
    }

    /// Keeps the last row for each `(verb, shape)` key, preserving relative
    /// order. Because the game's verbs follow the built-ins, a colliding game
    /// row replaces the built-in. Order is otherwise irrelevant — the parser
    /// re-sorts the table by specificity.
    private static func dedupedLastWins(_ rules: [SyntaxRule]) -> [SyntaxRule] {
        var lastIndex: [SyntaxRule.Key: Int] = [:]
        for (index, rule) in rules.enumerated() {
            lastIndex[rule.key] = index
        }
        return rules.enumerated()
            .filter { lastIndex[$0.element.key] == $0.offset }
            .map(\.element)
    }
}

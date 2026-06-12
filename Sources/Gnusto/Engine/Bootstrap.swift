/// All problems with a game definition, reported at once.
public struct BootstrapError: Error, CustomStringConvertible {
    public let diagnostics: [String]

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

        // Phase 1 — discover stored declarations by reflection. The property
        // name is the entity's ID.
        for child in Mirror(reflecting: game).children {
            guard var label = child.label else { continue }
            if label.hasPrefix("_") { label.removeFirst() }  // property wrappers
            let id = EntityID(label)

            switch child.value {
            case let location as Location:
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
                registry.ids[ObjectIdentifier(global.token)] = id
                globalDefaults[id] = global.defaultStateValue

            default:
                continue
            }
        }

        for (id, definition) in locations where definition.name == nil {
            diagnostics.append("location \"\(id)\" has no name(…) trait.")
        }
        for (id, definition) in items where definition.name == nil {
            diagnostics.append("item \"\(id)\" has no name(…) trait.")
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
                        + "of \(type(of: game)).")
                return nil
            }
            return id
        }

        func resolveItem(_ token: RefToken, role: String) -> EntityID? {
            guard let id = registry.id(for: token), registry.items[id] != nil else {
                diagnostics.append(
                    "\(role) references an item that is not a stored property "
                        + "of \(type(of: game)).")
                return nil
            }
            return id
        }

        for entry in game.map.entries {
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
                    placements[itemID] = .inside(containerID)
                case .worn:
                    placements[itemID] = .held
                    wornItems.insert(itemID)
                case .held:
                    placements[itemID] = .held
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

        // Phase 3 — assemble vocabulary.
        let syntaxRules = SyntaxRule.standardTable
        var vocabulary = Vocabulary()
        vocabulary.directions = Vocabulary.standardDirections
        for rule in syntaxRules {
            vocabulary.verbWords.formUnion(rule.verb)
            switch rule.slots {
            case .directThenParticle(let particle):
                vocabulary.prepositions.insert(particle)
            case .directPrepIndirect(let preposition):
                vocabulary.prepositions.insert(preposition)
            default:
                break
            }
        }
        for (id, item) in items {
            var lexicon = ItemLexicon()
            let nameWords = (item.name ?? "").lowercased().split(separator: " ").map(String.init)
            if let noun = nameWords.last {
                lexicon.nouns.insert(noun)
            }
            lexicon.adjectives.formUnion(nameWords.dropLast())
            lexicon.adjectives.formUnion(item.adjectives.map { $0.lowercased() })
            lexicon.nouns.formUnion(item.synonyms.map { $0.lowercased() })
            vocabulary.itemLexicons[id] = lexicon
            vocabulary.displayNames[id] = item.name ?? id.raw
        }

        // Phase 4 — evaluate the rules block inside a registration frame, so
        // any stray live reads see the initial state rather than trapping.
        let preliminary = GameDefinition(
            title: game.title,
            tagline: game.tagline,
            intro: game.intro,
            maxScore: game.maxScore,
            locations: locations,
            items: items,
            exits: exits,
            globalDefaults: globalDefaults,
            playerStart: playerStart,
            rules: RuleTable(),
            registry: registry,
            vocabulary: vocabulary,
            syntaxRules: syntaxRules)

        let registrationFrame = TurnFrame(definition: preliminary, state: state)
        let declaredRules = Ctx.$frame.withValue(registrationFrame) {
            game.rules.rules
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
                            + "of \(type(of: game)).")
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
                            + "property of \(type(of: game)).")
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

        let definition = GameDefinition(
            title: preliminary.title,
            tagline: preliminary.tagline,
            intro: preliminary.intro,
            maxScore: preliminary.maxScore,
            locations: preliminary.locations,
            items: preliminary.items,
            exits: preliminary.exits,
            globalDefaults: preliminary.globalDefaults,
            playerStart: preliminary.playerStart,
            rules: table,
            registry: preliminary.registry,
            vocabulary: preliminary.vocabulary,
            syntaxRules: preliminary.syntaxRules)

        return (definition, state)
    }
}

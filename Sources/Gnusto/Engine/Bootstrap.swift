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

                case let actor as Actor:
                    guard claim(id) else { continue }
                    if let existing = registry.id(for: actor.token) {
                        diagnostics.append(
                            "\"\(id)\" and \"\(existing)\" are the same Actor value; "
                                + "each actor must be its own declaration.")
                        continue
                    }
                    // Actors live in the item registry — one storage path
                    // for placement, visibility, rules, and saves. The
                    // definition's flag is what makes them people.
                    registry.ids[ObjectIdentifier(actor.token)] = id
                    registry.items[id] = actor.asItem
                    var definition = ItemDefinition(traits: actor.traits)
                    definition.isActor = true
                    items[id] = definition

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

        // The player is a thing in the world too, so `X ME` has something to
        // answer with. Synthesized rather than declared — every game has
        // exactly one player and no game should have to write it down — but
        // stored exactly like any other item, so vocabulary, scope, rules and
        // saves need no second code path. It bypasses `claim`, which exists to
        // stop an *author* taking this ID.
        registry.ids[ObjectIdentifier(Player.itemToken)] = .player
        registry.items[.player] = Player().item
        var playerItem = ItemDefinition(traits: Player.itemTraits)
        playerItem.isActor = true
        // "yourself" takes no article. The self lines cover the sites that
        // matter, but a line reached with the player in the object slot should
        // say "You can't reach yourself.", never "the yourself".
        playerItem.isProperName = true
        items[.player] = playerItem

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
            let kind = definition.isActor ? "actor" : "item"
            diagnostics.append("\(kind) \"\(id)\" has no name(…) trait.")
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
                guard let fromID = resolveLocation(from, role: "the source of a \(direction) exit"),
                    let toID = resolveLocation(to, role: "the \(direction) exit")
                else { continue }
                if exits[fromID]?[direction] != nil {
                    diagnostics.append(
                        "\"\(fromID)\" declares its \(direction) exit more than once.")
                }
                exits[fromID, default: [:]][direction] = .to(toID)

            case .blockedExit(let from, let direction, let message):
                guard
                    let fromID = resolveLocation(
                        from, role: "the source of a blocked \(direction) exit")
                else {
                    continue
                }
                if exits[fromID]?[direction] != nil {
                    diagnostics.append(
                        "\"\(fromID)\" declares its \(direction) exit more than once.")
                }
                exits[fromID, default: [:]][direction] = .blocked(message)

            case .doorExit(let from, let direction, let to, let doorToken):
                guard
                    let fromID = resolveLocation(
                        from, role: "the source of a \(direction) door exit"),
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
                guard
                    let fromID = resolveLocation(
                        from, role: "the source of a conditional \(direction) exit"),
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
                case .heldBy(let token):
                    guard
                        let holderID = resolveItem(
                            token, role: "the placement of \"\(itemID)\"")
                    else { continue }
                    // `starts(heldBy:)` only accepts an Actor, so this is
                    // defensive symmetry with the surface/container checks
                    // above, not a reachable authoring mistake.
                    if items[holderID]?.isActor != true {
                        diagnostics.append(
                            "\"\(itemID)\" starts heldBy \"\(holderID)\", which is "
                                + "not an Actor.")
                    }
                    placements[itemID] = .heldBy(holderID)
                }

            case .playerStart(let token):
                if playerStart != nil {
                    diagnostics.append("the map block declares player.starts(in:) more than once.")
                }
                playerStart = resolveLocation(token, role: "player.starts(in:)")

            case .lockKey(let itemToken, let keyToken):
                guard let itemID = resolveItem(itemToken, role: "a lockedBy entry"),
                    let keyID = resolveItem(keyToken, role: "the lock key for an item")
                else { continue }
                if items[itemID]?.isLockable == true {
                    diagnostics.append(
                        "\"\(itemID)\" declares lockedBy more than once.")
                }
                // The entry itself confers lockability — there is no separate
                // trait. The item starts locked unless `startsUnlocked` (seeded
                // below alongside the other opening state).
                items[itemID]?.isLockable = true
                items[itemID]?.lockKey = keyID
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

        var state = WorldState(playerLocation: playerStart, placements: placements)
        state.wornItems = wornItems
        state.litRooms = Set(locations.filter(\.value.inherentlyLit).keys)
        // Openable containers start open only with `startsOpen`; lockable items
        // start locked unless `startsUnlocked`. Non-openable containers are
        // implicitly open and never tracked in `openItems`.
        state.openItems = Set(
            items.filter { $0.value.isOpenable && $0.value.startsOpen }.keys)
        state.lockedItems = Set(
            items.filter { $0.value.isLockable && !$0.value.startsUnlocked }.keys)
        // Light sources start lit only with `startsLit`; the flag on a
        // non-light-source is inert and gets a warning below.
        state.litItems = Set(
            items.filter { $0.value.isLightSource && $0.value.startsLit }.keys)

        // Phase 3 — assemble the verb table and vocabulary. Built-ins first,
        // then bundle verbs, then the host game's — so precedence runs
        // built-ins < bundles/plugins < host game, and with last-wins the host
        // beats a bundle that claims the same shape. A custom row whose verb
        // and shape match a built-in reclaims it (last-wins) with a non-fatal
        // warning, so an author can override a verb while keeping it visible.
        // Keyed off `coreTable`, not `standardTable`: reclaiming a *stub* row
        // shadows no behavior, and overriding one is the expected end state, so
        // that case is silent. The intent has to match too, not just the shape:
        // a `verbs` block that lists an engine intent splices rows identical to
        // the built-in ones, and a row that reclaims a shape for the intent
        // that already held it overrides nothing.
        var verbWarnings: [String] = []
        let coreIntentsByShape = Dictionary(
            uniqueKeysWithValues: SyntaxRule.coreTable.map { ($0.key, $0.intent) })
        for verb in customVerbs {
            guard let claimed = coreIntentsByShape[verb.key], claimed != verb.intent else { continue }
            verbWarnings.append(
                "custom verb \"\(verb.patternDescription)\" overrides a "
                    + "built-in verb of the same shape.")
        }
        let syntaxRules = Self.dedupedLastWins(SyntaxRule.standardTable + customVerbs)
        var vocabulary = Vocabulary()
        vocabulary.directions = Vocabulary.standardDirections
        // Every declared word — an item's, a verb pattern's, a game's filler
        // list — goes through `Vocabulary.words(in:)`, the same split the
        // tokenizer applies to what the player types. Registering a declaration
        // verbatim instead is what made `adjectives("master's")` a string no
        // token could equal: dead on arrival, and silent both ways.
        var wordDiagnostics: [String] = []
        /// Splits a declared phrase, or reports it if there is no word in it.
        func declaredWords(_ phrase: String, _ role: String, _ id: EntityID) -> [String] {
            let words = Vocabulary.words(in: phrase)
            if words.isEmpty {
                wordDiagnostics.append(
                    "\"\(id)\" declares the \(role) \"\(phrase)\", which has no letters "
                        + "or digits in it; there is no word there for the parser to match.")
            }
            return words
        }
        for rule in syntaxRules {
            // Leading words identify the verb; literals deeper in the pattern
            // (particles, prepositions) are structural words the parser must
            // still recognize as known.
            vocabulary.verbWords.formUnion(rule.leadingWords)
            vocabulary.prepositions.formUnion(
                rule.literalWords.dropFirst(rule.leadingWords.count))
            // A pattern's literals are declarations too, and die the same way.
            for word in rule.literalWords
            where Vocabulary.words(in: word) != [word.lowercased()] {
                wordDiagnostics.append(
                    "the verb pattern \"\(rule.patternDescription)\" declares the word "
                        + "\"\(word)\", which the parser splits differently from what the "
                        + "player types; no input can reach it.")
            }
        }
        var vocabularyWarnings: [String] = []
        for (id, item) in items {
            var lexicon = ItemLexicon()
            // A name and a synonym are both noun phrases: the last word is the
            // noun, the words in front of it are adjectives.
            let nameWords = item.name.map { declaredWords($0, "name", id) } ?? []
            if let noun = nameWords.last {
                lexicon.nouns.insert(noun)
            }
            lexicon.adjectives.formUnion(nameWords.dropLast())
            for phrase in item.adjectives {
                lexicon.adjectives.formUnion(declaredWords(phrase, "adjective", id))
            }
            for phrase in item.synonyms {
                let words = declaredWords(phrase, "synonym", id)
                guard let noun = words.last else { continue }
                lexicon.nouns.insert(noun)
                lexicon.adjectives.formUnion(words.dropLast())
            }
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
            if item.isProperName { vocabulary.properNames.insert(id) }
        }

        // Game- and bundle-declared filler words join the built-in articles.
        // Noise words are stripped at tokenize time, before any matching, so
        // one that doubles as a verb, preposition, direction, or item word
        // would make that word untypeable — a fatal authoring error. The
        // built-in articles are checked alongside the game's own: a declaration
        // that lands on one of those is just as untypeable, and nothing was
        // looking.
        let customNoise = (modules.flatMap(\.noiseWords) + game.noiseWords)
            .flatMap(Vocabulary.words(in:))
        for word in customNoise + Vocabulary.defaultNoiseWords.sorted() {
            let clash: String? =
                if vocabulary.verbWords.contains(word) {
                    "a verb word"
                } else if vocabulary.prepositions.contains(word) {
                    "a structural word in a verb pattern"
                } else if vocabulary.directions.keys.contains(word) {
                    "a direction"
                } else if vocabulary.itemLexicons.values.contains(where: {
                    $0.nouns.contains(word) || $0.adjectives.contains(word)
                }) {
                    "an item word"
                } else {
                    nil
                }
            if let clash {
                wordDiagnostics.append(
                    "noise word \"\(word)\" is also \(clash); stripping it "
                        + "would make that word untypeable.")
            }
        }
        guard wordDiagnostics.isEmpty else {
            throw BootstrapError(diagnostics: wordDiagnostics)
        }
        vocabulary.noiseWords.formUnion(customNoise)
        vocabulary.finalize()

        var traitWarnings: [String] = []
        for (id, item) in items where item.startsLit && !item.isLightSource {
            traitWarnings.append(
                "item \"\(id)\" declares startsLit but is not a lightSource; "
                    + "the flag has no effect.")
        }
        for (id, item) in items where item.startsUnlocked && !item.isLockable {
            traitWarnings.append(
                "item \"\(id)\" declares startsUnlocked but has no lockedBy entry; "
                    + "the flag has no effect.")
        }
        // A capitalized name is very nearly a proper name, and the stock lines
        // put an article in front of anything that isn't one — "the Mrs. Vane".
        // Not inferred, because "Elvish sword" is a common noun and so is
        // "Orange Grove Avenue"; warned about, because the author who meant a
        // proper name will otherwise find out from a transcript. Locations are
        // exempt: the engine never articles a room name.
        for (id, item) in items
        where !item.isProperName && item.name?.first?.isUppercase == true {
            traitWarnings.append(
                "\(item.isActor ? "actor" : "item") \"\(id)\" is named "
                    + "\"\(item.name ?? id.raw)\", which reads as a proper name but is "
                    + "not declared properName; stock lines will say "
                    + "\"the \(item.name ?? id.raw)\".")
        }
        // Mechanical item traits on an actor are legal but almost never
        // intended — an actor holds things via its inventory, not by being a
        // container. Warn, don't strip: the trait behaves item-like if left.
        for (id, item) in items where item.isActor {
            let mechanical: [(Bool, String)] = [
                (item.isWearable, "wearable"), (item.isScenery, "scenery"),
                (item.isSurface, "surface"), (item.isContainer, "container"),
                (item.isOpenable, "openable"), (item.startsOpen, "startsOpen"),
                (item.isTransparent, "transparent"), (item.isLockable, "lockable"),
                (item.startsUnlocked, "startsUnlocked"), (item.capacity != nil, "capacity"),
            ]
            for (declared, trait) in mechanical where declared {
                traitWarnings.append(
                    "actor \"\(id)\" declares the item trait \"\(trait)\"; actors hold "
                        + "things via their inventory, and the trait will behave "
                        + "item-like if left in place.")
            }
        }

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
            if DefaultActions.engineIntents.contains(action.intent) {
                // UNDO and its neighbours are answered in `GameWorld.run`,
                // before any stage runs, so this row is dead on arrival. Silence
                // here would read as "registered" and cost somebody an
                // afternoon.
                actionWarnings.append(
                    "custom action for intent \"\(action.intent.raw)\" will never run; "
                        + "the engine answers \(action.intent.raw) before the turn "
                        + "pipeline.")
            } else if DefaultActions.builtInIntents.contains(action.intent) {
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
            castIDs: Set(items.filter { $0.key != .player && $0.value.isActor }.keys),
            exits: exits,
            reachableRooms: Set(
                exits.values.flatMap(\.values).compactMap { target in
                    switch target {
                    case .to(let destination), .door(let destination, _),
                        .conditional(let destination, _, _):
                        destination
                    case .blocked:
                        nil
                    }
                }),
            globalDefaults: globalDefaults,
            playerStart: playerStart,
            rules: RuleTable(),
            registry: registry,
            vocabulary: vocabulary,
            syntaxRules: syntaxRules,
            actionOverrides: actionOverrides,
            warnings: verbWarnings + vocabularyWarnings + traitWarnings + actionWarnings,
            onDeath: { game.onDeath() })

        let registrationFrame = TurnFrame(definition: definition, state: state)
        let (declaredRules, declaredTimers, declaredScores) = Ctx.$frame.withValue(
            registrationFrame
        ) { () -> ([Rule], [TimedEvent], [Int]) in
            let rules: [Rule] = game.rules.rules + modules.flatMap { $0.rules.rules }
            let timers: [TimedEvent] = game.timers + modules.flatMap { $0.timers }
            // Content that can total its own awards is asked here rather than
            // later, because the totals may be declared as item traits and a
            // trait read needs a live frame.
            let declaredItems = Array(registry.items.values)
            let scores: [Int] = modules.compactMap {
                ($0 as? ScoreDeclaring)?.declaredMaxScore(items: declaredItems)
            }
            return (rules, timers, scores)
        }
        _ = registrationFrame.retire()  // discard any stray writes

        var table = RuleTable()
        var ruleDiagnostics: [String] = []

        // Files a text-returning rule — `describe { … }` or `presence { … }` —
        // into the given slot, reporting the same two conflicts wherever it is
        // used: the static trait it competes with is already present, or the
        // entity declares the rule twice.
        func fileText(
            _ id: EntityID, noun: String, rule kind: String, trait: String,
            hasStaticText: Bool,
            into slot: WritableKeyPath<RuleTable, [EntityID: @Sendable () -> String]>,
            _ rule: Rule
        ) {
            if hasStaticText {
                ruleDiagnostics.append(
                    "\(noun) \"\(id)\" declares both a static \(trait) and a "
                        + "\(kind) { … } rule; a \(noun) may have only one.")
            } else if table[keyPath: slot][id] != nil {
                ruleDiagnostics.append(
                    "\(noun) \"\(id)\" declares more than one \(kind) { … } rule.")
            } else if let describeBody = rule.describeBody {
                table[keyPath: slot][id] = describeBody
            }
        }

        for rule in declaredRules {
            // A rule's scope token is opaque, so an unresolved attachment can't
            // be named — but the phase and the intents it watches identify which
            // rule it is, giving the author an anchor to find in their source.
            let watched = rule.intents.map(\.raw).sorted()
            let ruleDescriptor =
                watched.isEmpty
                ? "a \(rule.phase) rule"
                : "a \(rule.phase) rule (watching \(watched.joined(separator: ", ")))"

            switch rule.scope {
            case .item(let token):
                guard let id = registry.id(for: token), registry.items[id] != nil else {
                    ruleDiagnostics.append(
                        "\(ruleDescriptor) is attached to an item that is not a stored "
                            + "property of the game or any of its content bundles.")
                    continue
                }
                switch rule.phase {
                case .before: table.itemBefore[id, default: []].append(rule)
                case .after: table.itemAfter[id, default: []].append(rule)
                case .describe:
                    fileText(
                        id, noun: "item", rule: "describe", trait: "description(…)",
                        hasStaticText: items[id]?.description != nil,
                        into: \.itemDescribe, rule)
                case .presence:
                    fileText(
                        id, noun: "item", rule: "presence", trait: "firstSight(…)",
                        hasStaticText: items[id]?.firstSight != nil,
                        into: \.itemPresence, rule)
                case .beforeEachTurn, .afterEachTurn, .onEnter:
                    ruleDiagnostics.append(
                        "item \"\(id)\" has a \(rule.phase) rule, which only "
                            + "locations support.")
                }
            case .location(let token):
                guard let id = registry.id(for: token), registry.locations[id] != nil else {
                    ruleDiagnostics.append(
                        "\(ruleDescriptor) is attached to a location that is not a stored "
                            + "property of the game or any of its content bundles.")
                    continue
                }
                switch rule.phase {
                case .before: table.locationBefore[id, default: []].append(rule)
                case .after: table.locationAfter[id, default: []].append(rule)
                case .beforeEachTurn: table.locationBeforeEachTurn[id, default: []].append(rule)
                case .afterEachTurn: table.locationAfterEachTurn[id, default: []].append(rule)
                case .onEnter: table.locationOnEnter[id, default: []].append(rule)
                case .describe:
                    fileText(
                        id, noun: "location", rule: "describe", trait: "description(…)",
                        hasStaticText: locations[id]?.description != nil,
                        into: \.locationDescribe, rule)
                case .presence:
                    ruleDiagnostics.append(
                        "location \"\(id)\" has a \(rule.phase) rule, which only items "
                            + "and actors support.")
                }
            case .world:
                switch rule.phase {
                case .before, .beforeEachTurn: table.worldBefore.append(rule)
                case .after, .afterEachTurn: table.worldAfter.append(rule)
                case .onEnter:
                    ruleDiagnostics.append("a world-level onEnter rule is not supported.")
                case .describe:
                    ruleDiagnostics.append("a world-level describe rule is not supported.")
                case .presence:
                    ruleDiagnostics.append("a world-level presence rule is not supported.")
                }
            }
        }

        // Timers: names are global (a bundle's own rules start them by the
        // literal string it declared, so namespacing would break the author's
        // own name) — a shared name is the collision to catch. Zero-or-
        // negative fuse counts can never fire and are wiring errors too.
        var timers: [String: TimedEvent] = [:]
        for event in declaredTimers {
            if timers[event.name] != nil {
                ruleDiagnostics.append(
                    "two timers are both named \"\(event.name)\"; timer names must "
                        + "be unique across the game and its bundles.")
                continue
            }
            if case .fuse(let turns) = event.kind, turns < 1 {
                ruleDiagnostics.append(
                    "fuse \"\(event.name)\" declares after: \(turns); a fuse needs "
                        + "at least one turn.")
                continue
            }
            timers[event.name] = event
        }

        guard ruleDiagnostics.isEmpty else {
            throw BootstrapError(diagnostics: ruleDiagnostics)
        }

        // A #verb-declared intent's rows reach the parser only when a verbs
        // block lists it, so a rule (or custom action) watching an intent no
        // row produces is usually that forgotten listing. Non-fatal: nothing
        // breaks, the rule just never fires from typed input.
        let producedIntents = Set(syntaxRules.map(\.intent))
        var watchedIntents: Set<Intent> = []
        for rule in declaredRules {
            watchedIntents.formUnion(rule.intents)
        }
        watchedIntents.formUnion(customActions.map(\.intent))
        let deadIntents =
            watchedIntents
            .subtracting(producedIntents)
            .subtracting(DefaultActions.handledIntents)
        for intent in deadIntents.sorted(by: { $0.raw < $1.raw }) {
            definition.warnings.append(
                "a rule watches intent \"\(intent.raw)\", but no verb row produces "
                    + "it; if it was declared with #verb, list .\(intent.raw) in a "
                    + "verbs block.")
        }

        // The mirror of the check above: a row the parser can match whose
        // intent nothing anywhere answers. Typing it reaches stage 4, which
        // has no handler, no stub line and no override to offer, so the
        // player gets the engine's fall-back line and a free turn — correct,
        // but never what the author meant by adding the verb.
        //
        // Deliberately keyed on intents something *names*. A rule that answers
        // one noun and leaves the rest to the fall-back is the documented
        // pattern and warns nothing; a catch-all rule (empty `intents`, which
        // `Rule.matches` treats as "any") names no intent, so a game's
        // `world.beforeEachTurn` cannot quietly switch this check off.
        let unansweredIntents =
            producedIntents
            .subtracting(watchedIntents)
            .subtracting(DefaultActions.handledIntents)
            .subtracting(DefaultActions.engineIntents)
        for intent in unansweredIntents.sorted(by: { $0.raw < $1.raw }) {
            definition.warnings.append(
                "a verb row produces intent \"\(intent.raw)\", but nothing answers "
                    + "it; give it an action(.\(intent.raw)) or a rule, or the verb "
                    + "just prints the engine's fall-back line.")
        }

        // `maxScore` is read before any rule can run, so on its own it is the
        // author's arithmetic and nothing verifies it. Content conforming to
        // `ScoreDeclaring` knows its own award table; where one exists, the two
        // numbers must agree. Non-fatal — nothing breaks in play, and a
        // deliberately unreachable ceiling stays shippable.
        let declaredScore = declaredScores.reduce(0, +)
        if !declaredScores.isEmpty, declaredScore != game.maxScore {
            let drift = declaredScore - game.maxScore
            let consequence =
                drift > 0
                ? "\(drift) point(s) can be scored past the maximum"
                : "\(-drift) point(s) of the maximum are unreachable"
            definition.warnings.append(
                "the game's maxScore is \(game.maxScore), but its scoring content "
                    + "declares awards totalling \(declaredScore); \(consequence).")
        }

        definition.rules = table
        definition.timers = timers
        for event in timers.values where event.autostart {
            switch event.kind {
            case .fuse(let turns): state.activeFuses[event.name] = turns
            case .daemon: state.activeDaemons.insert(event.name)
            }
        }
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

/// Where an item currently is.
public enum Placement: Hashable, Sendable, Codable {
    case room(EntityID)
    /// Carried by the entity with this ID — the player today; an NPC once
    /// characters gain inventories of their own.
    case heldBy(EntityID)
    case on(EntityID)
    case inside(EntityID)
    /// Offstage — declared but not yet in play.
    case nowhere
}

/// Whether the game is in progress or how it ended.
public enum GameStatus: Hashable, Sendable, Codable {
    case playing
    case won
    case lost
    case quit
    /// The player has died. Over, but not final: the world's time has
    /// stopped, yet the program keeps reading — the death prompt offers
    /// RESTART / RESTORE / UNDO / QUIT.
    case dead

    /// Whether the program should stop reading input. `dead` is deliberately
    /// not final — the death prompt is still a conversation.
    var isFinal: Bool {
        self == .won || self == .lost || self == .quit
    }
}

/// Everything that changes during play, as a single value.
///
/// The immutable side of the world (names, descriptions, exits, rules,
/// vocabulary) lives in `GameDefinition`. Because `WorldState` is one
/// `Codable` value, save/restore *is* a serialization call — see `SaveFile`.
struct WorldState: Sendable, Codable {
    /// Where every item is. Written only through `place(_:_:)`, the one funnel
    /// that also invalidates `containmentCache`; the `private(set)` makes the
    /// compiler reject any write that would skip that funnel.
    private(set) var placements: [EntityID: Placement] = [:]
    /// The room the player is standing in. Written only through
    /// `setPlayerLocation(walkingTo:)` and `setPlayerLocation(placingAt:)`, the
    /// two funnels that also settle the boarding; the `private(set)` makes the
    /// compiler reject any write that would skip them.
    ///
    /// Turn-scoped code calls `Scratch.walkPlayer(to:)` and
    /// `Scratch.teleportPlayer(to:)` instead, which call through to these and
    /// also record the occupancy. They hold those two names on purpose: a
    /// `$0.state.walkPlayer(…)` inside a turn would skip the tally silently, so
    /// the spelling that would skip it does not exist.
    private(set) var playerLocation: EntityID
    var litRooms: Set<EntityID> = []
    /// `lightSource` items that are currently lit. Only light sources ever
    /// appear here; the `Item.isLit` setter and Bootstrap both guard on the
    /// trait.
    var litItems: Set<EntityID> = []
    var wornItems: Set<EntityID> = []
    /// Openable containers that are currently open. A container without the
    /// `openable` trait is always open and never appears here.
    var openItems: Set<EntityID> = []
    /// Lockable items that are currently locked.
    var lockedItems: Set<EntityID> = []
    /// Hidden items that have been revealed and are now perceivable normally.
    var revealedItems: Set<EntityID> = []
    /// Actors who are out cold. The engine branches on nothing here — see
    /// `Actor.isUnconscious` for why one condition is stored anyway.
    var unconsciousActors: Set<EntityID> = []
    /// What "it" currently refers to: the last direct object the player
    /// named (naming binds, even when the action then refuses).
    var pronounIt: EntityID?
    /// What "them" currently refers to: the group the last multi-object
    /// command expanded to, or the one `plural` thing the player last named
    /// — the stairs, the gloves. One slot for both, because the word does not
    /// distinguish them and the thing named last is the thing meant; a *count*
    /// of one is what makes the word a noun phrase rather than a group marker,
    /// and `StandardParser.Scope.soleThem` is where that is read.
    var pronounThem: [EntityID] = []
    /// The `enterable` the player has boarded, or nil on foot. The player
    /// still never appears in `placements`; `playerLocation` stays the room.
    ///
    /// This is the answer, not a claim to be re-checked: `strandIfSeparated()`
    /// clears it at the instant the player and the vehicle stop sharing a room.
    /// <doc:ActorsAndVehicles> states the rule the author sees.
    private(set) var playerVehicle: EntityID?
    var score = 0
    var moves = 0
    var touched: Set<EntityID> = []
    var visited: Set<EntityID> = []
    /// The actors the player has laid eyes on. Sampled once per turn in
    /// `GameWorld.commit` and never cleared within a timeline — though it is
    /// saved state like any other, so UNDO and RESTORE roll it back with
    /// everything else, and the next turn's sampling re-adds whoever is still
    /// in the room.
    ///
    /// This is what bounds the two naming reaches that are not visibility —
    /// FOLLOW's quarry and an order-taker's name — so that a person two
    /// hundred rooms away, whom the story has not introduced, cannot be
    /// followed or shouted at. See `Visibility.actorsElsewhere`.
    var metActors: Set<EntityID> = []
    var descriptionOverrides: [EntityID: String] = [:]
    var globals: [EntityID: StateValue] = [:]
    /// Running fuses: name → end-of-turn ticks left before firing. Names
    /// re-bind to the declared `TimedEvent` bodies; the closures themselves
    /// are code, not data, and never serialize.
    var activeFuses: [String: Int] = [:]
    /// Names of the daemons currently running each turn.
    var activeDaemons: Set<String> = []
    var status: GameStatus = .playing
    /// The random stream's position. Part of the saved state, so a restored
    /// game replays the exact same randomness it would have had.
    var rngState: UInt64 = 0

    /// The lazily built containment index for the current `placements`, or nil
    /// when it must be rebuilt. Pure derived data — never serialized (see
    /// `CodingKeys`) — and dropped by every `place(_:_:)`.
    private var containmentCache: ContainmentIndex?

    /// Every stored property except `containmentCache`, which is derived and
    /// must stay out of the save format. The cases carry their exact property
    /// names, so the encoded JSON matches the pre-index format key for key;
    /// the sole omission is the cache.
    ///
    /// The one difference from what the synthesized coder wrote: a nil
    /// ``pronounIt`` or ``playerVehicle`` is now an explicit `null` rather than
    /// an absent key. That is deliberate and is what ``init(from:)`` rests on —
    /// absence has to mean exactly one thing, "this save predates the
    /// property", and a coder that also omitted nils would make it mean two.
    /// Saves written either way still read, since `decodeIfPresent` answers nil
    /// to both.
    ///
    /// `CaseIterable` and internal rather than private so `SaveFormatTests` can
    /// ask the two questions a hand-written coder cannot answer for itself:
    /// that every key is encoded, and that every stored property has a key.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case placements
        case playerLocation
        case litRooms
        case litItems
        case wornItems
        case openItems
        case lockedItems
        case revealedItems
        case unconsciousActors
        case pronounIt
        case pronounThem
        case playerVehicle
        case score
        case moves
        case touched
        case visited
        case metActors
        case descriptionOverrides
        case globals
        case activeFuses
        case activeDaemons
        case status
        case rngState
    }

    /// Decodes a save written by *any* build whose format this one still reads.
    ///
    /// Hand-written for one reason: the synthesized `init(from:)` makes every
    /// key required, so the day a property was added, every save already on
    /// disk began throwing `keyNotFound` and the player was told "Restore
    /// failed." — indistinguishable from a corrupt file. Two properties went in
    /// that way before anyone noticed (#396).
    ///
    /// The rule, and it is the whole design: **a property with a declared
    /// default is a property an old save may omit.** Absence means the save
    /// predates the property, and the default is what that build would have
    /// behaved as. ``playerLocation`` is the one property with no default —
    /// there is no answer to "where is the player" to fall back on — so its
    /// absence is corruption rather than age, and it stays required.
    ///
    /// Adding a property therefore costs three lines (a ``CodingKeys`` case,
    /// one here, one in ``encode(to:)``) and no format bump. Forgetting any of
    /// the three is caught by `SaveFormatTests`, which is the trade that makes
    /// hand-writing this safe: the synthesized coder could not read an old
    /// save, but it also could not silently drop a property, and those tests
    /// buy that second guarantee back. It takes three of them to do it, one
    /// per line — and the third is the one that is easy not to think of.
    /// `theEncodedKeysAreExactlyTheCodingKeys` and
    /// `everyStoredPropertyHasACodingKey` are structural, and between them they
    /// prove only that every property has a key and every key is written. A
    /// property that has both and is never *read* here compiles cleanly — a
    /// stored property with a default is already initialized, so a hand-written
    /// `init` is under no obligation to assign it — and then resets to that
    /// default on every restore, with both structural tests green.
    /// `everyPropertySurvivesARoundTrip` is what hears that one: it sets every
    /// property to a value a fresh state doesn't hold, round-trips through
    /// JSON, and compares child by child over `Mirror`, so a property added
    /// later and left out of this list fails without anyone having to
    /// remember it.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The fallbacks are read off a fresh state rather than written out
        // again here, so "what an absent key means" and "what the property is
        // declared as" cannot drift apart — the property declaration stays the
        // single place either is stated.
        let fresh = WorldState(
            playerLocation: try container.decode(EntityID.self, forKey: .playerLocation))

        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try container.decodeIfPresent(T.self, forKey: key) ?? fallback
        }

        placements = try value(.placements, fresh.placements)
        playerLocation = fresh.playerLocation
        litRooms = try value(.litRooms, fresh.litRooms)
        litItems = try value(.litItems, fresh.litItems)
        wornItems = try value(.wornItems, fresh.wornItems)
        openItems = try value(.openItems, fresh.openItems)
        lockedItems = try value(.lockedItems, fresh.lockedItems)
        revealedItems = try value(.revealedItems, fresh.revealedItems)
        unconsciousActors = try value(.unconsciousActors, fresh.unconsciousActors)
        pronounIt = try container.decodeIfPresent(EntityID.self, forKey: .pronounIt)
        pronounThem = try value(.pronounThem, fresh.pronounThem)
        playerVehicle = try container.decodeIfPresent(EntityID.self, forKey: .playerVehicle)
        score = try value(.score, fresh.score)
        moves = try value(.moves, fresh.moves)
        touched = try value(.touched, fresh.touched)
        visited = try value(.visited, fresh.visited)
        metActors = try value(.metActors, fresh.metActors)
        descriptionOverrides = try value(.descriptionOverrides, fresh.descriptionOverrides)
        globals = try value(.globals, fresh.globals)
        activeFuses = try value(.activeFuses, fresh.activeFuses)
        activeDaemons = try value(.activeDaemons, fresh.activeDaemons)
        status = try value(.status, fresh.status)
        rngState = try value(.rngState, fresh.rngState)
    }

    /// Writes every key, always.
    ///
    /// Spelled out rather than synthesized so that it and ``init(from:)`` are
    /// the same list in the same order, and a property added to one but not the
    /// other is a line a reader can see missing. Nothing here is conditional:
    /// omitting a default-valued key would shrink the file at the cost of
    /// making "absent" mean two different things, and the decoder above rests
    /// on it meaning exactly one.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(placements, forKey: .placements)
        try container.encode(playerLocation, forKey: .playerLocation)
        try container.encode(litRooms, forKey: .litRooms)
        try container.encode(litItems, forKey: .litItems)
        try container.encode(wornItems, forKey: .wornItems)
        try container.encode(openItems, forKey: .openItems)
        try container.encode(lockedItems, forKey: .lockedItems)
        try container.encode(revealedItems, forKey: .revealedItems)
        try container.encode(unconsciousActors, forKey: .unconsciousActors)
        try container.encode(pronounIt, forKey: .pronounIt)
        try container.encode(pronounThem, forKey: .pronounThem)
        try container.encode(playerVehicle, forKey: .playerVehicle)
        try container.encode(score, forKey: .score)
        try container.encode(moves, forKey: .moves)
        try container.encode(touched, forKey: .touched)
        try container.encode(visited, forKey: .visited)
        try container.encode(metActors, forKey: .metActors)
        try container.encode(descriptionOverrides, forKey: .descriptionOverrides)
        try container.encode(globals, forKey: .globals)
        try container.encode(activeFuses, forKey: .activeFuses)
        try container.encode(activeDaemons, forKey: .activeDaemons)
        try container.encode(status, forKey: .status)
        try container.encode(rngState, forKey: .rngState)
    }
}

extension WorldState {
    /// A fresh state placing the player and every item. The one entry point
    /// that seeds `placements`, since the property is otherwise `private(set)`;
    /// Bootstrap uses it after assembling the starting map.
    ///
    /// - Parameters:
    ///   - playerLocation: the room the player starts in.
    ///   - placements: the starting item-to-placement map.
    init(playerLocation: EntityID, placements: [EntityID: Placement] = [:]) {
        self.playerLocation = playerLocation
        self.placements = placements
    }

    /// Sets an item's placement — the one write funnel for `placements`.
    /// Invalidating the cache here, and nowhere else, is what lets every reader
    /// trust `containment()`.
    ///
    /// - Parameters:
    ///   - id: the item to move.
    ///   - placement: where it now is.
    mutating func place(_ id: EntityID, _ placement: Placement) {
        placements[id] = placement
        containmentCache = nil
        if id == playerVehicle { strandIfSeparated() }
    }

    /// The player walks into `room`, and a boarded vehicle rides along — cargo
    /// and all, since cargo placements (`.inside(vehicle)`) never mention the
    /// room. Both halves land before anything can look, so the pair is never
    /// observed apart and the boarding survives the move.
    ///
    /// - Parameter room: the room the player ends up in.
    mutating func setPlayerLocation(walkingTo room: EntityID) {
        playerLocation = room
        if let playerVehicle { place(playerVehicle, .room(room)) }
    }

    /// The player is put down in `room` without walking there. A boarded
    /// vehicle stays where it was, and the boarding goes with it.
    ///
    /// - Parameter room: the room the player ends up in.
    mutating func setPlayerLocation(placingAt room: EntityID) {
        playerLocation = room
        strandIfSeparated()
    }

    /// Records that the player has boarded `vehicle`. A vehicle that isn't
    /// underfoot doesn't take, so the invariant holds on this writer too and
    /// no caller can seed a boarding the funnels could never settle.
    mutating func board(_ vehicle: EntityID) {
        playerVehicle = vehicle
        strandIfSeparated()
    }

    /// Records that the player is back on foot.
    mutating func disembark() {
        playerVehicle = nil
    }

    /// Drops the boarding when the player and their vehicle no longer share a
    /// room — the vehicle sank, was towed off, was pocketed, or the player was
    /// teleported out of it.
    ///
    /// Run after every write that can separate the two, which is what makes the
    /// stranding permanent. Deciding it at read time instead looks the same
    /// while they are apart and silently re-boards the player the moment they
    /// converge again (issue #321).
    ///
    /// Internal rather than private because decoding a save is the one write
    /// that reaches these properties without passing a funnel — `SaveFile.read`
    /// settles the boarding once on the way in.
    mutating func strandIfSeparated() {
        guard let vehicle = playerVehicle,
            placements[vehicle] != .room(playerLocation)
        else { return }
        disembark()
    }

    /// The containment index for the current `placements`, built on first use
    /// this turn and reused until the next `place(_:_:)`.
    ///
    /// - Returns: the cached (or freshly built) index.
    mutating func containment() -> ContainmentIndex {
        if let containmentCache { return containmentCache }
        let index = ContainmentIndex(placements: placements)
        containmentCache = index
        return index
    }

    /// Whether `id` is somewhere in `holder`'s possession — in their hands, or
    /// on or inside something they are carrying, to any depth. A placement walk
    /// UP from the item, so it costs the depth of the nesting and not the size
    /// of the world; cycle-guarded on the same grounds as `isConsistent`'s
    /// acyclicity check, since a corrupt save can present a cycle this walk
    /// must survive rather than trust.
    ///
    /// Not a scope question: an actor's possessions are his in the dark, in
    /// another room, and offstage. Backs ``Actor/possesses(_:)``.
    ///
    /// - Parameters:
    ///   - id: the item to trace upward.
    ///   - holder: the entity to look for on the way up.
    /// - Returns: true when `holder` carries `id`, however deeply.
    func isPossession(_ id: EntityID, of holder: EntityID) -> Bool {
        var current = id
        var visited: Set<EntityID> = []
        while visited.insert(current).inserted {
            switch placements[current] {
            case .heldBy(let carrier):
                if carrier == holder { return true }
                current = carrier
            case .on(let parent), .inside(let parent):
                current = parent
            case .room, .nowhere, nil:
                return false
            }
        }
        return false
    }

    /// The room `id` is ultimately standing in — the same walk UP as
    /// `isPossession(_:of:)`, run to the top instead of looking for somebody on
    /// the way. A coin inside a sack on a table in the Hall answers Hall, so it
    /// costs the depth of the nesting rather than the size of the world, where
    /// the alternative every caller reached for was a scan of a hand-written
    /// room list. Cycle-guarded on the same grounds: a corrupt save can present
    /// a cycle this walk must survive rather than trust.
    ///
    /// `nil` once the chain runs offstage — the item itself is `.nowhere`, or
    /// the container it sits in is, or the hands holding it are. Backs
    /// ``Item/location`` and, through it, ``Actor/location``.
    ///
    /// Not `Visibility.standing(_:in:)`, which reads one link and answers nil
    /// for a held or contained observer. That one is about reach, and being
    /// carried through a room is not standing in it; this one is about where
    /// a thing physically ends up.
    ///
    /// - Parameter id: the entity to trace upward.
    /// - Returns: the enclosing room, or nil when nothing in the chain is in one.
    func room(of id: EntityID) -> EntityID? {
        var current = id
        var visited: Set<EntityID> = []
        while visited.insert(current).inserted {
            // The player is placed `.nowhere` and their room tracked
            // separately, so they are the one link the placement map cannot
            // answer for. Checked first, which covers both the player's own
            // item and anything in their hands.
            if current == .player { return playerLocation }
            switch placements[current] {
            case .room(let room):
                return room
            case .heldBy(let parent), .on(let parent), .inside(let parent):
                current = parent
            case .nowhere, nil:
                return nil
            }
        }
        return nil
    }
}

extension WorldState {
    /// Whether this state is referentially consistent with `definition` — every
    /// ID it names is declared, every trait-gated set holds only entities with
    /// the trait, the containment graph is acyclic, and the scalar counters are
    /// in range. A restored save that fails any check is refused whole rather
    /// than silently repaired: a crafted or corrupt file must never reach the
    /// engine, where an unknown EntityID or a mistyped global would trap the
    /// process. Never mutates; `score` and `rngState` are accepted as-is (any
    /// value is legal for both).
    ///
    /// - Parameter definition: the bootstrapped game to validate against.
    /// - Returns: `true` when every check passes; `false` on the first failure.
    func isConsistent(with definition: GameDefinition) -> Bool {
        let items = definition.items
        let locations = definition.locations

        func isItem(_ id: EntityID) -> Bool { items[id] != nil }
        func isLocation(_ id: EntityID) -> Bool { locations[id] != nil }
        func isEntity(_ id: EntityID) -> Bool { isItem(id) || isLocation(id) }

        // The player must stand in a declared room.
        guard isLocation(playerLocation) else { return false }

        // Every placement's key is a declared item, and its target resolves to
        // an entity of the right kind (surfaces hold, containers contain).
        for (key, placement) in placements {
            guard isItem(key) else { return false }
            switch placement {
            case .room(let id):
                guard isLocation(id) else { return false }
            case .heldBy(let id):
                guard isItem(id) else { return false }
            case .on(let id):
                guard let def = items[id], def.isSurface else { return false }
            case .inside(let id):
                guard let def = items[id], def.isContainer else { return false }
            case .nowhere:
                break
            }
        }

        // The containment graph must be acyclic: walking each item's parent
        // chain (on / inside / held-by another item) must terminate.
        func parentItem(of placement: Placement) -> EntityID? {
            switch placement {
            case .on(let id), .inside(let id): return id
            case .heldBy(let id): return id
            case .room, .nowhere: return nil
            }
        }
        for start in placements.keys {
            var seen: Set<EntityID> = [start]
            var current = start
            while let parent = placements[current].flatMap(parentItem) {
                guard seen.insert(parent).inserted else { return false }
                current = parent
            }
        }

        // Trait-gated and existence sets: each holds only declared entities of
        // the required kind.
        guard litRooms.allSatisfy(isLocation) else { return false }
        guard litItems.allSatisfy({ items[$0]?.isLightSource == true }) else { return false }
        guard wornItems.allSatisfy({ items[$0]?.isWearable == true }) else { return false }
        guard openItems.allSatisfy({ items[$0]?.isOpenable == true }) else { return false }
        guard lockedItems.allSatisfy({ items[$0]?.isLockable == true }) else { return false }
        guard revealedItems.allSatisfy(isItem) else { return false }
        guard unconsciousActors.allSatisfy({ items[$0]?.isActor == true }) else { return false }
        guard visited.allSatisfy(isLocation) else { return false }
        guard touched.allSatisfy(isEntity) else { return false }
        guard metActors.allSatisfy({ items[$0]?.isActor == true }) else { return false }
        guard descriptionOverrides.keys.allSatisfy(isEntity) else { return false }

        // Pronouns name items; a boarded vehicle is an enterable item.
        if let it = pronounIt, !isItem(it) { return false }
        guard pronounThem.allSatisfy(isItem) else { return false }
        if let vehicle = playerVehicle, items[vehicle]?.isEnterable != true { return false }

        // Every global this build still declares must hold a value a rule
        // could read back, asked by running the very unboxing `@Global` would
        // run — so a mistyped scalar *and* a struct whose `Codable` shape moved
        // are both refused here, at the prompt, rather than trapping mid-turn
        // on first read.
        //
        // A name this build no longer declares is dropped rather than refused —
        // see `SaveFile.reconcile(_:with:)`, which owns that policy for globals
        // and timers alike.
        for (id, value) in globals {
            guard let global = definition.globals[id] else { continue }
            guard global.accepts(value) else { return false }
        }

        // Live fuses count down; a non-positive count would already have fired.
        guard activeFuses.values.allSatisfy({ $0 > 0 }) else { return false }

        // A save is taken mid-play, with a non-negative move count.
        guard status == .playing else { return false }
        guard moves >= 0 else { return false }

        return true
    }
}

extension StateValue {
    /// What the boxed value is, in the words the author declared it in.
    ///
    /// The half of a type-mismatch complaint that says what they *did* store,
    /// against the type they asked to read it as. The synthesized `description`
    /// would answer `int(5)`, which names the box rather than the declaration.
    var declaredTypeName: String {
        switch self {
        case .bool: "Bool"
        case .int: "Int"
        case .double: "Double"
        case .string: "String"
        // The type-erased case already carries `String(reflecting:)` of
        // whatever was boxed, which is the name the author wrote.
        case .data(let typeName, _): typeName
        }
    }

    /// The clause a trap uses for a value read as the wrong type.
    ///
    /// Two traps say this — `@Global`'s and ``TraitKey``'s — and one sentence
    /// written twice is how the timer traps lost half of theirs. Pure, so both
    /// wordings are pinned by the in-process tests over ``TraitKey`` rather than
    /// by a child process apiece.
    ///
    /// - Parameter wanted: the type the caller asked to read it as.
    /// - Returns: the clause, with no leading capital and no trailing stop.
    func cannotBeRead(as wanted: Any.Type) -> String {
        "is stored as \(declaredTypeName), which cannot be read as \(wanted)"
    }
}

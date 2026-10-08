// Gated on the `Playtest` package trait. See `Package.swift`.
#if Playtest

/// Every room a game declares and every exit its `map` block declares, read
/// without playing the game.
///
/// For offline tooling that needs the whole map before anyone walks it, such as
/// a layout solver. Room IDs are the IDs ``GameWorld/mapView()`` and
/// ``TurnReport/movement`` report at runtime, so a tool can match the two.
///
/// Reading it calls no author closure: a conditional exit's condition and a
/// dynamic exit's destination are never run. A dynamic exit reports the room
/// its author named with `mapsTo:`, if any. It holds no prose, so blocked-exit
/// messages and room descriptions are not in it. A move a rule makes, such as
/// `arrive(at:)`, is not an exit and is not in it either.
///
/// It lists exits as declared, whatever the world's state. A `hidden` door
/// that ``GameWorld/mapView()`` leaves out until it is revealed is listed as a
/// `door` exit. A conditional exit whose condition is false is listed, and so
/// are the exits of a dark room.
///
/// Encoding it with a `JSONEncoder` whose output formatting includes
/// `.sortedKeys` gives the same bytes every time for the same game. Room, door
/// and destination IDs are encoded as plain strings (`"kitchen"`), and optional
/// fields that are `nil` are left out of the JSON.
///
/// It exists only when Gnusto is compiled with its `Playtest` package trait,
/// which is on by default. `--disable-default-traits` turns that trait off only
/// in the package it is passed to. A package that depends on Gnusto turns it
/// off through its dependency's `traits:`, as a package made by `bin/new-game`
/// does by forwarding its own `Playtest` trait.
public struct DeclaredMap: Sendable, Codable, Equatable {
    /// One declared room.
    public struct Room: Sendable, Codable, Equatable {
        /// The room's ID.
        public let id: EntityID
        /// The room's declared name, as ``RoomMapView/name`` reports it.
        public let name: String
        /// The room's ``mapRegion(_:)`` label, if it declares one.
        public let region: String?
        /// The room's exits, in `Direction.allCases` order: north, south, east,
        /// west, northeast, northwest, southeast, southwest, up, down, in, out.
        public let exits: [Exit]
    }

    /// One declared exit.
    public struct Exit: Sendable, Codable, Equatable {
        /// How an exit was declared.
        public enum Kind: String, Sendable, Codable {
            /// A plain exit to a named room.
            case open
            /// A dead end that refuses with a message.
            case blocked
            /// An exit through a door item.
            case door
            /// An exit to a named room, passable while a condition holds.
            case conditional
            /// An exit whose destination is chosen when it is walked.
            case dynamic
        }

        /// The direction the exit leads.
        public let direction: Direction
        /// How it was declared.
        public let kind: Kind
        /// The declared destination of an `open`, `door` or `conditional` exit,
        /// or the room a `dynamic` exit was declared to map to with
        /// `mapsTo:`. `nil` for `blocked`, which leads nowhere,
        /// and for a `dynamic` exit that declares no map destination.
        public let destination: EntityID?
        /// The door item of a `door` exit; `nil` otherwise.
        public let door: EntityID?
        /// Whether the exit was declared ``MapEntry/secret``.
        public let isSecret: Bool
    }

    /// Every declared room, sorted by ID.
    public let rooms: [Room]

    /// Reads the map off a built definition, calling no closure.
    init(_ definition: GameDefinition) {
        rooms = definition.locations.sorted { $0.key < $1.key }.map { id, location in
            let exits = definition.exits[id] ?? [:]
            let secret = definition.secretExits[id] ?? []
            return Room(
                id: id,
                name: definition.locationName(of: id),
                region: location.mapRegion,
                exits: Direction.allCases.compactMap { direction in
                    exits[direction].map { Exit(direction, $0, isSecret: secret.contains(direction)) }
                })
        }
    }
}

extension DeclaredMap.Exit {
    /// Reads one exit's declared shape, running nothing.
    init(_ direction: Direction, _ target: ExitTarget, isSecret: Bool) {
        self.direction = direction
        self.isSecret = isSecret
        (kind, destination, door) =
            switch target {
            case .to(let destination): (.open, destination, nil)
            case .blocked: (.blocked, nil, nil)
            case .door(let destination, let door): (.door, destination, door)
            case .conditional(let destination, _, _): (.conditional, destination, nil)
            case .dynamic(_, let mapsTo): (.dynamic, mapsTo, nil)
            }
    }
}

// IDs are written as bare strings rather than as `EntityID`'s own keyed form,
// so a checked-in export reads `"id": "kitchen"`.
extension DeclaredMap.Room {
    private enum CodingKeys: String, CodingKey {
        case id, name, region, exits
    }

    /// Reads a room whose ID is a plain string.
    ///
    /// - Parameter decoder: the decoder to read from.
    /// - Throws: if a required field is missing or any field has the wrong type.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = EntityID(try container.decode(String.self, forKey: .id))
        name = try container.decode(String.self, forKey: .name)
        region = try container.decodeIfPresent(String.self, forKey: .region)
        exits = try container.decode([DeclaredMap.Exit].self, forKey: .exits)
    }

    /// Writes the room with its ID as a plain string, leaving out a `nil`
    /// region.
    ///
    /// - Parameter encoder: the encoder to write to.
    /// - Throws: if the encoder fails.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.raw, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(region, forKey: .region)
        try container.encode(exits, forKey: .exits)
    }
}

extension DeclaredMap.Exit {
    private enum CodingKeys: String, CodingKey {
        case direction, kind, destination, door, isSecret
    }

    /// Reads an exit whose destination and door are plain strings.
    ///
    /// - Parameter decoder: the decoder to read from.
    /// - Throws: if a required field is missing or any field has the wrong type.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        direction = try container.decode(Direction.self, forKey: .direction)
        kind = try container.decode(Kind.self, forKey: .kind)
        destination = try container.decodeIfPresent(String.self, forKey: .destination).map(EntityID.init)
        door = try container.decodeIfPresent(String.self, forKey: .door).map(EntityID.init)
        isSecret = try container.decode(Bool.self, forKey: .isSecret)
    }

    /// Writes the exit with its destination and door as plain strings,
    /// leaving out whichever is `nil`.
    ///
    /// - Parameter encoder: the encoder to write to.
    /// - Throws: if the encoder fails.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(direction, forKey: .direction)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(destination?.raw, forKey: .destination)
        try container.encodeIfPresent(door?.raw, forKey: .door)
        try container.encode(isSecret, forKey: .isSecret)
    }
}

extension PreparedGame {
    /// The game's declared rooms and exits, built on each read. See
    /// ``DeclaredMap``.
    public var declaredMap: DeclaredMap { DeclaredMap(definition) }
}

#endif

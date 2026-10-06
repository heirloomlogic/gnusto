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
/// dynamic exit's destination are never run. It holds no prose, so blocked-exit
/// messages and room descriptions are not in it. A move a rule makes, such as
/// `arrive(at:)`, is not an exit and is not in it either.
///
/// Encoding it with a `JSONEncoder` whose output formatting includes
/// `.sortedKeys` gives the same bytes every time for the same game. Optional
/// fields that are `nil` are left out of the JSON.
///
/// Part of the `Playtest` package trait: a build with
/// `--disable-default-traits` does not contain it.
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
        /// The declared destination of an `open`, `door` or `conditional` exit.
        /// `nil` for `blocked`, which leads nowhere, and for `dynamic`, which
        /// names no destination until it is walked.
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
            case .dynamic: (.dynamic, nil, nil)
            }
    }
}

extension PreparedGame {
    /// The game's declared rooms and exits, built on each read. See
    /// ``DeclaredMap``.
    public var declaredMap: DeclaredMap { DeclaredMap(definition) }
}

#endif

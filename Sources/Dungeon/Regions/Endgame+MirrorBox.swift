import Gnusto

/// Where the pole is. The source keeps `POLEUP` as a small integer and two
/// separate objects, `LPOLE` and `SPOLE`, for the two lengths of the same pole;
/// this is the integer, and the two objects are one item with a `describe` rule.
///
/// The distinction between ``inHole`` and ``inChannel`` is not decoration. Both
/// are "down" as far as rotating goes, and only ``inChannel`` satisfies the
/// Guardians.
enum PolePosition: Int, Codable, Sendable {
    /// Seated in the round hole in the floor of the second hallway room. Where
    /// it starts.
    case inHole = 0
    /// Seated in the stone channel, which needs the box square to the hallway.
    case inChannel = 1
    /// Resting on the floor, doing nothing.
    case onFloor = 2
    /// Up in the air, which is the only position the box will turn in.
    case raised = 3

    var isRaised: Bool { self == .raised }
}

/// Which part of the box a given side of it is.
enum BoxFace: Equatable {
    case mahogany
    case pine
    /// `MR1`, the one the red button opens.
    case mirror
    /// `MR2`, which only ever has to survive.
    case farMirror
}

/// The mirror box: its bearing, its berth, its pole and its glass.
///
/// A wrapper struct rather than seven `@Global`s for ``RoyalPuzzleGrid``'s
/// reason exactly — every read of a `@Global` decodes and every write encodes,
/// so the box is picked up once per rule body and put down once.
///
/// **The geometry is the issue's, derived from the source.** The mahogany end
/// stands at ``bearing``, the pine end opposite it, the openable mirror a
/// quarter turn counterclockwise and the second mirror a quarter turn
/// clockwise. Everything else here follows from that one sentence and from the
/// channel running north and south.
struct MirrorBox: Codable, Sendable, GlobalValue {
    /// The five hallway rooms the box can stand in, south to north:
    /// `MRA` `MRB` `MRC` `MRG` `MRD`. `MRG` is the Guardians'.
    static let berthCount = 5

    /// The index of the Guardians' room in that run.
    static let guardedBerth = 3

    /// The berth with the round hole in its floor, which is where the box
    /// starts and the only place the pole can be seated other than the channel.
    static let holeBerth = 1

    /// `MDIR`. Degrees clockwise from north, in steps of 45. Starts 270 — the
    /// box stands across the hallway with its openable mirror facing south.
    var bearing = 270

    /// `MLOC`, as an index into the channel. Starts at the second room.
    var berth = MirrorBox.holeBerth

    /// `POLEUP`.
    var pole = PolePosition.inHole

    /// `MR1` and `MR2`. Breaking either loses the game, so neither is ever set
    /// back to `true`.
    var mirrorIntact = true
    var farMirrorIntact = true

    /// `MIRROR-OPEN`, which the red button grants for seven turns.
    var mirrorOpen = false

    /// `WOOD-OPEN`, which pushing the pine end grants for five.
    var pineOpen = false

    init() {}

    /// A stale save has to degrade rather than trap, for the reason
    /// ``RoyalPuzzleGrid`` states: `Global`'s getter `fatalError`s on a payload
    /// it cannot decode instead of falling back to the declared default.
    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        bearing = (try? box.decode(Int.self, forKey: .bearing)) ?? 270
        berth = (try? box.decode(Int.self, forKey: .berth)) ?? Self.holeBerth
        pole = (try? box.decode(PolePosition.self, forKey: .pole)) ?? .inHole
        mirrorIntact = (try? box.decode(Bool.self, forKey: .mirrorIntact)) ?? true
        farMirrorIntact = (try? box.decode(Bool.self, forKey: .farMirrorIntact)) ?? true
        mirrorOpen = (try? box.decode(Bool.self, forKey: .mirrorOpen)) ?? false
        pineOpen = (try? box.decode(Bool.self, forKey: .pineOpen)) ?? false
    }

    // MARK: - Bearings

    /// The compass angle of a direction, clockwise from north. `nil` for the
    /// directions the hallway does not model.
    static func angle(of direction: Direction) -> Int? {
        switch direction {
        case .north: 0
        case .northeast: 45
        case .east: 90
        case .southeast: 135
        case .south: 180
        case .southwest: 225
        case .west: 270
        case .northwest: 315
        default: nil
        }
    }

    /// The word for a bearing, for the compass arrow to be read by.
    static func name(of angle: Int) -> String {
        [
            "north", "northeast", "east", "southeast",
            "south", "southwest", "west", "northwest",
        ][(angle % 360) / 45]
    }

    /// Which part of the box stands on the side facing `angle`, or `nil` when
    /// the box sits at a diagonal and no face is square to the hallway.
    func face(at angle: Int) -> BoxFace? {
        switch (angle - bearing + 720) % 360 {
        case 0: .mahogany
        case 180: .pine
        case 270: .mirror
        case 90: .farMirror
        default: nil
        }
    }

    /// The compass angle the named part of the box faces.
    func angle(of face: BoxFace) -> Int {
        let offset =
            switch face {
            case .mahogany: 0
            case .pine: 180
            case .mirror: 270
            case .farMirror: 90
            }
        return (bearing + offset) % 360
    }

    /// Whether an end of the box rather than a side of it faces along the
    /// hallway, which is what makes it narrow enough to squeeze past.
    var isEndOn: Bool { bearing % 180 == 0 }

    /// Whether the mirror the red button opens is standing open **and** facing
    /// the side the player is on.
    func isOpenToward(_ angle: Int) -> Bool {
        mirrorOpen && face(at: angle) == .mirror
    }

    /// Whether the box may be pushed one room along the channel: the mahogany
    /// end has to point along it.
    var slidesAlongTheChannel: Bool { isEndOn }

    /// Where a push on the mahogany end would take it, or `nil` at either end
    /// of the run.
    var berthAhead: Int? {
        guard slidesAlongTheChannel else { return nil }
        let next = bearing == 0 ? berth + 1 : berth - 1
        return (0..<Self.berthCount).contains(next) ? next : nil
    }

    /// The four conditions the Guardians let a box past on, all of which have
    /// to hold at once.
    var isSafeToPassTheGuardians: Bool {
        pole == .inChannel && mirrorIntact && farMirrorIntact && !mirrorOpen && !pineOpen
    }

    /// Whether swinging the pine end open would do it where the Guardians can
    /// see. In their own room always; one room north of them when the pine end
    /// faces south, and one room south of them when it faces north.
    var pineOpensInTheirView: Bool {
        if berth == Self.guardedBerth { return true }
        if berth == Self.guardedBerth + 1 { return angle(of: .pine) == 180 }
        if berth == Self.guardedBerth - 1 { return angle(of: .pine) == 0 }
        return false
    }

    /// Where the pole settles when it is let down: the round hole if the box is
    /// standing over it the way it started, the channel if it is square to the
    /// hallway, and the floor otherwise.
    var restingPlace: PolePosition {
        if berth == Self.holeBerth, bearing == 270 { return .inHole }
        return isEndOn ? .inChannel : .onFloor
    }
}

// MARK: - The hallway, and the box in it

extension DungeonEndgame {
    /// The five hallway rooms, south to north, indexed the way ``MirrorBox``
    /// indexes them.
    var channelRooms: [Location] {
        [hallwayA, hallwayB, hallwayC, hallwayG, hallwayD]
    }

    /// The narrow room on each side of each hallway room, in the same order.
    var flankingRooms: [(east: Location, west: Location)] {
        [
            (narrowAEast, narrowAWest), (narrowBEast, narrowBWest),
            (narrowCEast, narrowCWest), (narrowGEast, narrowGWest),
            (narrowDEast, narrowDWest),
        ]
    }

    /// Every room a player standing in it dies for standing in: the Guardians'
    /// own hallway room and the four narrow rooms in their reach.
    var guardedRooms: [Location] {
        [hallwayG, narrowGEast, narrowGWest, narrowDEast, narrowDWest]
    }

    /// The narrow rooms a player can actually be standing in, which is the first
    /// three berths' worth.
    ///
    /// Filtered against ``guardedRooms``, which is where "the Guardians can reach
    /// this" is actually recorded — not against the berth number, which only
    /// happens to agree with it today. A `describe` or a `before(.go)` on a room
    /// that kills on arrival can never run; eight such rules were declared until
    /// `/simplify` counted them.
    var standableFlankingRooms: [(east: Location, west: Location)] {
        let guarded = guardedRooms
        return flankingRooms.filter { !guarded.contains($0.east) }
    }

    /// The room one step north of a berth — the next hallway room, or, north of
    /// the last of them, the Dungeon Entrance.
    func roomNorth(of berth: Int) -> Location {
        berth + 1 < MirrorBox.berthCount ? channelRooms[berth + 1] : dungeonEntrance
    }

    /// And the room one step south of it, which below the first hallway room is
    /// the Small Room the beam crosses.
    func roomSouth(of berth: Int) -> Location {
        berth > 0 ? channelRooms[berth - 1] : smallRoom
    }

    /// Where the player is standing relative to the box, as a compass angle
    /// from the box, or `nil` when they are not beside it at all.
    ///
    /// - Parameter state: the box, already decoded by the caller.
    /// - Returns: the angle of the box's face the player is looking at.
    func angleOnTheBox(_ state: MirrorBox) -> Int? {
        let here = player.location
        if here == roomSouth(of: state.berth) { return 180 }
        if here == roomNorth(of: state.berth) { return 0 }
        let flanks = flankingRooms[state.berth]
        if here == flanks.east { return 90 }
        if here == flanks.west { return 270 }
        return nil
    }
}

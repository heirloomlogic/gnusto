// Per-direction map sugar for `Location`, split out to keep `Location.swift`
// lean. Every method here is a one-line delegation to one of the four general
// `exit(_:…)` forms declared on `Location`:
//
//   room.north(hall)                                  // plain destination
//   room.down(cellar, via: trapDoor)                  // shared openable door
//   room.west(forest, when: { flag }, otherwise: "…") // live-condition gate
//   room.east(blocked: "A wall blocks the way.")      // blocked with a message
//
// The four families (plain / via / when / blocked) repeat once per direction.
// Keeping them one-liners means the compass vocabulary reads uniformly and any
// new exit kind is added in exactly four general forms plus this thin sugar.
extension Location {
    /// An exit leading north to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func north(_ to: Location) -> MapEntry { exit(.north, to: to) }

    /// An exit leading south to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func south(_ to: Location) -> MapEntry { exit(.south, to: to) }

    /// An exit leading east to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func east(_ to: Location) -> MapEntry { exit(.east, to: to) }

    /// An exit leading west to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func west(_ to: Location) -> MapEntry { exit(.west, to: to) }

    /// An exit leading northeast to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func northeast(_ to: Location) -> MapEntry { exit(.northeast, to: to) }

    /// An exit leading northwest to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func northwest(_ to: Location) -> MapEntry { exit(.northwest, to: to) }

    /// An exit leading southeast to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func southeast(_ to: Location) -> MapEntry { exit(.southeast, to: to) }

    /// An exit leading southwest to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func southwest(_ to: Location) -> MapEntry { exit(.southwest, to: to) }

    /// An exit leading up to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func up(_ to: Location) -> MapEntry { exit(.up, to: to) }

    /// An exit leading down to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func down(_ to: Location) -> MapEntry { exit(.down, to: to) }

    /// An exit leading in to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func `in`(_ to: Location) -> MapEntry { exit(.in, to: to) }

    /// An exit leading out to `to`.
    ///
    /// - Parameter to: the destination room.
    /// - Returns: the map entry for this exit.
    public func out(_ to: Location) -> MapEntry { exit(.out, to: to) }

    /// A north exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func north(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.north, to: to, via: door) }

    /// A south exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func south(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.south, to: to, via: door) }

    /// An east exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func east(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.east, to: to, via: door) }

    /// A west exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func west(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.west, to: to, via: door) }

    /// A northeast exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func northeast(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.northeast, to: to, via: door) }

    /// A northwest exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func northwest(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.northwest, to: to, via: door) }

    /// A southeast exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func southeast(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.southeast, to: to, via: door) }

    /// A southwest exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func southwest(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.southwest, to: to, via: door) }

    /// An up exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func up(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.up, to: to, via: door) }

    /// A down exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func down(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.down, to: to, via: door) }

    /// An in exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func `in`(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.in, to: to, via: door) }

    /// An out exit through the shared openable door `door`.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - door: the shared openable door.
    /// - Returns: the map entry for this exit.
    public func out(
        _ to: Location,
        via door: Item
    ) -> MapEntry { exit(.out, to: to, via: door) }

    /// A north exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func north(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .north,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// A south exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func south(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .south,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// An east exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func east(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .east,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// A west exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func west(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .west,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// A northeast exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func northeast(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .northeast,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// A northwest exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func northwest(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .northwest,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// A southeast exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func southeast(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .southeast,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// A southwest exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func southwest(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .southwest,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// An up exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func up(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .up,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// A down exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func down(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .down,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// An in exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func `in`(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .in,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// An out exit gated by `condition`, refused with `otherwise` while false.
    ///
    /// - Parameters:
    ///   - to: the destination room.
    ///   - condition: gates the exit; open while it returns `true`.
    ///   - otherwise: the refusal shown while the condition is false.
    /// - Returns: the map entry for this exit.
    public func out(
        _ to: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise: String
    ) -> MapEntry {
        exit(
            .out,
            to: to,
            when: condition,
            otherwise: otherwise
        )
    }

    /// A north exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func north(blocked message: String) -> MapEntry { exit(.north, blocked: message) }

    /// A south exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func south(blocked message: String) -> MapEntry { exit(.south, blocked: message) }

    /// An east exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func east(blocked message: String) -> MapEntry { exit(.east, blocked: message) }

    /// A west exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func west(blocked message: String) -> MapEntry { exit(.west, blocked: message) }

    /// A northeast exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func northeast(blocked message: String) -> MapEntry { exit(.northeast, blocked: message) }

    /// A northwest exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func northwest(blocked message: String) -> MapEntry { exit(.northwest, blocked: message) }

    /// A southeast exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func southeast(blocked message: String) -> MapEntry { exit(.southeast, blocked: message) }

    /// A southwest exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func southwest(blocked message: String) -> MapEntry { exit(.southwest, blocked: message) }

    /// An up exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func up(blocked message: String) -> MapEntry { exit(.up, blocked: message) }

    /// A down exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func down(blocked message: String) -> MapEntry { exit(.down, blocked: message) }

    /// An in exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func `in`(blocked message: String) -> MapEntry { exit(.in, blocked: message) }

    /// An out exit blocked with the given refusal message.
    ///
    /// - Parameter message: the refusal shown when this way is tried.
    /// - Returns: the map entry for this exit.
    public func out(blocked message: String) -> MapEntry { exit(.out, blocked: message) }
}

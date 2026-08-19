import Gnusto

/// One appointment on an actor's day: where they are meant to be, from when.
///
/// The prose belongs to the *transition into* this stop — `departure` is
/// printed in the room being left and `arrival` in the room being entered, in
/// that order, the same way `GnustoActors` narrates a wandering actor. Both
/// are optional, and a stop with neither moves the actor in silence.
public struct Stop: Sendable {
    /// When the actor is due here.
    public let time: TimeOfDay

    /// Where they are due.
    public let destination: Location

    /// Printed in the room they leave on the way here, if the player is
    /// standing in it and can see.
    public let departure: String?

    /// Printed here on arrival, if the player is standing here and can see.
    public let arrival: String?

    /// What else happens when this stop comes round — once, on the turn it
    /// becomes current, whether or not the player is there to watch.
    public let perform: (@Sendable () throws -> Void)?

    /// Declares one stop on a timetable.
    ///
    /// - Parameters:
    ///   - time: when the actor is due.
    ///   - destination: where they are due.
    ///   - departure: the line printed in the room being left.
    ///   - arrival: the line printed in the room being entered.
    ///   - perform: what else happens when the stop comes round.
    public init(
        at time: TimeOfDay,
        in destination: Location,
        departure: String? = nil,
        arrival: String? = nil,
        perform: (@Sendable () throws -> Void)? = nil
    ) {
        self.time = time
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
        self.perform = perform
    }
}

/// An actor's day, written down: a list of stops the clock walks them through.
///
/// Where `GnustoActors`' `roams` gives a wanderer who *might* be somewhere,
/// a timetable gives one who *is*. That distinction is the whole point — it is
/// what makes ``location(at:)`` a truthful answer to "where was he at a quarter
/// to six", and so what lets a game check an alibi against something other than
/// prose somebody remembered to keep in sync.
///
/// ```swift
/// var butlerDay: Timetable {
///     Timetable(stops: [
///         Stop(at: TimeOfDay(17, 30), in: pantry),
///         Stop(at: TimeOfDay(17, 40), in: study,
///              departure: "The butler goes out through the service door.",
///              arrival: "The butler comes in with the coal scuttle."),
///         Stop(at: TimeOfDay(18, 15), in: pantry),
///     ])
/// }
///
/// var timers: [TimedEvent] { clock.schedule(butler, daemonName: "butler.day", butlerDay) }
/// var map: WorldMap { butler.starts(in: butlerDay.location(at: clock.start)) }
/// ```
///
/// A timetable is **plain data with no state of its own** — the bookkeeping
/// that makes a stop's action fire once lives on the ``Clock``, keyed by the
/// daemon's name. That is what lets a game declare one as an ordinary computed
/// property referring to its own rooms:
///
/// ```swift
/// var butlerDay: Timetable { Timetable(stops: [ … ]) }
/// ```
///
/// A stored property could not: property initializers run before `self`
/// exists, so `Stop(at: …, in: pantry)` would not compile. Keeping the type
/// stateless also means there is nothing to register in `content` and no
/// namespace to keep unique — the clock is the only bundle a scheduled game
/// has to remember.
public struct Timetable: Sendable {
    /// The stops, in time order.
    public let stops: [Stop]

    /// Declares a timetable.
    ///
    /// - Parameter stops: the day's appointments, in any order — they are
    ///   sorted here.
    public init(stops: [Stop]) {
        precondition(!stops.isEmpty, "Gnusto: a timetable needs at least one stop.")
        self.stops = stops.sorted { $0.time < $1.time }
    }

    /// Which stop is current at a given time: the latest one at or before it,
    /// wrapping at midnight so a time before the first stop belongs to the
    /// last stop of the previous day.
    ///
    /// - Parameter time: the time to resolve.
    /// - Returns: the index into ``stops``.
    func index(at time: TimeOfDay) -> Int {
        // Before the first stop the actor is still on yesterday's last one,
        // which is what makes an overnight timetable read the same on both
        // sides of midnight.
        var current = stops.count - 1
        for (index, stop) in stops.enumerated() where stop.time <= time {
            current = index
        }
        return current
    }

    /// The stop in force at a given time.
    ///
    /// - Parameter time: the time to resolve.
    /// - Returns: the stop the actor is keeping then.
    public func stop(at time: TimeOfDay) -> Stop {
        stops[index(at: time)]
    }

    /// Where the actor is — or was, or will be — at a given time.
    ///
    /// This is a pure function of the stops: it reads no world state and needs
    /// no live turn, so it works in a `map` block, in a rule, and in a plain
    /// unit test. That is deliberate. A game that answers "where was he?" from
    /// here cannot drift out of step with where he actually went.
    ///
    /// - Parameter time: the time to resolve.
    /// - Returns: the room the timetable puts the actor in then.
    public func location(at time: TimeOfDay) -> Location {
        stop(at: time).destination
    }
}

import Gnusto

extension Clock {
    /// Puts an actor on a timetable: a daemon that keeps them where their day
    /// says they should be.
    ///
    /// This is the deterministic counterpart to `GnustoActors`' `roams`. The
    /// announcement discipline is the same — the departure line prints only if
    /// the player is standing in the room being left, the arrival line only in
    /// the room being entered, and neither in the dark — but nothing here draws
    /// from the seeded random stream, because a suspect whose movements are a
    /// coin flip has no alibi worth checking.
    ///
    /// Movement is a **teleport to the scheduled room, with no exit-graph
    /// awareness**: a locked door on the route will not stop him. The contract
    /// a timetable is keeping is that he *is* in the study at a quarter past —
    /// not that he plausibly got there.
    ///
    /// If the physical journey matters, there are two ways to say so and they
    /// are not interchangeable:
    ///
    /// - **Make the room he passes through a stop of its own.** He is really
    ///   there, so `location(of:at:)` will say so and any testimony read off
    ///   the timetable inherits it. Costs a tick: the stop has to land on a
    ///   time the clock actually samples, which on a multi-minute turn means
    ///   taking one off a neighbouring leg.
    /// - **Say it from the stop that already moves him**, with a `perform:`
    ///   closure and `say(_:from:)` naming the room passed through. The line
    ///   prints on the same turn as that stop's own departure and arrival, and
    ///   in that room only. The timetable does not learn anything — he is
    ///   still a teleport, and a lookup will not place him on the grass — so
    ///   take this one when the crossing is *narration* and the stop times are
    ///   load-bearing elsewhere.
    ///
    /// `Sources/Fulminate` uses both: five actors on stops, and one crossing
    /// whose middle leg is a `perform:` line because the minutes on either side
    /// of it are quoted by a witness.
    ///
    /// An actor with no room — `vanish()`ed, shut in a chest, carried off —
    /// idles: the daemon does nothing and leaves the timetable's place
    /// untouched, so he picks his day back up where he left it if he is put
    /// down again. An actor merely *moved* somewhere off his route, by
    /// contrast, walks back on the next tick, because a timetable means he goes
    /// where he is supposed to be. **To take him off his rounds for good —
    /// arrested, murdered, sent away — call `stopDaemon(_:)`.**
    ///
    /// Timer names are global across a game; the convention here is
    /// `"<actor>.day"`.
    ///
    /// - Parameters:
    ///   - actor: whose day this is.
    ///   - daemonName: the daemon's name, unique across the whole game.
    ///   - timetable: the day to keep.
    /// - Returns: the timed event, for the game's `timers` block.
    public func schedule(
        _ actor: Actor,
        daemonName: String,
        _ timetable: Timetable
    ) -> TimedEvent {
        daemon(daemonName, autostart: true) {
            // Offstage entirely: idle without touching the place-keeper, so a
            // returning actor resumes his day rather than restarting it.
            guard let here = actor.location else { return }

            let due = timetable.index(at: now)
            let stop = timetable.stops[due]
            let isNewStop = stopIndices.byDaemon[daemonName] != due
            stopIndices.byDaemon[daemonName] = due

            if here != stop.destination {
                // Read the player's vantage point once, before the move, so
                // both lines are judged against where the player was standing
                // when it happened.
                let playerRoom = player.location
                let playerSees = playerRoom.isLit

                if let departure = stop.departure, playerSees, playerRoom == here {
                    say(departure)
                }
                actor.move(to: stop.destination)
                if let arrival = stop.arrival, playerSees, playerRoom == stop.destination {
                    say(arrival)
                }
            }

            // Once per stop, on the turn it comes round — not once per turn it
            // stays current, and not skipped when two stops share a room.
            if isNewStop {
                try stop.perform?()
            }
        }
    }

    /// Where a timetable puts its actor at a given time — the question a
    /// mystery is made of.
    ///
    /// - Parameters:
    ///   - timetable: the day to consult.
    ///   - time: the time to resolve.
    /// - Returns: the room the timetable puts the actor in then.
    public func location(of timetable: Timetable, at time: TimeOfDay) -> Location {
        timetable.location(at: time)
    }

    /// Where a timetable puts its actor right now.
    ///
    /// - Parameter timetable: the day to consult.
    /// - Returns: the room the timetable puts the actor in at the current time.
    public func location(of timetable: Timetable) -> Location {
        timetable.location(at: now)
    }
}

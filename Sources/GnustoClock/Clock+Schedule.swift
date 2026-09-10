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
    ///   the timetable inherits it. Costs a tick: for him to be *seen* there
    ///   the stop has to land on a time the clock actually samples, which on
    ///   a multi-minute turn means taking one off a neighbouring leg. A stop
    ///   that falls between two samples is jumped — its `perform:` still runs,
    ///   on the tick that passes it, but nobody watched him arrive or leave.
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
    /// idles: the daemon keeps his place in the day but moves him nowhere and
    /// runs no stop's `perform:`, so when he is put down again he goes where
    /// the day says he is *now*, and the stops that came round while he was
    /// gone stay unperformed rather than all firing at once. An actor merely
    /// *moved* somewhere off his route, by contrast, walks back on the next
    /// tick, because a timetable means he goes where he is supposed to be.
    /// **To take him off his rounds for good — arrested, murdered, sent away —
    /// call `stopDaemon(_:)`.**
    ///
    /// The daemon's first tick seeds his place from the opening time and runs
    /// nothing: the stop in force when the game opens has not *come round*, so
    /// a 9:00 stop's `perform:` does not fire on turn one of a game that opens
    /// at half past five.
    ///
    /// After that, a tick either **walks** or **lands**, and which one depends
    /// on the gap since the tick before it. A tick one turn after the last one
    /// walks: every stop it passed runs its `perform:`, in order, wrapping at
    /// midnight, which is what makes a clock running fifteen minutes to the
    /// turn honest about stops five minutes apart. Any other tick lands — he
    /// goes where the day says he is *now*, the stop in force runs, and the
    /// ones the gap flew over stay unperformed. That is the answer for a
    /// daemon started again some turns after `stopDaemon(_:)`, for a clock
    /// moved by ``advance(by:)`` or ``set(to:)``, and for a rewind, none of
    /// which mean he spent the interval walking his route. Inside a walk the
    /// place is written before each `perform:`, so a body that throws leaves
    /// that stop kept and the next tick picks up at the one after it.
    ///
    /// Timer names are global across a game; the convention here is
    /// `"<actor>.day"`.
    ///
    /// - Parameters:
    ///   - actor: whose day this is.
    ///   - name: the daemon's name, unique across the whole game.
    ///   - timetable: the day to keep.
    /// - Returns: the timed event, for the game's `timers` block.
    public func schedule(
        _ actor: Actor,
        named name: String,
        _ timetable: Timetable
    ) -> TimedEvent {
        daemon(name, autostart: true) {
            let due = timetable.index(at: now)
            let elapsed = elapsedMinutes
            let last = schedulePlaces.byDaemon[name]
            // Every path out of here records the place, because half of a
            // place is *when* it was taken: the next tick subtracts the two
            // readings to find out whether it is the turn immediately after
            // this one, and only a tick that is may walk the day forward over
            // the stops in between.
            func keep(_ stop: Int) {
                schedulePlaces.byDaemon[name] = Clock.Place(stop: stop, minutes: elapsed)
            }

            // Offstage entirely: keep his place in the day, and nothing else.
            guard let here = actor.location else {
                keep(due)
                return
            }

            let stop = timetable.stops[due]
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

            // The first tick only takes his place, and a tick on which
            // nothing came round has nothing to run.
            guard let last, last.stop != due else {
                keep(due)
                return
            }

            // An irregular tick — a daemon started again after
            // `stopDaemon(_:)`, a clock moved by `advance(by:)` or `set(to:)`,
            // a rewind — is looking at a place that was true a long time ago,
            // and walking the day forward from it would replay every stop
            // between, in a rush, possibly twice. So it *lands* instead: he
            // goes where the day says he is now and the stop in force runs,
            // which is what a tick did before the catch-up walk existed. The
            // stops the jump flew over stay unperformed, on the same grounds
            // the offstage branch above keeps his place silently.
            guard elapsed - last.minutes == minutesPerTurn else {
                keep(due)
                try stop.perform?()
                return
            }

            // A regular tick: once per stop, on the tick it comes round — not
            // once per turn it stays current, not skipped when two stops share
            // a room, and not skipped when a coarse clock steps over it. Every
            // stop passed since the last tick runs, in order, wrapping at
            // midnight. The place is written *before* each `perform`, so a
            // body that throws — `die`, a `reply` — leaves that stop marked
            // kept and the next tick resumes at the one after it rather than
            // dropping the rest of the walk for good.
            for index in timetable.indices(after: last.stop, through: due) {
                keep(index)
                try timetable.stops[index].perform?()
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

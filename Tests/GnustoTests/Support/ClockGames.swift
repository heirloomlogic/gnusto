import Gnusto
import GnustoClock

// Verbs the clock fixtures use to poke at the clock from inside a turn. They
// live here rather than in the library because moving the clock by hand is a
// game's business, not a verb every clock game should inherit.
extension Intent {
    /// Push the clock forward 45 minutes without spending the turns.
    #verb("skip", ["skip"])
    /// Set the clock forward to ten o'clock.
    #verb("jump", ["jump"])
    /// Set the clock to an hour *earlier* in the day — which lands tomorrow.
    #verb("rewind", ["rewind"])
    /// Stop the clock while turns keep passing.
    #verb("freeze", ["freeze"])
    /// Start it again.
    #verb("thaw", ["thaw"])
    /// Cancel an alarm that hasn't gone off.
    #verb("hush", ["hush"])
    /// Re-arm a cancelled or spent alarm.
    #verb("rearm", ["rearm"])
    /// Report which day it is.
    #verb("today", ["today"])
}

/// `skip` means the same thing in every fixture that has it, and two tests
/// assert its exact wording — so it is written once.
///
/// - Parameter clock: the fixture's clock.
/// - Returns: the skip action.
private func skipAction(_ clock: Clock) -> IntentAction {
    action(.skip) {
        clock.advance(by: 45)
        say("Skipped to \(clock.now).")
    }
}

/// One room and a clock at eight in the evening, a minute to the turn. The
/// room says the time on every look, so a bare `look` is a clock reading; the
/// boulder is here to be refused, and the three small items to be taken all at
/// once.
struct ClockLab: Game {
    let title = "Clock Lab"
    let intro = "A room with a clock in it."

    let clock = Clock(startingAt: TimeOfDay(20, 0), minutesPerTurn: 1)

    let lab = Location {
        name("Lab")
    }

    let boulder = Item {
        name("boulder")
        synonyms("rock", "stone")
        scenery
    }

    let coin = Item { name("coin") }
    let key = Item { name("key") }
    let pin = Item { name("pin") }

    var content: GameContents { clock }

    var verbs: [SyntaxRule] { [.skip, .jump, .rewind, .freeze, .thaw] }

    var actions: [IntentAction] {
        skipAction(clock)
        action(.jump) {
            clock.set(to: TimeOfDay(22, 0))
            say("Jumped to \(clock.now), day \(clock.day).")
        }
        action(.rewind) {
            clock.set(to: TimeOfDay(19, 0))
            say("Wound to \(clock.now), day \(clock.day).")
        }
        action(.freeze) {
            clock.pause()
            say("Frozen at \(clock.now).")
        }
        action(.thaw) {
            clock.resume()
            say("Thawed at \(clock.now).")
        }
    }

    var rules: Rules {
        lab.describe { "The lab. The clock says \(clock.now.formatted(.twentyFourHour))." }
    }

    var map: WorldMap {
        player.starts(in: lab)
        boulder.starts(in: lab)
        coin.starts(in: lab)
        key.starts(in: lab)
        pin.starts(in: lab)
    }
}

/// A quarter of an hour to the turn, with an alarm set for a minute the clock
/// never lands on exactly — the overstepping case.
struct SlowClockLab: Game {
    let title = "Slow Clock Lab"
    let intro = "A room where time moves in quarter hours."

    let clock = Clock(startingAt: TimeOfDay(20, 0), minutesPerTurn: 15)

    let lab = Location {
        name("Lab")
        description("A slow room.")
    }

    var content: GameContents { clock }

    var timers: [TimedEvent] {
        clock.at(TimeOfDay(20, 7), named: "slow.bell") {
            say("The bell rings at \(clock.now).")
        }
    }

    var map: WorldMap {
        player.starts(in: lab)
    }
}

/// Alarms, and the controls for cancelling and re-arming them.
struct AlarmLab: Game {
    let title = "Alarm Lab"
    let intro = "A room with two alarms in it."

    let clock = Clock(startingAt: TimeOfDay(20, 0), minutesPerTurn: 1)

    let lab = Location {
        name("Lab")
        description("A room with two alarms in it.")
    }

    var content: GameContents { clock }

    var verbs: [SyntaxRule] { [.skip, .hush, .rearm] }

    var actions: [IntentAction] {
        skipAction(clock)
        action(.hush) {
            stopDaemon("clock.bell")
            say("Hushed.")
        }
        action(.rearm) {
            startDaemon("clock.bell")
            say("Re-armed.")
        }
    }

    var timers: [TimedEvent] {
        clock.at(TimeOfDay(20, 5), named: "clock.bell") {
            say("The bell rings.")
        }
        clock.at(TimeOfDay(20, 30), named: "clock.late") {
            say("The late bell rings at \(clock.now).")
        }
    }

    var map: WorldMap {
        player.starts(in: lab)
    }
}

/// An hour to the turn, so a short run crosses midnight — for the day count
/// and for an alarm set earlier in the day than the game begins.
struct OvernightLab: Game {
    let title = "Overnight Lab"
    let intro = "A room where an hour goes by every turn."

    let clock = Clock(startingAt: TimeOfDay(20, 0), minutesPerTurn: 60)

    let lab = Location {
        name("Lab")
        description("A long night.")
    }

    var content: GameContents { clock }

    var verbs: [SyntaxRule] { [.today] }

    var actions: [IntentAction] {
        action(.today) {
            say("Day \(clock.day), \(clock.now).")
        }
    }

    var timers: [TimedEvent] {
        clock.at(TimeOfDay(2, 0), named: "clock.small") {
            say("The small hours arrive at \(clock.now).")
        }
    }

    var map: WorldMap {
        player.starts(in: lab)
    }
}

/// Two daemons whose names sort either side of any plausible clock daemon.
/// If the clock were advanced by a daemon of its own rather than derived from
/// the turn counter, these two would disagree — which is the whole point.
struct ProbeLab: Game {
    let title = "Probe Lab"
    let intro = "A room with two observers in it."

    let clock = Clock(startingAt: TimeOfDay(20, 0), minutesPerTurn: 1)

    let lab = Location {
        name("Lab")
        description("A watched room.")
    }

    var content: GameContents { clock }

    var timers: [TimedEvent] {
        daemon("aaa.probe", autostart: true) {
            say("aaa says \(clock.now)")
        }
        daemon("zzz.probe", autostart: true) {
            say("zzz says \(clock.now)")
        }
    }

    var map: WorldMap {
        player.starts(in: lab)
    }
}

// Verbs for poking at a scheduled actor from inside a turn.
extension Intent {
    /// Take the butler off the map entirely.
    #verb("abduct", ["abduct"])
    /// Put him back in the hall.
    #verb("recall", ["recall"])
    /// Move him somewhere his day doesn't call for.
    #verb("fetch", ["fetch"])
    /// Take him off his rounds for good.
    #verb("dismiss", ["dismiss"])
    /// Ask the timetable where he was at a quarter past eight.
    #verb("alibi", ["alibi"])
}

/// A butler on a fixed evening, in a house with one unlit room. A minute to
/// the turn from eight o'clock, so turn *n* reads `20:00 + (n-1)` and each
/// stop below falls on a turn you can count to.
///
/// The last two stops share a room on purpose: that is the case where the
/// actor never visibly moves and the stop's action must still fire exactly
/// once.
struct ManorLab: Game {
    let title = "Manor Lab"
    let intro = "A house with a butler in it."

    let clock = Clock(startingAt: TimeOfDay(20, 0), minutesPerTurn: 1)

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let dining = Location {
        name("Dining Room")
        description("A dining room.")
    }

    let study = Location {
        name("Study")
        description("A study.")
    }

    let cellar = Location {
        name("Cellar")
        description("A cellar.")
        dark
    }

    let butler = Actor {
        name("butler")
        description("The butler.")
        firstSight("The butler is here.")
    }

    /// Computed, not stored: a stored property initializer cannot see `self`,
    /// so it could not name the rooms above.
    var butlerDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(20, 0), in: hall),
            Stop(
                at: TimeOfDay(20, 3), in: dining,
                departure: "The butler leaves for the dining room.",
                arrival: "The butler comes in with a tray."),
            Stop(
                at: TimeOfDay(20, 6), in: study,
                departure: "The butler goes up.",
                arrival: "The butler lets himself into the study."),
            Stop(
                at: TimeOfDay(20, 9), in: cellar,
                departure: "The butler goes down to the cellar.",
                arrival: "The butler comes down the cellar steps."),
            Stop(
                at: TimeOfDay(20, 12), in: study,
                arrival: "The butler returns to the study."),
            Stop(at: TimeOfDay(20, 15), in: study) {
                say("The butler winds the clock.")
            },
        ])
    }

    var content: GameContents { clock }

    var verbs: [SyntaxRule] { [.abduct, .recall, .fetch, .dismiss, .alibi] }

    var actions: [IntentAction] {
        action(.abduct) {
            butler.vanish()
            say("Gone.")
        }
        action(.recall) {
            butler.move(to: hall)
            say("Back.")
        }
        action(.fetch) {
            butler.move(to: cellar)
            say("Sent down.")
        }
        action(.dismiss) {
            stopDaemon("butler.day")
            say("Dismissed.")
        }
        action(.alibi) {
            say("At 8:04 he was in the \(clock.location(of: butlerDay, at: TimeOfDay(20, 4)).name).")
        }
    }

    var timers: [TimedEvent] {
        clock.schedule(butler, daemonName: "butler.day", butlerDay)
    }

    var map: WorldMap {
        hall.north(dining)
        dining.south(hall)
        hall.up(study)
        study.down(hall)
        hall.down(cellar)
        cellar.up(hall)

        player.starts(in: hall)
        // Where the timetable says he is when the game opens — read from the
        // timetable rather than repeated, so the two can't disagree.
        butler.starts(in: butlerDay.location(at: TimeOfDay(20, 0)))
    }
}

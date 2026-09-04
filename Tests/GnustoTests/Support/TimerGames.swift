import Gnusto

/// A fixture for fuse/daemon mechanics: a bomb fuse the player primes and
/// defuses, a drip daemon summoned and banished, plus takable clutter and a
/// scenery boulder for refused-turn and `take all` tick discipline.
struct ClockGame: Game {
    let title = "Clock"
    let intro = "The workshop ticks."

    let workshop = Location {
        name("Workshop")
        description("Gears everywhere.")
    }

    let boulder = Item {
        name("granite boulder")
        scenery
    }

    let cog = Item { name("brass cog") }
    let spring = Item { name("coiled spring") }
    let widget = Item { name("dull widget") }

    var map: WorldMap {
        player.starts(in: workshop)
        boulder.starts(in: workshop)
        cog.starts(in: workshop)
        spring.starts(in: workshop)
        widget.starts(in: workshop)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("prime", intent: Intent("prime"))
        SyntaxRule("shortprime", intent: Intent("shortprime"))
        SyntaxRule("defuse", intent: Intent("defuse"))
        SyntaxRule("summon", intent: Intent("summon"))
        SyntaxRule("banish", intent: Intent("banish"))
        SyntaxRule("probe", intent: Intent("probe"))
    }

    var rules: Rules {
        world.before(Intent("prime")) {
            startFuse("bomb")
            try reply("You prime the bomb.")
        }
        world.before(Intent("shortprime")) {
            startFuse("bomb", after: 1)
            try reply("You prime the bomb on a short fuse.")
        }
        world.before(Intent("defuse")) {
            stopFuse("bomb")
            try reply("Defused.")
        }
        world.before(Intent("summon")) {
            startDaemon("drip")
            try reply("Summoned.")
        }
        world.before(Intent("banish")) {
            stopDaemon("drip")
            try reply("Banished.")
        }
        world.before(Intent("probe")) {
            try reply("Remaining: \(fuseRemaining("bomb").map(String.init) ?? "none")")
        }
    }

    var timers: [TimedEvent] {
        fuse("bomb", after: 3) {
            say("The bomb goes off!")
        }
        daemon("drip") {
            say("Drip.")
        }
    }
}

/// Autostarted timers: a heartbeat daemon running from turn one and a dawn
/// fuse that fires on its own schedule, no rule involved. The doom fuse ends
/// the game, proving a fatal fuse stops the daemons behind it that turn.
struct HeartbeatGame: Game {
    let title = "Heartbeat"
    let intro = "A quiet room with a pulse."

    let room = Location {
        name("Quiet Room")
        description("Nothing here but the sound.")
    }

    var map: WorldMap {
        player.starts(in: room)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("doom", intent: Intent("doom"))
    }

    var rules: Rules {
        world.before(Intent("doom")) {
            startFuse("doom", after: 1)
            try reply("The countdown starts.")
        }
    }

    var timers: [TimedEvent] {
        daemon("heartbeat", autostart: true) {
            say("Thump.")
        }
        fuse("dawn", after: 2, autostart: true) {
            say("Dawn breaks.")
        }
        fuse("doom", after: 9) {
            say("Doom arrives.")
            try end(won: false)
        }
    }
}

/// Invalid timer declarations: a duplicate name and a fuse with a zero count,
/// both fatal, reported together.
struct BadTimersGame: Game {
    let title = "Bad Timers"
    let intro = "Should never boot."

    let room = Location { name("Room") }

    var map: WorldMap {
        player.starts(in: room)
    }

    var timers: [TimedEvent] {
        fuse("dup", after: 2) {}
        daemon("dup") {}
        fuse("zero", after: 0) {}
    }
}

/// The seven ways a rule body can name a timer wrongly, and what the engine
/// must say about each.
///
/// Six are kind mismatches — a fuse helper handed a daemon's name, or the
/// reverse — and the seventh is a name no `timers` block declares. All seven
/// trap, and the message's job is to hand the author the helper they meant:
/// `startFuse` on a daemon has to say `startDaemon(_:)`, or the author reads a
/// complaint and still doesn't know the fix. `Codable` because
/// `TimerTests` feeds these cases into an exit test, whose body can only
/// capture values it can encode.
enum TimerMisuse: String, CaseIterable, Codable, Sendable {
    case startFuseOnADaemon
    case stopFuseOnADaemon
    case fuseRemainingOnADaemon
    case startDaemonOnAFuse
    case stopDaemonOnAFuse
    case isDaemonActiveOnAFuse
    case anUndeclaredName

    /// The misuse and the two things the trap has to say about it, on one line
    /// each: the call the message quotes back so the author can find the line,
    /// and the fix it names. Together rather than in three parallel switches,
    /// because a call paired with the wrong advice is the failure this is
    /// guarding against, and here that pairing is one line to read.
    var spec: (namesTheCall: String, saysUse: String, commit: @Sendable () -> Void) {
        switch self {
        case .startFuseOnADaemon:
            (#"startFuse("drip") names a daemon"#, "use startDaemon(_:)", { startFuse("drip") })
        case .stopFuseOnADaemon:
            (#"stopFuse("drip") names a daemon"#, "use stopDaemon(_:)", { stopFuse("drip") })
        case .fuseRemainingOnADaemon:
            (
                #"fuseRemaining("drip") names a daemon"#, "use isDaemonActive(_:)",
                { _ = fuseRemaining("drip") }
            )
        case .startDaemonOnAFuse:
            (#"startDaemon("bomb") names a fuse"#, "use startFuse(_:after:)", { startDaemon("bomb") })
        case .stopDaemonOnAFuse:
            (#"stopDaemon("bomb") names a fuse"#, "use stopFuse(_:)", { stopDaemon("bomb") })
        case .isDaemonActiveOnAFuse:
            (
                #"isDaemonActive("bomb") names a fuse"#, "use fuseRemaining(_:)",
                { _ = isDaemonActive("bomb") }
            )
        case .anUndeclaredName:
            (
                #"startFuse("nonesuch")"#, "no timer with that name is declared",
                { startFuse("nonesuch") }
            )
        }
    }

    /// The one-word verb ``TimerMisuseGame`` answers by committing this misuse.
    /// Derived, so two cases cannot collide on one verb and quietly declare the
    /// same intent twice.
    var command: String { rawValue.lowercased() }
}

/// Two content bundles that each declare a daemon with the bare name `roam` —
/// the collision issue #403 exists to allow — plus a host whose own daemon
/// claims the same bare name. Each bundle starts its own daemon from its own
/// rule, by the literal name it declared; the host can stop either bundle's
/// daemon only by its qualified name.
struct AlphaRoamBundle: GameContent {
    let porch = Location {
        name("Alpha Porch")
        description("A sagging porch.")
    }

    var rules: Rules {
        world.before(Intent("rousea")) {
            startDaemon("roam")
            try reply("The alpha roam wakes.")
        }
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("rousea", intent: Intent("rousea"))
    }

    var timers: [TimedEvent] {
        daemon("roam") {
            say("[alpha] Something roams.")
        }
    }
}

struct BetaRoamBundle: GameContent {
    let yard = Location {
        name("Beta Yard")
        description("A fenced yard.")
    }

    var rules: Rules {
        world.before(Intent("rouseb")) {
            startDaemon("roam")
            try reply("The beta roam wakes.")
        }
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("rouseb", intent: Intent("rouseb"))
    }

    var timers: [TimedEvent] {
        daemon("roam") {
            say("[beta] Something roams.")
        }
    }
}

/// The host of the two roaming bundles. Its own daemon is *also* named `roam`
/// and autostarts, so the schedule holds one bare key and two namespaced ones
/// at once.
struct RoamGame: Game {
    let title = "Roam"
    let intro = "Two porches and whatever roams between them."

    let alpha = AlphaRoamBundle()
    let beta = BetaRoamBundle()

    var content: GameContents {
        alpha
        beta
    }

    var map: WorldMap {
        player.starts(in: alpha.porch)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("hushalpha", intent: Intent("hushalpha"))
        SyntaxRule("hushbeta", intent: Intent("hushbeta"))
    }

    var rules: Rules {
        world.before(Intent("hushalpha")) {
            stopDaemon("AlphaRoamBundle.roam")
            try reply("The alpha roam sleeps.")
        }
        world.before(Intent("hushbeta")) {
            stopDaemon("BetaRoamBundle.roam")
            try reply("The beta roam sleeps.")
        }
    }

    var timers: [TimedEvent] {
        daemon("roam", autostart: true) {
            say("[game] Something roams.")
        }
    }
}

/// One fuse, one daemon, and a verb per way of confusing them.
///
/// **This game cannot be played to the end of a turn**: every verb it answers
/// traps. `TimerTests` runs it once per ``TimerMisuse`` in a child process.
struct TimerMisuseGame: Game {
    let title = "Timer Misuse"
    let intro = "A workshop where every lever is the wrong one."

    let workshop = Location {
        name("Workshop")
        description("Gears everywhere.")
    }

    var map: WorldMap {
        player.starts(in: workshop)
    }

    var verbs: [SyntaxRule] {
        for misuse in TimerMisuse.allCases {
            // `.word(_:)` rather than the string literal `SyntaxRule("verb", …)`
            // takes: the literal form needs a compile-time string, and this one
            // comes from the case.
            SyntaxRule(.word(misuse.command), intent: Intent(misuse.command))
        }
    }

    var rules: Rules {
        for misuse in TimerMisuse.allCases {
            // Bound out here rather than reached through `spec` in the body: the
            // property builds both strings to hand back the third field.
            let commit = misuse.spec.commit
            world.before(Intent(misuse.command)) { commit() }
        }
    }

    var timers: [TimedEvent] {
        fuse("bomb", after: 3) {}
        daemon("drip") {}
    }
}

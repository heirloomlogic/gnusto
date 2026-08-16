import Gnusto
import GnustoDangerousDark

/// Fixtures for the `DangerousDark` plugin: a lit camp, a dark cave, and a
/// carriable lamp. `NightfallGame` takes the plugin's stock prose but pins
/// `lethality` to 100 so the dice always bite on the first roll — a
/// deterministic cadence to assert the warn/grace structure; `PatientDarkGame`
/// overrides the grace and does the same; `FickleDarkGame` keeps a middling
/// lethality so the dice can spare a turn, proving they are dice.
struct NightfallGame: Game {
    let title = "Nightfall"
    let intro = "The sun is gone and the cave mouth gapes."

    let camp = Location {
        name("Camp")
        description("A ring of stones around dead coals.")
    }

    let cave = Location {
        name("Cave")
        description("A low limestone chamber.")
        dark
    }

    let lamp = Item {
        name("tin lamp")
        lightSource
        startsLit
    }

    let dangerousDark = DangerousDark(lethality: 100)

    var content: GameContents {
        dangerousDark
    }

    var map: WorldMap {
        camp.north(cave)
        cave.south(camp)
        player.starts(in: camp)
        lamp.starts(in: camp)
    }
}

/// A middling lethality (40%): the dice can and do spare a dark turn or two
/// before the grue lands, so a pinned seed shows a survived roll — proof the
/// schedule is a dice roll, not a fixed clock.
struct FickleDarkGame: Game {
    let title = "Fickle Dark"
    let intro = "The dark here is patient, but not forever."

    let camp = Location {
        name("Camp")
        description("A ring of stones around dead coals.")
    }

    let cave = Location {
        name("Cave")
        description("A low limestone chamber.")
        dark
    }

    let dangerousDark = DangerousDark(
        warning: "The darkness is absolute, and something in it is breathing.",
        death: "Something in the dark finds you before you find it.",
        graceTurns: 0,
        lethality: 40
    )

    var content: GameContents {
        dangerousDark
    }

    var map: WorldMap {
        camp.north(cave)
        cave.south(camp)
        player.starts(in: camp)
    }
}

/// A dark with a warded room in it: the Shrine suspends the grue for as long
/// as the player stands there, and the Cave switches it back on. This is the
/// shape of Dungeon's Crypt — the one room whose solution is to stand in the
/// dark on purpose — and the fixture the warning-turn guarantee is pinned
/// against across a suspension.
///
/// No grace and lethality 100, so the schedule is exactly two beats: warn on
/// dark turn 1, die on dark turn 2. A resumed count that killed instead of
/// warning would therefore be unmissable.
struct WardedDarkGame: Game {
    let title = "Warded Dark"
    let intro = "The cave mouth gapes, and something older keeps the shrine."

    let camp = Location {
        name("Camp")
        description("A ring of stones around dead coals.")
    }

    let cave = Location {
        name("Cave")
        description("A low limestone chamber.")
        dark
    }

    let shrine = Location {
        name("Shrine")
        description("Whatever is warded out of here stays out.")
        dark
    }

    /// Stock prose, like ``NightfallGame``'s — the knobs are the schedule, not
    /// the words.
    let dangerousDark = DangerousDark(graceTurns: 0, lethality: 100)

    var content: GameContents {
        dangerousDark
    }

    var rules: Rules {
        shrine.onEnter { dangerousDark.suspended = true }
        cave.onEnter { dangerousDark.suspended = false }
    }

    var map: WorldMap {
        camp.north(cave)
        camp.east(shrine)
        cave.south(camp)
        cave.north(shrine)
        shrine.west(camp)
        shrine.south(cave)
        player.starts(in: camp)
    }
}

/// The Zork arrangement: one sentence bound to *both* knobs. `text.pitchBlack`
/// and the plugin's `warning` are the same string, because in this voice the
/// dark-room line **is** the threat — which is exactly what Zork 1
/// (`Sources/Zork1/Zork1.swift`) and Dungeon (`Sources/Dungeon/Dungeon.swift`)
/// both do. Walking in fires the describer and then the daemon, so without a
/// once-per-turn emitter the player reads the sentence twice.
///
/// Grace 1 and lethality 100, so the cadence is three beats — warn on dark turn
/// 1, silence on 2, death on 3 — and a warning silenced for being a repeat can
/// be told apart from a warning that never ticked the counter.
struct GrueVoicedDarkGame: Game {
    /// The one sentence, so the fixture cannot drift out of agreement with
    /// itself the way two literals would.
    static let grue = "It is pitch black. You are likely to be eaten by a grue."

    let title = "Grue-Voiced Dark"
    let intro = "The lamp is the only argument you have."

    let camp = Location {
        name("Camp")
        description("A ring of stones around dead coals.")
    }

    let cave = Location {
        name("Cave")
        description("A low limestone chamber.")
        dark
    }

    let lamp = Item {
        name("tin lamp")
        lightSource
        startsLit
    }

    let dangerousDark = DangerousDark(
        warning: GrueVoicedDarkGame.grue,
        death: "Something in the dark finds you before you find it.",
        graceTurns: 1,
        lethality: 100
    )

    /// One voice for the whole dark: the room's line, the line that announces a
    /// doused lamp, and the grue's warning are one sentence. Three emitters,
    /// three routes into darkness, one thing to read.
    var text: GameText {
        var text = GameText()
        text.pitchBlack = .init(GrueVoicedDarkGame.grue)
        text.nowDark = .init(GrueVoicedDarkGame.grue)
        return text
    }

    var content: GameContents {
        dangerousDark
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("summon", intent: Intent("summon"))
    }

    var timers: [TimedEvent] {
        // The order-independent case: a timer that speaks the sentence *first*
        // and only then puts the player in the dark, so the describer is the
        // second emitter rather than the first. Fuses tick ahead of daemons
        // (`GameWorld.tickTimers`), so this turn has three claims on one
        // sentence — the fuse, the room describer, and the grue.
        fuse("lure", after: 1) {
            say(GrueVoicedDarkGame.grue)
            arrive(at: cave)
        }
    }

    var rules: Rules {
        world.before(Intent("summon")) {
            startFuse("lure")
            try reply("Something takes hold of you.")
        }
    }

    var map: WorldMap {
        camp.north(cave)
        cave.south(camp)
        player.starts(in: camp)
        lamp.starts(in: camp)
    }
}

/// Custom prose and a three-turn grace period.
struct PatientDarkGame: Game {
    let title = "Patient Dark"
    let intro = "Something out there is very, very patient."

    let camp = Location {
        name("Camp")
        description("A ring of stones around dead coals.")
    }

    let cave = Location {
        name("Cave")
        description("A low limestone chamber.")
        dark
    }

    let dangerousDark = DangerousDark(
        warning: "W.",
        death: "D.",
        graceTurns: 3,
        lethality: 100
    )

    var content: GameContents {
        dangerousDark
    }

    var map: WorldMap {
        camp.north(cave)
        cave.south(camp)
        player.starts(in: camp)
    }
}

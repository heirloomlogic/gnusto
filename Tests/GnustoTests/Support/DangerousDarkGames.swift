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

import Gnusto
import GnustoDangerousDark

/// Fixtures for the `DangerousDark` plugin: a lit camp, a dark cave, and a
/// carriable lamp. `NightfallGame` takes the plugin's stock prose and
/// schedule; `PatientDarkGame` overrides all three knobs to prove they are
/// knobs.
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

    let dangerousDark = DangerousDark()

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
        graceTurns: 3
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

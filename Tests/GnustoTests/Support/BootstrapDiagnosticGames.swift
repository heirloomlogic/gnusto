import Gnusto

extension TraitKey<Int> {
    static let diagnosticValue = Self("diagnosticValue")
}

struct DuplicateDeclarationsGame: Game {
    let title = "Duplicates"
    let intro = ""

    let zeta = Location {
        name("First room name")
        name("Second room name")
        description("First room description.")
        description("Second room description.")
        trait(.diagnosticValue, 1)
        trait(.diagnosticValue, 2)
    }

    let alpha = Item {
        name("first item name")
        name("second item name")
        description("First item description.")
        description("Second item description.")
        firstSight("First listing line.")
        firstSight("Second listing line.")
        capacity(1)
        capacity(2)
        trait(.diagnosticValue, 1)
        trait(.diagnosticValue, 2)
    }

    var map: WorldMap {
        player.starts(in: zeta)
        alpha.starts(in: zeta)
    }
}

struct StatefulPlugin: GamePlugin {
    @Global var counter = 0
    @Latch var fired
    let room = Location { name("Plugin room") }
    let item = Item { name("plugin item") }
    let actor = Actor { name("plugin actor") }
}

struct StatefulPluginHost: Game {
    let title = "Stateful plugin host"
    let intro = ""
    let contraband = StatefulPlugin()
    let hall = Location { name("Hall") }

    var map: WorldMap { player.starts(in: hall) }
}

struct InertDeclarationsGame: Game {
    let title = "Inert declarations"
    let intro = ""
    let hall = Location { name("Hall") }
    let wornOnly = Item { name("worn item") }
    let transparentOnly = Item {
        name("glass")
        transparent
    }
    let openOnly = Item {
        name("ajar thing")
        startsOpen
    }
    let capacityOnly = Item {
        name("measured thing")
        capacity(2)
    }

    var map: WorldMap {
        player.starts(in: hall)
        wornOnly.startsWorn
    }
}

struct ReservedWordItemGame: Game {
    let title = "Reserved item words"
    let intro = ""
    let hall = Location { name("Hall") }
    let ambiguous = Item {
        name("it")
        adjectives("them")
    }

    var map: WorldMap {
        player.starts(in: hall)
        ambiguous.starts(in: hall)
    }
}

struct CapitalizedVerbGame: Game {
    let title = "Capitalized verb"
    let intro = ""
    let hall = Location { name("Hall") }

    var verbs: [SyntaxRule] { SyntaxRule("Ring", intent: Intent("ring")) }
    var map: WorldMap { player.starts(in: hall) }
}

struct DanglingExitTargetsGame: Game {
    let title = "Dangling targets"
    let intro = ""
    let hall = Location { name("Hall") }
    let garden = Location { name("Garden") }

    var map: WorldMap {
        hall.north(Location { name("Inline destination") })
        hall.east(garden, via: Item { name("inline door") })
        player.starts(in: hall)
    }
}

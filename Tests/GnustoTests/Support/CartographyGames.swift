import Gnusto

/// The fixture for what a front end reads after each turn: ``TurnReport``,
/// ``GameWorld/vocabulary()`` and ``GameWorld/mapView()``.
///
/// One small house holds one of every kind of exit, so each read is pinned by
/// a walk of a few moves:
///
/// - the hall: a plain exit north; a trap door down, hidden under the rug until
///   it is pushed; a gate east, latched until `unlatch`; a solid wall west;
/// - the kitchen: a plain exit back south, a secret ladder up, and a dynamic
///   exit east whose destination is chosen when it is walked;
/// - the cellar, which is dark;
/// - two rooms of a maze, sharing one `mapRegion`.
///
/// `pray` puts the player in the garden without walking, from anywhere.
struct CartographyGame: Game {
    let title = "Cartography"
    let intro = "A small house, drawn for a map."

    @Global var gateOpen = false

    let hall = Location {
        name("Hall")
        description("A bare hall with a rug on the floor. The kitchen is north, and a gate stands east.")
    }
    let kitchen = Location {
        name("Kitchen")
        description("A cold kitchen. A door opens east.")
    }
    let garden = Location {
        name("Garden")
        description("A walled garden.")
    }
    let cellar = Location {
        name("Cellar")
        description("A damp cellar.")
        dark
    }
    let loft = Location {
        name("Loft")
        description("A low loft under the eaves.")
    }
    let mazeA = Location {
        name("Twisty Passage")
        description("Passages twist away in every direction.")
        mapRegion("Maze")
    }
    let mazeB = Location {
        name("Twisty Passage")
        description("Passages twist away in every direction.")
        mapRegion("Maze")
    }

    let rug = Item {
        name("rug")
        description("A threadbare rug.")
        scenery
    }
    let trapDoor = Item {
        name("trap door")
        openable
        hidden
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("unlatch", intent: Intent("unlatch"))
        SyntaxRule("pray", intent: Intent("pray"))
    }

    var map: WorldMap {
        player.starts(in: hall)
        rug.starts(in: hall)
        hall.north(kitchen)
        hall.down(cellar, via: trapDoor)
        hall.east(garden, when: { gateOpen }, otherwise: "The gate is latched.")
        hall.west(blocked: "The west wall is solid stone.")
        kitchen.south(hall)
        kitchen.up(loft).secret
        kitchen.exit(.east, toward: { mazeA })
        cellar.up(hall, via: trapDoor)
        garden.west(hall)
        loft.down(kitchen)
        mazeA.north(mazeB)
        mazeB.south(mazeA)
        mazeB.west(kitchen)
    }

    var rules: Rules {
        rug.before(.push) {
            trapDoor.reveal()
            try reply("You push the rug aside. There is a trap door under it.")
        }
        world.before(Intent("unlatch")) {
            gateOpen = true
            try reply("You lift the latch.")
        }
        world.before(Intent("pray")) {
            arrive(at: garden)
            try handled()
        }
    }
}

struct RedirectedMovementGame: Game {
    let title = "Redirected Movement"
    let intro = "A movement experiment."
    let hall = Location {
        name("Hall")
        description("A hall.")
    }
    let garden = Location {
        name("Garden")
        description("A garden.")
    }
    var map: WorldMap {
        player.starts(in: hall)
        hall.north(garden)
    }
    var rules: Rules {
        hall.before(.go) {
            arrive(at: garden)
            try handled()
        }
    }
}

/// Adversarial movement through the real default actions and author hooks.
struct CausalMovementGame: Game {
    let title = "Causal Movement"
    let intro = "A movement experiment."
    let hall = Location {
        name("Hall")
        description("A hall.")
    }
    let kitchen = Location {
        name("Kitchen")
        description("A kitchen.")
    }
    let garden = Location {
        name("Garden")
        description("A garden.")
    }
    let door = Item {
        name("oak door")
        openable
        startsOpen
    }
    let brassKey = Item { name("brass key") }
    let ironKey = Item { name("iron key") }
    @Global var destinationReads = 0
    @Global var arrivalMode = "plain"

    var map: WorldMap {
        player.starts(in: hall)
        brassKey.starts(in: hall)
        ironKey.starts(in: hall)
        hall.north(kitchen, when: { false }, otherwise: "The north gate is barred.")
        hall.east(kitchen, via: door)
        hall.south(hall)
        hall.out(garden)
        hall.west {
            destinationReads += 1
            return destinationReads == 1 ? kitchen : garden
        }
        kitchen.north(garden)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("readings", intent: Intent("readings"))
        SyntaxRule("teleport", intent: Intent("teleport"))
        SyntaxRule("roundtrip", intent: Intent("roundtrip"))
        SyntaxRule("chainwalk", intent: Intent("chainwalk"))
        SyntaxRule("authorwalk", intent: Intent("authorwalk"))
        SyntaxRule("unanswered", intent: Intent("unanswered"))
        SyntaxRule("perish", intent: Intent("perish"))
    }

    var rules: Rules {
        world.before(Intent("readings")) { try reply("Destination reads: \(destinationReads).") }
        world.before(Intent("teleport")) {
            arrivalMode = "teleport"
            try handled()
        }
        world.before(Intent("roundtrip")) {
            arrivalMode = "roundtrip"
            try handled()
        }
        world.before(Intent("chainwalk")) {
            arrivalMode = "chainwalk"
            try handled()
        }
        world.before(Intent("authorwalk")) {
            try enter(kitchen)
            try handled()
        }
        world.before(Intent("unanswered")) { arrive(at: garden) }
        world.before(Intent("perish")) {
            arrive(at: garden)
            try die("The garden claims you.")
        }
        kitchen.onEnter {
            switch arrivalMode {
            case "teleport": arrive(at: garden)
            case "roundtrip": arrive(at: hall)
            case "chainwalk": try enter(garden)
            default: break
            }
        }
    }
}

/// Output hooks may move the player; wrapper reports still have their contract.
struct ReportOutputHookGame: Game {
    let title = "Report Output Hooks"
    let intro = "A movement experiment."
    let hall = Location { name("Hall") }
    let kitchen = Location {
        name("Kitchen")
        description("A kitchen.")
    }
    let garden = Location {
        name("Garden")
        description("A garden.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        kitchen.north(garden)
    }

    var rules: Rules {
        hall.describe {
            player.location = kitchen
            return "The opening carried you into the kitchen."
        }
    }

    var text: GameText {
        var text = GameText()
        text.scoreLine = .naming { _ in
            player.location = garden
            return "The closing carried you into the garden."
        }
        return text
    }
}

import Gnusto

/// The room the September parser audit's missing rows are tried in: a
/// staircase to climb, a doorway to walk out of, somebody to give things to and
/// look for, a surface to stand on, and a cloak to put on.
///
/// Declares no verbs and no actions, for the reason ``CoreLab`` doesn't — every
/// line these tests read is one the engine ships.
struct AuditLab: Game {
    let title = "Audit Lab"
    let intro = "A room for the words the parser did not know."

    let hall = Location {
        name("Hall")
        description("A stone hall. Stairs climb to a gallery, and a doorway opens west.")
    }

    let gallery = Location {
        name("Gallery")
        description("A narrow walk above the hall.")
    }

    let yard = Location {
        name("Yard")
        description("Open air, and a good deal of it.")
    }

    let cloak = Item {
        name("velvet cloak")
        adjectives("velvet")
        description("Heavier than it looks.")
        wearable
    }

    let rug = Item {
        name("woven rug")
        adjectives("woven")
        scenery
    }

    let bench = Item {
        name("long bench")
        adjectives("long")
        scenery
        surface
    }

    let sack = Item {
        name("canvas sack")
        adjectives("canvas")
        container
    }

    let coin = Item {
        name("gold coin")
        adjectives("gold")
    }

    let warden = Actor {
        name("night warden")
        adjectives("night")
        description("A warden, keeping the hours nobody else wants.")
    }

    var map: WorldMap {
        hall.up(gallery)
        gallery.down(hall)
        hall.out(yard)
        yard.east(hall)
        player.starts(in: hall)
        warden.starts(in: hall)
        rug.starts(in: hall)
        bench.starts(in: hall)
        sack.starts(in: hall)
        coin.startsHeld
        cloak.startsHeld
    }
}

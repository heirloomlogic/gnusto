import Gnusto

/// Fixture for a worn item that a rule moves somewhere else. The player starts
/// wearing a straw hat, and every custom verb but `check` moves it through one
/// of the author-facing movers: onto the floor, into a box, onto a shelf, into
/// a thief's hands, back into the player's own hands, or scattered with
/// `scatterInventory`. `check` reports whether the hat is worn.
struct WardrobeGame: Game {
    let title = "Wardrobe"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let hat = Item {
        name("straw hat")
        adjectives("straw")
        wearable
        description(when: \.isWorn, "The hat sits on your head.", otherwise: "A plain straw hat.")
    }

    let box = Item {
        name("hat box")
        container
    }

    let shelf = Item {
        name("oak shelf")
        adjectives("oak")
        surface
    }

    let thief = Actor {
        name("thief")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hat.startsWorn
        box.starts(in: hall)
        shelf.starts(in: hall)
        thief.starts(in: hall)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("scatter", intent: Intent("scatter"))
        SyntaxRule("fling", intent: Intent("fling"))
        SyntaxRule("stow", intent: Intent("stow"))
        SyntaxRule("perch", intent: Intent("perch"))
        SyntaxRule("steal", intent: Intent("steal"))
        SyntaxRule("regrip", intent: Intent("regrip"))
        SyntaxRule("check", intent: Intent("check"))
    }

    var rules: Rules {
        world.before(Intent("scatter")) {
            player.scatterInventory(across: [hall])
            try reply("Everything you carry falls to the floor.")
        }
        world.before(Intent("fling")) {
            hat.move(to: hall)
            try reply("The hat lands on the floor.")
        }
        world.before(Intent("stow")) {
            hat.move(inside: box)
            try reply("The hat drops into the box.")
        }
        world.before(Intent("perch")) {
            hat.move(onto: shelf)
            try reply("The hat lands on the shelf.")
        }
        world.before(Intent("steal")) {
            hat.move(heldBy: thief)
            try reply("The thief lifts the hat off your head.")
        }
        // Moves the hat to where it already is: the player's hands.
        world.before(Intent("regrip")) {
            hat.move(heldBy: player.item)
            try reply("You adjust your grip.")
        }
        world.before(Intent("check")) {
            try reply("worn=\(hat.isWorn)")
        }
    }
}

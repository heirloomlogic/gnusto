import Gnusto

/// Fixture for the entity-collection helpers (`Player.inventory`,
/// `Item.contents`) and `Item.moveToPlayer()`. A pantry holds a chest
/// (container) and a shelf (surface) each with contents, plus a conjuring
/// verb that drops a summoned coin straight into the player's hands.
struct LarderGame: Game {
    let title = "Pantry"
    let intro = "Shelves, a chest, and a whiff of magic."

    let pantry = Location {
        name("Pantry")
        description("Well-stocked, dimly lit.")
    }

    let chest = Item {
        name("cedar chest")
        adjectives("cedar")
        container
        openable
    }

    let shelf = Item {
        name("pine shelf")
        adjectives("pine")
        surface
    }

    let jam = Item { name("jar of jam") }
    let flour = Item { name("bag of flour") }
    let candle = Item { name("wax candle") }

    let coin = Item { name("gold coin") }

    var map: WorldMap {
        player.starts(in: pantry)
        chest.starts(in: pantry)
        shelf.starts(in: pantry)
        jam.starts(inside: chest)
        flour.starts(inside: chest)
        candle.starts(on: shelf)
        // The coin is offstage until conjured.
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("tally", intent: Intent("tally"))
        SyntaxRule("peek", intent: Intent("peek"))
        SyntaxRule("conjure", intent: Intent("conjure"))
    }

    var rules: Rules {
        // Reports the player's inventory, sorted by ID, through the helper.
        world.before(Intent("tally")) {
            let names = player.inventory.map(\.name)
            try reply("Carrying: \(names.joined(separator: ", ")).")
        }
        // Reports the chest's and shelf's contents through the helper.
        world.before(Intent("peek")) {
            let inChest = chest.contents.map(\.name).joined(separator: ", ")
            let onShelf = shelf.contents.map(\.name).joined(separator: ", ")
            try reply("Chest: \(inChest). Shelf: \(onShelf).")
        }
        // Puts the coin straight into the player's hands.
        world.before(Intent("conjure")) {
            coin.moveToPlayer()
            try reply("A coin appears in your hand.")
        }
    }
}

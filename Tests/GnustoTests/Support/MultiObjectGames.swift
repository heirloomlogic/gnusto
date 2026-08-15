import Gnusto

/// Exercises multi-object commands: "take all", "drop all", "put all in …",
/// the group pronoun "them", and conjunction lists ("take the coin and the
/// feather"). The vault holds a mix of takables, a scenery statue that "all"
/// must skip, an idol whose `before` rule refuses, a held sack for container
/// targets, and a `cup and saucer` whose own name contains the conjunction;
/// the closet is bare.
struct VaultGame: Game {
    let title = "Vault"
    let intro = "A vault and an empty closet."

    let vault = Location {
        name("Vault")
        description("A steel vault. A bare closet lies north.")
    }

    let closet = Location {
        name("Closet")
        description("Nothing but dust in here.")
    }

    let coin = Item {
        name("brass coin")
        adjectives("brass")
    }

    let feather = Item {
        name("gray feather")
        adjectives("gray")
    }

    let idol = Item {
        name("cursed idol")
        adjectives("cursed")
    }

    let statue = Item {
        name("marble statue")
        adjectives("marble")
        scenery
    }

    let sack = Item {
        name("leather sack")
        adjectives("leather")
        container
    }

    let cloak = Item {
        name("velvet cloak")
        adjectives("velvet")
        wearable
    }

    /// One object whose own phrase contains the conjunction: `take cup and
    /// saucer` must be this item, never a list of two.
    let saucer = Item {
        name("cup and saucer")
    }

    var map: WorldMap {
        player.starts(in: vault)
        coin.starts(in: vault)
        feather.starts(in: vault)
        idol.starts(in: vault)
        statue.starts(in: vault)
        saucer.starts(in: vault)
        sack.startsHeld
        cloak.startsWorn
        vault.north(closet)
        closet.south(vault)
    }

    var rules: Rules {
        idol.before(.take) {
            try refuse("The idol refuses to budge.")
        }
        world.afterEachTurn {
            say("Tick.")
        }
    }
}

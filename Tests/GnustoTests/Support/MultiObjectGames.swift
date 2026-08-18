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

/// Every nesting `all` has to tell apart, in one room (#267). Three things are
/// nameable and must **not** be offered by `take all` — what you already carry
/// one level down, what sits behind glass, and what somebody else is holding —
/// against two positive controls that must be, one loose on the floor and one
/// inside an open crate the player is not carrying.
struct NestedAllGame: Game {
    let title = "Depot"
    let intro = "A depot, and rather too many things inside other things."

    let depot = Location {
        name("Depot")
        description("A depot with a counter along one wall.")
    }

    /// Carried and open, so its contents are in the *visible* set by way of
    /// the player's own hands.
    let canteen = Item {
        name("tin canteen")
        adjectives("tin")
        container
        openable
        startsOpen
    }

    /// Inside the carried canteen: already the player's, one level down.
    let water = Item {
        name("quantity of water")
        adjectives("quantity")
    }

    /// Shut and transparent: the medal is in plain view and out of reach.
    let showcase = Item {
        name("glass showcase")
        adjectives("glass")
        container
        openable
        transparent
    }

    let medal = Item {
        name("bronze medal")
        adjectives("bronze")
    }

    /// Holding the ledger — visible, nameable, and never the player's to take.
    let clerk = Actor {
        name("bored clerk")
        adjectives("bored")
        description("Bored, and making sure you know it.")
    }

    let ledger = Item {
        name("leather ledger")
        adjectives("leather")
        description("Columns of numbers, none of them yours.")
    }

    /// The positive controls: loose on the floor, and one level down inside an
    /// open container the player is *not* carrying.
    let key = Item {
        name("brass key")
        adjectives("brass")
    }

    let crate = Item {
        name("wooden crate")
        adjectives("wooden")
        container
    }

    let wafer = Item {
        name("dry wafer")
        adjectives("dry")
    }

    var map: WorldMap {
        player.starts(in: depot)
        canteen.startsHeld
        water.starts(inside: canteen)
        showcase.starts(in: depot)
        medal.starts(inside: showcase)
        clerk.starts(in: depot)
        ledger.starts(heldBy: clerk)
        key.starts(in: depot)
        crate.starts(in: depot)
        wafer.starts(inside: crate)
    }
}

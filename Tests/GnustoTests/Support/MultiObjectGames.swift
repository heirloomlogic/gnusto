import Gnusto

/// Exercises multi-object commands: "take all", "drop all", "put all in …",
/// the group pronoun "them", and conjunction lists ("take the coin and the
/// feather"), and exclusions ("take all but the coin"). The vault holds a mix
/// of takables, a scenery statue that "all" must skip, an idol whose `before`
/// rule refuses, a held sack for container targets, and two things whose own
/// names contain a word the parser also reads as punctuation — a `cup and
/// saucer` and a `last but one ticket`; the closet is bare.
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

    /// And one whose own phrase contains an exclusion word: `take last but one
    /// ticket` must be this item, never everything-except-a-ticket.
    let ticket = Item {
        name("last but one ticket")
    }

    var map: WorldMap {
        player.starts(in: vault)
        coin.starts(in: vault)
        feather.starts(in: vault)
        idol.starts(in: vault)
        statue.starts(in: vault)
        saucer.starts(in: vault)
        ticket.starts(in: vault)
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

    /// The counter the room description names: a surface, so a thing resting on
    /// it is lying about in plain sight rather than packed away, and `all`
    /// sweeps it along with the floor.
    let counter = Item.scenery("counter") { surface }

    let receipt = Item {
        name("paper receipt")
        adjectives("paper")
    }

    /// Scenery, and a container: nothing in it can ever be swept, which is not
    /// the same as nothing being in it.
    let cabinet = Item {
        name("oak cabinet")
        adjectives("oak")
        container
        scenery
    }

    let mop = Item {
        name("straw mop")
        adjectives("straw")
        scenery
    }

    var map: WorldMap {
        player.starts(in: depot)
        cabinet.starts(in: depot)
        mop.starts(inside: cabinet)
        canteen.startsHeld
        water.starts(inside: canteen)
        showcase.starts(in: depot)
        medal.starts(inside: showcase)
        clerk.starts(in: depot)
        ledger.starts(heldBy: clerk)
        key.starts(in: depot)
        crate.starts(in: depot)
        wafer.starts(inside: crate)
        counter.starts(in: depot)
        receipt.starts(on: counter)
    }
}

/// The boarded case (#540): a punt you climb into, which is a container, so
/// `drop` puts what you let go of into the hull rather than on the water
/// sliding past. A hamper already aboard, with a loaf packed inside it, is the
/// control for "the hull is a floor, not an unpacking" — and the mooring post
/// on the quay is the control for the room floor still being in reach from the
/// thwart.
struct MooringGame: Game {
    let title = "Mooring"
    let intro = "A quay, a punt, and a slack rope."

    let quay = Location {
        name("Quay")
        description("Bollards, weed, and water slapping the stones.")
    }

    /// The vehicle: enterable *and* a container, which is the pair `drop`
    /// reads.
    let punt = Item {
        name("flat punt")
        adjectives("flat")
        description("Tarred boards and one pole.")
        enterable
        container
    }

    let pole = Item {
        name("ash pole")
        adjectives("ash")
    }

    let biscuit = Item {
        name("ship biscuit")
        adjectives("ship")
    }

    /// Packed, and aboard: sweeping the hull must take the hamper and leave
    /// the loaf in it.
    let hamper = Item {
        name("wicker hamper")
        adjectives("wicker")
        container
    }

    let loaf = Item {
        name("brown loaf")
        adjectives("brown")
    }

    /// On the quay rather than in the punt: reach is room-granular, so this
    /// stays on offer from aboard.
    let lantern = Item {
        name("dock lantern")
        adjectives("dock")
    }

    var map: WorldMap {
        player.starts(in: quay)
        punt.starts(in: quay)
        pole.startsHeld
        biscuit.startsHeld
        hamper.starts(inside: punt)
        loaf.starts(inside: hamper)
        lantern.starts(in: quay)
    }
}

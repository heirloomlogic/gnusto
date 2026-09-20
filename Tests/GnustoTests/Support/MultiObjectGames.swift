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
/// against three positive controls that must be: one loose on the floor, one
/// inside an open crate the player is not carrying, and one resting on the
/// counter. Every holder `take X from Y` can name is here too: a container, a
/// surface, a shut container, a person, and the player's own hands.
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

    /// The surface the room description has always mentioned, and what sits
    /// on it: `take X from Y` has to answer for a thing resting on something
    /// as well as for a thing inside it.
    let counter = Item {
        name("long counter")
        adjectives("long")
        scenery
        surface
    }

    let mug = Item {
        name("chipped mug")
        adjectives("chipped")
    }

    /// Open, full, and in the clerk's hands: visible, and reachable by
    /// nobody. A holder the player can see has something in it, so "there is
    /// nothing there to take" would be a visible lie.
    let pouch = Item {
        name("canvas pouch")
        adjectives("canvas")
        container
    }

    let coin = Item {
        name("copper coin")
        adjectives("copper")
    }

    /// Openable and shut without being a container — the window case. Nothing
    /// is ever inside it, so being shut is not why it has nothing to give.
    let shutter = Item {
        name("iron shutter")
        adjectives("iron")
        scenery
        openable
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
        cabinet.starts(in: depot)
        mop.starts(inside: cabinet)
        receipt.starts(on: counter)
        counter.starts(in: depot)
        mug.starts(on: counter)
        pouch.starts(heldBy: clerk)
        coin.starts(inside: pouch)
        shutter.starts(in: depot)
    }
}

/// A game that writes one of `take all from Y`'s refusals as a live line. The
/// crate is empty, so the line prints, and it reads the world to do it — which
/// is only possible from inside a turn frame (#507).
struct LiveHolderLineGame: Game {
    let title = "Signal Box"
    let intro = "A signal box, and an empty crate in it."

    let signalBox = Location {
        name("Signal Box")
        description("A signal box with an empty crate and a shuttered window.")
    }

    let crate = Item {
        name("wooden crate")
        adjectives("wooden")
        container
    }

    /// Openable, shut, and no sort of container: the rung that separates
    /// "there is nothing there" from "it is closed".
    let hatch = Item {
        name("coal hatch")
        adjectives("coal")
        scenery
        openable
    }

    var text: GameText {
        var text = GameText()
        text.emptyContainer = .naming { _ in
            self.crate.isTouched ? "Empty, the same as last time." : "Empty."
        }
        text.nothingToTakeThere = .live {
            self.crate.isTouched ? "Empty, the same as last time." : "Empty."
        }
        return text
    }

    var map: WorldMap {
        player.starts(in: signalBox)
        crate.starts(in: signalBox)
        hatch.starts(in: signalBox)
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

/// Upkeep can invalidate a group that was nonempty before the turn started.
struct ChangingHolderGame: Game {
    let title = "Changing Holder"
    let intro = ""
    var darkens = false

    init() {}
    init(darkens: Bool) { self.darkens = darkens }
    let room = Location {
        name("Store")
        description("A store room.")
        dark
    }
    let lamp = Item {
        name("lamp")
        lightSource
        startsLit
    }
    let crate = Item {
        name("crate")
        container
        openable
        startsOpen
    }
    let coin = Item { name("copper coin") }
    let key = Item { name("brass key") }
    let token = Item { name("wooden token") }
    @Global var changed = false

    var map: WorldMap {
        player.starts(in: room)
        lamp.startsHeld
        crate.starts(in: room)
        coin.starts(inside: crate)
        key.starts(in: room)
        token.starts(in: room)
    }

    var rules: Rules {
        world.beforeEachTurn {
            guard command.intent == .take, command.indirectObject == crate,
                !changed
            else { return }
            changed = true
            if darkens { lamp.isLit = false } else { crate.isOpen = false }
        }
    }
}

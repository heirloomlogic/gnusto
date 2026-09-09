import Gnusto

/// A shop with three lanterns sharing a noun — one round of adjectives
/// ("brass") still leaves two, so narrowing can take a second question —
/// plus a held cloak and a hook for completing "hang cloak".
struct LanternShopGame: Game {
    let title = "Lantern Shop"
    let intro = "Lanterns as far as the eye can see."

    let shop = Location {
        name("Shop")
        description("Shelves of lanterns.")
    }

    let brassLantern = Item {
        name("brass lantern")
        adjectives("brass")
    }

    let rustyLantern = Item {
        name("rusty lantern")
        adjectives("rusty")
    }

    let smallLantern = Item {
        name("small brass lantern")
        adjectives("small", "brass")
    }

    let cloak = Item {
        name("velvet cloak")
        adjectives("velvet")
        wearable
    }

    let hook = Item {
        name("iron hook")
        adjectives("iron")
        surface
        scenery
    }

    var map: WorldMap {
        player.starts(in: shop)
        brassLantern.starts(in: shop)
        rustyLantern.starts(in: shop)
        smallLantern.starts(in: shop)
        cloak.startsHeld
        hook.starts(in: shop)
    }
}

/// Two doors sharing the noun "door" and one giveable item — the
/// recipient-first GIVE row (#445 round 2): `give door lamp` cannot tell
/// which door is meant, and the answer to "Which do you mean" must splice
/// back into the sentence exactly as it does for every other slot.
struct DoorGiftGame: Game {
    let title = "Door Gift"
    let intro = "Two doors, one lamp."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    let trapDoor = Item.scenery("trap door", adjectives: "trap")
    let woodenDoor = Item.scenery("wooden door", adjectives: "wooden")

    let lamp = Item {
        name("lamp")
    }

    var map: WorldMap {
        player.starts(in: room)
        trapDoor.starts(in: room)
        woodenDoor.starts(in: room)
        lamp.startsHeld
    }
}

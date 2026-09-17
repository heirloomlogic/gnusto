import Gnusto

/// A world with a carrying cap and the player standing exactly on it, so every
/// `take` refusal can be asked for while the weight check is live.
///
/// The starting load is the cap: brick 15 + cloak 5 + sack 5 + crumb 5 = 30.
/// So a new thing off the floor is over the cap, and everything already in the
/// player's hands — at any depth — is not.
struct BurdenGame: Game {
    let title = "Burden"
    let intro = ""

    let load = Burden(carryCap: 30)

    var content: GameContents { load }

    let den = Location {
        name("Den")
        description("A cramped den.")
    }

    let brick = Item {
        name("clay brick")
        trait(.weight, 15)
    }
    let cloak = Item {
        name("velvet cloak")
        wearable
    }
    let sack = Item {
        name("burlap sack")
        container
        startsOpen
    }
    let crumb = Item {
        name("stale crumb")
    }
    let pebble = Item {
        name("grey pebble")
    }
    let charm = Item {
        name("tin charm")
    }
    let statue = Item {
        name("marble statue")
        scenery
    }
    let cart = Item {
        name("wooden cart")
        enterable
    }
    let showcase = Item {
        name("glass case")
        container
        openable
        transparent
    }
    let medal = Item {
        name("bronze medal")
    }
    let watchman = Actor {
        name("old watchman")
    }

    /// The game's own reason to refuse one particular thing. The cap is the
    /// broader answer, so it must not be the one printed.
    var rules: Rules {
        charm.before(.take) {
            try refuse("The watchman glares until you put it back.")
        }
    }

    var map: WorldMap {
        player.starts(in: den)
        brick.startsHeld
        cloak.startsWorn
        sack.startsHeld
        crumb.starts(inside: sack)
        pebble.starts(in: den)
        charm.starts(in: den)
        statue.starts(in: den)
        cart.starts(in: den)
        showcase.starts(in: den)
        medal.starts(inside: showcase)
        watchman.starts(in: den)
    }
}

/// The same cap with an empty-handed player, for the takes that must still
/// succeed and for `take all`.
struct LightBurdenGame: Game {
    let title = "Light Burden"
    let intro = ""

    let load = Burden(carryCap: 30)

    var content: GameContents { load }

    let den = Location {
        name("Den")
        description("A cramped den.")
    }

    let anvil = Item {
        name("iron anvil")
        trait(.weight, 40)
    }
    let pebble = Item {
        name("grey pebble")
    }
    let feather = Item {
        name("white feather")
    }

    var map: WorldMap {
        player.starts(in: den)
        anvil.starts(in: den)
        pebble.starts(in: den)
        feather.starts(in: den)
    }
}

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
    let mat = Item {
        name("welcome mat")
        trait(.weight, 10)
    }
    let key = Item {
        name("rusty key")
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

    /// True until the mat is lifted off the key. The one-shot the cap must
    /// not be able to spend — `Sources/Dungeon/Regions/Palantir.swift`'s
    /// `liftTheMat()` in miniature.
    @Global var keyUnderMat = true

    var rules: Rules {
        // The game's own reason to refuse one particular thing. The cap is
        // asked first, so at the cap this line is not the one printed.
        charm.before(.take) {
            try refuse("The watchman glares until you put it back.")
        }

        // Dungeon's welcome mat: a `before(.take)` that changes the world and
        // does *not* throw, so the take goes on to complete. If the cap were
        // asked after this rule instead of before it, the key would be off the
        // mat with the mat still on the floor and the reveal spent.
        mat.before(.take) {
            guard keyUnderMat else { return }
            keyUnderMat = false
            key.move(to: den)
            say("As you lift the mat, a rusty key tumbles out from under it.")
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
        mat.starts(in: den)
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

/// A cap and a game that replaces `take` wholesale. The cap is a stage-1 world
/// rule, so it still holds for a verb the game has taken over.
struct BurdenOverrideGame: Game {
    let title = "Burden Override"
    let intro = ""

    let load = Burden(carryCap: 10)

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

    var actions: [IntentAction] {
        action(.take) {
            try reply("You pocket it with a guilty glance.")
        }
    }

    var map: WorldMap {
        player.starts(in: den)
        anvil.starts(in: den)
        pebble.starts(in: den)
    }
}

/// No ``Burden`` at all: the player's hands are unlimited and nothing weighs
/// anything against anything.
struct NoBurdenGame: Game {
    let title = "No Burden"
    let intro = ""

    let den = Location {
        name("Den")
        description("A cramped den.")
    }

    let anvil = Item {
        name("iron anvil")
        trait(.weight, 4000)
    }

    var map: WorldMap {
        player.starts(in: den)
        anvil.starts(in: den)
    }
}

import Gnusto

/// Hangs everything a game can hang on the synthesized player item: a
/// `describe { }` rule that varies with state, a `before` rule, and an
/// `after` rule that replaces the description outright at runtime.
struct SelfAwareGame: Game {
    let title = "Self-Aware"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let hat = Item {
        name("straw hat")
        wearable
    }

    let mud = Item {
        name("handful of mud")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hat.starts(in: hall)
        mud.starts(in: hall)
    }

    var rules: Rules {
        player.item.describe {
            player.isWearing(hat) ? "You are wearing a straw hat, and it suits you." : "Hatless."
        }
        player.item.before(.drop) {
            try refuse("You stay where you are.")
        }
        mud.after(.take) {
            player.item.description = "Mud to the elbows."
        }
    }
}

/// Re-skins the stock self lines, the way any game re-skins `GameText`.
struct SelfSkinGame: Game {
    let title = "Self-Skin"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    var text: GameText {
        var text = GameText()
        text.selfDescription = "A detective, and it shows."
        text.cantTakeSelf = "You are already had."
        return text
    }

    var map: WorldMap {
        player.starts(in: hall)
    }
}

import Gnusto

/// A room the map keeps as one place and the game divides in two: the near end
/// and the far end, with `stroll` walking between them. The whole point of the
/// shape is that containment cannot tell the ends apart — everything below is
/// "in the gallery" from both — so `reach { … }` is the only thing that can.
///
/// Issue #150. Away from the Royal Puzzle's grid on purpose: the feature is
/// about rooms with an inside, not about sliding blocks.
struct SplitRoomGame: Game {
    let title = "The Long Gallery"
    let intro = "One room, two ends."

    @Global var atFarEnd = false

    let gallery = Location {
        name("Long Gallery")
        description("A gallery long enough that its two ends are different places.")
    }

    /// Far end, with a refusal of its own.
    let chalk = Item {
        name("chalk")
    }

    /// Far end, with no `otherwise:` — so the stock `cantReach` answers for it.
    let hasp = Item {
        name("hasp")
        openable
    }

    /// Far end, and the target of `put X in Y`: the slot the two-object verbs
    /// have to check.
    let alcove = Item {
        name("alcove")
        container
        scenery
    }

    /// Far end, and a person: the `Actor` spelling of the same rule.
    let porter = Actor {
        name("porter")
        firstSight("A porter stands at the far end, doing nothing in particular.")
    }

    /// Held, and declaring a reach rule that is false at the near end — the
    /// thing in your hand that must stay usable anyway.
    let taper = Item {
        name("taper")
        lightSource
    }

    /// Held, and open: the bag the pouch is in. Issue #605.
    let satchel = Item {
        name("satchel")
        container
    }

    /// Inside the satchel, so that what it holds is two levels below the hand:
    /// the chalk can be carried back in it.
    let pouch = Item {
        name("pouch")
        container
    }

    /// The porter's, and holding the apple.
    let basket = Item {
        name("basket")
        container
    }

    /// In the porter's basket, with a rule that is false at the near end:
    /// what the porter carries is his to reach, as the player's is theirs.
    let apple = Item {
        name("apple")
    }

    /// Held, and the thing that goes into the alcove.
    let coin = Item {
        name("coin")
    }

    /// No reach rule at all: the control, takable from either end.
    let stool = Item {
        name("stool")
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("stroll", intent: Intent("stroll"))
        SyntaxRule("probe", intent: Intent("probe"))
    }

    var map: WorldMap {
        player.starts(in: gallery)
        taper.startsHeld
        coin.startsHeld
        satchel.startsHeld
        pouch.starts(inside: satchel)
        basket.starts(heldBy: porter)
        apple.starts(inside: basket)
        chalk.starts(in: gallery)
        hasp.starts(in: gallery)
        alcove.starts(in: gallery)
        porter.starts(in: gallery)
        stool.starts(in: gallery)
    }

    var rules: Rules {
        world.before(Intent("stroll")) {
            atFarEnd.toggle()
            try reply(atFarEnd ? "You walk to the far end." : "You walk back to the near end.")
        }

        world.before(Intent("probe")) {
            try reply(
                """
                chalk: \(chalk.isReachable ? "reachable" : "out of reach")
                stool: \(stool.isReachable ? "reachable" : "out of reach")
                taper: \(taper.isReachable ? "reachable" : "out of reach")
                porter reaches chalk: \(chalk.isReachable(from: porter) ? "yes" : "no")
                porter reaches stool: \(stool.isReachable(from: porter) ? "yes" : "no")
                porter reaches apple: \(apple.isReachable(from: porter) ? "yes" : "no")
                """)
        }

        chalk.reach(otherwise: "The chalk is the length of the gallery away.") { atFarEnd }
        apple.reach(otherwise: "The apple is at the far end.") { atFarEnd }
        alcove.reach(otherwise: "The alcove is cut into the far wall.") { atFarEnd }
        porter.reach(otherwise: "The porter is too far off to touch.") { atFarEnd }
        taper.reach(otherwise: "The taper is at the far end.") { atFarEnd }
        // No `otherwise:`: the stock line answers.
        hasp.reach { atFarEnd }

        // The proof that stage 0 is early enough. An item that answers its own
        // verb pre-empts the default action, so a reach gate living in stage 4
        // would never fire for this one.
        hasp.before(.open) {
            try reply("The hasp lifts, sticky with varnish.")
        }
    }
}

/// Two `reach { … }` rules on one item: a fatal bootstrap diagnostic, like a
/// second `describe` or `presence`.
struct TwiceReachedGame: Game {
    let title = "Twice Reached"
    let intro = ""

    let hall = Location { name("Hall") }
    let plinth = Item { name("plinth") }

    var map: WorldMap {
        player.starts(in: hall)
        plinth.starts(in: hall)
    }

    var rules: Rules {
        plinth.reach { true }
        plinth.reach { false }
    }
}

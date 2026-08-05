import Gnusto

/// The Machine Room in miniature: a robot you can send where you cannot go,
/// and a button only it can reach.
///
/// The Dingy Closet is **dark** and one room north. Once the robot has walked
/// into it, the button is in nobody's sight but the robot's — which is the
/// whole point of ordering somebody about, and what an order parsed against
/// the player's scope could never express.
struct MachineRoom: Game {
    let title = "Machine Room"
    let intro = "A low room, and a robot in it."

    let lowRoom = Location {
        name("Low Room")
        description("A low room with a doorway north.")
    }

    let closet = Location {
        name("Dingy Closet")
        description("A dingy closet.")
        dark
    }

    let robot = Actor {
        name("robot")
        description("A dented robot, willing enough.")
        takesOrders
    }

    /// The control group: a person in the same room who never opted in, so
    /// the stock refusal still has somebody to refuse for.
    let clerk = Actor {
        name("clerk")
        description("A clerk with a clipboard.")
    }

    let wrench = Item {
        name("wrench")
        description("A heavy wrench.")
    }

    let button = Item {
        name("triangular button")
        description("A triangular button.")
        scenery
    }

    /// In the Low Room, where player and robot both stand: the one object
    /// whose rule can be asked "which of you pushed me?"
    let lever = Item {
        name("brass lever")
        description("A brass lever.")
        scenery
    }

    var rules: Rules {
        // The robot walks on your word. Movement for somebody who isn't the
        // player is a game's own business: the engine's `go` moves the player.
        robot.before(.go) {
            guard let direction = command.direction else {
                try refuse("The robot waits for a direction.")
            }
            guard direction == .north, robot.isIn(lowRoom) else {
                try refuse("The robot's treads grind, and it stays where it is.")
            }
            robot.move(to: closet)
            try reply("The robot clanks north through the doorway.")
        }

        button.before(.push) {
            try reply("Whirr, click. Something heavy lifts in the darkness.")
        }

        // The same object, the two agents, one rule: `command.actor` is the
        // whole difference between them.
        lever.before(.push) {
            if command.actor == robot {
                try reply("The robot hauls the lever down with a servo whine.")
            }
            try reply("The lever does not budge for you.")
        }

        // A rule keyed on the addressee rather than the object, to prove the
        // agent's own rules are consulted.
        robot.before(.wait) {
            try reply("The robot idles, ticking.")
        }
    }

    var map: WorldMap {
        lowRoom.north(closet)
        player.starts(in: lowRoom)
        robot.starts(in: lowRoom)
        clerk.starts(in: lowRoom)
        wrench.starts(heldBy: robot)
        lever.starts(in: lowRoom)
        button.starts(in: closet)
    }
}

/// `takesOrders` on something that isn't a person: a bootstrap warning, not a
/// fatal error — the flag has nobody to describe.
struct OrderTakingKettle: Game {
    let title = "Kettle"
    let intro = "A kitchen."

    let kitchen = Location {
        name("Kitchen")
        description("A kitchen.")
    }

    let kettle = Item {
        name("kettle")
        description("A copper kettle.")
        takesOrders
    }

    var map: WorldMap {
        player.starts(in: kitchen)
        kettle.starts(in: kitchen)
    }
}

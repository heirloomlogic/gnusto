import Gnusto

/// Vehicle fixture: a dock with a red boat (enterable container — the real
/// vehicle), a pine crate (enterable, for the one-at-a-time refusal), a tin
/// bucket (carriable enterable), and a pebble for cargo. The boathouse and
/// the dark cave give the rides somewhere to go.
struct HarborGame: Game {
    let title = "Harbor"
    let intro = "Gulls, rope, and one questionable boat."

    let dock = Location {
        name("Dock")
        description("Weathered planks over gray water.")
    }

    let boathouse = Location {
        name("Boathouse")
        description("Paint cans and cobwebs.")
    }

    let cave = Location {
        name("Sea Cave")
        description("The tide has hollowed this out.")
        dark
    }

    let boat = Item {
        name("red boat")
        adjectives("red")
        description("Flaking red paint; sound enough hull.")
        enterable
        container
    }

    let crate = Item {
        name("pine crate")
        adjectives("pine")
        enterable
    }

    let bucket = Item {
        name("tin bucket")
        adjectives("tin")
        enterable
    }

    let pebble = Item {
        name("smooth pebble")
        adjectives("smooth")
    }

    let lantern = Item {
        name("small lantern")
        adjectives("small")
        lightSource
    }

    @Global var chained = false

    var map: WorldMap {
        dock.north(boathouse)
        boathouse.south(dock)
        boathouse.east(cave)
        cave.west(boathouse)

        player.starts(in: dock)
        boat.starts(in: dock)
        crate.starts(in: dock)
        bucket.starts(in: dock)
        pebble.starts(in: dock)
        lantern.starts(in: dock)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("chain", intent: Intent("chain"))
        SyntaxRule("row", .direction, intent: Intent("row"))
        SyntaxRule("scuttle", intent: Intent("scuttle"))
    }

    var rules: Rules {
        boat.before(.board) {
            if chained {
                try refuse("The boat is chained to the dock.")
            }
        }
        // The terrain-gating pattern: some directions just don't take
        // boats. Gating a direction with no exit also proves the rule
        // outranks exit resolution.
        world.before(.go) {
            if player.vehicle == boat, command.direction == .south {
                try refuse("The boat refuses to go overland.")
            }
        }
        world.before(Intent("scuttle")) {
            boat.vanish()
            try reply("The boat gives up on buoyancy.")
        }
        world.before(Intent("chain")) {
            chained = true
            try reply("You loop the chain through the bow ring.")
        }
        // A6: the "river current" pattern — a rule moves the vehicle and
        // the boarded player comes along.
        world.before(Intent("row")) {
            guard player.vehicle == boat else {
                try refuse("You'd want to be in the boat for that.")
            }
            boat.move(to: boathouse)
            say("The current does the actual work.")
            describeSurroundings()
            try reply("")
        }
    }
}

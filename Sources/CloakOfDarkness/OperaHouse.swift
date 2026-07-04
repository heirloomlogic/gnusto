import Gnusto

// The hook's description reads its own state, and a stored property's
// initializer can't reference `self` or a sibling — so the two entities that
// name each other live at file scope, and the game aliases them below.

private let velvetCloak = Item {
    name("velvet cloak")
    adjectives("handsome", "dark", "black", "velvet", "satin")
    synonyms("cape")
    description(
        """
        A handsome cloak, of velvet trimmed with satin, and slightly
        spattered with raindrops. Its blackness is so deep that it
        almost seems to suck light from the room.
        """)
    wearable
}

private let brassHook = Item {
    name("small brass hook")
    adjectives("small", "brass")
    synonyms("peg")
    firstSight("A small brass hook is on the wall.")
    description {
        brassHook.holds(velvetCloak)
            ? "It's just a small brass hook, with a cloak hanging on it."
            : "It's just a small brass hook, screwed to the wall."
    }
    scenery
    surface
}

/// "Cloak of Darkness" — the classic IF demonstration game by Roger Firth,
/// ported to Gnusto. This file is the engine's acceptance benchmark: every
/// API decision serves how this reads.
struct OperaHouse: Game {
    /// The game's title.
    let title = "Cloak of Darkness"
    /// The game's one-line tagline.
    let tagline = "A basic IF demonstration."
    /// The maximum achievable score.
    let maxScore = 2
    /// The opening text shown when play begins.
    let intro = """
        Hurrying through the rainswept November night, you're glad to see the
        bright lights of the Opera House. It's surprising that there aren't
        more people about but, hey, what do you expect in a cheap demo game...?
        """

    // MARK: - Rooms

    let foyer = Location {
        name("Foyer of the Opera House")
        description(
            """
            You are standing in a spacious hall, splendidly decorated in red
            and gold, with glittering chandeliers overhead. The entrance from
            the street is to the north, and there are doorways south and west.
            """)
    }

    let cloakroom = Location {
        name("Cloakroom")
        description(
            """
            The walls of this small room were clearly once lined with hooks,
            though now only one remains. The exit is a door to the east.
            """)
    }

    let bar = Location {
        name("Foyer Bar")
        description(
            """
            The bar, much rougher than you'd have guessed after the opulence
            of the foyer to the north, is completely empty.
            """)
        dark
    }

    // MARK: - Things

    let cloak = velvetCloak
    let hook = brassHook

    let message = Item {
        name("scrawled message")
        adjectives("scrawled")
        synonyms("sawdust", "floor")
        firstSight(
            """
            There seems to be some sort of message scrawled in the sawdust
            on the floor.
            """)
        description(
            """
            The message, neatly marked in the sawdust, reads...

                "You win."
            """)
        scenery
    }

    // MARK: - State

    @Global var disturbances = 0
    @Global var cloakIsHung = false

    // MARK: - Map

    /// Geography and initial entity placement.
    var map: WorldMap {
        foyer.north(
            blocked: """
                You've only just arrived, and besides, the weather outside
                seems to be getting worse.
                """)
        foyer.south(bar)
        foyer.west(cloakroom)
        cloakroom.east(foyer)
        bar.north(foyer)

        player.starts(in: foyer)
        cloak.startsWorn
        hook.starts(in: cloakroom)
        message.starts(in: bar)
    }

    // MARK: - Rules

    /// All game logic.
    var rules: Rules {
        cloak.before(.drop, .putOn) {
            try require(
                player.location == cloakroom,
                else: "This isn't the best place to leave a smart cloak lying around.")
        }

        cloak.after(.drop, .putOn) {
            bar.isLit = true
            if !cloakIsHung {
                cloakIsHung = true
                player.score += 1
            }
        }

        cloak.after(.take, .wear) {
            bar.isLit = false
        }

        bar.beforeEachTurn {
            guard !bar.isLit else { return }
            if command.intent == .look { return }
            if command.intent == .go {
                guard command.direction != .north else { return }
                disturbances += 2
                try refuse("Blundering around in the dark isn't a good idea!")
            }
            disturbances += 1
            try refuse("In the dark? You could easily disturb something!")
        }

        bar.afterEachTurn {
            if disturbances >= 2 {
                message.description = """
                    The message has been carelessly trampled, making it
                    difficult to read. You can just distinguish the words...

                        "You lose."
                    """
            }
        }

        message.before(.read, .examine) {
            if disturbances < 2 { player.score += 1 }
            say(message.description)
            try end(won: disturbances < 2)
        }
    }
}

import Gnusto

/// The top of the lighthouse, split out as its own ``GameContent`` bundle to
/// show how a region can own its declarations — rooms, items, and the rules
/// that only concern them — in a separate type. The stairs that join the Lamp
/// Room to the base below, and the puzzle of relighting the beacon (which needs
/// the oil the player finds downstairs), are cross-bundle seams, so the host
/// `Lighthouse` owns those — the ordinary division of labor between a bundle
/// and its host.
///
/// See ``Fixtures`` for the other reason to reach for a bundle: somewhere to put
/// declarations that would otherwise swamp the host file.
struct Tower: GameContent {
    /// The lantern room at the top of the tower. `dark` on its own — the great
    /// beacon has gone out — so the player has to climb up carrying a light.
    let lampRoom = Location {
        name("Lamp Room")
        description(
            """
            Glass on every side, and the night pressed up against all of it. The
            great beacon squats cold at the center on its iron carriage. Stairs
            spiral back down.
            """)
        dark
    }

    /// The beacon the whole game turns on. A ``lightSource`` that starts unlit;
    /// once relit it blazes and the game is won (the winning rule is the host's,
    /// since lighting it depends on the oil found downstairs). Its look-text is
    /// a live ``Item/describe(_:)`` keyed on ``Item/isLit``, and the winning rule
    /// sets that trait before it ends the game — so the lit branch is reachable,
    /// and a save taken at the final move restores a lighthouse that is lit.
    let beacon = Item {
        name("beacon")
        adjectives("great", "brass")
        synonyms("beam", "light", "reservoir", "carriage", "ring", "lens")
        scenery
        lightSource
    }

    // MARK: - The nouns the Lamp Room's description prints

    let glass = Item {
        name("glass")
        adjectives("curved", "salt", "great")
        synonyms("panes", "pane", "window", "windows", "glazing")
        description(
            """
            Curved panes in a brass frame, every one of them clean on the inside.
            The salt on the outside is nobody's fault and nobody's to fix.
            """)
        scenery
    }

    let night = Item {
        name("night")
        adjectives("black")
        synonyms("sky")
        description(
            """
            Black, and up against the glass on every side of you. Somewhere out
            in it is water, and somewhere on the water are people who would like
            to know where this rock is.
            """)
        scenery
    }

    let stairs = Item {
        name("spiral stairs")
        adjectives("spiral", "iron", "narrow")
        synonyms("stairs", "stair", "staircase", "steps", "step", "treads", "tread", "rail")
        description(
            """
            Iron, and narrow enough that two people meeting on them would have to
            settle it between themselves. Hollowed at the center, the same as the
            stone ones below.
            """)
        scenery
    }

    /// Where the tower's own things start. Cross-bundle geography — the stair
    /// down to the base — is wired by the host in ``Lighthouse``.
    var map: WorldMap {
        beacon.starts(in: lampRoom)
        glass.starts(in: lampRoom)
        night.starts(in: lampRoom)
        stairs.starts(in: lampRoom)
    }

    var rules: Rules {
        beacon.describe {
            beacon.isLit
                ? "The beacon roars with light, its beam wheeling out across the black water."
                : """
                The great beacon, cold and dark, its reservoir dry. The brass is
                bright where hands go and dull where they don't — polished by
                work, not for visitors.
                """
        }
    }
}

import Gnusto

/// The top of the lighthouse, split out as its own ``GameContent`` bundle to
/// show how a region can own its declarations — rooms, items, and the rules
/// that only concern them — in a separate type. The stairs that join the Lamp
/// Room to the base below, and the puzzle of relighting the beacon (which needs
/// the oil the player finds downstairs), are cross-bundle seams, so the host
/// `Lighthouse` owns those — the ordinary division of labor between a bundle
/// and its host.
struct Tower: GameContent {
    /// The lantern room at the top of the tower. `dark` on its own — the great
    /// beacon has gone out — so the player has to climb up carrying a light.
    let lampRoom = Location {
        name("Lamp Room")
        description(
            """
            Glass walls wrap the top of the tower, open to the night on every
            side. The great beacon squats at the center on its iron carriage.
            Stairs spiral back down.
            """)
        dark
    }

    /// The beacon the whole game turns on. A ``lightSource`` that starts unlit;
    /// once relit it blazes and the game is won (the winning rule is the host's,
    /// since lighting it depends on the oil found downstairs). Its look-text is
    /// a live ``Location/describe(_:)`` keyed on ``Item/isLit``, so it reads
    /// differently the instant it catches.
    let beacon = Item {
        name("beacon")
        adjectives("great", "brass")
        synonyms("beam", "light")
        scenery
        lightSource
    }

    /// Where the tower's own things start. Cross-bundle geography — the stair
    /// down to the base — is wired by the host in ``Lighthouse``.
    var map: WorldMap {
        beacon.starts(in: lampRoom)
    }

    var rules: Rules {
        beacon.describe {
            beacon.isLit
                ? "The beacon roars with light, its beam wheeling out across the black water."
                : "The great brass beacon is cold and dark, its oil reservoir bone dry."
        }
    }
}

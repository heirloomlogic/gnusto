import Gnusto

/// The fixture for the two map hints: a pair of maze rooms sharing one `mapRegion`, and a secret exit out of the hall.
struct MapHintGame: Game {
    let title = "Map Hints"
    let intro = "A hall, a hidden stair, and a little maze."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }
    let attic = Location {
        name("Attic")
        description("A dusty attic.")
    }
    let mazeA = Location {
        name("Twisty Passage")
        description("Passages twist away.")
        mapRegion("Maze")
    }
    let mazeB = Location {
        name("Twisty Passage")
        description("Passages twist away.")
        mapRegion("Maze")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.up(attic).secret
        hall.north(mazeA)
        attic.down(hall)
        mazeA.north(mazeB)
        mazeA.south(hall)
        mazeB.south(mazeA)
    }
}

/// `.secret` on a blocked exit, which can never be walked and so never drawn.
struct SecretBlockedExitGame: Game {
    let title = "Secret Wall"
    let intro = "A hall."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.west(blocked: "The west wall is solid stone.").secret
    }
}

/// `.secret` after a map entry that is not an exit.
struct SecretPlacementGame: Game {
    let title = "Secret Coin"
    let intro = "A hall."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }
    let coin = Item {
        name("coin")
    }

    var map: WorldMap {
        player.starts(in: hall)
        coin.starts(in: hall).secret
    }
}

/// Rooms declaring duplicate, whitespace-only, and empty regions.
struct BadRegionGame: Game {
    let title = "Bad Regions"
    let intro = "Three rooms."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
        mapRegion("Maze")
        mapRegion("Caves")
    }
    let cellar = Location {
        name("Cellar")
        description("A damp cellar.")
        mapRegion("  ")
    }
    let empty = Location {
        name("Empty Region")
        mapRegion("")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.down(cellar)
        cellar.up(hall)
        cellar.east(empty)
    }
}

/// Every passable exit family accepts a secret hint, while an ordinary exit stays ordinary.
struct SecretExitKindsGame: Game {
    let title = "Secret Exit Kinds"
    let intro = "A hall with several ways out."

    let hall = Location { name("Hall") }
    let attic = Location { name("Attic") }
    let hatch = Item {
        name("hatch")
        openable
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.north(attic, via: hatch).secret
        hall.south(attic, when: { true }, otherwise: "The way is shut.").secret
        hall.exit(.east, toward: { attic }).secret
        hall.west(attic)
        attic.down(hall)
    }
}

/// `.secret` is invalid on the player's start and a lock/key declaration too.
struct SecretStartAndLockGame: Game {
    let title = "Secret Start and Lock"
    let intro = "A hall, a box, and a key."

    let hall = Location { name("Hall") }
    let box = Item {
        name("box")
        openable
    }
    let key = Item { name("key") }

    var map: WorldMap {
        player.starts(in: hall).secret
        box.lockedBy(key).secret
    }
}

/// A dynamic exit drawn to the attic on a map and walked to the cellar.
struct MapsToGame: Game {
    let title = "Maps To"
    let intro = "A hall with a shifting stair."

    let hall = Location {
        name("Hall")
        description("A hall. A stair leads up.")
    }
    let attic = Location {
        name("Attic")
        description("An attic.")
    }
    let cellar = Location {
        name("Cellar")
        description("A cellar.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.up { cellar }.mapsTo(attic)
        attic.down(hall)
        cellar.up(hall)
    }
}

/// `.mapsTo(_:)` after a plain exit, a placement, and naming a room the
/// bootstrap never registered.
struct BadMapsToGame: Game {
    let title = "Bad Maps To"
    let intro = "A hall and a coin."

    let hall = Location { name("Hall") }
    let attic = Location { name("Attic") }
    let coin = Item { name("coin") }
    var nowhere: Location { Location { name("Nowhere") } }

    var map: WorldMap {
        player.starts(in: hall)
        hall.north(attic).mapsTo(attic)
        coin.starts(in: hall).mapsTo(attic)
        hall.east { attic }.mapsTo(nowhere)
        attic.south(hall)
    }
}

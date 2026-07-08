import Gnusto

// A door item is shared between two rooms' exits by naming the same stored
// property from both — the `map` block is a computed property, so `via:`/`when:`
// and `lockedBy(_:)` can all reference sibling items freely.

/// Two rooms joined by a shared trap door: living room above, cellar below. The
/// same `trapDoor` item is named by both rooms' vertical exits, so its open
/// state is shared for free — open it from below and you can ascend.
struct TrapDoorGame: Game {
    let title = "TrapDoor"
    let intro = ""

    let livingRoom = Location {
        name("Living Room")
        description("A cozy living room.")
    }

    let cellar = Location {
        name("Cellar")
        description("A damp cellar.")
    }

    let trapDoor = Item {
        name("trap door")
        openable
    }

    var map: WorldMap {
        player.starts(in: livingRoom)
        livingRoom.down(cellar, via: trapDoor)
        cellar.up(livingRoom, via: trapDoor)
    }
}

/// A locked door between a hall and a vault. The door is openable + lockable;
/// the player must unlock it with the key before it will open, and only then
/// can pass.
struct LockedDoorGame: Game {
    let title = "LockedDoor"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A stone hall.")
    }

    let vault = Location {
        name("Vault")
        description("A treasure vault.")
    }

    let ironDoor = Item {
        name("iron door")
        openable
    }

    let key = Item {
        name("iron key")
    }

    var map: WorldMap {
        player.starts(in: hall)
        key.startsHeld
        ironDoor.lockedBy(key)
        hall.north(vault, via: ironDoor)
        vault.south(hall, via: ironDoor)
    }
}

/// A clearing whose west exit to the forest is gated by a `@Global` flag. While
/// the grating is locked the way is barred; flipping the flag opens it. Proves
/// the condition closure evaluates live at `go` time.
struct GratingGame: Game {
    let title = "Grating"
    let intro = ""

    @Global var gratingUnlocked = false

    let clearing = Location {
        name("Clearing")
        description("A forest clearing.")
    }

    let forest = Location {
        name("Forest")
        description("A dark forest.")
    }

    let lever = Item {
        name("rusty lever")
        scenery
    }

    var map: WorldMap {
        player.starts(in: clearing)
        lever.starts(in: clearing)
        clearing.west(forest, when: { gratingUnlocked }, otherwise: "The way is barred.")
    }

    var rules: Rules {
        lever.before(.push) {
            gratingUnlocked = true
            try reply("The grating springs open.")
        }
    }
}

/// A hidden door: the study's east exit runs through a bookcase-door that stays
/// out of scope and impassable until a lever reveals it.
struct HiddenDoorGame: Game {
    let title = "HiddenDoor"
    let intro = ""

    let study = Location {
        name("Study")
        description("A book-lined study.")
    }

    let passage = Location {
        name("Secret Passage")
        description("A narrow passage.")
    }

    let bookcase = Item {
        name("bookcase door")
        openable
        hidden
    }

    let switchLever = Item {
        name("brass switch")
        scenery
    }

    var map: WorldMap {
        player.starts(in: study)
        switchLever.starts(in: study)
        study.east(passage, via: bookcase)
    }

    var rules: Rules {
        switchLever.before(.push) {
            bookcase.reveal()
            try reply("A bookcase swings aside, revealing a door.")
        }
    }
}

/// Invalid: a door exit names an item that isn't openable, and another names an
/// item that was never declared. Bootstrap must report both.
struct BadDoorGame: Game {
    let title = "BadDoor"
    let intro = ""

    let start = Location {
        name("Start")
        description("The start.")
    }

    let other = Location {
        name("Other")
        description("The other.")
    }

    let plank = Item {
        name("wooden plank")  // not openable
    }

    var map: WorldMap {
        player.starts(in: start)
        start.north(other, via: plank)  // plank is not openable
        start.south(other, via: Item { name("phantom door") })  // never declared
    }
}

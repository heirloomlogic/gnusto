import Gnusto
import GnustoScoring

/// The Coal Mine region — a dead mine reached through the Slide Room, and the
/// most machinery-laden corner of the underground. From the Mine Entrance a
/// vampire bat guards the Bat Room (hold the garlic or it carries you off into
/// the coal maze); past the Shaft Room, with its basket on a long chain, a
/// staircase drops to the Gas Room, where any naked flame is fatal. Beyond the
/// four-room coal maze and a ladder lie the Timber Room and, through a crack too
/// narrow to pass with anything in hand, the Drafty Room and the Machine Room,
/// where coal fed to the machine and its switch thrown becomes a diamond.
///
/// Three of the region's mechanisms cross bundle boundaries and so are
/// host-wired in ``Zork1``, the same way the dam's bolt and the troll's east
/// exit are: the bat reads the garlic (a ``ZorkHouse`` item), the machine switch
/// is thrown with the screwdriver (a ``ZorkDam`` item), and the Slide Room's
/// north opening onto the Mine Entrance crosses from ``ZorkMirror``. Everything
/// self-contained to the mine — the gas death, the basket, the crack — lives
/// here. See `FIDELITY.md`.
struct ZorkCoalMine: GameContent {
    // MARK: - Rooms

    let mineEntrance = Location {
        name("Mine Entrance")
        description(Prose.mineEntrance)
        dark
    }

    let squeakyRoom = Location {
        name("Squeaky Room")
        description(Prose.squeakyRoom)
        dark
    }

    let batRoom = Location {
        name("Bat Room")
        description(Prose.batRoom)
        dark
    }

    /// The head of the shaft, where the basket hangs on its chain. Down the
    /// shaft itself is a fatal squeeze (the blocked exit below).
    let shaftRoom = Location {
        name("Shaft Room")
        description(Prose.shaftRoom)
        dark
    }

    let smellyRoom = Location {
        name("Smelly Room")
        description(Prose.smellyRoom)
        dark
    }

    /// Thick with coal gas. Carrying a lit open flame in here, or striking one
    /// while you stand here, sets the air alight (the `afterEachTurn` rule
    /// below). The electric lantern is safe.
    let gasRoom = Location {
        name("Gas Room")
        description(Prose.gasRoom)
        dark
    }

    // The four-room coal maze. Every room is named "Coal Mine"; the thread that
    // reaches the ladder is east, northeast, southeast, southwest, down.
    let mine1 = Location {
        name("Coal Mine")
        description(Prose.coalMine)
        dark
    }

    let mine2 = Location {
        name("Coal Mine")
        description(Prose.coalMine)
        dark
    }

    let mine3 = Location {
        name("Coal Mine")
        description(Prose.coalMine)
        dark
    }

    let mine4 = Location {
        name("Coal Mine")
        description(Prose.coalMine)
        dark
    }

    let ladderTop = Location {
        name("Ladder Top")
        description(Prose.ladderTop)
        dark
    }

    let ladderBottom = Location {
        name("Ladder Bottom")
        description(Prose.ladderBottom)
        dark
    }

    let deadEnd = Location {
        name("Dead End")
        description(Prose.coalDeadEnd)
        dark
    }

    let timberRoom = Location {
        name("Timber Room")
        description(Prose.timberRoom)
        dark
    }

    /// The bottom of the shaft, lit only by whatever the basket brings down.
    /// Reached from the Timber Room through a crack too narrow to pass carrying
    /// anything (the `before(.go)` rule below).
    let draftyRoom = Location {
        name("Drafty Room")
        description(Prose.draftyRoom)
        dark
    }

    let machineRoom = Location {
        name("Machine Room")
        description(Prose.machineRoom)
        dark
    }

    // MARK: - Items

    /// The jade figurine: five on the find, five in the case (the original's
    /// SIZE 10 / VALUE 5 / TVALUE 5).
    let jade = Item {
        name("jade figurine")
        adjectives("jade", "exquisite")
        synonyms("figurine")
        firstSight(Prose.jadeFirstSight)
        description(Prose.jade)
        trait(.weight, 10)
        trait(.takeValue, 5)  // find
        trait(.depositValue, 5)  // case
    }

    /// The sapphire-encrusted bracelet: five on the find, five in the case.
    let sapphireBracelet = Item {
        name("sapphire-encrusted bracelet")
        adjectives("sapphire", "sapphire-encrusted")
        synonyms("bracelet", "jewel")
        firstSight(Prose.sapphireBraceletFirstSight)
        description(Prose.sapphireBracelet)
        trait(.weight, 10)
        trait(.takeValue, 5)  // find
        trait(.depositValue, 5)  // case
    }

    /// A small pile of coal — not a treasure, but the machine's raw material.
    /// Fed to the machine and transmuted, it becomes the huge diamond.
    let coal = Item {
        name("small pile of coal")
        adjectives("small", "black")
        synonyms("coal", "pile", "heap")
        firstSight(Prose.coalFirstSight)
        description(Prose.coal)
        trait(.weight, 20)  // the original's SIZE
    }

    /// The huge diamond: ten on the find, ten in the case. It has no starting
    /// placement (it begins ``.nowhere``); throwing the machine switch on a load
    /// of coal (host-wired) moves it into the machine.
    let diamond = Item {
        name("huge diamond")
        adjectives("huge", "enormous")
        synonyms("diamond")
        firstSight(Prose.diamondFirstSight)
        description(Prose.diamond)
        trait(.takeValue, 10)  // find
        trait(.depositValue, 10)  // case
    }

    /// The basket on the chain, an open, transparent container the shaft's
    /// mechanism raises and lowers between the Shaft Room and the Drafty Room. A
    /// lit torch left in it lights whichever room it hangs in. It can't be taken
    /// (fastened to the chain); the raise/lower rules live below.
    ///
    /// The chain shows a basket at *both* ends: whichever room holds the real
    /// container, the other holds ``basketStandin`` — so "raise basket" and
    /// "lower basket" always name a basket in the Shaft Room, however the chain
    /// currently hangs, and never two at once.
    let basket = Item {
        name("basket")
        synonyms("cage", "dumbwaiter")
        description(Prose.basket)
        container
        openable
        startsOpen
        transparent
        capacity(50)
    }

    /// The far end of the chain — the basket seen from the opposite room. Not a
    /// container; you work it only from the Shaft Room. See ``basket``.
    let basketStandin = Item {
        name("basket")
        synonyms("cage", "dumbwaiter")
        description(Prose.basketFarEnd)
        scenery
    }

    /// The dryer-like machine. A closed container with a lid; feed it coal, shut
    /// it, and throw its switch with a screwdriver (host-wired) to make a
    /// diamond. Too large to carry.
    let machine = Item {
        name("machine")
        adjectives("large")
        synonyms("dryer", "lid", "pdp10")
        description(Prose.machine)
        container
        openable
    }

    /// The machine's start switch — thrown with a screwdriver (host-wired). Too
    /// small for bare fingers.
    let machineSwitch = Item {
        name("switch")
        synonyms("start")
        description(Prose.machineSwitch)
        scenery
    }

    // MARK: - State

    /// Whether the basket hangs at the bottom of the shaft (in the Drafty Room)
    /// rather than the top (the Shaft Room). Flipped by the raise/lower rules.
    @Global var basketLowered = false

    // MARK: - Map

    var map: WorldMap {
        // Mine Entrance. South to the Slide Room crosses into ZorkMirror, so the
        // host wires it. Its canonical IN alias folds into WEST (same target).
        mineEntrance.west(squeakyRoom)

        // Squeaky Room.
        squeakyRoom.north(batRoom)
        squeakyRoom.east(mineEntrance)

        // Bat Room. Entering without the garlic gets you carried off (host-wired,
        // since the bat reads a house item).
        batRoom.south(squeakyRoom)
        batRoom.east(shaftRoom)

        // Shaft Room. Down the shaft is a fatal squeeze.
        shaftRoom.down(blocked: Prose.shaftTooNarrow)
        shaftRoom.west(batRoom)
        shaftRoom.north(smellyRoom)

        // Smelly Room.
        smellyRoom.down(gasRoom)
        smellyRoom.south(shaftRoom)

        // Gas Room.
        gasRoom.up(smellyRoom)
        gasRoom.east(mine1)

        // The coal maze — the canonical exit graph, self-loops and all.
        mine1.north(gasRoom)
        mine1.east(mine1)
        mine1.northeast(mine2)

        mine2.north(mine2)
        mine2.south(mine1)
        mine2.southeast(mine3)

        mine3.south(mine3)
        mine3.southwest(mine4)
        mine3.east(mine2)

        mine4.north(mine3)
        mine4.west(mine4)
        mine4.down(ladderTop)

        // Ladder Top & Bottom.
        ladderTop.down(ladderBottom)
        ladderTop.up(mine4)

        ladderBottom.south(deadEnd)
        ladderBottom.west(timberRoom)
        ladderBottom.up(ladderTop)

        // Dead End — the coal lies here.
        deadEnd.north(ladderBottom)

        // Timber Room. West through the crack to the Drafty Room needs empty
        // hands (the before(.go) rule below); the exit itself is unconditional.
        timberRoom.east(ladderBottom)
        timberRoom.west(draftyRoom)

        // Drafty Room. East back through the crack likewise needs empty hands.
        // Its canonical OUT alias folds into EAST (same target).
        draftyRoom.south(machineRoom)
        draftyRoom.east(timberRoom)

        // Machine Room.
        machineRoom.north(draftyRoom)

        // Entities. (The diamond is unplaced — it starts .nowhere.)
        jade.starts(in: batRoom)
        sapphireBracelet.starts(in: gasRoom)
        coal.starts(in: deadEnd)
        basket.starts(in: shaftRoom)
        basketStandin.starts(in: draftyRoom)
        machine.starts(in: machineRoom)
        machineSwitch.starts(in: machineRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        // The coal gas. At the end of any turn spent in the Gas Room with a lit
        // open flame in hand — carried in or struck here — the air goes up. The
        // electric lantern carries no flame and is safe.
        gasRoom.afterEachTurn {
            guard player.inventory.contains(where: { $0[default: .openFlame] && $0.isLit })
            else { return }
            try die(Prose.gasExplosion)
        }

        // The narrow crack between the Timber Room and the Drafty Room. Nothing
        // in hand fits through — the reason the basket, not your arms, carries
        // the coal and torch down the shaft.
        timberRoom.before(.go) {
            guard command.direction == .west else { return }
            try require(player.inventory.isEmpty, else: Prose.crackTooNarrow)
        }
        draftyRoom.before(.go) {
            guard command.direction == .east else { return }
            try require(player.inventory.isEmpty, else: Prose.crackTooNarrow)
        }

        // The basket on the chain. It can't be taken, and it's worked only from
        // the Shaft Room; lowering or raising it swings the real container to
        // the far end and leaves the stand-in behind.
        basket.before(.take) { try refuse(Prose.basketFastened) }
        basketStandin.before(.take) { try refuse(Prose.basketFastened) }
        basket.before(.lower) { try lowerBasket() }
        basketStandin.before(.lower) { try lowerBasket() }
        basket.before(.raise) { try raiseBasket() }
        basketStandin.before(.raise) { try raiseBasket() }

        // The machine is far too large to carry.
        machine.before(.take) { try refuse(Prose.machineTooBig) }
    }

    // MARK: - Basket mechanism

    /// Lower the basket to the bottom of the shaft (the Drafty Room). Worked
    /// only from the Shaft Room; the real container and its stand-in trade
    /// rooms. Ends the turn with its own reply.
    private func lowerBasket() throws {
        guard player.location == shaftRoom else { try reply(Prose.basketReachFromShaft) }
        guard !basketLowered else { try reply(Prose.basketAlreadyLowered) }
        basket.move(to: draftyRoom)
        basketStandin.move(to: shaftRoom)
        basketLowered = true
        try reply(Prose.basketLowered)
    }

    /// Raise the basket back to the Shaft Room. The mirror of ``lowerBasket()``.
    private func raiseBasket() throws {
        guard player.location == shaftRoom else { try reply(Prose.basketReachFromShaft) }
        guard basketLowered else { try reply(Prose.basketAlreadyRaised) }
        basket.move(to: shaftRoom)
        basketStandin.move(to: draftyRoom)
        basketLowered = false
        try reply(Prose.basketRaised)
    }
}

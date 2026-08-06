import Gnusto
import GnustoScoring

/// The coal mine — the deepest and most machinery-laden corner of the map, and
/// the one that punishes a light source hardest.
///
/// From the Mine Entrance a deranged vampire bat holds the Bat Room and will
/// carry you off into the maze unless you are holding the garlic. Past the
/// Shaft Room, where a basket hangs on a long iron chain, a staircase drops to
/// the Gas Room, where any naked flame is the last thing that happens to you.
/// Beyond the seven rooms of the coal maze and a rickety ladder lie the Timber
/// Room and, through a crack that admits nothing carried in the hands, the
/// Lower Shaft and the Machine Room, where coal shut in the machine and its
/// switch thrown becomes a diamond.
///
/// **This is not Zork I's coal mine.** The trilogy kept the puzzle and shrank
/// the map around it:
///
/// - the maze is **seven rooms**, not four, and the Gas Room is not one of its
///   doors: the mine is entered from a **Wooden Tunnel** that Zork I never
///   built, and the Gas Room is a dead end off it;
/// - the **Mine Entrance has two openings**, northeast and northwest;
/// - the **Bat Room has one door**, and the bat drops you anywhere in the
///   maze — all seven rooms and both ends of the ladder;
/// - the room at the bottom of the shaft is the **Lower Shaft**, not the
///   Drafty Room, its narrow ways out are east and northeast, and **reaching
///   it lit is worth ten points** (`LIGHT-SHAFT`) — an event award, paid once,
///   and paid by the host;
/// - the **crack is a pair of conditional exits**, as in the source, rather
///   than a rule: the refusal is the same either way round.
///
/// The seams the host wires are the Mine Entrance's path south to the Slide
/// Room, the bat's reading of the garlic (a ``DungeonHouse`` item), the
/// machine's switch and the screwdriver that throws it (a ``DungeonDam``
/// item), and the `LIGHT-SHAFT` award. See `FIDELITY.md`.
struct DungeonCoalMine: GameContent {
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

    /// Always described: whether the bat is hanging there at all depends on
    /// the garlic, and a brief re-entry would print a bare room name over a
    /// creature about to pick you up.
    let batRoom = Location {
        name("Bat Room")
        alwaysDescribed
        dark
    }

    let shaftRoom = Location {
        name("Shaft Room")
        description(Prose.shaftRoom)
        dark
    }

    let woodenTunnel = Location {
        name("Wooden Tunnel")
        description(Prose.woodenTunnel)
        dark
    }

    let smellyRoom = Location {
        name("Smelly Room")
        description(Prose.smellyRoom)
        dark
    }

    /// Thick with coal gas. Carrying a lit open flame in, or striking one
    /// here, sets the air alight. The electric lantern is safe.
    let gasRoom = Location {
        name("Gas Room")
        description(Prose.gasRoom)
        dark
    }

    // The seven-room coal maze. Every room carries the same name and the same
    // description, exactly as the source gives all seven one `MINDESC`.
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

    let mine5 = Location {
        name("Coal Mine")
        description(Prose.coalMine)
        dark
    }

    let mine6 = Location {
        name("Coal Mine")
        description(Prose.coalMine)
        dark
    }

    let mine7 = Location {
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

    let coalDeadEnd = Location {
        name("Dead End")
        description(Prose.coalDeadEnd)
        dark
    }

    let timberRoom = Location {
        name("Timber Room")
        description(Prose.timberRoom)
        dark
    }

    /// The bottom of the shaft, lit only by whatever the basket brought down.
    /// Arriving here with light is the mainframe's `LIGHT-SHAFT` award.
    let lowerShaft = Location {
        name("Lower Shaft")
        description(Prose.lowerShaft)
        dark
    }

    /// Always described: whether the lid stands open is the difference between
    /// a diamond and nothing at all, and it only shows in the long
    /// description.
    let machineRoom = Location {
        name("Machine Room")
        alwaysDescribed
        dark
    }

    // MARK: - State

    /// Whether the basket hangs at the bottom of the shaft. The mainframe's
    /// `CAGE-TOP`, inverted — and derived, because the basket is fastened to
    /// the chain and so is only ever in one of these two rooms.
    var basketLowered: Bool { basket.isIn(lowerShaft) }

    /// The maze rooms the bat drops you into — the source's `BAT-DROPS`, which
    /// is all seven mine rooms and both ends of the ladder.
    var batDrops: [Location] {
        [mine1, mine2, mine3, mine4, mine5, mine6, mine7, ladderTop, ladderBottom]
    }

    // MARK: - Items

    let mineEntrances = Item {
        name("entrances")
        synonyms("entrance", "openings", "opening", "mine", "shaft")
        description(Prose.mineEntrances)
        scenery
        plural
    }

    let squeakySounds = Item {
        name("squeaky sounds")
        adjectives("strange", "squeaky")
        synonyms("sounds", "sound", "squeaking", "passage")
        description(Prose.squeakySounds)
        scenery
        plural
    }

    /// The bat. Nothing to be done about it; the garlic is the answer, and the
    /// host holds the rule because the garlic is a ``DungeonHouse`` item.
    let bat = Item {
        name("vampire bat")
        adjectives("vampire", "deranged", "giant", "large")
        description(Prose.bat)
        scenery
    }

    /// The jade figurine: five to find and five to case.
    let jade = Item {
        name("jade figurine")
        adjectives("jade", "exquisite")
        synonyms("figurine", "jade")
        firstSight(Prose.jadeFirstSight)
        description(Prose.jade)
        trait(.weight, 10)
        trait(.takeValue, 5)
        trait(.depositValue, 5)
    }

    let ironChain = Item {
        name("iron chain")
        adjectives("heavy", "iron", "metal")
        synonyms("chain", "framework", "shaft")
        description(Prose.ironChain)
        scenery
    }

    /// The basket on the chain: an open, transparent container the shaft's
    /// mechanism swings between the Shaft Room and the Lower Shaft.
    let basket = Item {
        name("basket")
        synonyms("cage", "dumbwaiter")
        firstSight(Prose.basket)
        description(Prose.basketExamined)
        container
        openable
        startsOpen
        transparent
        capacity(50)
    }

    /// The far end of the chain — the source's separate `FBASK`. It is not a
    /// container and cannot be worked from here; one ``Item/reach(otherwise:)``
    /// rule says so once, and `take`, `open`, `put in` and `look in` all
    /// inherit the mainframe's own sentence.
    let basketFarEnd = Item {
        name("basket")
        synonyms("cage", "dumbwaiter")
        description(Prose.basketFarEndExamined)
        scenery
    }

    let woodenBeams = Item {
        name("wooden beams")
        adjectives("large", "wooden")
        synonyms("beams", "beam", "timber", "ceiling", "walls", "wall")
        description(Prose.woodenBeams)
        scenery
        plural
    }

    let foulOdor = Item {
        name("foul odor")
        adjectives("foul")
        synonyms("odour", "odor", "smell", "staircase", "stairs")
        description(Prose.foulOdor)
        scenery
    }

    let coalGas = Item {
        name("coal gas")
        adjectives("coal")
        synonyms("gas", "air", "stairs")
        description(Prose.coalGas)
        scenery
    }

    /// The sapphire bracelet: five to find and **three** to case, where the
    /// trilogy pays five.
    let sapphireBracelet = Item {
        name("sapphire-encrusted bracelet")
        adjectives("sapphire", "encrusted")
        synonyms("bracelet", "jewel", "sapphires")
        firstSight(Prose.sapphireBraceletFirstSight)
        description(Prose.sapphireBracelet)
        trait(.weight, 10)
        trait(.takeValue, 5)
        trait(.depositValue, 3)
    }

    // One fixture for all seven maze rooms would answer in only one of them,
    // so each gets its own — the tax the "every printed noun answers" rule
    // charges on a maze. Seven identical declarations, as the seven identical
    // rooms deserve.
    let coalMineWalls1 = Item {
        name("coal")
        synonyms("mine", "walls", "wall", "props", "prop", "seam")
        description(Prose.coalMineWalls)
        scenery
    }

    let coalMineWalls2 = Item {
        name("coal")
        synonyms("mine", "walls", "wall", "props", "prop", "seam")
        description(Prose.coalMineWalls)
        scenery
    }

    let coalMineWalls3 = Item {
        name("coal")
        synonyms("mine", "walls", "wall", "props", "prop", "seam")
        description(Prose.coalMineWalls)
        scenery
    }

    let coalMineWalls4 = Item {
        name("coal")
        synonyms("mine", "walls", "wall", "props", "prop", "seam")
        description(Prose.coalMineWalls)
        scenery
    }

    let coalMineWalls5 = Item {
        name("coal")
        synonyms("mine", "walls", "wall", "props", "prop", "seam")
        description(Prose.coalMineWalls)
        scenery
    }

    let coalMineWalls6 = Item {
        name("coal")
        synonyms("mine", "walls", "wall", "props", "prop", "seam")
        description(Prose.coalMineWalls)
        scenery
    }

    let coalMineWalls7 = Item {
        name("coal")
        synonyms("mine", "walls", "wall", "props", "prop", "seam")
        description(Prose.coalMineWalls)
        scenery
    }

    let woodenLadder = Item {
        name("wooden ladder")
        adjectives("rickety", "wooden", "narrow")
        synonyms("ladder", "staircase", "stairs")
        description(Prose.woodenLadder)
        scenery
    }

    /// A small pile of coal — not a treasure, but the machine's raw material.
    let coal = Item {
        name("small pile of coal")
        adjectives("small", "black")
        synonyms("coal", "pile", "heap")
        firstSight(Prose.coalFirstSight)
        description(Prose.coal)
        trait(.weight, 20)
    }

    let brokenTimber = Item {
        name("broken timber")
        adjectives("broken")
        synonyms("timber", "timbers", "pile")
        firstSight(Prose.brokenTimberFirstSight)
        description(Prose.brokenTimber)
        trait(.weight, 50)
    }

    let machine = Item {
        name("machine")
        adjectives("large")
        synonyms("dryer", "lid", "pdp10", "box")
        description(Prose.machine)
        container
        openable
        scenery
    }

    let machineSwitch = Item {
        name("switch")
        synonyms("start")
        description(Prose.machineSwitch)
        scenery
    }

    /// The huge diamond: ten to find and **six** to case, where the trilogy
    /// pays ten. It starts nowhere; the machine makes it.
    let diamond = Item {
        name("huge diamond")
        adjectives("huge", "enormous", "perfectly", "cut")
        synonyms("diamond")
        firstSight(Prose.diamondFirstSight)
        description(Prose.diamond)
        trait(.takeValue, 10)
        trait(.depositValue, 6)
    }

    /// What the machine makes of anything that was not coal. Starts nowhere,
    /// and crumbles the moment anybody picks it up.
    let slag = Item {
        name("piece of vitreous slag")
        adjectives("vitreous")
        synonyms("slag", "piece")
        firstSight(Prose.slagFirstSight)
        description(Prose.slag)
        trait(.weight, 10)
    }

    // MARK: - Map

    var map: WorldMap {
        mineExits
        minePlacements
    }

    @MapBuilder private var mineExits: WorldMap {
        // The Mine Entrance. South is the Slide Room, a ``DungeonMirror``
        // room — host-wired.
        mineEntrance.northwest(squeakyRoom)
        mineEntrance.northeast(shaftRoom)

        squeakyRoom.west(batRoom)
        squeakyRoom.south(mineEntrance)

        batRoom.east(squeakyRoom)

        // The Shaft Room. Down the shaft itself is a fatal squeeze.
        shaftRoom.down(blocked: Prose.shaftTooNarrow)
        shaftRoom.west(mineEntrance)
        shaftRoom.north(woodenTunnel)

        woodenTunnel.south(shaftRoom)
        woodenTunnel.west(smellyRoom)
        woodenTunnel.northeast(mine1)

        smellyRoom.down(gasRoom)
        smellyRoom.east(woodenTunnel)

        gasRoom.up(smellyRoom)

        // The coal maze, exactly as the source draws it: no self-loops, but no
        // symmetry either, and two of MINE5's six ways out land in the same
        // room as two others.
        mine1.north(mine4)
        mine1.southwest(mine2)
        mine1.east(woodenTunnel)

        mine2.south(mine1)
        mine2.west(mine5)
        mine2.up(mine3)
        mine2.northeast(mine4)

        mine3.west(mine2)
        mine3.northeast(mine5)
        mine3.east(mine5)

        mine4.up(mine5)
        mine4.northeast(mine6)
        mine4.south(mine1)
        mine4.west(mine2)

        mine5.down(mine6)
        mine5.north(mine7)
        mine5.west(mine2)
        mine5.south(mine3)
        mine5.up(mine3)
        mine5.east(mine4)

        mine6.southeast(mine4)
        mine6.up(mine5)
        mine6.northwest(mine7)

        mine7.east(mine1)
        mine7.west(mine5)
        mine7.down(ladderTop)
        mine7.south(mine6)

        ladderTop.down(ladderBottom)
        ladderTop.up(mine7)

        ladderBottom.northeast(coalDeadEnd)
        ladderBottom.south(timberRoom)
        ladderBottom.up(ladderTop)

        coalDeadEnd.south(ladderBottom)

        // The crack. A conditional exit in both directions, as in the source,
        // with the source's own refusal: nothing carried in the hands fits,
        // which is why the basket and not your arms takes the coal down.
        timberRoom.north(ladderBottom)
        timberRoom.southwest(
            lowerShaft, when: { player.inventory.isEmpty }, otherwise: Prose.crackTooNarrow)

        lowerShaft.east(machineRoom)
        lowerShaft.up(blocked: Prose.chainNotClimbable)
        for way in [Direction.out, .northeast] {
            lowerShaft.exit(
                way, to: timberRoom, when: { player.inventory.isEmpty },
                otherwise: Prose.crackTooNarrow)
        }

        machineRoom.northwest(lowerShaft)
    }

    /// The second half of the same list, split for hazard #174's reason: peak
    /// bootstrap stack depth scales with the largest single declaration body,
    /// and milestone 8's seventeenth bundle put the suite over the edge again.
    @MapBuilder private var minePlacements: WorldMap {
        mineEntrances.starts(in: mineEntrance)
        squeakySounds.starts(in: squeakyRoom)
        bat.starts(in: batRoom)
        jade.starts(in: batRoom)

        ironChain.starts(in: shaftRoom)
        basket.starts(in: shaftRoom)
        basketFarEnd.starts(in: lowerShaft)

        woodenBeams.starts(in: woodenTunnel)
        foulOdor.starts(in: smellyRoom)
        coalGas.starts(in: gasRoom)
        sapphireBracelet.starts(in: gasRoom)

        coalMineWalls1.starts(in: mine1)
        coalMineWalls2.starts(in: mine2)
        coalMineWalls3.starts(in: mine3)
        coalMineWalls4.starts(in: mine4)
        coalMineWalls5.starts(in: mine5)
        coalMineWalls6.starts(in: mine6)
        coalMineWalls7.starts(in: mine7)

        woodenLadder.starts(in: ladderTop)
        coal.starts(in: coalDeadEnd)
        brokenTimber.starts(in: timberRoom)

        machine.starts(in: machineRoom)
        machineSwitch.starts(in: machineRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        // The bat only shows itself to somebody holding the garlic; without it
        // the host's `onEnter` rule has already carried you away.
        batRoom.describe {
            bat.isVisible ? "\(Prose.batRoom)\n\n\(Prose.batHangsThere)" : Prose.batRoom
        }

        // The machine's lid is the last word of the room's description, as it
        // is in the source.
        machineRoom.describe {
            "\(Prose.machineRoom) \(machine.isOpen ? Prose.machineLidOpen : Prose.machineLidClosed)"
        }

        // The coal gas. At the end of any turn spent here with a live flame in
        // hand, whether it was carried in or struck where you stand.
        gasRoom.afterEachTurn {
            guard player.inventory.contains(where: { $0[default: .openFlame] && $0.isLit })
            else { return }
            try die(command.intent == .go ? Prose.gasExplosionCarried : Prose.gasExplosionStruck)
        }

        // The basket. Fastened to the chain, and worked from whichever end of
        // the shaft you are standing at — the source checks that a basket is
        // in scope and nothing else, so both ends answer the same.
        //
        // Only the near end needs a `take` refusal: the far end's reach rule
        // below answers first, at stage 0.
        basket.before(.take) { try refuse(Prose.basketFastened) }
        for cage in [basket, basketFarEnd] {
            cage.before(.lower) { try swingBasket(down: true) }
            cage.before(.raise) { try swingBasket(down: false) }
        }

        // The far end of the chain is out of reach by definition: it is a
        // basket you can see down (or up) the shaft and not touch. One
        // ``Item/reach(otherwise:)`` rule says so once, and every verb the
        // engine gates on reach — `take`, `open`, `look in`, `put in` —
        // answers with the mainframe's own sentence instead of four rules
        // saying it four times.
        basketFarEnd.reach(otherwise: Prose.basketFarEnd) { false }

        // The machine is far too large to carry, and its lid is worked by hand.
        machine.before(.take) { try refuse(Prose.machineTooBig) }

        // Bare fingers will not throw the switch; the screwdriver that will is
        // a ``DungeonDam`` item, so the host owns the working rule.
        machineSwitch.before(.turn) { try reply(Prose.switchNeedsTool) }

        // The slag crumbles at a touch, which is the mainframe's way of saying
        // you fed the machine the wrong thing.
        slag.before(.take) {
            slag.vanish()
            try reply(Prose.slagCrumbles)
        }
    }

    // MARK: - The basket on the chain

    /// Swing the chain. The real container and its far end trade rooms, and if
    /// the basket was carrying the only light, the room you are standing in
    /// goes dark on the spot.
    private func swingBasket(down: Bool) throws {
        guard basketLowered != down else {
            try reply(down ? Prose.basketAlreadyLowered : Prose.basketAlreadyRaised)
        }
        let wasLit = player.location.isLit
        basket.move(to: down ? lowerShaft : shaftRoom)
        basketFarEnd.move(to: down ? shaftRoom : lowerShaft)

        let done = down ? Prose.basketLowered : Prose.basketRaised
        guard wasLit, !player.location.isLit else { try reply(done) }
        try reply("\(done)\n\n\(Prose.itIsNowPitchBlack)")
    }
}

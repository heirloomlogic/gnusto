import Gnusto
import GnustoScoring

extension TraitKey<Bool> {
    /// An item that carries a live, naked flame — the ivory torch, the lit
    /// candles, a struck match. Nothing in the engine reads it yet; the Gas
    /// Room (a later region) will, to tell a safe light source from one that
    /// sets the air alight. Minted here because the torch and candles are the
    /// game's first open flames. See `FIDELITY.md`.
    public static let openFlame = Self("openFlame", default: false)
}

/// The Temple & Hades region — the dark religious heart of the underground.
/// From the Engravings Cave the Dome Room opens onto a shaft too deep to climb;
/// tie the attic rope to its railing and you can drop to the Torch Room, where
/// an ivory torch burns that never goes out. Below lie the Temple, its Altar,
/// and the Egyptian Room with a king's gold coffin; below those a draughty cave
/// falls away to the Entrance to Hades, where a wall of spirits bars the Land of
/// the Dead until they are exorcised.
///
/// Three seams cross out of this region and so are host-wired in ``Zork1``, the
/// same way the dam's bolt and the troll's east exit are: the way in from the
/// Round Room; the `tie rope to railing` rule (the rope is a ``ZorkHouse``
/// item); praying at the Altar (which lands the player in ``ZorkAboveGround``'s
/// forest — the only way to carry the coffin out); and the match mechanics
/// (the matchbook is a ``ZorkDam`` item, placed in the Dam Lobby). Everything
/// self-contained to the temple lives here. See `FIDELITY.md`.
struct ZorkTemple: GameContent {
    // MARK: - Rooms

    let engravingsCave = Location {
        name("Engravings Cave")
        description(Prose.engravingsCave)
        dark
    }

    let domeRoom = Location {
        name("Dome Room")
        description(Prose.domeRoom)
        dark
    }

    /// Dark by nature, but the ivory torch starts here and lights it; carry the
    /// torch away and the room falls dark like any other.
    let torchRoom = Location {
        name("Torch Room")
        description(Prose.torchRoom)
        dark
    }

    let temple = Location {
        name("Temple")
        description(Prose.temple)
        dark
    }

    let egyptRoom = Location {
        name("Egyptian Room")
        description(Prose.egyptRoom)
        dark
    }

    let altar = Location {
        name("Altar")
        description(Prose.altar)
        dark
    }

    /// The draughty cave between the altar and Hades. A cold draught here snuffs
    /// any lit candles (the `onEnter` rule below) — the reason the candles must
    /// be lit *at* the gate for the exorcism, not carried down alight.
    let cave = Location {
        name("Cave")
        description(Prose.templeCave)
        dark
    }

    let entranceToHades = Location {
        name("Entrance to Hades")
        description(Prose.entranceToHades)
        dark
    }

    let landOfDead = Location {
        name("Land of the Dead")
        description(Prose.landOfDead)
        dark
    }

    // MARK: - Items

    /// The ivory torch: a treasure (fourteen on the find, six in the case) and a
    /// permanent light source. There is no "always burning" trait — the
    /// documented idiom is to declare it a lit `lightSource` and refuse
    /// `.turnOff` in a rule, which the rules block below does.
    let torch = Item {
        name("ivory torch")
        adjectives("ivory")
        synonyms("torch")
        firstSight("An ivory torch, burning, is here.")
        description(Prose.ivoryTorch)
        lightSource
        startsLit
        trait(.openFlame, true)
        trait(.weight, 20)
        trait(.takeValue, 14)  // find
        trait(.depositValue, 6)  // case
    }

    let railing = Item {
        name("stone railing")
        adjectives("stone")
        synonyms("rail", "railing")
        description(Prose.templeRailing)
        scenery
    }

    let bell = Item {
        name("brass bell")
        adjectives("brass")
        synonyms("bell", "handbell")
        description(Prose.bell)
    }

    let book = Item {
        name("black book")
        adjectives("black", "prayer")
        synonyms("book", "prayerbook")
        description(Prose.book)
    }

    let candles = Item {
        name("pair of candles")
        adjectives("white", "wax")
        synonyms("candles", "candle")
        description(Prose.candles)
        lightSource
        trait(.openFlame, true)
    }

    /// The gold coffin: a treasure (ten on the find, fifteen in the case) and a
    /// container holding the sceptre. It weighs 55 — heavier than the altar
    /// crack's load cap of 50, so it can never be carried down toward Hades and
    /// must leave by the altar's PRAY egress instead (host-wired).
    let coffin = Item {
        name("gold coffin")
        adjectives("gold", "golden")
        synonyms("coffin", "casket")
        firstSight(Prose.coffinFirstSight)
        description(Prose.coffin)
        container
        openable
        trait(.weight, 55)
        trait(.takeValue, 10)  // find
        trait(.depositValue, 15)  // case
    }

    let sceptre = Item {
        name("sceptre")
        adjectives("ornate", "gold")
        synonyms("scepter", "sceptre", "staff", "wand")
        description(Prose.sceptre)
        trait(.takeValue, 4)  // find
        trait(.depositValue, 6)  // case
    }

    let crystalSkull = Item {
        name("crystal skull")
        adjectives("crystal")
        synonyms("skull", "head")
        firstSight(Prose.crystalSkullFirstSight)
        description(Prose.crystalSkull)
        trait(.takeValue, 10)  // find
        trait(.depositValue, 10)  // case
    }

    /// A single lit match. It has no starting placement, so it begins
    /// ``.nowhere``; striking a match (host-wired, since the matchbook is a dam
    /// item) moves it to the player's hand and arms a two-turn fuse that
    /// vanishes it again. Its only use is lighting the candles.
    let burningMatch = Item {
        name("burning match")
        adjectives("burning", "lit")
        synonyms("match")
        description(Prose.burningMatch)
        lightSource
        trait(.openFlame, true)
    }

    // MARK: - State

    /// Whether the rope is made fast to the dome railing — gates the descent to
    /// the Torch Room. Set by the host's `tie` rule (the rope is a house item).
    @Global var ropeTiedToRailing = false

    /// Whether the rung bell is still glowing red hot — too hot to pick up, and
    /// past ringing again, until it cools.
    @Global var bellHot = false

    /// The exorcism's progress at the gate of Hades: 0 nothing, 1 bell rung,
    /// 2 candles relit after the bell, 3 spirits banished. Stages 1 and 2 have
    /// a three-turn window (the `exorcismLapse` fuse) before the spirits recover.
    @Global var exorcismStage = 0

    /// Whether the spirits have been banished — opens the gate south to the
    /// Land of the Dead.
    @Global var ghostsBanished = false

    /// Candle fuel banked while they are unlit: a dim warning, then out for
    /// good. Two fuses where the lantern has three (FIDELITY.md).
    @Global var candlesDimIn = 20
    @Global var candlesDieIn = 25
    @Global var candlesBurnedOut = false

    // MARK: - Map

    var map: WorldMap {
        // Engravings Cave. Its west exit to the Round Room crosses into
        // ZorkRoundRoom, so the host wires it.
        engravingsCave.east(domeRoom)

        // Dome Room. The drop to the Torch Room needs the rope tied; there is
        // no reverse (the rope can't be climbed — see the Torch Room's up).
        domeRoom.west(engravingsCave)
        domeRoom.down(torchRoom, when: { ropeTiedToRailing }, otherwise: Prose.domeNoRope)

        // Torch Room. Up the shaft the rope hangs out of reach — a one-way
        // drop, canonical. Steps and a passage both reach the Temple.
        torchRoom.up(blocked: Prose.torchNoRope)
        torchRoom.south(temple)
        torchRoom.down(temple)

        // Temple. Down/east to the Egyptian Room, up/north back to the Torch
        // Room, south to the Altar.
        temple.east(egyptRoom)
        temple.down(egyptRoom)
        temple.north(torchRoom)
        temple.up(torchRoom)
        temple.south(altar)

        // Egyptian Room — a dead end but for the way back.
        egyptRoom.west(temple)
        egyptRoom.up(temple)

        // Altar. The crack south drops to the cave; too heavy a load (the
        // coffin) can't fit through (the before(.go) rule below).
        altar.north(temple)
        altar.down(cave)

        // Cave (canonically the Tiny Cave). Down to Hades; its north and west
        // openings onto the mirror region are host-wired in ``Zork1`` (they
        // cross into ``ZorkMirror``). There is deliberately no way back up to
        // the altar — the drop through the altar crack is one-way, and the way
        // out of the temple complex is onward through the mirror rooms.
        cave.down(entranceToHades)

        // Entrance to Hades. South to the Land of the Dead once the spirits
        // are gone.
        entranceToHades.up(cave)
        entranceToHades.south(landOfDead, when: { ghostsBanished }, otherwise: Prose.hadesGateBlocked)

        // Land of the Dead.
        landOfDead.north(entranceToHades)

        // Entities. (The burning match is unplaced — it starts .nowhere.)
        torch.starts(in: torchRoom)
        railing.starts(in: domeRoom)
        bell.starts(in: temple)
        book.starts(in: altar)
        candles.starts(in: altar)
        coffin.starts(in: egyptRoom)
        sceptre.starts(inside: coffin)
        crystalSkull.starts(in: landOfDead)
    }

    // MARK: - Rules

    var rules: Rules {
        // The ivory torch never goes out.
        torch.before(.turnOff) {
            try refuse(Prose.torchWontExtinguish)
        }

        // The altar crack is too narrow for a heavy load. The coffin (55)
        // trips the cap; ordinary exploring loads (torch, bell, book, candles)
        // do not. Canonically the block is coffin-specific; here it's a ≤50
        // load cap, reusing the burden weight (FIDELITY.md).
        altar.before(.go) {
            guard command.direction == .down else { return }
            let carried = player.inventory.reduce(0) { $0 + burdenWeight(of: $1) }
            try require(carried <= 50, else: Prose.coffinTooHeavy)
        }

        // The bell, red hot after ringing, can't be picked up until it cools.
        bell.before(.take) {
            try require(!bellHot, else: Prose.bellTooHotToTake)
        }

        // Ringing the bell. Away from the gate (or once the spirits are gone)
        // it just rings. At the gate it opens the exorcism: the spirits freeze,
        // the bell goes red hot and drops, any lit candles are snuffed, and a
        // three-turn window opens (with a twenty-turn cool on the bell).
        bell.before(.ring) {
            guard player.location == entranceToHades, !ghostsBanished else {
                try reply(Prose.bellRingsHollow)
            }
            guard !bellHot else { try reply(Prose.bellAlreadyRung) }
            bellHot = true
            exorcismStage = 1
            if candles.isLit {
                candles.isLit = false
                candlesDimIn = fuseRemaining("candlesDim") ?? 0
                candlesDieIn = fuseRemaining("candlesDie") ?? 0
                stopFuse("candlesDim")
                stopFuse("candlesDie")
            }
            bell.move(to: entranceToHades)
            startFuse("exorcismLapse", after: 3)
            startFuse("bellCools", after: 20)
            try reply(Prose.bellRingRedHot)
        }

        // Lighting the candles. Needs a live flame in hand — a struck match.
        // Done at the gate during the window (stage 1) it advances the ritual;
        // anywhere else it's just light. The candles are lit by hand here so
        // the reply is ours, not the default turn-on line.
        candles.before(.turnOn) {
            try require(!candlesBurnedOut, else: Prose.candlesSpent)
            try require(player.inventory.contains(burningMatch), else: Prose.candlesNeedFlame)
            candles.isLit = true
            if candlesDimIn > 0 { startFuse("candlesDim", after: candlesDimIn) }
            startFuse("candlesDie", after: candlesDieIn)
            if player.location == entranceToHades && exorcismStage == 1 {
                exorcismStage = 2
                stopFuse("exorcismLapse")
                startFuse("exorcismLapse", after: 3)
                try reply(Prose.candlesLitForRitual)
            }
            try reply(Prose.candlesLit)
        }

        // Blowing the candles out banks their remaining fuel.
        candles.before(.turnOff) {
            guard candles.isLit else { return }
            candles.isLit = false
            candlesDimIn = fuseRemaining("candlesDim") ?? 0
            candlesDieIn = fuseRemaining("candlesDie") ?? 0
            stopFuse("candlesDim")
            stopFuse("candlesDie")
            try reply(Prose.candlesDie)
        }

        // Reading the marked prayer, with the candles lit after the bell,
        // banishes the spirits and opens the way south. Read at any other time
        // it's just a book (the default action shows its text).
        book.before(.read) {
            guard player.location == entranceToHades, exorcismStage == 2 else { return }
            ghostsBanished = true
            exorcismStage = 3
            stopFuse("exorcismLapse")
            try reply(Prose.spiritsBanished)
        }

        // The draught in the cave snuffs lit candles as you enter.
        cave.onEnter {
            guard candles.isLit else { return }
            candles.isLit = false
            candlesDimIn = fuseRemaining("candlesDim") ?? 0
            candlesDieIn = fuseRemaining("candlesDie") ?? 0
            stopFuse("candlesDim")
            stopFuse("candlesDie")
            say(Prose.candlesSnuffedByDraft)
        }
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        // The exorcism window. If the ritual stalls at stage 1 or 2 for three
        // turns, the spirits recover and the sequence must start over.
        fuse("exorcismLapse", after: 3) {
            guard !ghostsBanished else { return }
            exorcismStage = 0
            say(Prose.exorcismLapses)
        }

        // The rung bell cools after twenty turns — a deliberate anti-softlock
        // so a fumbled ritual never traps the bell red hot for good
        // (FIDELITY.md).
        fuse("bellCools", after: 20) {
            bellHot = false
            say(Prose.bellCools)
        }

        // Candle burn-down: a dim warning, then out for good. Banked while
        // unlit, like the lantern.
        fuse("candlesDim", after: 20) {
            say(Prose.candlesDim)
        }
        fuse("candlesDie", after: 25) {
            candlesBurnedOut = true
            candles.isLit = false
            say(Prose.candlesDie)
        }
    }
}

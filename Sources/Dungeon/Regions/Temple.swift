import Gnusto
import GnustoScoring

/// The temple, the gate of Hades, and the glacier — the religious quarter of
/// the mainframe's map, and the one place where the trilogy's geography and the
/// mainframe's part company most completely.
///
/// From the Deep Ravine a rocky crawl reaches the rim of a dome; tie the attic
/// rope to its railing and you can drop into the Torch Room, where an ivory
/// torch burns that nothing puts out. Elsewhere — and it is *elsewhere*, not
/// below — the Grail Room's stairs climb to the Temple and its Altar, where a
/// bell, a black book and a pair of candles are the whole of what an exorcism
/// takes. Down past a cave the gate of Hades stands open behind a wall of
/// spirits. And north-west of the crawl the Egyptian Room holds a gold coffin
/// too wide for half the passages in this quarter, with a staircase above it
/// climbing to a wall of ice.
///
/// **This is not Zork I's temple.** The trilogy folded the whole quarter into
/// one vertical shaft — Torch Room down to Temple down to Altar down to Hades —
/// and re-lettered the compass to suit. Here:
///
/// - the **Temple hangs off the Grail Room**, not the Torch Room. `TEMP1`'s
///   only door is `MGRAI`'s staircase, which is why this milestone builds the
///   Grail Room even though the trilogy has no such place;
/// - the **Torch Room drops to the North-South Crawlway**, a milestone-1 room,
///   and has a door west besides;
/// - the **Temple is the west end** of the building and the **Altar the east**,
///   with the inscription on the south wall and the granite on the north; there
///   is no hole in the Altar's floor and no staircase down from the Temple;
/// - the **Egyptian Room's staircase climbs to a Glacier Room** that Zork I
///   does not have, and the coffin's way out of this quarter is over the ice
///   rather than through a prayer;
/// - there is **no crystal skull and no sceptre.** Both are the trilogy's
///   inventions. The Land of the Living Dead pays a room value of 30 instead,
///   and the coffin is empty.
///
/// What the host wires is what crosses a bundle: the crawl's west end, the
/// Grail Room's two passages, the Torch Room's drop, the Glacier Room's north
/// path, the gate's climb, the coffin's four gates on milestone-2 exits, the
/// prayer that lands you in the forest, the match that lights the candles, and
/// the flood that carries the torch to Stream View. See `FIDELITY.md`.
struct DungeonTemple: GameContent {
    // MARK: - Rooms

    let rockyCrawl = Location {
        name("Rocky Crawl")
        description(Prose.rockyCrawl)
        dark
    }

    /// The rim of the dome. ``alwaysDescribed`` because the rope over the
    /// railing is the only thing that tells you the drop is survivable, and a
    /// brief re-entry — after UNDO, or after walking back from the crawl —
    /// would print the room's name and withhold it.
    let domeRoom = Location {
        name("Dome Room")
        alwaysDescribed
        dark
    }

    /// Dark by nature; the torch on its pedestal is what lights it, and
    /// carrying the torch away puts the room back in the dark. Always
    /// described, for the rope that hangs five feet out of reach.
    let torchRoom = Location {
        name("Torch Room")
        alwaysDescribed
        dark
    }

    let grailRoom = Location {
        name("Grail Room")
        description(Prose.grailRoom)
        dark
    }

    /// Lit, as in the mainframe (`RLIGHTBIT`), and sacred besides.
    let temple = Location {
        name("Temple")
        description(Prose.temple)
    }

    /// Lit, as in the mainframe.
    let altar = Location {
        name("Altar")
        description(Prose.altar)
    }

    let egyptianRoom = Location {
        name("Egyptian Room")
        description(Prose.egyptianRoom)
        dark
    }

    /// Always described: whether the ice still stands is the whole state of
    /// this half of the map, and it only appears in the long description.
    let glacierRoom = Location {
        name("Glacier Room")
        alwaysDescribed
        dark
    }

    let rubyRoom = Location {
        name("Ruby Room")
        description(Prose.rubyRoom)
        dark
    }

    let engravingsCave = Location {
        name("Engravings Cave")
        description(Prose.engravingsCave)
        dark
    }

    /// Lit, as in the mainframe. Always described: the spirits are the reason
    /// the gate refuses, and a brief re-entry would show an open gate and no
    /// reason for it.
    let entranceToHades = Location {
        name("Entrance to Hades")
        alwaysDescribed
    }

    /// Lit, as in the mainframe, and worth thirty points for arriving —
    /// the mainframe's `RVAL`, awarded by the host.
    let landOfTheLivingDead = Location {
        name("Land of the Living Dead")
        description(Prose.landOfTheLivingDead)
    }

    // MARK: - State

    /// Whether the gold coffin is out of your hands, which is the mainframe's
    /// `COFFIN-CURE`: six narrow passages in three bundles are shut while it
    /// is not, and every one of them asks here.
    var coffinIsStowed: Bool { !coffin.isHeld }

    /// Whether the rope is made fast to the dome's railing. Read off the
    /// fitting rather than saved beside it — ``ropeOnTheRailing`` standing in
    /// the Dome Room *is* the knot holding — for `cageSprung`'s reason: two
    /// representations of one fact are two things a later edit can put out of
    /// step, and this one is read by an exit gate and three describers. The
    /// host's `tie` rule is what places it, because the coil it replaces is a
    /// ``DungeonHouse`` item.
    var ropeTiedToRailing: Bool { ropeOnTheRailing.isIn(domeRoom) }

    /// Whether the torch has been quenched in the melting glacier. One-way:
    /// nothing in the game relights it.
    @Global var torchBurnedOut = false

    /// Whether the Great Glacier has been thrown down. The mainframe's
    /// `GLACIER-FLAG`, and the only thing that opens the way to the Ruby Room.
    @Global var glacierMelted = false

    /// Whether somebody has held a flame against the ice and paid for it. The
    /// mainframe's `GLACIER-MELT`: the drowning is fatal, so this only ever
    /// shows to a player the game has already resurrected once.
    @Global var glacierScarred = false

    /// Whether the rung bell is still red hot — the mainframe swaps `BELL` for
    /// a separate `HBELL` object; one item and a flag says the same thing.
    @Global var bellHot = false

    /// The exorcism's progress at the gate: 0 nothing, 1 the bell rung, 2 the
    /// candles lit again after it, 3 the spirits gone. Stages 1 and 2 lapse —
    /// the source gives the first six turns and the second three.
    @Global var exorcismStage = 0

    /// Whether the spirits have been banished, which is what opens the gate.
    /// Derived: stage 3 *is* the banishment, and nothing else reaches it.
    var spiritsBanished: Bool { exorcismStage == 3 }

    /// Candle fuel banked while they are out, so blowing them out to save them
    /// works. The mainframe burns them in three stages — twenty turns, then
    /// ten, then five — and this is how far through that it is.
    @Global var candleStage = 0
    @Global var candleTicksLeft = 0

    /// Whether there is anything left of them. Derived: the last stage is the
    /// one that runs out.
    var candlesBurnedOut: Bool { candleStage >= Self.candleStages.count }

    /// How long a candle burns at each stage, and what it says on arriving
    /// there. The source's `CANDLE-TICKS` and `CANDLE-TELLS`.
    static let candleStages = [20, 10, 5]

    // MARK: - The Rocky Crawl

    let rockyCrawlRubble = Item {
        name("loose rock")
        adjectives("loose")
        synonyms("rocks", "rock", "ceiling", "floor", "passages", "passage", "corners", "corner")
        description(Prose.rockyCrawlRubble)
        scenery
    }

    // MARK: - The Dome Room

    let railing = Item {
        name("wooden railing")
        adjectives("wooden")
        synonyms("rail", "railing")
        scenery
    }

    let dome = Item {
        name("dome")
        adjectives("large")
        synonyms("ceiling", "drop")
        description(Prose.domeRoom)
        scenery
    }

    /// The rope while the knot is tied: not a coil anybody is carrying any
    /// more, but a fitting of the two rooms it hangs through. Offstage until
    /// ``ropeTiedToRailing``.
    ///
    /// **Two of them for one rope**, because a rope hung through a dome is in
    /// two rooms at once and an item is in one — the ``steelCage``/``cageBars``
    /// shape, a thing seen from two sides. Each takes the paragraph its own
    /// room prints as its examine line, exactly as that pair takes one
    /// constant between them. `ROPE-AWAY` (`act3.199:1287`) needs neither,
    /// because MDL can set `NDESCBIT` on the coil at runtime and a Gnusto game
    /// cannot; but the runtime flag would not have saved the second item, only
    /// the first. (#286)
    private static func hangingRope(_ text: String) -> Item {
        Item {
            name("rope")
            adjectives("large", "hemp", "stout")
            synonyms("rope", "hemp")
            description(text)
            scenery
        }
    }

    let ropeOnTheRailing = hangingRope(Prose.ropeOverTheRailing)

    // MARK: - The Torch Room

    let ropeAboveTheTorchRoom = hangingRope(Prose.torchRoomRope)

    /// The ivory torch: fourteen to find and six to case, and the game's only
    /// light that needs no tending — until the glacier takes it.
    let ivoryTorch = Item {
        name("ivory torch")
        adjectives("ivory")
        synonyms("torch")
        firstSight(Prose.ivoryTorchInPlace)
        lightSource
        startsLit
        trait(.openFlame, true)
        trait(.weight, 20)
        trait(.takeValue, 14)
        trait(.depositValue, 6)
    }

    let marblePedestal = Item {
        name("white marble pedestal")
        adjectives("white", "marble")
        synonyms("pedestal")
        description(Prose.marblePedestal)
        scenery
    }

    /// The dome and its railing seen from below, and the west doorway the
    /// mainframe's Torch Room has and Zork I's does not. One fixture answering
    /// the nouns the room prints.
    let torchRoomFittings = Item {
        name("doorway")
        synonyms("dome", "railing", "rail", "staircase", "stairs", "wall", "walls")
        description(Prose.torchRoomDoorway)
        scenery
    }

    // MARK: - The Grail Room

    /// The grail: two to find and five to case, the mainframe's own values for
    /// a treasure the trilogy never carried.
    let grail = Item {
        name("grail")
        adjectives("golden")
        synonyms("cup", "chalice")
        firstSight(Prose.grailFirstSight)
        description(Prose.grail)
        trait(.weight, 10)
        trait(.takeValue, 2)
        trait(.depositValue, 5)
    }

    let grailPedestal = Item {
        name("stone pedestal")
        adjectives("stone")
        synonyms("pedestal")
        description(Prose.grailPedestal)
        scenery
    }

    let grailStairs = Item {
        name("flight of stairs")
        synonyms("stairs", "staircase", "passages", "passage")
        description(Prose.grailStairs)
        scenery
        plural
    }

    // MARK: - The Temple

    let bell = Item {
        name("brass bell")
        adjectives("brass", "small")
        synonyms("handbell")
        trait(.weight, 10)
    }

    let prayerInscription = Item {
        name("ancient inscription")
        adjectives("ancient")
        synonyms("prayer", "inscription", "writing")
        description(Prose.prayerInscription)
        scenery
    }

    let marblePillars = Item {
        name("marble pillars")
        adjectives("huge", "marble")
        synonyms("pillars", "pillar", "entrance")
        description(Prose.marblePillars)
        scenery
        plural
    }

    let graniteWall = Item {
        name("granite wall")
        adjectives("solid", "granite", "north")
        synonyms("wall", "walls")
        description(Prose.graniteWall)
        scenery
    }

    // MARK: - The Altar

    let altarStone = Item {
        name("altar")
        synonyms("slab", "stone")
        description(Prose.altarStone)
        scenery
    }

    let blackBook = Item {
        name("black book")
        adjectives("black")
        synonyms("book", "prayerbook", "bible")
        description(Prose.blackBook)
        trait(.weight, 10)
    }

    let candles = Item {
        name("pair of candles")
        adjectives("white", "wax")
        synonyms("candles", "candle", "pair")
        description(Prose.candles)
        lightSource
        startsLit
        trait(.openFlame, true)
        trait(.weight, 10)
    }

    // MARK: - The Egyptian Room

    /// The gold coffin: **three** to find and **seven** to case, where the
    /// trilogy pays ten and fifteen. Empty, because the mainframe has no
    /// sceptre to put in it.
    let coffin = Item {
        name("gold coffin")
        adjectives("gold", "golden", "solid")
        synonyms("coffin", "casket")
        firstSight(Prose.coffin)
        description(Prose.coffinExamined)
        container
        openable
        trait(.weight, 55)
        trait(.takeValue, 3)
        trait(.depositValue, 7)
    }

    let egyptianStaircase = Item {
        name("ascending staircase")
        adjectives("ascending")
        synonyms("staircase", "stairs", "stair")
        description(Prose.egyptianStaircase)
        scenery
    }

    let egyptianDoors = Item {
        name("doors")
        synonyms("door", "doorway", "doorways", "tomb")
        description(Prose.egyptianDoors)
        scenery
        plural
    }

    // MARK: - The glacier

    let glacier = Item {
        name("glacier")
        adjectives("great", "cold", "icy")
        synonyms("ice", "mass", "wall")
        scenery
    }

    // MARK: - The Ruby Room

    let ruby = Item {
        name("ruby")
        adjectives("red")
        synonyms("gem", "stone")
        firstSight(Prose.ruby)
        description(Prose.rubyExamined)
        trait(.takeValue, 15)
        trait(.depositValue, 8)
    }

    let rubyRoomPassages = Item {
        name("narrow passages")
        adjectives("narrow", "small")
        synonyms("passages", "passage", "chamber")
        description(Prose.rubyRoom)
        scenery
        plural
    }

    // MARK: - The Engravings Cave

    let engravings = Item {
        name("wall with engravings")
        adjectives("old", "beautiful")
        synonyms("engravings", "engraving", "inscription", "wall", "walls")
        description(Prose.engravings)
        scenery
    }

    // MARK: - Hades

    let hadesGates = Item {
        name("gate")
        adjectives("large", "iron")
        synonyms("gates", "gateway")
        description(Prose.hadesGates)
        scenery
    }

    let spirits = Item {
        name("number of ghosts")
        adjectives("evil")
        synonyms("spirits", "spirit", "ghosts", "ghost", "fiends", "fiend", "wraiths", "wraith")
        // Described by a rule: the exorcism sends them through the walls.
        scenery
        plural
    }

    let pileOfCorpses = Item {
        name("pile of mangled bodies")
        adjectives("mangled")
        synonyms("corpses", "corpse", "bodies", "body", "pile", "desolation")
        description(Prose.pileOfCorpses)
        scenery
    }

    let pileOfBodies = Item {
        name("stack of remains")
        adjectives("previous")
        synonyms("remains", "bodies", "body", "adventurers", "adventurer", "souls", "corner")
        description(Prose.pileOfBodies)
        scenery
    }

    // MARK: - Map

    var map: WorldMap {
        // The Rocky Crawl. West is the Deep Ravine, a ``DungeonRoundRoom``
        // room — host-wired. Northwest is the coffin's first refusal.
        rockyCrawl.east(domeRoom)
        rockyCrawl.northwest(
            egyptianRoom, when: { coffinIsStowed }, otherwise: Prose.coffinTooWideForCrawl)

        // The Dome Room. The drop needs the rope; there is no climbing back.
        domeRoom.east(rockyCrawl)
        domeRoom.down(torchRoom, when: { ropeTiedToRailing }, otherwise: Prose.domeNoRope)

        // The Torch Room. Down is the North-South Crawlway, a ``DungeonCellar``
        // room — host-wired, and one-way, because that crawlway's own `up` is
        // already blocked. West is the Tiny Room, which a later milestone
        // builds; the room's description keeps the doorway regardless.
        torchRoom.up(blocked: Prose.torchNoRope)

        // The Grail Room. Both passages cross a bundle — west to the Round Room
        // and east to the Narrow Crawlway — so the host wires them.
        grailRoom.up(temple)

        // The Temple and the Altar. Two rooms, three exits between them, and
        // no staircase anywhere: the mainframe's temple is horizontal.
        temple.west(grailRoom)
        temple.east(altar)
        altar.west(temple)

        // The Egyptian Room. South is Volcano View, a later milestone. East is
        // the coffin's second refusal; up is the way the coffin actually
        // leaves this quarter.
        egyptianRoom.up(glacierRoom)
        egyptianRoom.east(
            rockyCrawl, when: { coffinIsStowed }, otherwise: Prose.coffinTooWideForCrawl)

        // The Glacier Room. North is Stream View, a ``DungeonDam`` room —
        // host-wired.
        glacierRoom.east(egyptianRoom)
        glacierRoom.west(rubyRoom, when: { glacierMelted }, otherwise: Prose.glacier)

        // The Ruby Room. West is the Lava Room and the volcano beyond it, a
        // later milestone.
        rubyRoom.south(glacierRoom)

        // The Engravings Cave. North is the Round Room — host-wired. Southeast
        // is the Riddle Room, a later milestone.

        // The gate of Hades. Up is a ``DungeonMirror`` cave — host-wired.
        for way in [Direction.east, .in] {
            entranceToHades.exit(
                way, to: landOfTheLivingDead, when: { spiritsBanished },
                otherwise: Prose.hadesGateBlocked)
        }

        // The Land of the Living Dead. East is the Tomb of the Unknown
        // Implementer, a later milestone.
        landOfTheLivingDead.west(entranceToHades)
        landOfTheLivingDead.out(entranceToHades)

        rockyCrawlRubble.starts(in: rockyCrawl)

        railing.starts(in: domeRoom)
        dome.starts(in: domeRoom)

        ivoryTorch.starts(in: torchRoom)
        marblePedestal.starts(in: torchRoom)
        torchRoomFittings.starts(in: torchRoom)

        grail.starts(in: grailRoom)
        grailPedestal.starts(in: grailRoom)
        grailStairs.starts(in: grailRoom)

        bell.starts(in: temple)
        prayerInscription.starts(in: temple)
        marblePillars.starts(in: temple)
        graniteWall.starts(in: temple)

        altarStone.starts(in: altar)
        blackBook.starts(in: altar)
        candles.starts(in: altar)

        coffin.starts(in: egyptianRoom)
        egyptianStaircase.starts(in: egyptianRoom)
        egyptianDoors.starts(in: egyptianRoom)

        glacier.starts(in: glacierRoom)

        ruby.starts(in: rubyRoom)
        rubyRoomPassages.starts(in: rubyRoom)

        engravings.starts(in: engravingsCave)

        hadesGates.starts(in: entranceToHades)
        spirits.starts(in: entranceToHades)
        pileOfCorpses.starts(in: entranceToHades)

        pileOfBodies.starts(in: landOfTheLivingDead)
    }

    // MARK: - Rules

    var rules: Rules {
        templeRules
        moreTempleRules
    }

    @RuleBuilder private var templeRules: Rules {
        // The four rooms whose description carries state. Each is
        // ``alwaysDescribed``, so the state survives a rewind and a re-entry.
        domeRoom.describe {
            ropeTiedToRailing
                ? "\(Prose.domeRoom)\n\n\(Prose.ropeOverTheRailing)" : Prose.domeRoom
        }
        torchRoom.describe {
            ropeTiedToRailing
                ? "\(Prose.torchRoom)\n\n\(Prose.torchRoomRope)" : Prose.torchRoom
        }
        glacierRoom.describe {
            if glacierMelted { return "\(Prose.glacierRoomThawed)\n\n\(Prose.glacierGone)" }
            if glacierScarred { return "\(Prose.glacierRoom)\n\n\(Prose.glacierPartlyMelted)" }
            return Prose.glacierRoom
        }
        // The gate's paragraph reads the ceremony, not just its end. The bell
        // stops the jeering at stage 1 and the candles have them cowering at
        // stage 2, and the room went on saying "who jeer at your attempts to
        // pass" through both of them.
        entranceToHades.describe {
            let atTheGate: String? =
                if spiritsBanished {
                    nil
                } else {
                    switch exorcismStage {
                    case 1: Prose.spiritsBarTheGateSilent
                    case 2: Prose.spiritsBarTheGateCowering
                    default: Prose.spiritsBarTheGate
                    }
                }
            return atTheGate.map { "\(Prose.entranceToHades)\n\n\($0)" } ?? Prose.entranceToHades
        }

        // And the spirits themselves, who flee through the walls at stage 3 and
        // went on being examined as a wall of them enjoying this.
        spirits.describe { spiritsBanished ? Prose.spiritsFled : Prose.spirits }

        railing.describe { ropeTiedToRailing ? Prose.railingTied : Prose.railingBare }

        // The far end of the rope, five feet over the head of anybody standing
        // in the Torch Room. A `reach` rule rather than a list of verbs: it
        // settles at stage 0, ahead of every complaint a verb would make for
        // itself, and it answers `touch`, `tie` and `attack` as well as the
        // four the round happened to type. EXAMINE is `reach: .notNeeded`, so
        // the noun still answers — which is the whole reason the fitting is
        // here. The refusal is the one `torchRoom.up(blocked:)` already uses.
        ropeAboveTheTorchRoom.reach(otherwise: Prose.torchNoRope) { false }
        glacier.describe { glacierMelted ? Prose.glacierRemains : Prose.glacierExamined }
        ivoryTorch.describe { torchBurnedOut ? Prose.burnedOutTorch : Prose.ivoryTorch }

        // The torch never goes out by hand, and once the ice has had it there
        // is nothing to put out.
        ivoryTorch.before(.turnOff) {
            try refuse(torchBurnedOut ? Prose.torchAlreadyOut : Prose.torchWontExtinguish)
        }
    }

    /// The second half of the same list. Split when hazard #174 was thought to
    /// be a limit on body size; kept because it reads better in two.
    @RuleBuilder private var moreTempleRules: Rules {
        // The bell, red hot from the gate, is a *reach* problem rather than a
        // per-verb one: the mainframe refuses take, ring and everything else
        // with the same sentence, so one rule says it once and `take`, `open`
        // and `push` all inherit it. `ring` is this game's own verb, so custom
        // intents are not gated by the engine and the ring rule asks itself.
        bell.reach(otherwise: Prose.bellTooHotToReach) { !bellHot }
        bell.describe { bellHot ? Prose.bellRedHot : Prose.bell }

        // Ringing the bell. Away from the gate, or once the spirits are gone,
        // it is only a bell. At the gate it opens the ceremony: the bell goes
        // red hot and drops, any candles in your hands drop with it and go
        // out, and the source's six-turn window starts.
        bell.before(.ring) {
            try require(bell.isReachable, else: Prose.bellTooHotToReach)
            guard player.location == entranceToHades, !spiritsBanished else {
                try reply(Prose.bellRingsHollow)
            }
            bellHot = true
            exorcismStage = 1
            bell.move(to: entranceToHades)
            startFuse("exorcismLapse", after: 6)
            startFuse("bellCools", after: 20)
            guard candles.isHeld else { try reply(Prose.bellRingRedHot) }
            snuffCandles()
            candles.move(to: entranceToHades)
            try reply("\(Prose.bellRingRedHot)\n\n\(Prose.candlesDropInConfusion)")
        }

        // The candles start lit, as the source declares them, and start
        // burning down the moment somebody picks them up — the source's own
        // `TAKE` branch. Without it they would be a second everlasting lamp.
        candles.after(.take) {
            guard candles.isLit, !candlesBurnedOut, fuseRemaining("candlesBurn") == nil
            else { return }
            startCandleBurn()
        }

        // Blowing the candles out banks whatever is left of them.
        candles.before(.turnOff) {
            guard candles.isLit else { try reply(Prose.candlesNotLit) }
            snuffCandles()
            try reply(Prose.candlesOut)
        }

        // Reading the marked prayer with the candles alight after the bell
        // banishes the spirits. At any other time the book answers with the
        // page rather than with the cover: falling through to the default
        // action printed `Prose.blackBook`, which is a description of a book
        // advertised as open at a marked page, so `read book` was the one
        // command that asked what the page said and got what the book looked
        // like. (#286)
        blackBook.before(.read) {
            guard player.location == entranceToHades, exorcismStage == 2 else {
                try reply(Prose.blackBookPage)
            }
            exorcismStage = 3
            stopFuse("exorcismLapse")
            try reply(Prose.spiritsBanished)
        }

        // The second stage of the ceremony is not a verb. The source watches
        // for lit candles in your hands while the bell's window is open,
        // whatever you did to get them there.
        entranceToHades.afterEachTurn {
            guard exorcismStage == 1, candles.isHeld, candles.isLit else { return }
            exorcismStage = 2
            startFuse("exorcismLapse", after: 3)
            say(Prose.candlesLitForRitual)
        }

        // `exorcise` is the mainframe's own hint verb: it tells you whether you
        // are carrying the ceremony's three pieces, and never performs it.
        world.before(.exorcise) {
            guard player.location == entranceToHades, !spiritsBanished else { return }
            let equipped = [bell, blackBook, candles].allSatisfy(\.isHeld)
            try reply(equipped ? Prose.exorcismNeedsCeremony : Prose.exorcismUnequipped)
        }

        // The spirits shrug off everything.
        spirits.before(.attack) {
            try reply(
                command.indirectObject == nil
                    ? Prose.spiritsUnaffected : Prose.spiritsUnaffectedByObject)
        }
        spirits.before(.take) { try reply(Prose.spiritsUnaffected) }
        pileOfCorpses.before(.take) { try reply(Prose.corpsesLeaveThemBe) }
        pileOfBodies.before(.take) { try reply(Prose.corpsesLeaveThemBe) }

        // Melting the glacier by holding a flame to it drowns you — the
        // source's own answer, and the reason the torch has to be thrown.
        glacier.before(.melt) {
            guard let tool = command.indirectObject else {
                try reply(Prose.glacierWontMeltWithThat)
            }
            try require(
                tool[default: .openFlame] && tool.isLit,
                else: Prose.glacierWontMeltWithThat)
            glacierScarred = true
            try die(Prose.glacierDrownsYou)
        }

        // Anything but the torch bounces off it.
        glacier.before(.throwAt) {
            guard command.directObject != ivoryTorch else { return }
            try reply(Prose.glacierUnmoved)
        }
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        // The ceremony's window. Six turns after the bell, three after the
        // candles; either lapsing puts the spirits back.
        //
        // The window closes wherever the player has walked to; the wraiths only
        // jeer at somebody standing in front of them, so the state change is
        // unconditional and the telling is not.
        fuse("exorcismLapse", after: 6) {
            guard !spiritsBanished else { return }
            exorcismStage = 0
            say(Prose.exorcismLapses, from: entranceToHades)
        }

        // The rung bell cools, so a fumbled ceremony is never a dead end.
        // "Appears to have cooled" is an observation, and the bell is lying
        // where it fell at the gate.
        fuse("bellCools", after: 20) {
            bellHot = false
            say(Prose.bellCools, from: bell)
        }

        // The candles burn down in the source's three stages — twenty turns,
        // then ten, then five — and are gone.
        fuse("candlesBurn", after: 20) {
            burnCandleStage()
        }
    }

    // MARK: - The candles

    /// Put the candles out and bank what is left of them, so a player who
    /// saves them for the gate still has them when they get there.
    func snuffCandles() {
        guard candles.isLit else { return }
        candles.isLit = false
        candleTicksLeft = fuseRemaining("candlesBurn") ?? 0
        stopFuse("candlesBurn")
    }

    /// Light the candles and set them burning again from wherever they were
    /// banked. Called by the host, because the match is lit from a
    /// ``DungeonDam`` matchbook.
    func lightCandles() {
        candles.isLit = true
        startCandleBurn()
    }

    /// Set the wick burning again — from whatever was banked when they were
    /// last blown out, or from the top of the stage they are in.
    private func startCandleBurn() {
        startFuse(
            "candlesBurn",
            after: candleTicksLeft > 0 ? candleTicksLeft : Self.candleStages[candleStage])
        candleTicksLeft = 0
    }

    /// One stage of the burn-down: say how short they are now and set the next
    /// stage running, or put them out for good.
    func burnCandleStage() {
        candleStage += 1
        guard candleStage < Self.candleStages.count else {
            // Said while they are still alight. Candles that have already gone
            // out light nothing, themselves included, so asking afterwards
            // would leave a player watching them burn down in an unlit room
            // with no account of why it went dark.
            say(Prose.candlesGone, from: candles)
            candles.isLit = false
            return
        }
        startFuse("candlesBurn", after: Self.candleStages[candleStage])
        say(
            candleStage == Self.candleStages.count - 1 ? Prose.candlesVeryShort : Prose.candlesShorter,
            from: candles)
    }
}

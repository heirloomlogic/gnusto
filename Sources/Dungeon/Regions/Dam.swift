import Gnusto
import GnustoScoring

extension TraitKey<Bool> {
    /// Whether a room has standing water to fill a bottle from. The mainframe
    /// marks these rooms with the `RGWATER` global; this milestone brings the
    /// first five of them into the game, which is why the bottle in the Kitchen
    /// has had nothing to fill from until now.
    public static let waterSource = Self("waterSource", default: false)
}

/// Flood Control Dam #3, the reservoir it holds back, and the stream that
/// drains it. The dam's Maintenance Room carries four buttons labelled in a
/// character set nobody has read in centuries; the yellow one charges the
/// control panel so the great bolt will turn under a wrench, and turning it
/// works the sluice gates. Open them and the reservoir empties, laying bare a
/// trunk of jewels; close them and it fills again. The blue button springs a
/// leak that floods the Maintenance Room and seals it for good — unless you
/// plug it with the gunk from the tube.
///
/// **This is not Zork I's dam.** The trilogy kept the puzzle and re-cut the
/// map around it:
///
/// - the Dam's fourth path runs **east**, into the Damp Cave, where Zork I runs
///   it west onto the reservoir's south shore. **There is no exit from the Dam
///   to Reservoir South at all**; the shore is reached from Deep Canyon or from
///   the Deep Ravine;
/// - **Reservoir South has six exits** — west to Stream View, up to Deep
///   Canyon, south to the Deep Ravine, and three onto the water — where Zork I
///   gives it four;
/// - **Stream View's path runs north and east**, north being the Glacier Room,
///   rather than following the stream west to east;
/// - the **gates work instantly.** `BOLT-FUNCTION` empties or fills the
///   reservoir in the same breath that turns the bolt; Zork I's eight-turn
///   drain is the trilogy's addition, and this game does not have it;
/// - the **leak can be plugged.** Zork I dropped the putty; here it is the only
///   way to keep the Maintenance Room.
///
/// The whole mechanism is self-contained, so all of it lives here. What the
/// host wires is only geography: the three crossings into ``DungeonRoundRoom``,
/// and the trunk's place on the trophy-case roster. See `FIDELITY.md`.
struct DungeonDam: GameContent {
    // MARK: - Rooms

    /// Lit, as in the mainframe — the one lit room below ground in this
    /// milestone, and the reason a lightless dash to the dam is survivable.
    let damRoom = Location {
        name("Dam")
        trait(.waterSource, true)
    }

    let damLobby = Location {
        name("Dam Lobby")
        description(Prose.damLobby)
    }

    /// Dark until the red button turns the room's own lights on.
    ///
    /// ``alwaysDescribed`` because the water is part of the paragraph and a
    /// re-entry would print the room name over it — and this is a room the
    /// player walks in and out of while the level climbs.
    let maintenanceRoom = Location {
        name("Maintenance Room")
        dark
        alwaysDescribed
    }

    /// Lit, as in the mainframe. The river runs past it, and the boat that
    /// launches from here arrives with the river milestone.
    let damBase = Location {
        name("Dam Base")
        description(Prose.damBase)
        trait(.waterSource, true)
    }

    let reservoirSouth = Location {
        name("Reservoir South")
        dark
        trait(.waterSource, true)
    }

    /// The reservoir itself: water while the gates are shut, a bed of mud once
    /// they are open. You can only stand on it drained, and only get back to
    /// the bolt by walking off it first.
    let reservoir = Location {
        name("Reservoir")
        dark
        trait(.waterSource, true)
    }

    let reservoirNorth = Location {
        name("Reservoir North")
        dark
        trait(.waterSource, true)
    }

    let streamView = Location {
        name("Stream View")
        description(Prose.streamView)
        dark
        trait(.waterSource, true)
    }

    let stream = Location {
        name("Stream")
        description(Prose.stream)
        dark
        trait(.waterSource, true)
    }

    // MARK: - State

    /// Whether the sluice gates stand open. The mainframe's `LOW-TIDE`: it
    /// drives the reservoir's crossable bed, the trunk's reveal, and every one
    /// of the four descriptions that report the water.
    @Global var gatesOpen = false

    /// Whether the yellow button has charged the control panel. The bolt turns
    /// only while this is true; the brown button clears it.
    @Global var bubbleGlowing = false

    /// Whether the red button has switched the Maintenance Room's lights on.
    @Global var maintenanceRoomLit = false

    /// How far the water has climbed, counted in rungs of
    /// ``Prose/floodLadder``. Zero until the blue button; the daemon raises it
    /// and prints the rung it lands on, so the first thing the player hears is
    /// the water at their ankles. It never comes back down, which is what jams
    /// the button afterwards — plugging the leak keeps the room, it does not
    /// un-break the pipe.
    @Global var floodLevel = 0

    /// The mainframe's five matches. `MATCH` is one object with a count on
    /// it, which is why the book itself lights rather than a separate flame.
    @Global var matchesLeft = 5

    /// Whether the leak is still running. The daemon *is* the leak, so this
    /// asks it rather than keeping a second flag beside it — as `Zork1`'s dam
    /// does for the same button.
    var leakRunning: Bool { isDaemonActive("damLeak") }

    /// Whether the water won: the room is full and cannot be entered again.
    /// Derived, because it is exactly the state the daemon stops in.
    var maintenanceRoomFlooded: Bool { floodLevel > Prose.floodLadder.count }

    /// The rung of ``Prose/floodLadder`` the water is standing at, or `nil`
    /// while the room is dry. Clamped at the top rung rather than running off
    /// the end: past the last one the room is full, and nobody is left in it
    /// to read a description. (#329)
    var floodRung: String? {
        guard floodLevel > 0 else { return nil }
        return Prose.floodLadder[min(floodLevel, Prose.floodLadder.count) - 1]
    }

    /// Whether a reader standing in the Maintenance Room is under the water —
    /// the last two rungs of the ladder, which are the two the room can be
    /// read from before it kills whoever is in it.
    ///
    /// Published here rather than derived by the caller, because the ladder is
    /// this bundle's and a second reading of its length is a second place for
    /// an off-by-one to live. ``Dungeon/torchRules`` is the caller. (#329)
    var waterOverYourHead: Bool { floodLevel >= Prose.floodLadder.count - 1 }

    /// Whether whoever is reading this is *in* that water: the rung and the
    /// room, which is the whole question a sentence about a flame has to ask
    /// before it prints.
    ///
    /// The pair used to be spelled out privately in ``Dungeon/torchRules`` and
    /// nowhere else, so the ivory torch knew it was under water and the
    /// matchbook two lines away in the same transcript did not — a match was
    /// struck and reported burning with the flood over the player's head.
    /// #329 published the rung for exactly this and the second flame never
    /// read it. One reader now, and both flames ask it. (#350)
    var readerIsUnderWater: Bool { player.location == maintenanceRoom && waterOverYourHead }

    // MARK: - Dam controls

    let dam = Item {
        name("dam")
        // `concrete`: both paragraphs about this dam count its concrete by the
        // foot, and the word answered nowhere. It is what the dam is made of
        // rather than a second thing standing beside it, so it is a synonym and
        // not an item. (#332)
        synonyms("gate", "gates", "fcd", "sluice", "concrete")
        description(Prose.damItem)
        scenery
    }

    let bolt = Item {
        name("metal bolt")
        adjectives("metal", "large")
        synonyms("nut")
        description(Prose.bolt)
        scenery
    }

    let bubble = Item {
        name("green bubble")
        adjectives("green", "small", "plastic")
        description(Prose.bubble)
        scenery
    }

    let controlPanel = Item {
        name("control panel")
        adjectives("control")
        synonyms("panel")
        description(Prose.controlPanel)
        scenery
    }

    // MARK: - Dam Lobby

    let guidebook = Item {
        name("tour guidebook")
        adjectives("tour", "guide")
        synonyms("book", "guidebooks")
        firstSight(Prose.guidebookInPlace)
        description(Prose.guidebook)
        trait(.burnable, true)
    }

    /// The matchbook, and — as in the mainframe, where `MATCH` is one object
    /// with a count on it — the match itself: lighting it lights the book in
    /// your hand for two turns. Milestone 2 left it a readable object because
    /// nothing yet needed a flame; the temple's candles do.
    let matchbook = Item {
        name("matchbook")
        adjectives("match")
        synonyms("matches", "match")
        firstSight(Prose.matchbookInPlace)
        description(Prose.matchbook)
        lightSource
        trait(.openFlame, true)
        trait(.weight, 2)
        trait(.burnable, true)
    }

    let receptionDesk = Item {
        name("reception desk")
        adjectives("reception")
        synonyms("desk")
        description(Prose.receptionDesk)
        scenery
    }

    // MARK: - Maintenance Room

    let blueButton = Item {
        name("blue button")
        adjectives("blue")
        synonyms("switch")
        description(Prose.plainButton("blue"))
        scenery
    }

    let redButton = Item {
        name("red button")
        adjectives("red")
        synonyms("switch")
        description(Prose.plainButton("red"))
        scenery
    }

    let brownButton = Item {
        name("brown button")
        adjectives("brown")
        synonyms("switch")
        description(Prose.plainButton("brown"))
        scenery
    }

    let yellowButton = Item {
        name("yellow button")
        adjectives("yellow")
        synonyms("switch")
        description(Prose.plainButton("yellow"))
        scenery
    }

    /// The four of them as a group, so `examine buttons` answers instead of
    /// asking which colour you meant.
    let buttonPanel = Item {
        name("group of buttons")
        synonyms("buttons", "wall", "walls")
        description(Prose.buttonPanel)
        scenery
        plural
    }

    /// The mainframe's buttons are labelled in EBCDIC, which is the joke; the
    /// answer is Zork I's, which made the same joke about Greek.
    let buttonLabels = Item {
        name("labels")
        synonyms("label", "script", "lettering", "writing")
        description(Prose.buttonLabels)
        scenery
        plural
    }

    /// The mainframe's own joke: the chests the room is named for are empty,
    /// and bolted down besides.
    let toolChests = Item {
        name("group of tool chests")
        adjectives("tool")
        synonyms("chests", "chest")
        description(Prose.toolChests)
        scenery
        plural
    }

    /// The equipment the room is missing and the wreckage the wrench lies in.
    /// One item: what is *gone* is one sentence, and it is not the sentence
    /// ``toolChests`` tells about what is still here. (#233)
    let maintenanceWreckage = Item {
        name("wreckage")
        synonyms("wreckage", "equipment", "junk", "debris")
        description(Prose.maintenanceWreckage)
        scenery
    }

    /// The room's own two ways out. No `door`/`doors` — ``privateDoorways``
    /// owns those in the Lobby and there is no reason to widen the word here.
    let maintenanceDoorways = Item {
        name("doorways")
        adjectives("open")
        synonyms("doorway", "doorways")
        description(Prose.maintenanceDoorways)
        scenery
        plural
    }

    let leak = Item {
        name("leak")
        synonyms("drip", "pipe", "hole")
        scenery
        hidden
    }

    /// The water on the floor, which is a different thing from the hole it
    /// comes out of. Revealed by the same button, and described off
    /// ``floodLevel``, because how deep it is *is* the examine. (#329)
    let floodWater = Item {
        name("water")
        adjectives("rising", "cold")
        synonyms("water", "flood", "stream")
        scenery
        hidden
    }

    let wrench = Item {
        name("wrench")
        synonyms("tool")
        firstSight(Prose.wrenchInPlace)
        description(Prose.wrench)
        trait(.weight, 10)
    }

    let screwdriver = Item {
        name("screwdriver")
        adjectives("screw")
        synonyms("driver", "tool")
        firstSight(Prose.screwdriverInPlace)
        description(Prose.screwdriver)
        // One of the source's four `PALOBJS` — the things long enough to go
        // into the oak door's keyhole. See ``DungeonPalantir``.
        trait(.keyholeTool, true)
    }

    /// The Frobozz Magic Gunk Company's finest, and the only thing in the game
    /// that will stop the leak.
    let tube = Item {
        name("tube")
        adjectives("toothpaste")
        firstSight(Prose.tubeInPlace)
        description(Prose.tube)
        container
        openable
        trait(.weight, 10)
    }

    let putty = Item {
        name("viscous material")
        adjectives("viscous")
        synonyms("gunk", "glue", "putty", "material")
        description(Prose.putty)
        trait(.weight, 6)
    }

    // MARK: - Reservoir

    let handPump = Item {
        name("hand-held air pump")
        adjectives("hand", "held", "air", "small")
        synonyms("pump")
        firstSight(Prose.handPumpInPlace)
        description(Prose.handPump)
    }

    /// The trunk of jewels: fifteen to find, **eight** to case, where Zork I
    /// pays five. It lies under the water until the gates drain it.
    let trunk = Item {
        name("trunk of jewels")
        adjectives("old")
        synonyms("trunk", "chest", "jewels", "treasure")
        firstSight(Prose.trunkFirstSight)
        description(Prose.trunk)
        trait(.weight, 35)
        trait(.takeValue, 15)
        trait(.depositValue, 8)
        hidden
    }

    /// The coil of wire the brick in the Attic will one day want. It is inert
    /// here, exactly as the brick is — the explosion is a later milestone's.
    let wireCoil = Item {
        name("wire coil")
        adjectives("shiny", "thin", "coil")
        synonyms("wire", "fuse")
        firstSight(Prose.wireCoilInPlace)
        description(Prose.wireCoil)
        trait(.weight, 1)
        trait(.burnable, true)
    }

    // MARK: - Water scenery

    /// One per room, because an item lives in exactly one place and each of
    /// these five rooms prints the water in its own description. The tax M1
    /// records under "every printed noun answers".
    let reservoirWater = Item {
        name("reservoir")
        adjectives("large")
        synonyms("water", "lake", "mud", "bed", "shore", "shores", "dam")
        // Described by a rule: the gates decide whether there is any water in
        // it, and the room the player is standing in is the reservoir bed.
        scenery
    }

    let reservoirFromSouth = Item {
        name("reservoir")
        adjectives("large")
        synonyms("water", "lake", "stream", "mud")
        description(Prose.reservoirFromShore)
        scenery
    }

    /// The path and the cliff it climbs — one fitting, because the room's own
    /// sentence treats them as one feature and the path is the `up` exit to
    /// Deep Canyon. `cliff` used to sit on ``reservoirFromSouth``, so the
    /// wall at the player's back answered with a sentence about the water
    /// behind them. (#329)
    let reservoirSouthPath = Item {
        name("steep path")
        adjectives("steep")
        synonyms("path", "cliff", "edge", "ledge")
        description(Prose.reservoirSouthPath)
        scenery
    }

    let reservoirFromNorth = Item {
        name("reservoir")
        adjectives("large")
        synonyms("water", "lake", "stream", "mud", "tunnel")
        description(Prose.reservoirFromShore)
        scenery
    }

    /// No `path`: Stream View stands the player *on a path beside* the stream,
    /// so that noun is the ground and belongs to ``streamViewBank``. (#233)
    let streamWater = Item {
        name("stream")
        adjectives("gently", "flowing")
        synonyms("water", "cleft", "brook")
        description(Prose.streamWater)
        scenery
    }

    /// Which is also where the wire is lying — "A coil of thin shiny wire lies
    /// on the bank." — and the word went unanswered.
    let streamViewBank = Item {
        name("bank")
        adjectives("wet", "stone")
        synonyms("bank", "banks", "path", "shore")
        description(Prose.streamViewBank)
        scenery
    }

    let streamChannel = Item {
        name("beach")
        adjectives("narrow")
        synonyms("shore", "stream", "water", "walls", "wall")
        description(Prose.streamChannel)
        scenery
    }

    /// Described by a rule: the bolt this room's own control panel carries is
    /// what decides whether there is any water out there to look at.
    let damView = Item {
        name("reservoir")
        adjectives("wide")
        synonyms("water", "lake", "path", "paths")
        scenery
    }

    let damFromBelow = Item {
        name("dam")
        // `concrete`: both paragraphs about this dam count its concrete by the
        // foot, and the word answered nowhere. It is what the dam is made of
        // rather than a second thing standing beside it, so it is a synonym and
        // not an item. (#332)
        synonyms("gate", "gates", "fcd", "sluice", "concrete")
        description(Prose.damItem)
        scenery
    }

    let privateDoorways = Item {
        name("doorways")
        adjectives("private", "open")
        synonyms("doorway", "door", "doors", "path")
        description(Prose.privateDoorways)
        scenery
        plural
    }

    let river = Item {
        name("river")
        adjectives("frigid")
        synonyms("water")
        description(Prose.frigidRiver)
        scenery
    }

    let whiteCliffs = Item {
        name("white cliffs")
        adjectives("white")
        synonyms("cliff", "cliffs", "wall", "walls")
        description(Prose.whiteCliffs)
        scenery
        plural
    }

    // MARK: - Map

    var map: WorldMap {
        // The Dam. South is Deep Canyon and east is the Damp Cave, both
        // ``DungeonRoundRoom`` rooms — host-wired. There is deliberately no
        // path west to Reservoir South: the mainframe does not have one.
        damRoom.down(damBase)
        damRoom.north(damLobby)

        // Dam Lobby. Both doors marked "Private" reach the same room, and both
        // are shut once the water has taken it.
        damLobby.south(damRoom)
        for door in [Direction.north, .east] {
            damLobby.exit(
                door, to: maintenanceRoom, when: { !maintenanceRoomFlooded },
                otherwise: Prose.maintenanceRoomFull)
        }

        maintenanceRoom.south(damLobby)
        maintenanceRoom.west(damLobby)

        // Dam Base. Launching onto the Frigid River waits for its milestone.
        damBase.north(damRoom)
        damBase.up(damRoom)

        // Reservoir South. South is the Deep Ravine and up is Deep Canyon, both
        // ``DungeonRoundRoom`` rooms — host-wired. North onto the bed is the
        // mainframe's `LOW-TIDE` gate; its refusal is the source's own.
        reservoirSouth.west(streamView)
        reservoirSouth.north(reservoir, when: { gatesOpen }, otherwise: Prose.notEquippedToSwim)

        // The reservoir bed.
        reservoir.north(reservoirNorth)
        reservoir.south(reservoirSouth)
        reservoir.up(stream)
        reservoir.down(blocked: Prose.damBlocksWay)

        // Reservoir North. North is the Atlantis Room, a later milestone.
        reservoirNorth.south(reservoir, when: { gatesOpen }, otherwise: Prose.notEquippedToSwim)

        // Stream View. North is the Glacier Room, a later milestone.
        streamView.east(reservoirSouth)

        // The stream. Landing on the beach is the boat's disembark and waits
        // for the river milestone; on foot the shore is reached from Reservoir
        // South's west.
        stream.down(reservoir)
        stream.up(blocked: Prose.streamTooNarrow)

        dam.starts(in: damRoom)
        bolt.starts(in: damRoom)
        bubble.starts(in: damRoom)
        controlPanel.starts(in: damRoom)

        guidebook.starts(in: damLobby)
        matchbook.starts(in: damLobby)
        receptionDesk.starts(in: damLobby)

        blueButton.starts(in: maintenanceRoom)
        redButton.starts(in: maintenanceRoom)
        brownButton.starts(in: maintenanceRoom)
        yellowButton.starts(in: maintenanceRoom)
        buttonPanel.starts(in: maintenanceRoom)
        buttonLabels.starts(in: maintenanceRoom)
        toolChests.starts(in: maintenanceRoom)
        maintenanceWreckage.starts(in: maintenanceRoom)
        maintenanceDoorways.starts(in: maintenanceRoom)
        leak.starts(in: maintenanceRoom)
        floodWater.starts(in: maintenanceRoom)
        wrench.starts(in: maintenanceRoom)
        screwdriver.starts(in: maintenanceRoom)
        tube.starts(in: maintenanceRoom)
        putty.starts(inside: tube)

        handPump.starts(in: reservoirNorth)
        trunk.starts(in: reservoir)
        wireCoil.starts(in: streamView)

        reservoirWater.starts(in: reservoir)
        reservoirFromSouth.starts(in: reservoirSouth)
        reservoirSouthPath.starts(in: reservoirSouth)
        reservoirFromNorth.starts(in: reservoirNorth)
        streamWater.starts(in: streamView)
        streamViewBank.starts(in: streamView)
        streamChannel.starts(in: stream)
        damView.starts(in: damRoom)
        damFromBelow.starts(in: damBase)
        privateDoorways.starts(in: damLobby)
        river.starts(in: damBase)
        whiteCliffs.starts(in: damBase)
    }

    // MARK: - Rules

    var rules: Rules {
        damRules
        moreDamRules
    }

    @RuleBuilder private var damRules: Rules {
        // The water in the seven rooms this region flags ``TraitKey/waterSource``,
        // drunk from where it lies. `drink water` used to fall through to
        // ``DungeonSystems``' stage-4 default and answer "There is nothing here
        // to drink." standing on top of the dam — while `fill bottle` succeeded
        // in the same frame, because `bottle.before(.fill)` already reads the
        // trait. The bottle's own line, because it is the same water; nothing
        // is emptied, because a reservoir is not a bottle. (#233)
        for pool in [
            damView, damFromBelow, reservoirWater, reservoirFromSouth,
            reservoirFromNorth, streamWater, streamChannel,
        ] {
            pool.before(.drink) { try reply(Prose.drinkWater) }
        }

        // The four rooms whose description is the state of the water.
        damRoom.describe {
            var paragraphs = [
                Prose.dam,
                gatesOpen ? Prose.damGatesOpen : Prose.damGatesShut,
                Prose.damControlPanel,
            ]
            if bubbleGlowing { paragraphs.append(Prose.damBubbleGlowing) }
            return paragraphs.joined(separator: "\n\n")
        }
        reservoirSouth.describe {
            gatesOpen ? Prose.reservoirSouthDrained : Prose.reservoirSouthFull
        }
        reservoir.describe {
            gatesOpen ? Prose.reservoirDrained : Prose.reservoirFull
        }
        // The water the reservoir bed's own paragraph is a claim about. Its two
        // neighbours already had the state-aware line; the item under them did
        // not, so `x water` counted a billion and a half cubic feet of it while
        // the player walked across the mud.
        reservoirWater.describe {
            gatesOpen ? Prose.reservoirWaterDrained : Prose.reservoirWater
        }
        // `search mud` is a fair question in a room whose own listing line says
        // the trunk is *half buried in the mud*, and it was answered by the
        // stock `.lookIn` refusal — which renders the item's name, and this
        // item's name is "reservoir", which is also the room's. So a question
        // about the mud came back as a claim about the whole place the player
        // was standing in. The mud answers for itself now, the way the trunk
        // already does one rule below. (#350)
        reservoirWater.before(.lookIn) {
            try reply(
                trunk.isIn(reservoir) ? Prose.mudHidesTheTrunk : Prose.mudSearched)
        }
        reservoirNorth.describe {
            gatesOpen ? Prose.reservoirNorthDrained : Prose.reservoirNorthFull
        }
        // The fifth. `x reservoir` from the top of the dam is the one reading
        // of the water taken from the room that holds the bolt, and it was the
        // one that never moved. (#329)
        damView.describe {
            gatesOpen ? Prose.damReservoirViewDrained : Prose.damReservoirView
        }
        leak.describe { leakRunning ? Prose.leak : Prose.leakStopped }

        // The Maintenance Room and the water standing in it. The daemon calls
        // each rung as the water reaches it and then stops; after it stops,
        // the room's paragraph and this item are the only channels left, and
        // both used to describe a dry room. (#329)
        maintenanceRoom.describe {
            guard let rung = floodRung else { return Prose.maintenanceRoom }
            let water = Prose.maintenanceRoomWater(rung, stillRunning: leakRunning)
            return "\(Prose.maintenanceRoom)\n\n\(water)"
        }
        floodWater.describe {
            Prose.floodWater(floodRung, stillRunning: leakRunning)
        }

        // Bare `turn bolt`. The bolt is the one fixture in the game that needs
        // a tool named, so pointing at one beats "The bolt doesn't turn."
        bolt.before(.turn) {
            try reply(Prose.boltBareHanded)
        }

        // The bolt with the wrench: the sluice gates. Only with the wrench, and
        // only while the yellow button has the panel charged.
        //
        // The gates move the water **at once**, which is the mainframe's own
        // `BOLT-FUNCTION` re-bitting the reservoir in the same breath as the
        // message. Zork I's eight-turn drain and refill are the trilogy's, and
        // so is the drowning they make possible: there is no drowning branch
        // here and none is reachable, because the bolt is on top of the dam and
        // the only way onto the reservoir bed is a walk from the shore, so
        // nobody can be standing on the bed when the gates close.
        // See `FIDELITY.md`.
        bolt.before(.turnWith) {
            try require(command.indirectObject == wrench, else: Prose.boltNeedsWrench)
            try require(bubbleGlowing, else: Prose.boltWontTurn)
            gatesOpen.toggle()
            if gatesOpen { trunk.reveal() }
            try reply(gatesOpen ? Prose.gatesOpen : Prose.gatesClose)
        }

        // The buttons. Yellow charges the panel, brown clears it, and both say
        // no more than the mainframe does — the bubble in the Dam room is where
        // you read the result.
        yellowButton.before(.push) {
            bubbleGlowing = true
            try reply(Prose.buttonClick)
        }
        brownButton.before(.push) {
            bubbleGlowing = false
            try reply(Prose.buttonClick)
        }

        // Red toggles the room's own lights. Tracked with a flag rather than
        // read back from `isLit`, so a lit lantern in hand cannot be mistaken
        // for the room's own light.
        redButton.before(.push) {
            maintenanceRoomLit.toggle()
            maintenanceRoom.isLit = maintenanceRoomLit
            try reply(maintenanceRoomLit ? Prose.lightsOn : Prose.lightsOff)
        }
    }

    /// The second half of the same list. Split when hazard #174 was thought to
    /// be a limit on body size; kept because it reads better in two.
    @RuleBuilder private var moreDamRules: Rules {
        // Blue springs the leak. Once only: after that it is jammed, whether
        // the water is still rising or the room has already been given up for
        // lost.
        // The button jams once the water has run at all, plugged or not — the
        // mainframe's own rule, and the reason plugging the leak keeps the
        // room rather than merely postponing it.
        blueButton.before(.push) {
            guard floodLevel == 0 else { try reply(Prose.blueButtonJammed) }

            leak.reveal()
            floodWater.reveal()
            startDaemon("damLeak")
            try reply(Prose.blueButtonPush)
        }

        // Striking a match. The source keeps the count on the matchbook and
        // lights the book itself, so that is what happens here; the flame
        // lasts two turns, and the candles it exists for are the temple's.
        matchbook.before(.burn, .turnOn) {
            // An item rule fires for the indirect object too, and the whole
            // point of a match is to be named as one — so `burn candles with
            // match` must reach the candles rather than light a second match.
            guard command.directObject == matchbook else { return }
            // Struck twice, this used to *return* rather than refuse, and the
            // turn fell through to the engine's switch language: "It's already
            // on.", about a matchbook. (#329)
            try require(!matchbook.isLit, else: Prose.matchAlreadyBurning)
            // The third branch, and the one #329 missed while it was giving the
            // ivory torch its own: `light match` reported a match burning with
            // the flood over the player's head, two lines above the torch
            // saying it was burning under water. A struck match is the one
            // flame in this game the water simply wins against, so this is a
            // refusal rather than a wet-burning line. (#350)
            try require(!readerIsUnderWater, else: Prose.matchDrowned)
            try require(matchesLeft > 0, else: Prose.matchesGone)
            matchesLeft -= 1
            matchbook.isLit = true
            startFuse("matchBurnsOut", after: 2)
            try reply(Prose.matchStrikes)
        }
        matchbook.before(.turnOff) {
            guard matchbook.isLit else { return }
            matchbook.isLit = false
            stopFuse("matchBurnsOut")
            try reply(Prose.matchIsOut)
        }

        // SEARCH lands on the stock `.lookIn` path, which refuses anything not
        // declared a `container` with "You find nothing of interest in the …"
        // — a denial about a trunk this room's own listing calls *bulging with
        // jewels*. The trait is not the answer here; the line is. (#329)
        trunk.before(.lookIn) { try reply(Prose.trunkSearched) }

        // The tube gives up its gunk when squeezed — the mainframe's own verb
        // for it, and the only way to get the putty into your hand.
        tube.before(.squeeze) {
            try require(tube.isOpen, else: Prose.tubeClosed)
            try require(tube.holds(putty), else: Prose.tubeEmpty)
            putty.moveToPlayer()
            try reply(Prose.puttyOozes)
        }

        // Plugging the leak. `plug leak with putty` is the mainframe's
        // sentence; `put putty in leak` reaches the same rule, because an item
        // rule fires for the indirect object too and a player with the gunk in
        // hand should not have to guess the verb.
        leak.before(.plug, .putIn) {
            try require(leakRunning, else: Prose.nothingLeaking)
            try require(
                command.indirectObject == putty || command.directObject == putty,
                else: Prose.plugNeedsGunk)
            putty.vanish()

            stopDaemon("damLeak")
            try reply(Prose.leakPlugged)
        }
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        // A struck match lasts two turns. The flame goes out wherever the book
        // has got to; the line about it is only said where the player could
        // watch it happen, and said before the change for the same reason the
        // lantern's last rung is (``DungeonHouse/timers``).
        fuse("matchBurnsOut", after: 2) {
            say(Prose.matchBurnsOut, from: matchbook)
            matchbook.isLit = false
        }

        // The rising water. One rung of the ladder each turn; when it goes over
        // the last of them the room is full, whoever is still in it drowns, and
        // the doors are shut for the rest of the game.
        daemon("damLeak") {
            floodLevel += 1
            guard floodLevel <= Prose.floodLadder.count else {
                stopDaemon("damLeak")
                // Drowning is not a `say`, so this one keeps its own room test.
                if player.location == maintenanceRoom { try die(Prose.floodDrowns) }
                return
            }
            say(Prose.floodRises(floodRung ?? ""), from: maintenanceRoom)
        }
    }
}

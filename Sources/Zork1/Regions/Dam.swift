import Gnusto
import GnustoScoring

/// The Dam & Reservoir region — Flood Control Dam #3 and the water it holds
/// back. The dam's Maintenance Room carries four coloured buttons; the yellow
/// one charges the control panel (its green bubble glows), and only then will
/// the great bolt turn under a wrench to work the sluice gates. Opening the
/// gates drains the reservoir over eight turns, laying bare the bed and the
/// trunk of jewels sunk in it; closing them fills it again. The blue button
/// springs a leak that floods the Maintenance Room and drowns anyone who
/// lingers.
///
/// The bolt, the gates, and the water they move are the region's cross-region
/// seam: draining or filling sets the Round Room bundle's ``waterMoving`` (which
/// the Loud Room reads), and the trunk pays into the house's trophy case. A
/// bundle can't reach another bundle's `@Global` or entities from its own
/// rules, so those pieces — the `turn bolt with wrench` rule and the eight-turn
/// drain/refill fuses — are host-wired in ``Zork1``, the same way the troll's
/// east exit and the chimney's burden gate are. Everything self-contained to
/// the dam lives here. See `FIDELITY.md`.
struct ZorkDam: GameContent {
    // MARK: - Rooms

    let damRoom = Location {
        name("Dam")
        description(Prose.dam)
        dark
    }

    let damLobby = Location {
        name("Dam Lobby")
        description(Prose.damLobby)
        dark
    }

    /// Dark until the red button turns the room's own lights on.
    let maintenanceRoom = Location {
        name("Maintenance Room")
        description(Prose.maintenanceRoom)
        dark
    }

    let damBase = Location {
        name("Dam Base")
        description(Prose.damBase)
        dark
    }

    let reservoirSouth = Location {
        name("Reservoir South")
        description(Prose.reservoirSouth)
        dark
        trait(.waterSource, true)
    }

    /// The reservoir bed. You can only stand here once the gates have drained
    /// it (``reservoirDrained``); crossing a full reservoir would drown you, and
    /// closing the gates while you stand here does exactly that (host-wired).
    let reservoir = Location {
        name("Reservoir")
        description(Prose.reservoir)
        dark
        trait(.waterSource, true)
    }

    let reservoirNorth = Location {
        name("Reservoir North")
        description(Prose.reservoirNorth)
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

    // MARK: - Dam controls (Dam Room)

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

    // MARK: - Dam Lobby items

    let guidebook = Item {
        name("tour guidebook")
        adjectives("tour", "guide")
        synonyms("book")
        description(Prose.guidebookText)
    }

    let matchbook = Item {
        name("matchbook")
        adjectives("match")
        synonyms("matches")
        description(Prose.matchbookText)
        trait(.weight, 2)
    }

    // MARK: - Maintenance Room items

    let blueButton = Item {
        name("blue button")
        adjectives("blue")
        synonyms("switch")
        description(Prose.blueButton)
        scenery
    }

    let redButton = Item {
        name("red button")
        adjectives("red")
        synonyms("switch")
        description(Prose.redButton)
        scenery
    }

    let brownButton = Item {
        name("brown button")
        adjectives("brown")
        synonyms("switch")
        description(Prose.brownButton)
        scenery
    }

    let yellowButton = Item {
        name("yellow button")
        adjectives("yellow")
        synonyms("switch")
        description(Prose.yellowButton)
        scenery
    }

    let wrench = Item {
        name("wrench")
        synonyms("tool")
        description(Prose.wrench)
        trait(.weight, 10)
    }

    let screwdriver = Item {
        name("screwdriver")
        adjectives("screw")
        synonyms("driver", "tool")
        description(Prose.screwdriver)
    }

    let tube = Item {
        name("tube")
        synonyms("gunk")
        description(Prose.tube)
        trait(.weight, 5)
    }

    // MARK: - Reservoir items

    let handPump = Item {
        name("hand-held air pump")
        adjectives("hand-held", "air", "small")
        synonyms("pump")
        description(Prose.handPump)
    }

    /// The trunk of jewels: fifteen on the find, five in the case. It lies on
    /// the reservoir bed, hidden beneath the water until the gates drain it —
    /// the host's drain fuse reveals it.
    let trunk = Item {
        name("trunk of jewels")
        adjectives("old")
        synonyms("trunk", "chest", "jewels", "treasure")
        firstSight(Prose.trunkFirstSight)
        description(Prose.trunk)
        trait(.weight, 35)
        trait(.takeValue, 15)  // find
        trait(.depositValue, 5)  // case
        hidden
    }

    // MARK: - State

    /// Whether the gates have drained the reservoir. Drives the crossable-bed
    /// exits, the trunk's reveal, and the refill-drowning check.
    @Global var reservoirDrained = false

    /// Whether the yellow button has charged the control panel. The bolt only
    /// turns while this is true; the brown button clears it.
    @Global var bubbleGlowing = false

    /// The current gate state, toggled by `turn bolt with wrench` (host-wired).
    @Global var gatesOpen = false

    /// Whether the red button has switched the Maintenance Room lights on.
    @Global var maintenanceRoomLit = false

    /// Turns since the blue button sprang the leak — the flood daemon's clock.
    @Global var floodLevel = 0

    // MARK: - Map

    var map: WorldMap {
        // Dam. Its south exit (to Deep Canyon) crosses into ZorkRoundRoom, so
        // the host wires it; everything else is internal.
        damRoom.down(damBase)
        damRoom.east(damBase)
        damRoom.north(damLobby)
        damRoom.west(reservoirSouth)

        // Dam Lobby.
        damLobby.south(damRoom)
        damLobby.north(maintenanceRoom)
        damLobby.east(maintenanceRoom)

        // Maintenance Room.
        maintenanceRoom.south(damLobby)
        maintenanceRoom.west(damLobby)

        // Dam Base. (The pile of plastic — the boat — arrives with the river
        // region; see `FIDELITY.md`.)
        damBase.north(damRoom)
        damBase.up(damRoom)

        // Reservoir South. Southeast (Deep Canyon) and southwest (Chasm) cross
        // into ZorkRoundRoom and are host-wired. North onto the bed is barred
        // while the reservoir is full.
        reservoirSouth.east(damRoom)
        reservoirSouth.west(streamView)
        reservoirSouth.north(
            reservoir, when: { reservoirDrained }, otherwise: Prose.reservoirWouldDrown)

        // Reservoir bed. Reachable only when drained (from either shore); once
        // on it you can move freely until it fills.
        reservoir.north(reservoirNorth)
        reservoir.south(reservoirSouth)
        reservoir.up(stream)
        reservoir.west(stream)
        reservoir.down(blocked: Prose.damBlocksWay)

        // Reservoir North. North (Atlantis) awaits the mirror region.
        reservoirNorth.south(
            reservoir, when: { reservoirDrained }, otherwise: Prose.reservoirWouldDrown)

        // Stream View & Stream. The stream's boat-only disembark to Stream View
        // (ZIL's LAND exit) waits for the river region; on foot the shore is
        // reached from Reservoir South's west. See `FIDELITY.md`.
        streamView.east(reservoirSouth)
        streamView.west(blocked: Prose.streamTooSmall)
        stream.down(reservoir)
        stream.east(reservoir)
        stream.up(blocked: Prose.channelTooNarrow)
        stream.west(blocked: Prose.channelTooNarrow)

        // Entities.
        bolt.starts(in: damRoom)
        bubble.starts(in: damRoom)
        controlPanel.starts(in: damRoom)
        guidebook.starts(in: damLobby)
        matchbook.starts(in: damLobby)
        blueButton.starts(in: maintenanceRoom)
        redButton.starts(in: maintenanceRoom)
        brownButton.starts(in: maintenanceRoom)
        yellowButton.starts(in: maintenanceRoom)
        wrench.starts(in: maintenanceRoom)
        screwdriver.starts(in: maintenanceRoom)
        tube.starts(in: maintenanceRoom)
        handPump.starts(in: reservoirNorth)
        trunk.starts(in: reservoir)
    }

    // MARK: - Rules

    var rules: Rules {
        // The yellow button charges the panel so the bolt will turn; the brown
        // button clears it again.
        yellowButton.before(.push) {
            bubbleGlowing = true
            try reply(Prose.yellowButtonPush)
        }
        brownButton.before(.push) {
            bubbleGlowing = false
            try reply(Prose.brownButtonPush)
        }

        // The red button toggles the room's own lights. Tracked with a flag
        // rather than read back from `isLit`, so a lit lantern in hand can't be
        // mistaken for the room's own light.
        redButton.before(.push) {
            maintenanceRoomLit.toggle()
            maintenanceRoom.isLit = maintenanceRoomLit
            try reply(maintenanceRoomLit ? Prose.redButtonLightsOn : Prose.redButtonLightsOff)
        }

        // The blue button springs the leak: the flood daemon starts, and the
        // water rises turn by turn.
        blueButton.before(.push) {
            guard !isDaemonActive("damFlood") else { try reply(Prose.blueButtonAgain) }
            floodLevel = 0
            startDaemon("damFlood")
            try reply(Prose.blueButtonPush)
        }
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        // The Maintenance Room flood. Deterministic bands (ankle → waist →
        // neck) mark the rise; whoever is still in the room when it fills at
        // turn 13 drowns, and the room then seals (the daemon stops). Leaving
        // is the only escape — the leak isn't plugged in this slice. The bands
        // and the fixed 13-turn seal replace the original's continuous rise;
        // see `FIDELITY.md`.
        daemon("damFlood") {
            floodLevel += 1
            let here = player.location == maintenanceRoom
            if here {
                switch floodLevel {
                case 4: say(Prose.floodAnkle)
                case 8: say(Prose.floodWaist)
                case 12: say(Prose.floodNeck)
                default: break
                }
            }
            if floodLevel >= 13 {
                stopDaemon("damFlood")
                if here { try die(Prose.floodDrowns) }
            }
        }
    }
}

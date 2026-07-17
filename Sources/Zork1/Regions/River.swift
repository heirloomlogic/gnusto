import Gnusto
import GnustoScoring

extension TraitKey<Bool> {
    /// An item with a point or an edge sharp enough to hole an inflatable boat —
    /// the sword, the nasty knife, the sceptre (and, in later regions, the rusty
    /// knife, the axe, and the thief's stiletto). Nothing in the engine reads it;
    /// the magic boat does, to burst when boarded or loaded with one. Minted here
    /// because the boat is the first thing that cares. See `FIDELITY.md`.
    public static let sharp = Self("sharp", default: false)
}

/// The Frigid River region — the water run below Flood Control Dam #3 and the
/// only way to reach the country past it. An inflatable boat (a pile of plastic
/// pumped full of air) carries the player down five stretches of river; the
/// current does the steering unless you paddle or land, and drifting past the
/// last stretch goes over Aragain Falls. The White Cliffs wall the west bank
/// (a narrow foot-path squeezes back into the Damp Cave); the east bank holds a
/// sandy beach with a buried scarab, the shore, and the falls themselves. A
/// rainbow arches the falls — waved solid with the sceptre, it turns walkable
/// and a pot of gold appears at its far end, down in the canyon.
///
/// Three seams cross into other bundles and so are host-wired in ``Zork1``, like
/// the dam's bolt: the boat is inflated with the dam's hand pump, the rainbow is
/// woken with the temple's sceptre, and the White Cliffs open west onto the Damp
/// Cave (a ``ZorkRoundRoom`` room). The launch itself is host-wired too, since
/// its first launch point is the dam's Dam Base. Everything self-contained —
/// the current, the puncture, the digging — lives here. See `FIDELITY.md`.
struct ZorkRiver: GameContent {
    // MARK: - Rooms

    // The five river stretches. All share the name "Frigid River"; the current
    // carries you from one to the next (the drift fuse below). None is dark —
    // the river valley is open to the sky.
    let river1 = Location {
        name("Frigid River")
        description(Prose.river1)
    }

    let river2 = Location {
        name("Frigid River")
        description(Prose.river2)
    }

    let river3 = Location {
        name("Frigid River")
        description(Prose.river3)
    }

    let river4 = Location {
        name("Frigid River")
        description(Prose.river4)
    }

    let river5 = Location {
        name("Frigid River")
        description(Prose.river5)
    }

    let whiteCliffsNorth = Location {
        name("White Cliffs Beach")
        description(Prose.whiteCliffsNorth)
    }

    let whiteCliffsSouth = Location {
        name("White Cliffs Beach")
        description(Prose.whiteCliffsSouth)
    }

    let shore = Location {
        name("Shore")
        description(Prose.shore)
    }

    let sandyBeach = Location {
        name("Sandy Beach")
        description(Prose.sandyBeach)
    }

    let sandyCave = Location {
        name("Sandy Cave")
        description(Prose.sandyCave)
    }

    let aragainFalls = Location {
        name("Aragain Falls")
        description(Prose.aragainFalls)
    }

    /// The middle of the solid rainbow, reachable only while it holds. Waving the
    /// sceptre here drops you into the falls (the host-wired wave rule).
    let onRainbow = Location {
        name("On the Rainbow")
        description(Prose.onRainbow)
    }

    // MARK: - Items

    /// The boat before air: a folded pile of plastic with a valve. Inflating it
    /// with the pump (host-wired) trades it for the ``magicBoat``.
    let pileOfPlastic = Item {
        name("pile of plastic")
        adjectives("plastic", "folded", "inflatable")
        synonyms("boat", "pile", "plastic", "valve")
        firstSight(Prose.pileOfPlasticFirstSight)
        description(Prose.pileOfPlastic)
        trait(.weight, 20)
    }

    /// The inflated boat: an open-topped container you can climb into and ride.
    /// It has no starting placement (begins ``.nowhere``); inflating the pile
    /// puts it in play. Carrying or stowing a sharp thing bursts it back to the
    /// ``puncturedBoat``.
    let magicBoat = Item {
        name("magic boat")
        adjectives("magic", "plastic", "seaworthy")
        synonyms("boat", "raft")
        description(Prose.magicBoat)
        enterable
        container
        capacity(100)
        trait(.weight, 20)
    }

    /// The boat after a puncture — a useless deflated ruin. Begins ``.nowhere``;
    /// a puncture swaps it in for the ``magicBoat``.
    let puncturedBoat = Item {
        name("punctured boat")
        adjectives("punctured", "plastic", "large")
        synonyms("boat", "pile", "plastic")
        description(Prose.puncturedBoat)
        trait(.weight, 20)
    }

    /// The red buoy afloat in River-4, an open-and-shut container. Inside is the
    /// emerald.
    let buoy = Item {
        name("red buoy")
        adjectives("red")
        synonyms("buoy")
        firstSight(Prose.buoyFirstSight)
        description(Prose.buoy)
        container
        openable
        capacity(20)
        trait(.weight, 10)
    }

    /// The large emerald, five on the find and ten in the case (the original's
    /// VALUE 5 / TVALUE 10). Starts inside the buoy.
    let emerald = Item {
        name("large emerald")
        adjectives("large", "enormous")
        synonyms("emerald", "jewel")
        description(Prose.emerald)
        trait(.takeValue, 5)  // find
        trait(.depositValue, 10)  // case
    }

    /// The shovel on the sandy beach — the tool the buried scarab needs.
    let shovel = Item {
        name("shovel")
        synonyms("shovel", "spade", "tool")
        firstSight(Prose.shovelFirstSight)
        description(Prose.shovel)
        trait(.weight, 15)
    }

    /// The jewelled scarab, five and five, buried in the sand of the Sandy Cave.
    /// Starts `hidden`; the third dig with the shovel reveals it (a fourth digs
    /// your own grave).
    let scarab = Item {
        name("jewelled scarab")
        adjectives("jewelled", "beautiful", "carved")
        synonyms("scarab", "beetle", "bug")
        firstSight(Prose.scarabFirstSight)
        description(Prose.scarab)
        hidden
        trait(.weight, 8)
        trait(.takeValue, 5)  // find
        trait(.depositValue, 5)  // case
    }

    /// The sand of the Sandy Cave — scenery, but the thing you `dig`.
    let sand = Item {
        name("sand")
        synonyms("sand")
        description(Prose.sandyCave)
        scenery
    }

    /// The pot of gold, ten and ten. A river treasure, but it materialises at the
    /// End of Rainbow (a ``ZorkAboveGround`` room) when the rainbow turns solid,
    /// so the host places it there and reveals it. Starts `hidden`.
    let potOfGold = Item {
        name("pot of gold")
        adjectives("gold", "golden")
        synonyms("pot", "gold")
        firstSight(Prose.potOfGoldFirstSight)
        description(Prose.potOfGold)
        hidden
        trait(.weight, 15)
        trait(.takeValue, 10)  // find
        trait(.depositValue, 10)  // case
    }

    // MARK: - State

    /// Whether the sceptre has been waved to turn the rainbow solid and walkable.
    /// Gates the crossings onto the rainbow (host-wired, since one end is an
    /// above-ground room) and governs the pot of gold.
    @Global var rainbowSolid = false

    /// How many times the sand of the Sandy Cave has been dug. The third dig
    /// bares the scarab; a fourth collapses the hole.
    @Global var digCount = 0

    /// Turns left before the current carries the boat to the next stretch — the
    /// continuous interrupt's countdown, reloaded on entering each stretch (and
    /// by the host's launch rule). See the `riverCurrent` daemon and
    /// ``driftDelay()``.
    @Global var riverDwell = 0

    /// Sets the current's countdown — used by the host's cross-bundle launch
    /// rule, which arms the boat as it slips onto its first stretch.
    func armCurrent(_ turns: Int) { riverDwell = turns }

    // MARK: - Map

    var map: WorldMap {
        // The river runs one way — downstream. UP is always refused; DOWN paddles
        // to the next stretch, but the current (the drift fuse) will carry you
        // even if you sit still. Landing is sideways, onto the banks.
        river1.up(blocked: Prose.noSwimming)
        river1.down(river2)
        // West back to Dam Base is host-wired (it's a dam room).

        river2.up(blocked: Prose.noSwimming)
        river2.down(river3)

        river3.up(blocked: Prose.noSwimming)
        river3.down(river4)
        river3.west(whiteCliffsNorth)

        river4.up(blocked: Prose.noSwimming)
        river4.down(river5)
        river4.east(sandyBeach)
        river4.west(whiteCliffsSouth)

        river5.up(blocked: Prose.noSwimming)
        river5.east(shore)

        // The White Cliffs foot-paths. The N↔S path and the west passage into
        // the Damp Cave (host-wired) are walkable only on foot — the before(.go)
        // rules below refuse them from the boat.
        whiteCliffsNorth.south(whiteCliffsSouth)
        whiteCliffsSouth.north(whiteCliffsNorth)

        // The east bank on foot.
        shore.north(sandyBeach)
        shore.south(aragainFalls)
        sandyBeach.south(shore)
        sandyBeach.northeast(sandyCave)
        sandyCave.southwest(sandyBeach)
        aragainFalls.north(shore)

        // The rainbow's near end (the falls side). Stepping onto it needs it
        // solid; the far end (onto the End of Rainbow, an above-ground room) is
        // host-wired. Once on the rainbow you can always step back off.
        aragainFalls.exit(.up, to: onRainbow, when: { rainbowSolid }, otherwise: Prose.rainbowNotSolid)
        aragainFalls.exit(.west, to: onRainbow, when: { rainbowSolid }, otherwise: Prose.rainbowNotSolid)
        onRainbow.east(aragainFalls)

        // Entities. (The boat pile starts at Dam Base and the pot of gold at the
        // End of Rainbow — both host-placed, since those rooms belong to other
        // bundles. The magic and punctured boats begin .nowhere.)
        buoy.starts(in: river4)
        emerald.starts(inside: buoy)
        shovel.starts(in: sandyBeach)
        scarab.starts(in: sandyCave)
        sand.starts(in: sandyCave)
    }

    // MARK: - Rules

    var rules: Rules {
        // The current. Each river stretch, on entry, reloads the drift countdown
        // for that stretch's dwell (see ``driftDelay()``). Paddling downstream
        // re-enters the next room and resets the count; sitting still lets the
        // `riverCurrent` daemon carry you on.
        river1.onEnter { riverDwell = driftDelay() }
        river2.onEnter { riverDwell = driftDelay() }
        river3.onEnter { riverDwell = driftDelay() }
        river4.onEnter { riverDwell = driftDelay() }
        river5.onEnter { riverDwell = driftDelay() }

        // Paddling off the end of River-5 goes over the falls, the same as
        // drifting there would.
        river5.before(.go) {
            guard command.direction == .down else { return }
            try die(Prose.overTheFalls)
        }

        // You can't step out of the boat onto open water — you'd be swept away.
        // Land on a bank first.
        world.before(.disembark) {
            guard isOnRiver() else { return }
            try refuse(Prose.disembarkOntoWater)
        }

        // Boarding the boat while carrying anything sharp bursts it. Boarding
        // happens on a bank, so this only wrecks the boat — no drowning.
        magicBoat.before(.board) {
            guard carryingSomethingSharp() else { return }
            puncture()
            try refuse(Prose.boatPuncturedOnLand)
        }

        // Stowing a sharp thing in the boat bursts it too — and if you're already
        // afloat, that's fatal.
        magicBoat.before(.putIn) {
            guard let stowed = command.directObject, stowed[default: .sharp] else { return }
            let afloat = isOnRiver()
            puncture()
            if afloat {
                try die(Prose.boatPuncturedAfloat)
            }
            try reply(Prose.boatPuncturedOnLand)
        }

        // Letting the air out. Only on dry land, and not while you're sitting in
        // it. Trades the boat back for the pile of plastic.
        magicBoat.before(.deflate) {
            guard player.vehicle != magicBoat else { try reply(Prose.deflateWhileAboard) }
            magicBoat.vanish()
            pileOfPlastic.move(to: player.location)
            try reply(Prose.boatDeflates)
        }

        // Inflating the already-firm boat, or launching it while it's beached and
        // empty, get polite refusals rather than the stage-4 defaults.
        magicBoat.before(.inflate) { try reply(Prose.boatAlreadyFirm) }

        // The White Cliffs foot-paths refuse the boat.
        whiteCliffsNorth.before(.go) {
            guard command.direction == .south || command.direction == .west else { return }
            try require(player.vehicle == nil, else: Prose.cliffPathTooNarrow)
        }
        whiteCliffsSouth.before(.go) {
            guard command.direction == .north else { return }
            try require(player.vehicle == nil, else: Prose.cliffPathTooNarrow)
        }

        // Digging the sand. Bare hands do nothing; the shovel deepens the hole,
        // bares the scarab on the third dig, and buries you on the fourth.
        sand.before(.dig) {
            try require(command.indirectObject == shovel, else: Prose.digWithoutShovel)
            digCount += 1
            if digCount == 3 {
                scarab.reveal()
                try reply(Prose.digRevealsScarab)
            }
            if digCount > 3 {
                try die(Prose.digCollapses)
            }
            try reply(Prose.digProgress)
        }
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        // The river current — a continuous per-turn interrupt (the original's
        // river clock), not a one-shot fuse. Every turn the player is afloat it
        // counts the stretch's dwell down; at zero it carries the boat — and you
        // — one stretch downstream and reloads the next dwell. Off the last
        // stretch there is no downstream but the falls. Draw-free: the dwell
        // schedule is fixed data, no RNG. The daemon sorts before the thief's,
        // so its lines and the RNG stream are unchanged from the old fuse.
        //
        // Two reload sites, one turn apart in when the daemon next ticks them:
        // a stretch entered by paddling (`onEnter`) or launch is reloaded during
        // the command, so this same turn's tick decrements it once; a stretch
        // reached by drifting is reloaded here, *after* this turn's tick, so it
        // gets its first decrement next turn. Reloading to `driftDelay() - 1` on
        // the drift path keeps the two consistent — `driftDelay() - 1` waits on
        // every stretch either way.
        daemon("riverCurrent", autostart: true) {
            guard player.vehicle == magicBoat, isOnRiver() else { return }
            riverDwell -= 1
            guard riverDwell <= 0 else { return }
            guard let next = nextRiverRoom() else {
                // On River-5 with nowhere left downstream: over the falls.
                try die(Prose.overTheFalls)
            }
            magicBoat.move(to: next)
            say(Prose.currentCarriesYou)
            describeSurroundings()
            riverDwell = driftDelay() - 1
        }
    }

    // MARK: - Current helpers

    /// Whether the player is on one of the five river stretches.
    private func isOnRiver() -> Bool {
        let here = player.location
        return here == river1 || here == river2 || here == river3
            || here == river4 || here == river5
    }

    /// The stretch downstream of where the player is, or nil at River-5 (where
    /// downstream is the falls).
    private func nextRiverRoom() -> Location? {
        let here = player.location
        if here == river1 { return river2 }
        if here == river2 { return river3 }
        if here == river3 { return river4 }
        if here == river4 { return river5 }
        return nil
    }

    /// How long to reload the current's countdown for on the stretch the player
    /// is now on. The canonical dwell is River-1/2: 4 turns, River-3: 3,
    /// River-4: 2, River-5: 1 — but a stretch entered by paddling is reloaded
    /// during the command and so takes its first `riverCurrent` decrement that
    /// same turn, so reloading at dwell + 1 nets the player exactly that many
    /// turns on each stretch before the current takes them on. See `FIDELITY.md`.
    private func driftDelay() -> Int {
        let here = player.location
        if here == river1 || here == river2 { return 5 }
        if here == river3 { return 4 }
        if here == river4 { return 3 }
        return 2
    }

    /// Whether the player is carrying anything sharp enough to hole the boat.
    private func carryingSomethingSharp() -> Bool {
        player.inventory.contains { $0[default: .sharp] }
    }

    /// Burst the magic boat: swap in the punctured wreck and scatter whatever the
    /// boat was carrying into the room. Shared by the board and stow punctures.
    private func puncture() {
        for cargo in magicBoat.contents {
            cargo.move(to: player.location)
        }
        magicBoat.vanish()
        puncturedBoat.move(to: player.location)
    }
}

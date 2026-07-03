import Gnusto

/// The cellar region below the house: East of Chasm, the Gallery with its
/// painting, and the Studio whose chimney climbs back up to the kitchen.
/// Together with the lit lantern this closes the Phase-5 "dark cellar
/// soft-lock" — a sealed-in player either carries light or dashes for the
/// Gallery's daylight and the chimney. The `Cellar` room itself stays in
/// ``ZorkHouse`` (the trap door joins two rooms one bundle owns); this
/// bundle meets it through the host-wired exits in ``Zork1``.
///
/// The troll passage north of the cellar and the maze beyond are later
/// phases — see `FIDELITY.md`.
struct ZorkCellar: GameContent {
    // MARK: - Rooms

    let eastOfChasm = Location {
        name("East of Chasm")
        description(Prose.eastOfChasm)
        dark
    }

    /// Lit, as in the original — daylight from somewhere high above. Also
    /// the resting point that makes the lightless chimney dash survivable.
    let gallery = Location {
        name("Gallery")
        description(Prose.gallery)
    }

    let studio = Location {
        name("Studio")
        description(Prose.studio)
        dark
    }

    // MARK: - Items

    let chasm = Item {
        name("chasm")
        description(Prose.chasm)
        scenery
    }

    let painting = Item {
        name("painting")
        adjectives("beautiful")
        firstSight(Prose.paintingFirstSight)
        description(Prose.painting)
    }

    let chimney = Item {
        name("chimney")
        adjectives("dark", "narrow")
        description(Prose.chimney)
        scenery
    }

    // MARK: - The grue

    /// Consecutive turns the player has ended in darkness.
    @Global var darkTurns = 0

    /// Darkness is lethal: a warning on the first dark turn, one silent
    /// turn of grace, death on the third. Lingering-based, not movement-
    /// based — the daemon counts consecutive turns *ending* in darkness,
    /// wherever they're spent — so the warning turn is a guarantee (the
    /// classic fairness contract) and the lightless dash to the Gallery can
    /// still succeed. Deterministic rather than `chance(…)` so transcripts
    /// reproduce without pinned seeds. Written self-contained (one
    /// `@Global`, no house/cellar references) so Phase 8's dangerous-dark
    /// plugin can lift it out wholesale — see `FIDELITY.md`.
    var timers: [TimedEvent] {
        daemon("grue", autostart: true) {
            guard !player.location.isLit else {
                darkTurns = 0
                return
            }
            darkTurns += 1
            if darkTurns == 1 {
                say(Prose.grueWarning)
            } else if darkTurns >= 3 {
                try die(Prose.grueDeath)
            }
        }
    }

    // MARK: - Map

    var map: WorldMap {
        eastOfChasm.east(gallery)
        gallery.west(eastOfChasm)
        gallery.north(studio)
        studio.south(gallery)

        chasm.starts(in: eastOfChasm)
        painting.starts(in: gallery)
        chimney.starts(in: studio)
    }
}

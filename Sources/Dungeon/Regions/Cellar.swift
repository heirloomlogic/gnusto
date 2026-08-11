import Gnusto

/// The rooms immediately below the house: the Troll Room, the North-South
/// Crawlway, West of Chasm, the Gallery and the Studio — and the troll who
/// stands in the middle of them.
///
/// The Cellar itself belongs to ``DungeonHouse``; this bundle meets it through
/// host-wired exits, the ordinary way two bundles' geography joins.
///
/// **This region is not Zork I's cellar.** The mainframe puts two rooms here
/// the trilogy never had — ``crawlway`` and ``westOfChasm`` — and reshapes the
/// rest around them:
///
/// - the Cellar's passage runs **east** to the Troll Room, not north;
/// - the Troll Room opens in **four** directions, and the troll gates three of
///   them (east to the crawlway, north to the East-West Passage, south into
///   the maze);
/// - the Gallery hangs between the chasm (north), the Studio (south) and the
///   **Bank of Zork** (west);
/// - the Studio's doors are north and northwest, and its chimney climbs to the
///   Kitchen.
///
/// So the Studio and the Gallery are reachable **without** beating the troll,
/// by the crawlway south of West of Chasm — and the chimney out of the Studio
/// is the only way back above ground once the trap door has barred itself.
///
/// Seams left for later milestones, and recorded in `FIDELITY.md`: the Troll
/// Room's north and south passages, and the Gallery's west door into the Bank.
struct DungeonCellar: GameContent {
    // MARK: - Rooms

    let trollRoom = Location {
        name("The Troll Room")
        description(Prose.trollRoom)
        dark
    }

    /// Mainframe-only. North to ``westOfChasm``, south to ``studio``, east to
    /// ``trollRoom``, and a hole overhead that goes nowhere.
    let crawlway = Location {
        name("North-South Crawlway")
        description(Prose.crawlway)
        dark
    }

    /// Mainframe-only. Zork I stands its player on the other lip of this
    /// chasm; the mainframe keeps the west side, and the passage west of it
    /// runs back to the Cellar.
    let westOfChasm = Location {
        name("West of Chasm")
        description(Prose.westOfChasm)
        dark
    }

    /// Lit, as in the mainframe — daylight from somewhere high above, and the
    /// resting point that makes a lightless dash survivable.
    let gallery = Location {
        name("Gallery")
        description(Prose.gallery)
    }

    let studio = Location {
        name("Studio")
        description(Prose.studio)
        dark
    }

    // MARK: - The troll

    let troll = Actor {
        name("troll")
        adjectives("nasty")
        description(Prose.troll)
        firstSight(Prose.troll)
    }

    /// The troll's axe. It starts in his hands — offstage — and clatters to
    /// the floor when he falls (his `onDefeat`, host-wired).
    let axe = Item {
        name("bloody axe")
        adjectives("bloody")
        synonyms("axe", "ax")
        description(Prose.axe)
        trait(.weight, 25)
        trait(.weapon, true)
    }

    @Global var trollDefeated = false

    // MARK: - Rules

    /// The one thing the troll does that is not a fight. Everything else about
    /// him is host-wired, because the melee plugin and the blades he is fought
    /// with are the host's; this needs nothing from another bundle, so it lives
    /// with him.
    ///
    /// Two states, which is the source's own count. `reply` rather than `say`:
    /// the engine's `.greet` default is a `say`, so a rule that only said would
    /// print both lines. A *dead* troll needs no branch — the melee plugin
    /// `vanish()`es him, and the parser answers before any rule runs.
    @RuleBuilder var rules: Rules {
        troll.before(.greet) {
            try reply(troll.isUnconscious ? Prose.trollGreetedOnTheFloor : Prose.trollGreeted)
        }
    }

    // MARK: - Items

    let chasm = Item {
        name("chasm")
        synonyms("chasm", "pit")
        description(Prose.chasm)
        scenery
    }

    let crawlwayHole = Item {
        name("hole")
        adjectives("ragged")
        synonyms("hole")
        description(Prose.crawlwayHole)
        scenery
    }

    /// The mainframe's values: 4 to find, **7** to case, where Zork I pays 6.
    let painting = Item {
        name("painting")
        adjectives("beautiful")
        synonyms("art", "canvas", "masterpiece", "picture", "work", "paintings")
        firstSight(Prose.paintingFirstSight)
        description(Prose.painting)
        trait(.takeValue, 4)
        trait(.depositValue, 7)
        trait(.weight, 15)
    }

    /// The Troll Room's walls carry his housekeeping, and the room says so.
    let bloodstains = Item {
        name("bloodstains")
        adjectives("deep")
        synonyms("bloodstain", "stains", "scratches", "scratch", "walls", "wall")
        description(Prose.bloodstains)
        scenery
        plural
    }

    /// The Studio's 69 colors are the joke, so they answer for themselves.
    let paints = Item {
        name("paints")
        adjectives("splattered")
        synonyms("paint", "colors", "colours", "walls", "floor", "doors")
        description(Prose.paints)
        scenery
        plural
    }

    let chimney = Item {
        name("chimney")
        adjectives("dark", "narrow")
        synonyms("chimney")
        description(Prose.chimney)
        scenery
    }

    let fireplace = Item {
        name("fireplace")
        synonyms("hearth")
        description(Prose.fireplace)
        scenery
    }

    // MARK: - Map

    var map: WorldMap {
        // The troll gates all three passages out of his room that are not the
        // way you came. Two of the three reach regions later milestones build;
        // this one is wholly inside this bundle, so it is declared here.
        trollRoom.east(
            crawlway, when: { trollDefeated }, otherwise: Prose.trollBlocksTheWay)
        crawlway.east(trollRoom)

        crawlway.north(westOfChasm)
        crawlway.south(studio)
        crawlway.up(blocked: Prose.crawlwayHoleRefusal)

        westOfChasm.north(crawlway)
        westOfChasm.south(gallery)
        westOfChasm.down(blocked: Prose.chasmDownRefusal)
        // West runs back to the Cellar, a ``DungeonHouse`` room — host-wired.

        gallery.north(westOfChasm)
        gallery.south(studio)
        // West is the Bank of Zork's entrance hall, a later milestone.

        studio.north(crawlway)
        studio.northwest(gallery)
        // Up the chimney is the Kitchen, a ``DungeonHouse`` room, and it is
        // gated on a light load — host-wired, since the gate weighs the lamp.

        bloodstains.starts(in: trollRoom)
        paints.starts(in: studio)
        chasm.starts(in: westOfChasm)
        crawlwayHole.starts(in: crawlway)
        painting.starts(in: gallery)
        chimney.starts(in: studio)
        fireplace.starts(in: studio)
        troll.starts(in: trollRoom)
    }
}

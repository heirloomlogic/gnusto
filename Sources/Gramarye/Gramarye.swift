import Gnusto
import GnustoSpellcasting

extension TraitKey<Bool> {
    /// Marks a target that `firebolt` can destroy. Anything else shrugs the
    /// spell off, so casting fire at the wrong thing is a wasted turn, not a win.
    static let combustible = Self("combustible")
}

extension Intent {
    /// **glow** — an at-will cantrip that reveals what magic has hidden.
    #verb("glow", ["glow"], ["cast", "glow"])
    /// **unbar** — a memorized spell that parts a warded door.
    #verb("unbar", ["unbar"], ["cast", "unbar"])
    /// **firebolt** — an energy spell hurled at a target.
    #verb(
        "firebolt", ["firebolt"], ["cast", "firebolt"],
        ["firebolt", .directObject], ["cast", "firebolt", "at", .directObject])
    /// **passwall** — a one-shot spell read from a scroll, opening solid stone.
    #verb("passwall", ["passwall"], ["cast", "passwall"], ["read", "passwall"])
    /// Memorizing **unbar** into working memory (needs the spellbook in hand).
    #verb("learnUnbar", ["memorize", "unbar"], ["learn", "unbar"], ["study", "unbar"])
}

/// A small original spell game that proves the engine hosts a general
/// spellcasting layer: its four spells each use a different casting paradigm —
/// an at-will cantrip (**glow**), a memorized spell (**unbar**), an
/// energy-pool spell (**firebolt**), and a one-shot scroll (**passwall**) —
/// wired to a puzzle that needs all four to reach the amulet.
///
/// Original title and prose: "Enchanter" and its spell words are trademarks;
/// the mechanics here are the general RPG paradigms, not that specific game.
@main
struct Gramarye: Game, GameMain {
    let title = "Gramarye"
    let tagline = "A novice's first working."
    let maxScore = 10
    let intro = """
        Your master is three days gone to the Circle and left you the tower to \
        mind. You would have kept to your reading, but the warded door to the \
        undercroft has swung to on its own — and the master's amulet is not on \
        its hook. Best you fetch it back before anyone thinks to ask.
        """

    let magic = Spellcasting(memorySlots: 3, maxMana: 12)

    // MARK: - Rooms

    let study = Location {
        name("The Study")
        description("""
            A close, candle-warm room walled in books. A heavy door, its frame \
            cut with old warding-marks, stands in the west wall; a shadowed \
            niche gapes beside it.
            """)
    }

    let gallery = Location {
        name("The Long Gallery")
        description("""
            A cold stone gallery. The way west runs back to the study; to the \
            north the passage is stopped by a blank wall of dressed granite, \
            fitted so close a knife could not find the seams.
            """)
    }

    let undercroft = Location {
        name("The Undercroft")
        description("A low vaulted cellar, the air chalky with old magic.")
    }

    // MARK: - Items

    let spellbook = Item {
        name("spellbook")
        adjectives("master's", "leather")
        synonyms("book")
        description("The master's working book, its pages dense with a careful hand.")
    }

    /// Hidden in the niche until **glow** reveals it — so the cantrip is not
    /// mere flavour: without it the scroll is never found.
    let scroll = Item {
        name("passwall scroll")
        adjectives("passwall")
        synonyms("scroll", "parchment")
        description("A single spell inked on brittle parchment: passwall, good for one reading.")
        hidden
    }

    let wardedDoor = Item {
        name("warded door")
        adjectives("warded", "heavy")
        synonyms("door")
        description("A stout door, its frame graven with warding-marks that still hold it fast.")
        scenery
        openable
    }

    let graniteWall = Item {
        name("granite wall")
        adjectives("granite", "blank", "dressed")
        synonyms("wall", "stone")
        description("A wall of dressed granite, seamless and cold. No door, no crack — just stone.")
        scenery
        openable
    }

    let golem = Actor {
        name("clay golem")
        adjectives("clay", "hulking")
        synonyms("guardian")
        description("A hulking figure of baked clay, planted between you and the amulet's hook.")
        trait(.combustible, true)
    }

    /// Hidden behind the golem's bulk until **firebolt** clears it.
    let amulet = Item {
        name("silver amulet")
        adjectives("silver", "master's")
        synonyms("amulet", "talisman")
        description("The master's amulet, a moon of worn silver on a fine chain.")
        hidden
    }

    // MARK: - Composition

    var content: GameContents {
        magic
    }

    var verbs: [SyntaxRule] {
        [.glow, .unbar, .firebolt, .passwall, .learnUnbar]
    }

    var actions: [IntentAction] {
        // Cantrip — free, at-will. Reveals the hidden scroll in the study.
        magic.spell(.glow, cost: .cantrip) {
            if !scroll.isRevealed {
                scroll.reveal()
                say("Pale light seeps from your fingers, and in the niche it finds a rolled parchment.")
            } else {
                say("Pale light seeps from your fingers, but there is nothing hidden here to find.")
            }
        }

        // Memorized — learned from the spellbook, spent on the casting.
        magic.spell(.unbar, cost: .prepared(book: spellbook, learnVia: .learnUnbar)) {
            try require(
                !wardedDoor.isOpen,
                else: "The warded door already stands open.")
            wardedDoor.isOpen = true
            say("You speak the unbinding. The warding-marks gutter and die, and the door drifts open.")
        }

        // Energy — draws from the mana pool; hurled at a target.
        magic.spell(.firebolt, cost: .energy(4)) {
            guard let target = command.directObject else {
                try reply("Cast firebolt at what?")
            }
            try require(
                target[.combustible] == true,
                else: "The firebolt washes over the \(target.name) and leaves it untouched.")
            target.vanish()
            amulet.reveal()
            say("Fire leaps from your hand and bursts against the golem; it slumps to rubble, and behind it the amulet gleams on its hook.")
        }

        // Scroll — one reading, then the parchment is spent.
        magic.spell(.passwall, cost: .scroll(scroll)) {
            try require(
                !graniteWall.isOpen,
                else: "The granite has already been opened.")
            graniteWall.isOpen = true
            say("You read the scroll and it crumbles to ash — but the granite before you turns to a soft grey mist you can step through.")
        }
    }

    var rules: Rules {
        // The barriers yield only to magic: no ordinary hand opens them, so the
        // spells are the only way through.
        wardedDoor.before(.open) {
            try reply("The warding-marks hold the door fast; no hand of yours will open it.")
        }
        graniteWall.before(.open) {
            try reply("It is a wall of solid granite. You cannot simply open it.")
        }

        // The amulet is out of reach until the golem is dealt with; the reveal
        // in firebolt's effect is what actually makes it takable.
        amulet.after(.take) {
            player.score += 10
            say("You lift the master's amulet from its hook. Three days' worry lifts with it.")
            try end(won: true)
        }
    }

    var map: WorldMap {
        study.west(gallery, via: wardedDoor)
        gallery.east(study, via: wardedDoor)
        gallery.north(undercroft, via: graniteWall)
        undercroft.south(gallery, via: graniteWall)

        player.starts(in: study)
        spellbook.starts(in: study)
        scroll.starts(in: study)
        wardedDoor.starts(in: study)
        graniteWall.starts(in: gallery)
        golem.starts(in: undercroft)
        amulet.starts(in: undercroft)
    }
}

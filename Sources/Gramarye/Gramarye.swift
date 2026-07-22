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
        The tower has been in an uproar since dawn — cloak, staff, letters, a hat he cannot find because he is wearing \
        it. The Circle has summoned your master, and the Circle does not care to wait.

        At the threshold he stops, turns back, and takes you by the shoulder, fixing you with the look he otherwise \
        reserves for cracked cauldrons. "The amulet," he says. "Is it secret? Is it safe?" He then reminds you, at \
        some volume, that it hangs on its hook in the undercroft, behind the warded door — which rather settles the \
        first question. Should anything happen while he is away — anything at all — you are to see that it remains \
        secure.

        And he is gone, down the hill at a pace that does not suit his robes, leaving you to mind the tower on the \
        theory that nothing ever happens here.

        The master's spellbook is on the desk. It knows more magic than you do, though in fairness, so does the door.
        """

    let magic = Spellcasting(memorySlots: 3, maxMana: 12)

    /// Tracks the moment the wards catch. The warded door starts open with its
    /// wards dormant; a draught seals it a few turns in (see `timers`). This
    /// flag is what tells "nothing is wrong yet" apart from "the door is open
    /// again because you unbarred it" — states `wardedDoor.isOpen` cannot.
    @Global var doorSealed = false

    // MARK: - Rooms

    let study = Location {
        name("The Study")
    }

    let gallery = Location {
        name("The Long Gallery")
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
        description(
            """
            The master's working book, bound in cracked leather, the pages dense with his careful hand. The margins \
            are crowded with notes to himself, which is the nearest he comes to conversation. You could read them.
            """)
    }

    /// The shadowed niche beside the warded door: examinable scenery whose
    /// description carries the **glow** clue, and tracks the scroll's fate.
    let niche = Item {
        name("shadowed niche")
        adjectives("shadowed", "dark")
        synonyms("niche", "alcove", "shadow")
        scenery
    }

    /// Hidden in the niche until **glow** reveals it — so the cantrip is not
    /// mere flavour: without it the scroll is never found.
    let scroll = Item {
        name("passwall scroll")
        adjectives("passwall")
        synonyms("scroll", "parchment")
        description(
            "A single spell inked on brittle parchment: passwall, good for exactly one reading. Handle it accordingly.")
        hidden
    }

    /// Starts open with its wards dormant; a draught from the study window
    /// seals it a few turns in (see `timers`), which is when the puzzle begins.
    let wardedDoor = Item {
        name("warded door")
        adjectives("warded", "heavy")
        synonyms("door")
        scenery
        openable
        startsOpen
    }

    let graniteWall = Item {
        name("granite wall")
        adjectives("granite", "blank", "dressed")
        synonyms("wall", "stone")
        scenery
        openable
    }

    let golem = Actor {
        name("clay golem")
        adjectives("clay", "hulking", "raw")
        synonyms("guardian")
        description(
            """
            A hulking figure of raw clay, planted between you and the amulet's hook. It has the patient look of \
            something with no other engagements.
            """)
        trait(.combustible, true)
    }

    /// The open study window — the quiet culprit whose draught seals the door.
    /// Scenery, hiding in plain sight until the master names it at the end.
    let window = Item {
        name("study window")
        adjectives("study", "open")
        synonyms("window")
        scenery
        description(
            """
            The study window stands open to the morning. A pleasant draught comes and goes. It is the least suspicious \
            thing in the tower.
            """)
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

    /// The inciting event: the warded door seals itself a few turns in. It
    /// fires only while the apprentice is in the study — if it caught them in
    /// the gallery they would be sealed out with the spellbook still on the
    /// desk — so the fuse re-arms and waits whenever they have wandered off.
    var timers: [TimedEvent] {
        fuse("doorSeals", after: 2, autostart: true) {
            guard player.location == study else {
                startFuse("doorSeals", after: 1)  // wait until the apprentice is back
                return
            }
            wardedDoor.isOpen = false
            doorSealed = true
            say(
                """
                Behind you, the warded door meets its frame with a boom that rattles the inkwells. The warding-marks \
                flare and settle into a steady burn: the wards lock of their own accord whenever the door closes — a \
                feature the master has always been rather proud of. You touched nothing. There will be time to \
                establish that later. The pressing matter is that the amulet is now on the far side of a sealed door, \
                and your instructions were not ambiguous.
                """)
        }
    }

    var actions: [IntentAction] {
        // Cantrip — free, at-will. Reveals the hidden scroll in the study.
        magic.spell(.glow, cost: .cantrip) {
            if player.location == study, !scroll.isRevealed {
                scroll.reveal()
                say("Pale light seeps from your fingers, and in the niche it finds a rolled parchment.")
            } else {
                say(
                    """
                    Pale light seeps from your fingers, but there is nothing hidden here to find. The spell has done \
                    its part; the venue was your idea.
                    """)
            }
        }

        // Memorized — learned from the spellbook, spent on the casting.
        magic.spell(.unbar, cost: .prepared(book: spellbook, learnVia: .learnUnbar)) {
            try require(
                !wardedDoor.isOpen,
                else: "The warded door already stands open; it needs nothing further from you.")
            wardedDoor.isOpen = true
            say(
                """
                You speak the unbinding, correctly, on the first attempt. The warding-marks gutter and die, and the \
                door drifts open.
                """)
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
            say(
                """
                Fire leaps from your hand and bursts against the golem; it slumps to rubble, and behind it the amulet \
                gleams on its hook.
                """
            )
        }

        // Scroll — one reading, then the parchment is spent. Refusals abort
        // before the cost is paid, so a cast away from the wall (or after it
        // is open) never wastes the scroll.
        magic.spell(.passwall, cost: .scroll(scroll)) {
            try require(
                player.location == gallery,
                else:
                    "You begin the reading, then stop: the working wants a "
                    + "wall of stone before you, and there is none here. The scroll survives the false start.")
            try require(
                !graniteWall.isOpen,
                else: "The granite has already been opened; once was sufficient.")
            graniteWall.isOpen = true
            say(
                """
                You read the scroll and it crumbles to ash — but the granite before you turns to a soft grey mist you \
                can step through.
                """
            )
        }
    }

    var rules: Rules {
        // The rooms and barriers describe themselves by their state, so a
        // solved gate is visible the next time the player looks.
        study.describe {
            wardedDoor.isOpen
                ? """
                A close, candle-warm room walled in books. The heavy door in the west wall stands open, its \
                warding-marks dark; beside it, the shadowed niche.
                """
                : """
                A close, candle-warm room walled in books. A heavy door stands shut in the west wall, its frame cut \
                with old warding-marks; beside it, a shadowed niche.
                """
        }
        gallery.describe {
            graniteWall.isOpen
                ? """
                A cold stone gallery. The way east runs back to the study. To the north, where the granite wall stood, \
                an archway of grey mist breathes cellar-cold air.
                """
                : """
                A cold stone gallery. The way east runs back to the study; to the north the passage is stopped by a \
                blank wall of dressed granite, fitted so close a knife could not find the seams. You are, for \
                reference, larger than a knife.
                """
        }
        wardedDoor.describe {
            wardedDoor.isOpen
                ? "The warding-marks are dark and dead. The door stands open on the gallery."
                : "A stout door, held shut by the warding-marks cut into its frame. It is not locked in any sense a key could improve."
        }
        graniteWall.describe {
            graniteWall.isOpen
                ? """
                Where the granite stood there hangs a soft grey mist, cool as cellar air. You could walk through it as \
                through a curtain.
                """
                : "A wall of dressed granite, seamless and cold. No door, no crack — just stone."
        }
        niche.describe {
            if !scroll.isRevealed {
                """
                A niche cut shoulder-high into the stone beside the door. The shadow in it lies deeper than any candle \
                can account for; if something rests there, no unaided eye will find it.
                """
            } else if !scroll.isHeld {
                "The shadow has been persuaded to give up its secret: a rolled parchment rests in the niche."
            } else {
                "An empty niche cut shoulder-high into the stone. What it kept, you carry now. Do try not to lose it."
            }
        }

        // The book is read state-by-state: each read is the apprentice hunting
        // for the thing he thinks he needs and blundering into the thing the
        // player actually needs. One accidental discovery per obstacle, in
        // chain order, so the words arrive as they become useful and never
        // all at once. Before the door seals, nothing is wrong and the book
        // knows it.
        spellbook.before(.read) {
            if !doorSealed {
                try reply(
                    """
                    You leaf through the book out of a sense of duty. It offers you a treatise on the correct storage \
                    of newts. Nothing is currently wrong, and the book appears to know it.
                    """)
            } else if !scroll.isRevealed {
                try reply(
                    """
                    You search the book for anything on warded doors. The index proceeds from "divination" directly to \
                    "drowning, avoidance of", with no stop for doors; the wards go unmentioned. What your flipping \
                    does shake loose is a cantrip called glow — a small finding-light, the note says, for what the eye \
                    alone will miss. You asked for a way through a door and have been issued a nightlight. Still, the \
                    master has never yet wasted ink. Probably.
                    """)
            } else if !wardedDoor.isOpen {
                try reply(
                    """
                    You put the question of doors to the book a second time, and this time it relents: unbar, the \
                    unbinding, for doors that wards hold fast. Then the small print. It must be memorized fresh, book \
                    in hand, and it is spent in the speaking — one door per sitting. The master calls this discipline. \
                    You have other words for it.
                    """)
            } else if !graniteWall.isOpen {
                try reply(
                    """
                    You consult the book on walls of dressed granite. Nothing. The master has evidently never met a \
                    wall he thought worth writing about, which says something about how he deals with them. What you \
                    do find, doing duty as a bookmark, is a stationer's receipt: one parchment, best quality. His \
                    filing defies comment.
                    """)
            } else if !amulet.isRevealed {
                try reply(
                    """
                    You go through the pages at speed, looking for anything at all on golems, and find only a spell \
                    related to pottery: firebolt, filed under the firing of kilns, with a note that raw clay cannot \
                    abide it. A further advisory states that the fire is drawn from your own reserves, and that a rest \
                    afterwards is "earned". So — nothing on golems, then. You are, however, now unusually well \
                    informed about earthenware.
                    """)
            } else {
                try reply(
                    """
                    You flip through the book in a spirit of triumph, looking for nothing in particular. For once it \
                    has nothing to teach you. You decide to enjoy the feeling while it lasts.
                    """)
            }
        }

        // The barriers yield only to magic: no ordinary hand opens them, so the
        // spells are the only way through — and each refusal points at the way.
        // While the door is still open (dormant, or already unbarred), there is
        // simply nothing to force.
        wardedDoor.before(.open) {
            if wardedDoor.isOpen {
                try reply("The warded door already stands open; it needs nothing further from you.")
            }
            try reply(
                """
                The warding-marks hold the door fast; no amount of pulling will embarrass them into moving. Marks like \
                these are made to be unmade — the master's book would know the word.
                """)
        }
        graniteWall.before(.open) {
            try reply(
                """
                You push; the wall declines to notice. It was built by someone who knew what they were doing, which \
                puts you at a disadvantage. Still, what a mason fitted a mage may unfit, and stone keeps other laws \
                than doors do.
                """)
        }

        // The amulet is out of reach until the golem is dealt with; the reveal
        // in firebolt's effect is what actually makes it takable. Taking it
        // brings the master back — through his own dispersed wall — to explain
        // the draught and, to your relief, to laugh.
        amulet.after(.take) {
            player.score += 10
            say(
                """
                You lift the master's amulet from its hook. Secure at last — held personally by the one responsible \
                for its safety, which is nearly the same thing.

                Behind you, someone clears his throat.

                The master stands in the archway that was, until recently, his granite wall. He takes a slow \
                inventory: the warded door unbound, the wall dispersed, the golem redistributed evenly across the \
                floor, and his amulet in your fist. "The window," he says at last, mildly. "I have asked you before to \
                keep it shut. A draught takes that door, and the wards see to the rest." He regards the rubble that \
                was, as of this morning, the finest guardian clay can make. And then, to your lasting relief, he \
                begins — quite helplessly — to laugh.
                """)
            try end(won: true)
        }
    }

    var map: WorldMap {
        study.west(gallery, via: wardedDoor)
        gallery.east(study, via: wardedDoor)
        gallery.north(undercroft, via: graniteWall)
        undercroft.south(gallery, via: graniteWall)

        // You were left to mind the tower; the road is not an option.
        study.out(
            blocked:
                "You were left to mind the tower. A tower cannot be minded from the road, however much you might prefer to try."
        )
        study.down(
            blocked:
                "You were left to mind the tower. A tower cannot be minded from the road, however much you might prefer to try."
        )

        player.starts(in: study)
        spellbook.starts(in: study)
        niche.starts(in: study)
        scroll.starts(in: study)
        wardedDoor.starts(in: study)
        window.starts(in: study)
        graniteWall.starts(in: gallery)
        golem.starts(in: undercroft)
        amulet.starts(in: undercroft)
    }
}

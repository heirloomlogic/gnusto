import Gnusto
import GnustoScoring
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
    /// One award, paid on taking the amulet. It is declared in ``scoring``'s
    /// table rather than added to the score by hand, so the bootstrap can check
    /// this literal against what the game can actually pay.
    let maxScore = 10
    let intro = """
        The tower has been in an uproar since dawn — cloak, staff, letters, a hat he cannot find because he is wearing
        it. The Circle has summoned your master, and the Circle does not care to wait.

        At the threshold he stops, turns back, and takes hold of you, fixing you with the look he otherwise
        reserves for cracked cauldrons. "The amulet," he says. "Is it secret? Is it safe?" He then reminds you, at
        some volume, that it hangs on its hook in the undercroft, behind the warded door — which rather settles the
        first question. Should anything happen while he is away — anything at all — you are to see that it remains
        secure.

        And he is gone, down the hill at a pace that does not suit his robes, leaving you to mind the tower on the
        theory that nothing ever happens here.

        The master's spellbook is on the desk. It knows more magic than you do, though in fairness, so does the door.
        """

    let magic = Spellcasting(memorySlots: 3, maxMana: 12)

    /// The game's single award. Not a scoring demo — one register, declared so
    /// that ``maxScore`` is checked rather than trusted.
    let scoring = Scoring(awards: ["amulet": 10])

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

    /// Two states, so its `describe` rule lives in ``rules`` and it declares no
    /// static `description` — the two are mutually exclusive.
    let undercroft = Location {
        name("The Undercroft")
    }

    // MARK: - Items

    let spellbook = Item {
        name("spellbook")
        adjectives("master", "leather")
        // Every noun the book's own description and its six read rungs put on
        // the page. They all answer with the description below, which is why
        // the description names the receipt and the index rather than leaving
        // them to be discovered only in a rung the player may never reach.
        synonyms(
            "book", "pages", "page", "margins", "margin", "notes", "note",
            "leather", "binding", "index", "receipt", "bookmark", "newts")
        description(
            """
            The master's working book, bound in cracked leather, the pages dense with his careful hand. The margins
            are crowded with notes to himself, which is the nearest he comes to conversation; a stationer's receipt
            keeps his place, and the index proceeds from "divination" directly to "drowning, avoidance of". You could
            read it.
            """)
    }

    /// The shadowed niche beside the warded door: examinable scenery whose
    /// description carries the **glow** clue, and tracks the scroll's fate.
    ///
    /// A `container`, because the scroll is genuinely inside it — `search
    /// niche` refuses anything that isn't one, and the room listing has to
    /// agree with what `x niche` says. Not `openable`: a container that isn't
    /// openable is always open, which a hole in a wall is.
    let niche = Item {
        name("shadowed niche")
        adjectives("shadowed", "dark")
        synonyms("niche", "alcove", "shadow")
        scenery
        container
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
        synonyms("door", "frame")
        scenery
        openable
        startsOpen
    }

    /// The marks the whole first puzzle is about, named in six passages and
    /// until now not a word the parser knew: the tokenizer splits the hyphen
    /// the prose writes, so `name("warding marks")` — adjective `warding`,
    /// noun `marks` — is what makes `x warding-marks` parse.
    ///
    /// Declared here rather than in ``Fixtures`` because its two states read
    /// the door, and a bundle cannot see the host's items.
    let wardingMarks = Item {
        name("warding marks")
        adjectives("old")
        synonyms("mark", "wards", "ward", "warding", "sigils", "sigil", "markings")
        scenery
    }

    let graniteWall = Item {
        name("granite wall")
        adjectives("granite", "blank", "dressed")
        // Both states of the same item: the granite, and the mist that replaces
        // it. One item, so the gallery's two descriptions answer to one noun
        // set. Not `stone` — the gallery is made of the stuff, and the room's
        // own stonework has the better claim on the bare word.
        synonyms(
            "wall", "granite", "seams", "seam", "passage",
            "mist", "archway", "arch", "curtain")
        scenery
        openable
    }

    let golem = Actor {
        name("clay golem")
        adjectives("clay", "hulking", "raw")
        synonyms("guardian", "clay")
        description(
            """
            A hulking figure of raw clay, planted between you and the amulet's hook. It has the patient look of
            something with no other engagements.
            """)
        trait(.combustible, true)
    }

    /// The open study window — the quiet culprit whose draught seals the door.
    /// Scenery, hiding in plain sight until the master names it at the end.
    let window = Item {
        name("study window")
        adjectives("study", "open")
        synonyms("window", "draught", "draft", "breeze", "air", "morning")
        scenery
        description(
            """
            The study window stands open to the morning. A pleasant draught comes and goes. It is the least suspicious
            thing in the tower.
            """)
    }

    /// Hidden behind the golem's bulk until **firebolt** clears it, and hanging
    /// on ``Fixtures/hook`` rather than lying on the floor, because the intro,
    /// firebolt's success line and the ending all say it hangs.
    let amulet = Item {
        name("silver amulet")
        adjectives("silver", "master")
        synonyms("amulet", "talisman", "moon", "chain")
        description("The master's amulet, a moon of worn silver on a fine chain.")
        hidden
    }

    /// What is left of the golem. The ending inventories it as "redistributed
    /// evenly across the floor" and the master regards it, so it has to be on
    /// the floor to be regarded; `hidden` until the firebolt makes it.
    let rubble = Item {
        name("rubble")
        adjectives("baked", "fired")
        synonyms("clay", "shards", "shard", "fragments", "pieces", "dust")
        description(
            """
            An even layer of fired clay across the flags, still warm, in pieces small enough that nobody is going to
            be putting it back together. The master will have views.
            """)
        scenery
        hidden
    }

    // MARK: - Composition

    /// The nouns the tower's prose prints and nothing else answered to. A
    /// bundle rather than another screenful of stored properties here; see
    /// ``Fixtures``.
    let fixtures = Fixtures()

    var content: GameContents {
        magic
        scoring
        fixtures
    }

    var verbs: [SyntaxRule] {
        [.glow, .unbar, .firebolt, .passwall, .learnUnbar]
    }

    /// The inciting event: the warded door seals itself a few turns in. It
    /// fires only while the apprentice is in the study — if it caught them in
    /// the gallery they would be sealed out with the spellbook still on the
    /// desk — so the fuse re-arms and waits whenever they have wandered off.
    ///
    /// And it stands down entirely if the door is already shut, because the
    /// only way that happens is that the apprentice shut it himself, and a slam
    /// that insisted "You touched nothing" over his own hand on the door would
    /// be the game telling him a lie about the last thing he did.
    var timers: [TimedEvent] {
        fuse("doorSeals", after: 2, autostart: true) {
            guard player.location == study else {
                startFuse("doorSeals", after: 1)  // wait until the apprentice is back
                return
            }
            guard wardedDoor.isOpen else { return }  // he got there first
            sealTheDoor()
            say(
                """
                Behind you, the warded door meets its frame with a boom that rattles the inkwells. The warding-marks
                flare and settle into a steady burn: the wards lock of their own accord whenever the door closes — a
                feature the master has always been rather proud of. You touched nothing. There will be time to
                establish that later. The pressing matter is that the amulet is now on the far side of a sealed door,
                and your instructions were not ambiguous.
                """)
        }
    }

    /// Shuts the door and records that the wards have caught, in that order and
    /// always together.
    ///
    /// Two things close this door — the draught and the apprentice — and the
    /// book's read ladder keys its first rung on `doorSealed`, not on the door's
    /// position, because "nothing is wrong yet" and "open again because you
    /// unbarred it" look identical to `isOpen`. A closer that set one and forgot
    /// the other would freeze the book on *Nothing is currently wrong* with the
    /// amulet sealed away, which is the defect this pairing exists to prevent.
    private func sealTheDoor() {
        wardedDoor.isOpen = false
        doorSealed = true
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
                    Pale light seeps from your fingers, but there is nothing hidden here to find. The spell has done
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
                You speak the unbinding, correctly, on the first attempt. The warding-marks gutter and die, and the
                door drifts open.
                """)
        }

        // Energy — draws from the mana pool; hurled at a target.
        magic.spell(.firebolt, cost: .energy(4)) {
            guard let target = command.directObject else {
                try reply("Cast firebolt at what?")
            }
            guard !target.isPlayer else {
                try reply(
                    """
                    You consider it, briefly, and then don't. The book is silent on apprentices who set fire to
                    themselves, which is itself a kind of advice.
                    """)
            }
            // `definiteName` and not "the \(name)": the article is the engine's,
            // chosen from the `properName` trait. The line used to write its own
            // and answer `firebolt me` with "the yourself"; the guard above is
            // what handles the player now, and this is what keeps the same
            // mistake from arriving with the first proper-named target.
            try require(
                target[.combustible] == true,
                else: "The firebolt washes over \(target.definiteName) and leaves it untouched.")
            target.vanish()
            rubble.reveal()
            amulet.reveal()
            say(
                """
                Fire leaps from your hand and bursts against the golem; it slumps to rubble, and behind it the amulet
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
                else: """
                    You begin the reading, then stop: the working wants a wall of stone
                    before you, and there is none here. The scroll survives the false start.
                    """)
            try require(
                !graniteWall.isOpen,
                else: "The granite has already been opened; once was sufficient.")
            graniteWall.isOpen = true
            say(
                """
                You read the scroll and it crumbles to ash — but the granite before you turns to a soft grey mist you
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
                A close, candle-warm room walled in books. The heavy door in the west wall stands open, its
                warding-marks dark; beside it, the shadowed niche.
                """
                : """
                A close, candle-warm room walled in books. A heavy door stands shut in the west wall, its frame cut
                with old warding-marks; beside it, a shadowed niche.
                """
        }
        gallery.describe {
            graniteWall.isOpen
                ? """
                A cold stone gallery. The way east runs back to the study. To the north, where the granite wall stood,
                an archway of grey mist breathes cellar-cold air.
                """
                : """
                A cold stone gallery. The way east runs back to the study; to the north the passage is stopped by a
                blank wall of dressed granite, fitted so close the seams are a matter of faith. You are, for
                reference, not a matter of faith.
                """
        }
        // Two states, like the other two rooms: the way back, the hook the
        // ending says the amulet was lifted from, and — once the firebolt has
        // been thrown — what is left on the floor for the master to regard.
        //
        // The second state appends rather than rewrites, so the room is written
        // once — the study and the gallery diverge from their first clause and
        // are two paragraphs, this one is one paragraph and a consequence.
        undercroft.describe {
            let cellar = """
                A low vaulted cellar, the air chalky with old magic. The gallery is back the way you came, to the
                south; at the far end, an iron hook is driven into the stone at head height.
                """
            return golem.isIn(undercroft)
                ? cellar
                : """
                \(cellar) Between here and there, the floor wears an even layer of what used to
                be a golem.
                """
        }
        wardingMarks.describe {
            wardedDoor.isOpen
                ? """
                Cut deep into the door's frame and dark all the way along, the way a thing is dark when it has
                finished. Whatever they are made of, it is not ink.
                """
                : """
                Cut deep into the door's frame and burning steadily along every stroke, without smoke and without
                heat. They are not doing anything, in the sense that a locked door is not doing anything.
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
                Where the granite stood there hangs a soft grey mist, cool as cellar air. You could walk through it as
                through a curtain.
                """
                : "A wall of dressed granite, seamless and cold. No door, no crack — just stone."
        }
        // Four states, not three. The old ladder asked whether the scroll was
        // *held*, so the spent scroll — `vanish()`ed by the reading — fell into
        // the branch written for "revealed and not yet picked up" and went on
        // advertising a parchment that was ash. `niche.holds` asks where the
        // thing actually is, and the last rung is what is true once it is
        // nowhere.
        niche.describe {
            if !scroll.isRevealed {
                """
                A niche cut shoulder-high into the stone beside the door. The shadow in it lies deeper than any candle
                can account for; if something rests there, no unaided eye will find it.
                """
            } else if niche.holds(scroll) {
                "The shadow has been persuaded to give up its secret: a rolled parchment rests in the niche."
            } else if scroll.isHeld {
                "An empty niche cut shoulder-high into the stone. What it kept, you carry now. Do try not to lose it."
            } else {
                """
                An empty niche cut shoulder-high into the stone. What it kept is out of it, and out of your hands too,
                and the shadow has gone back to keeping nothing.
                """
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
                    You leaf through the book out of a sense of duty. It offers you a treatise on the correct storage
                    of newts. Nothing is currently wrong, and the book appears to know it.
                    """)
            } else if !scroll.isRevealed {
                try reply(
                    """
                    You search the book for anything on warded doors. The index proceeds from "divination" directly to
                    "drowning, avoidance of", with no stop for doors; the wards go unmentioned. What your flipping
                    does shake loose is a cantrip called glow — a small finding-light, the note says, for what the eye
                    alone will miss. You asked for a way through a door and have been issued a nightlight. Still, the
                    master has never yet wasted ink. Probably.
                    """)
            } else if !wardedDoor.isOpen {
                // No "a second time": the ladder is keyed on world state, and
                // `glow` can be cast without ever opening the book, so a rung
                // that back-referenced the rung above it would narrate a read
                // the player never saw.
                try reply(
                    """
                    You put the question of doors to the book, and the book relents: unbar, the unbinding, for doors
                    that wards hold fast. Then the small print. It must be memorized fresh, book in hand, and it is
                    spent in the speaking — one door per sitting. The master calls this discipline. You have other
                    words for it.
                    """)
            } else if !graniteWall.isOpen {
                try reply(
                    """
                    You consult the book on walls of dressed granite. Nothing. The master has evidently never met a
                    wall he thought worth writing about, which says something about how he deals with them. What you
                    do find, doing duty as a bookmark, is a stationer's receipt: one parchment, best quality. His
                    filing defies comment.
                    """)
            } else if !amulet.isRevealed {
                try reply(
                    """
                    You go through the pages at speed, looking for anything at all on golems, and find only a spell
                    related to pottery: firebolt, filed under the firing of kilns, with a note that raw clay cannot
                    abide it. A further advisory states that the fire is drawn from your own reserves, and that a rest
                    afterwards is "earned". So — nothing on golems, then. You are, however, now unusually well
                    informed about earthenware.
                    """)
            } else {
                try reply(
                    """
                    You flip through the book in a spirit of triumph, looking for nothing in particular. For once it
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
                The warding-marks hold the door fast; no amount of pulling will embarrass them into moving. Marks like
                these are made to be unmade — the master's book would know the word.
                """)
        }
        graniteWall.before(.open) {
            // The same `isOpen` guard the door has twenty lines up. Without it
            // the hint went on being offered after the mage had unfit the
            // stone and the only means of doing so was ash.
            if graniteWall.isOpen {
                try reply(
                    "The mist parts around your hand and closes behind it. There is nothing left here to open.")
            }
            try reply(
                """
                You push; the wall declines to notice. It was built by someone who knew what they were doing, which
                puts you at a disadvantage. Still, what a mason fitted a mage may unfit, and stone keeps other laws
                than doors do.
                """)
        }

        // Both barriers refuse to be shut into an unwinnable game. This is the
        // player-driven half of the guard the `doorSeals` fuse already carries:
        // the fuse waits for the apprentice to be on the book's side of the
        // door, and so, now, does the apprentice.
        wardedDoor.before(.close) {
            if !wardedDoor.isOpen {
                try reply("It is shut, and the warding-marks are seeing to it.")
            }
            // Not a warning and not a death: he simply declines. The wards catch
            // whenever this door shuts, and everything that could unmake them is
            // in the book.
            try require(
                spellbook.isReachable,
                else: """
                    You put a hand to the door and think better of it. These wards catch of their own accord whenever
                    it shuts, and the master's book is on the wrong side of it. There is a version of this morning
                    where you do that anyway, and you would rather not live in it.
                    """)
            sealTheDoor()
            try reply(
                """
                You push the door to. The warding-marks take light and settle into a steady burn — the wards lock of
                their own accord, a feature the master has always been rather proud of. The book, at least, is on
                this side.
                """)
        }
        graniteWall.before(.close) {
            // Refused outright rather than conditionally, because `passwall` is
            // the only writer that can open the granite again and the scroll is
            // ash by the time anybody could try this. Every path refuses; the
            // state only picks which words.
            try refuse(
                graniteWall.isOpen
                    ? """
                    You reach for the mist and your hand goes through it. Whatever the working did to the granite, it
                    did not leave you anything to take hold of.
                    """
                    : "The granite is as shut as granite gets.")
        }

        // The book files firebolt under the firing of kilns and notes that raw
        // clay cannot abide it, so the stock "you have no way to set fire to
        // this" is the one thing the game must not say about the golem.
        // `reply`, not `say`: stage 4 uses `say`, and both lines would print.
        golem.before(.burn) {
            try reply(
                """
                You have nothing to set it alight with, and nothing in the undercroft does either. Fire, if it is
                coming, will have to come out of you.
                """)
        }

        // The amulet is out of reach until the golem is dealt with; the reveal
        // in firebolt's effect is what actually makes it takable. Taking it
        // brings the master back — through his own dispersed wall — to explain
        // the draught and, to your relief, to laugh.
        amulet.after(.take) {
            scoring.awardOnce("amulet")
            // The inventory is of the world he is standing in, so the one item
            // of it the player can still change has to be read rather than
            // assumed. The wall is safe to assert: nothing can close it, and
            // he is standing in the hole.
            let door =
                wardedDoor.isOpen
                ? "the warded door unbound"
                : "the warded door shut again and burning quietly to itself"
            say(
                """
                You lift the master's amulet from its hook. Secure at last — held personally by the one responsible
                for its safety, which is nearly the same thing.

                Behind you, someone clears his throat.

                The master stands in the archway that was, until recently, his granite wall. He takes a slow
                inventory: \(door), the wall dispersed, the golem redistributed evenly across the floor, and his
                amulet in your fist. "The window," he says at last, mildly. "I have asked you before to keep it shut.
                A draught takes that door, and the wards see to the rest." He regards the rubble that was, as of this
                morning, the finest guardian clay can make. And then, to your lasting relief, he begins — quite
                helplessly — to laugh.
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
        niche.starts(in: study)
        wardedDoor.starts(in: study)
        wardingMarks.starts(in: study)
        window.starts(in: study)
        graniteWall.starts(in: gallery)
        golem.starts(in: undercroft)
        rubble.starts(in: undercroft)

        // Where the prose says these are. The intro's one instruction is "The
        // master's spellbook is on the desk"; the niche's whole job is to be
        // where the scroll is; and the amulet has hung on its hook since the
        // master shouted about it from the threshold.
        spellbook.starts(on: fixtures.desk)
        scroll.starts(inside: niche)
        amulet.starts(on: fixtures.hook)

        // The nouns the tower's prose prints. A bundle can only place into
        // rooms it can name, and these are ours.
        fixtures.desk.starts(in: study)
        fixtures.books.starts(in: study)
        fixtures.studyWalls.starts(in: study)
        fixtures.candle.starts(in: study)
        fixtures.cauldrons.starts(in: study)
        fixtures.master.starts(in: study)
        fixtures.hill.starts(in: study)
        fixtures.galleryStone.starts(in: gallery)
        fixtures.vault.starts(in: undercroft)
        fixtures.hook.starts(in: undercroft)
    }
}

import Gnusto

/// The nouns the tower's own prose puts on the page.
///
/// A room that names a thing and then doesn't know the word for it reads like a
/// bug, and Gramarye's opening paragraph alone names thirteen. None of these is
/// a puzzle and none is takeable — they exist so that `X DESK` gets an answer
/// instead of *I don't know the word "desk"*.
///
/// They live in a ``GameContent`` bundle because ten more scenery items would
/// otherwise be a quarter of the host file. The host places them: a bundle can
/// only place into rooms it can *name*, and the rooms are ``Gramarye``'s.
///
/// What is *not* here is anything whose text depends on host state. The warding
/// marks read the door and the rubble is revealed by a spell, so both live with
/// the things they answer to.
///
/// A note on what is declared and what is derived: a `name` already contributes
/// its last word as a noun and every earlier word as an adjective, so
/// `name("iron hook")` needs neither `adjectives("iron")` nor `synonyms("hook")`.
/// The extra lines are for the words the prose prints that the name doesn't
/// reach — and the last word of a typed phrase has to be a noun, which is why
/// `stone` is a synonym on things that already have it as an adjective.
struct Fixtures: GameContent {
    // MARK: - The study

    /// Where the intro says the spellbook is, and therefore the first thing a
    /// player reaches for. A `surface`, so the book can actually be on it and
    /// the room listing says so.
    let desk = Item {
        name("desk")
        adjectives("writing", "littered")
        synonyms("table", "inkwells", "inkwell", "ink", "quills", "quill")
        description(
            """
            A working surface under a working man's idea of order: inkwells at three
            different levels of evaporation, quills he has given up on, and a clear patch
            in the middle exactly the size of the book.
            """)
        surface
        scenery
    }

    /// Not `book`: the spellbook owns that word, the intro tells the player to
    /// go and read it, and a shelf full of the ones he never opens has the
    /// weaker claim.
    let books = Item {
        name("books")
        adjectives("shelved", "bound")
        synonyms("shelves", "shelf", "volumes", "volume", "library")
        description(
            """
            Wall to wall and floor to ceiling, spines in nine languages and at least one
            alphabet you would rather not look at directly. Not one of them is the one on
            the desk, which is the only one he ever opens.
            """)
        scenery
    }

    let studyWalls = Item {
        name("study wall")
        adjectives("west", "warm")
        synonyms("wall", "walls", "stone", "stones", "tower", "room", "study")
        description(
            """
            Tower stone, warm from the candle and from three centuries of somebody being
            in here. The west wall is the one with the door in it, and the door is the one
            with the opinions.
            """)
        scenery
    }

    let candle = Item {
        name("candle")
        adjectives("burning", "tallow")
        synonyms("candles", "candlelight", "flame")
        description(
            """
            Burning steadily on a saucer of its own drippings. It has been lit since dawn
            and shows every sign of intending to outlast the morning.
            """)
        scenery
    }

    let cauldrons = Item {
        name("cauldrons")
        adjectives("cracked", "stacked")
        synonyms("cauldron", "pots", "pot", "stack")
        description(
            """
            Stacked in the corner, three deep, two of them cracked clean through. You know
            precisely what the look he gave you at the threshold meant, because you have
            seen him give it to these.
            """)
        scenery
    }

    /// The master, and everything he left with. One description that is true of
    /// all of them, because all of them went down the hill in the same hurry.
    let master = Item {
        name("master")
        adjectives("absent", "hurrying")
        synonyms("wizard", "mage", "cloak", "staff", "hat", "robes", "robe", "letters", "letter", "circle")
        description(
            """
            Halfway to the Circle by now, in the cloak, the robes, and the hat he found in
            the end by taking it off his own head, with the staff in one hand and their
            letters in the other. The Circle does not care to wait, and he has never once
            asked it to.
            """)
        scenery
    }

    /// Visible from the open window, which is also the road the blocked exits
    /// refuse to let you take.
    let hill = Item {
        name("hill")
        adjectives("green", "steep")
        synonyms("road", "track", "lane", "path", "slope")
        description(
            """
            Green, steep, and going down to a road with nobody on it. He was making better
            time than the robes deserved, and there is no sign of him coming back up.
            """)
        scenery
    }

    // MARK: - The long gallery

    /// Not `wall`, and not `granite`: the only wall the gallery's prose names is
    /// the barrier at the north end, and a second claim on the word turns
    /// `OPEN WALL` — the refusal that clues the whole scroll puzzle — into a
    /// disambiguation question.
    let galleryStone = Item {
        name("gallery")
        adjectives("cold", "long")
        synonyms("walls", "stone", "stones", "stonework", "tower", "air")
        description(
            """
            Cold tower stone, unrelieved for the whole length of the gallery. Nobody has
            ever hung anything here or wanted to stand here, and the air knows it.
            """)
        scenery
    }

    // MARK: - The undercroft

    let vault = Item {
        name("vaulting")
        adjectives("low", "chalky")
        synonyms("vault", "cellar", "ceiling", "stone", "stones", "tower", "air", "magic", "undercroft")
        description(
            """
            Low ribs of stone springing from the floor and meeting overhead, chalky to look
            at and chalkier to breathe. The magic down here is nobody's in particular any
            more; it has simply been worked into the air by everyone who ever came down.
            """)
        scenery
    }

    /// Named in the intro, in `firebolt`'s success line, and in the ending, and
    /// until now not a word the one room containing it knew. A `surface`, so the
    /// amulet hangs on it rather than lying on the floor beside it.
    let hook = Item {
        name("iron hook")
        adjectives("plain", "bent")
        synonyms("peg", "nail")
        description(
            """
            Driven into the vault stone at head height and bent up at the tip. The last of
            the master's security arrangements, and by some distance the least ingenious.
            """)
        surface
        scenery
    }
}

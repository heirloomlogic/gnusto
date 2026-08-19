import Gnusto

/// The nouns the mine prints and could not answer.
///
/// The 2026-08-02 play-test round counted about sixty distinct words over 286
/// occurrences that this game's own prose put on the page and the parser had
/// never heard of — `wall` 28 times, `entry` 21, `frame` 19. Per CLAUDE.md,
/// every noun a room description prints must be answerable; a named thing the
/// parser doesn't know reads as a bug.
///
/// Most of that census closes as a synonym on something that already exists, and
/// those are declared on the items themselves in ``KindlyDeep``. These are the
/// words with nothing to hang on. None is a puzzle, none is takeable, none is
/// listed: they exist so that `X ENTRY` — the single most-printed noun in the
/// game, in four room descriptions and twice in the intro — gets an answer.
///
/// What is deliberately **absent** is the third of the census that the design doc
/// rules out: a noun naming something *outside* the workings is a referent, not
/// scenery. The stable boss, the trip and its cars, the cager, the hoisting
/// engineer, the men timbering in from the far side, the dinner bucket under the
/// rock — all real in the fiction, none of them here, and giving each one an item
/// to be examined would make the game worse rather than more complete.
///
/// They live in a ``GameContent`` bundle on ``Fulminate``'s precedent: seventeen
/// more items would otherwise push the host past twelve hundred lines. The host
/// places them, because a bundle can only place into rooms it can *name*.
///
/// One deliberate ambiguity: at the Shaft Bottom both the cage gate and the
/// air-door answer to `frame`, because the room has two framed things in it and
/// says so. "Which do you mean: the air-door or the cage gate?" is the right
/// answer to that, not a defect.
struct Fixtures: GameContent {
    // MARK: - The entry, four times over

    // The roadway itself: the thing the player is standing in, in four of the six
    // rooms and twice in the intro, and unanswerable in every one of them. It
    // needs an item per room rather than one shared item, because there is no
    // backdrop scenery in this engine — and each stretch of it has a different
    // thing to say anyway.

    let fallEntry = Item {
        name("entry")
        synonyms("entries", "roadway")
        description(
            """
            The main entry, which stops here now. You have walked it in the dark twice a
            day for two years and could still walk it, if there were any of it left to
            walk.
            """)
        scenery
    }

    let stableEntry = Item {
        name("entry")
        synonyms("entries", "roadway")
        description(
            """
            The stable entry, running back east toward the fall. Wide enough for a mule
            and a loaded trip, and swept, because the stable boss holds views about that
            too.
            """)
        scenery
    }

    let shelterEntry = Item {
        name("entry")
        synonyms("entries", "roadway")
        description(
            """
            The entry runs past above you, back up to the north. Down here you are out of
            it, which is the entire architectural argument for a shelter hole.
            """)
        scenery
    }

    let forksEntry = Item {
        name("entry")
        synonyms("entries", "roadway")
        description(
            """
            The entry ends its useful career here, at the mouth of the old works. What
            continues east is a crawl, and what goes north is nobody's road any more.
            """)
        scenery
    }

    // MARK: - The Stable

    let stableWalls = Item {
        name("walls")
        adjectives("stable")
        synonyms("wall", "whitewash", "whitewashed", "stable")
        description(
            """
            Whitewashed, and recently. Lime over rock, laid on to throw what light there
            is back at you — a small kindness that costs a mine nothing and is therefore
            rarer than it should be.
            """)
        scenery
    }

    let stableFloor = Item {
        name("floor")
        adjectives("worn", "brick")
        synonyms("brick", "bricks", "paving")
        description(
            """
            Worn brick, laid in a herringbone by somebody who did not have to and swept
            by somebody who does. It is the only floor in these workings that is not
            simply whatever the rock left.
            """)
        scenery
    }

    // MARK: - The Shelter Hole

    let shelterRib = Item {
        name("rib")
        synonyms("shelter", "hole", "timbers", "floor")
        description(
            """
            The shelter hole is cut square into the rib and timbered honestly, which is
            more than can be said for some of this section. Its floor is dry, and dry is
            the whole of what it is selling.
            """)
        scenery
    }

    // MARK: - The Low Crawl

    let crawlRock = Item {
        name("rock")
        synonyms("stone", "sides", "roof", "wall", "walls", "floor", "shadow")
        description(
            """
            Rock above, rock below, and rock at both elbows, close enough that the lamp
            throws your own shadow across it and into your eyes. It is not going anywhere
            and neither, for the moment, are you.
            """)
        scenery
    }

    let crawlItself = Item {
        name("crawl")
        adjectives("low", "dark")
        synonyms("gap")
        description(
            """
            From the inside it is simply the shape you are: a gap the fall did not quite
            close, running east and west, and no wider anywhere than it is here.
            """)
        scenery
    }

    // MARK: - The Forks

    /// The fall reaches this far. It is the same event as the Fresh Fall's wall
    /// of rock — but that item is a room away, and the Forks' own paragraph names
    /// the fall twice while pointing at the gap along the edge of it.
    let forksFall = Item {
        name("fall")
        adjectives("fresh", "fallen")
        synonyms("rubble", "rock", "rocks")
        description(
            """
            The far edge of the same fall, come round the corner to meet you. It left the
            crawl the way a man leaves a tip: without meaning to, and not generously.
            """)
        scenery
    }

    // MARK: - The Shaft Bottom

    let shaftWall = Item {
        name("wall")
        synonyms("walls")
        description(
            """
            Rock, squared off where the sinkers squared it forty years ago, with the bell
            bolted to it at the height of a man's hand. Everything down here that matters
            is fixed to this wall.
            """)
        scenery
    }

    /// The crawl's other mouth. The room's own paragraph names it, now that the
    /// crawl runs both ways.
    let shaftCrawl = Item {
        name("crawl")
        adjectives("low", "dark")
        synonyms("gap", "floor")
        description(
            """
            The crawl comes out here at floor level, beside the air-door, looking from
            this side like exactly what it is: the way a man gets through, and nothing
            larger.
            """)
        scenery
    }

    // MARK: - The Old Works

    let oldProps = Item {
        name("props")
        adjectives("standing", "old")
        synonyms("prop", "timbers", "timber", "floor")
        description(
            """
            Props set forty years ago and still standing, which says something for the
            man who set them. The floor between them has not been walked on since, and
            shows it: undisturbed, and undisturbed a long while.
            """)
        scenery
    }

    let oldAir = Item {
        name("air")
        adjectives("sweet", "still")
        synonyms("sweetness", "quiet")
        description(
            """
            It smells faintly sweet, and it is perfectly still, and there is nothing
            whatever alarming about it to look at. That is the entire problem with it,
            and the reason a mule's nose outranks a man's opinion down here.
            """)
        scenery
    }
}

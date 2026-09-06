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

    let fallEntry = Item.backdrop(
        "entry",
        synonyms: ["entries", "roadway"],
        description:
            """
            The main entry, which stops here now. You have walked it in the dark twice a
            day for two years and could still walk it, if there were any of it left to
            walk.
            """
    )

    let stableEntry = Item.backdrop(
        "entry",
        synonyms: ["entries", "roadway"],
        description:
            """
            The stable entry, running back east toward the fall. Wide enough for a mule
            and a loaded trip, and swept, because the stable boss holds views about that
            too.
            """
    )

    let shelterEntry = Item.backdrop(
        "entry",
        synonyms: ["entries", "roadway"],
        description:
            """
            The entry runs past above you, back up to the north. Down here you are out of
            it, which is the entire architectural argument for a shelter hole.
            """
    )

    let forksEntry = Item.backdrop(
        "entry",
        synonyms: ["entries", "roadway"],
        description:
            """
            The entry ends its useful career here, at the mouth of the old works. What
            continues east is a crawl, and what goes north is nobody's road any more.
            """
    )

    // MARK: - The Stable

    let stableWalls = Item.backdrop(
        "walls",
        adjectives: ["stable"],
        synonyms: ["wall", "whitewash", "whitewashed", "stable"],
        description:
            """
            Whitewashed, and recently. Lime over rock, laid on to throw what light there
            is back at you — a small kindness that costs a mine nothing and is therefore
            rarer than it should be.
            """
    )

    let stableFloor = Item.backdrop(
        "floor",
        adjectives: ["worn", "brick"],
        synonyms: ["brick", "bricks", "paving"],
        description:
            """
            Worn brick, laid in a herringbone by somebody who did not have to and swept
            by somebody who does. It is the only floor in these workings that is not
            simply whatever the rock left.
            """
    )

    // MARK: - The Shelter Hole

    let shelterRib = Item.backdrop(
        "rib",
        synonyms: ["shelter", "hole", "timbers", "floor"],
        description:
            """
            The shelter hole is cut square into the rib and timbered honestly, which is
            more than can be said for some of this section. Its floor is dry, and dry is
            the whole of what it is selling.
            """
    )

    // MARK: - The Low Crawl

    let crawlRock = Item.backdrop(
        "rock",
        synonyms: ["stone", "sides", "roof", "wall", "walls", "floor", "shadow"],
        description:
            """
            Rock above, rock below, and rock at both elbows, close enough that the lamp
            throws your own shadow across it and into your eyes. It is not going anywhere
            and neither, for the moment, are you.
            """
    )

    let crawlItself = Item.backdrop(
        "crawl",
        adjectives: ["low", "dark"],
        synonyms: ["gap"],
        description:
            """
            From the inside it is simply the shape you are: a gap the fall did not quite
            close, running east and west, and no wider anywhere than it is here.
            """
    )

    // MARK: - The Forks

    /// The fall reaches this far. It is the same event as the Fresh Fall's wall
    /// of rock — but that item is a room away, and the Forks' own paragraph names
    /// the fall twice while pointing at the gap along the edge of it.
    let forksFall = Item.backdrop(
        "fall",
        adjectives: ["fresh", "fallen"],
        synonyms: ["rubble", "rock", "rocks"],
        description:
            """
            The far edge of the same fall, come round the corner to meet you. It left the
            crawl the way a man leaves a tip: without meaning to, and not generously.
            """
    )

    // MARK: - The Shaft Bottom

    let shaftWall = Item.backdrop(
        "wall",
        synonyms: ["walls"],
        description:
            """
            Rock, squared off where the sinkers squared it forty years ago, with the bell
            bolted to it at the height of a man's hand. Everything down here that matters
            is fixed to this wall.
            """
    )

    /// The crawl's other mouth. The room's own paragraph names it, now that the
    /// crawl runs both ways.
    let shaftCrawl = Item.backdrop(
        "crawl",
        adjectives: ["low", "dark"],
        synonyms: ["gap", "floor"],
        description:
            """
            The crawl comes out here at floor level, beside the air-door, looking from
            this side like exactly what it is: the way a man gets through, and nothing
            larger.
            """
    )

    // MARK: - The Old Works

    let oldProps = Item.backdrop(
        "props",
        adjectives: ["standing", "old"],
        synonyms: ["prop", "timbers", "timber", "floor"],
        description:
            """
            Props set forty years ago and still standing, which says something for the
            man who set them. The floor between them has not been walked on since, and
            shows it: undisturbed, and undisturbed a long while.
            """
    )

    let oldAir = Item.backdrop(
        "air",
        adjectives: ["sweet", "still"],
        synonyms: ["sweetness", "quiet"],
        description:
            """
            It smells faintly sweet, and it is perfectly still, and there is nothing
            whatever alarming about it to look at. That is the entire problem with it,
            and the reason a mule's nose outranks a man's opinion down here.
            """
    )
}

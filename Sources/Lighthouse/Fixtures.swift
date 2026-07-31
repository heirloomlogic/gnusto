import Gnusto

/// The nouns the rock's own prose puts on the page.
///
/// A room that names a thing and then doesn't know the word for it reads like a
/// bug, so every noun in a description here has an item behind it. None of them
/// is a puzzle and none is takeable — they exist so that `X MOORING` gets an
/// answer instead of *I don't know the word "mooring"*.
///
/// They live in a ``GameContent`` bundle for a reason worth naming, because it
/// is a second use of the same idiom the ``Tower`` demonstrates: the Tower is a
/// bundle because a *region* wants to own its declarations, and this is a bundle
/// because eight scenery items would otherwise be a third of the host file. A
/// bundle is a place to put declarations, and "a region" is only the most
/// obvious reason to want one.
///
/// The host places these. A bundle can only place into rooms it can *name*, and
/// the only rooms it can store are its own — so these belong to ``Lighthouse``'s
/// `map`, on the same cross-bundle seam that wires the stairs up into the Tower.
///
/// A note on what is declared and what is derived, since these blocks are short
/// enough to read as a list: a `name` already contributes its last word as a
/// noun and every earlier word as an adjective, so `name("coiled rope")` needs
/// neither `adjectives("coiled")` nor `synonyms("rope")`. What the extra lines
/// are for is the words the prose prints that the name doesn't reach.
struct Fixtures: GameContent {
    // MARK: - The jetty

    let sea = Item {
        name("sea")
        adjectives("cold")
        synonyms("water", "tide", "waves", "wave", "ebb")
        description(
            """
            Coming in, the way it comes in twice a day whether or not anybody is
            standing here to watch. It has had this jetty before and given it
            back.
            """)
        scenery
    }

    let planks = Item {
        name("timber jetty")
        synonyms("planks", "plank", "boards", "board", "footings", "footing")
        description(
            """
            Timber on stone footings, and the timber is the part that gets
            replaced. The planks are laid a finger apart so the sea can come up
            between them instead of lifting the lot.
            """)
        scenery
    }

    let boat = Item {
        name("keeper's boat")
        synonyms("mooring", "dinghy")
        description(
            """
            An open boat, rowed out and rowed back for forty years, with the
            mooring line made fast in a hitch you could undo one-handed in the
            dark. She has had to.
            """)
        scenery
    }

    let lighthouse = Item {
        name("lighthouse")
        adjectives("dark", "white")
        synonyms("tower")
        description(
            """
            Stone, tapered, whitewashed to the gallery rail, and dark at the top
            where it has no business being dark. From out on the water it is the
            first thing anyone looks for.
            """)
        scenery
    }

    // MARK: - The base

    /// The tower seen from inside it, which is why this and not the jetty's
    /// `lighthouse` answers those words down here — a single item occupies one
    /// room, and the view from within a lighthouse is its wall.
    ///
    /// `stone` is a synonym rather than an adjective on purpose: the name makes
    /// it an adjective already, and the last word of a typed phrase has to be a
    /// noun, so `x stone` needs it declared on this side.
    let wall = Item {
        name("stone wall")
        adjectives("round")
        synonyms("stone", "walls", "tower", "lighthouse")
        description(
            """
            Blocks the length of your forearm, laid in a circle thick enough that
            the weather out there is a rumor in here.
            """)
        scenery
    }

    let stairs = Item {
        name("stone stairs")
        synonyms("stair", "staircase", "steps", "step", "treads", "tread", "rail")
        description(
            """
            They climb into the dark and go on climbing. Every tread is hollowed
            at the center, and the rail is bright along its whole length where a
            hand has gone.
            """)
        scenery
    }

    // MARK: - The storeroom

    let rope = Item {
        name("coiled rope")
        synonyms("ropes", "coil", "coils", "pegs", "peg")
        description(
            """
            Hung on pegs by size, largest to the left. Somebody put them in that
            order and everybody since has kept them in it.
            """)
        scenery
    }

    let stores = Item {
        name("stores")
        synonyms("store", "things", "gear", "supplies", "tar", "brine")
        description(
            """
            Tar and brine and forty years of things put where they go. Nobody on
            this rock has had to look for anything in a long while.
            """)
        scenery
    }
}

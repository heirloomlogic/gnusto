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
/// because a dozen scenery items would otherwise be two thirds of the host file.
/// A bundle is a place to put declarations, and "a region" is only the most
/// obvious reason to want one.
///
/// The host places these, since a bundle's `map` can only reach rooms the bundle
/// itself declares and all three of these rooms belong to ``Lighthouse``. That is
/// the same cross-bundle seam that wires the stairs up into the Tower.
struct Fixtures: GameContent {
    // MARK: - The jetty

    let sea = Item {
        name("sea")
        adjectives("cold", "grey", "open")
        synonyms("water", "tide", "waves", "wave", "swell", "ebb", "surf")
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
        adjectives("timber", "short", "wooden")
        synonyms("jetty", "planks", "plank", "boards", "board", "footings", "footing", "decking")
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
        adjectives("small", "open", "clinker")
        synonyms("boat", "dinghy", "mooring", "painter")
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
        adjectives("tall", "white", "stone")
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

    let wall = Item {
        name("stone wall")
        adjectives("stone", "round", "thick")
        // "lighthouse" as well as "tower", because the room's own name prints it.
        synonyms("wall", "walls", "stone", "stonework", "masonry", "tower", "lighthouse")
        description(
            """
            Blocks the length of your forearm, laid in a circle thick enough that
            the weather out there is a rumor in here.
            """)
        scenery
    }

    let stairs = Item {
        name("stone stairs")
        adjectives("stone", "worn")
        synonyms(
            "stairs", "stair", "staircase", "steps", "step", "treads", "tread",
            "rail", "handrail", "banister")
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
        adjectives("coiled", "tarred", "hemp")
        synonyms("rope", "ropes", "coil", "coils", "pegs", "peg")
        description(
            """
            Hung on pegs by size, largest to the left. Somebody put them in that
            order and everybody since has kept them in it.
            """)
        scenery
    }

    let stores = Item {
        name("stores")
        adjectives("kept")
        synonyms("store", "things", "gear", "supplies", "tar", "brine")
        description(
            """
            Tar and brine and forty years of things put where they go. Nobody on
            this rock has had to look for anything in a long while.
            """)
        scenery
    }
}

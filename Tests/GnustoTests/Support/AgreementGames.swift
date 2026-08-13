import Gnusto

/// A yard full of honestly plural things, for the stock lines on ``GameText``
/// proper — the ones a room description and the core verbs print, where
/// ``StubLab`` covers the idle verbs.
///
/// Every plural noun here has a singular twin standing next to it (the crates
/// and the jar, the lamps and the lantern, the Wilsons and the butler), because
/// a line that agrees in the plural by accident — by dropping the verb, or by
/// always saying "are" — passes a plural-only fixture and fails the game. The
/// pair is what makes the assertion mean *agreement* rather than *plural*.
///
/// Nothing in it is declared for prose's sake: a mine really does have rails,
/// a scullery really does have scales, and the point of ``plural`` is that a
/// game says so once and stops thinking about it.
struct PluralLab: Game {
    let title = "Plural Lab"
    let intro = "A yard of things that come in numbers."

    let yard = Location {
        name("Yard")
        description("A brick yard, gated on the north side.")
    }

    let shed = Location {
        name("Shed")
        description("A shed with nothing in it.")
    }

    // MARK: - The gates, which are a door and are locked

    /// Both halves of the closed-door path in one item: locked, so `open gates`
    /// reaches ``GameText/locked``, and shut, so walking north reaches
    /// ``GameText/closedContainer`` through `travel`.
    let gates = Item {
        name("iron gates")
        adjectives("iron")
        openable
        plural
    }

    let key = Item {
        name("iron key")
        adjectives("iron")
    }

    // MARK: - Containers, plural and singular

    /// Open (no `openable`) and empty, for ``GameText/emptyContainer``.
    let crates = Item {
        name("wooden crates")
        adjectives("wooden")
        container
        plural
    }

    /// The singular twin of the crates.
    let jar = Item {
        name("stoneware jar")
        adjectives("stoneware")
        container
    }

    /// Openable, so it starts closed, for ``GameText/closedContainer`` off the
    /// search path rather than the travel one.
    let bins = Item {
        name("metal bins")
        adjectives("metal")
        container
        openable
        plural
    }

    /// The singular twin of the gates and the bins both: locked, so `open
    /// chest` answers ``GameText/locked``, and shut, so `search chest` answers
    /// ``GameText/closedContainer``.
    let chest = Item {
        name("oak chest")
        adjectives("oak")
        container
        openable
    }

    /// Holds a plural thing, so the room's listing line and `search` both have
    /// to decide what agrees with what: the verb belongs to the *contents*, and
    /// the contents are the second thing the sentence names.
    let hamper = Item {
        name("wicker hamper")
        adjectives("wicker")
        container
    }

    let weights = Item {
        name("lead weights")
        adjectives("lead")
        plural
    }

    /// Shut and transparent, so the pins are in plain view and out of arm's
    /// reach — ``GameText/cantReach`` has no verb to agree and must not move.
    let glassCase = Item {
        name("glass case")
        adjectives("glass")
        container
        openable
        transparent
    }

    let pins = Item {
        name("steel pins")
        adjectives("steel")
        plural
    }

    // MARK: - Lights, plural and singular

    let lamps = Item {
        name("carriage lamps")
        adjectives("carriage")
        lightSource
        plural
    }

    let lantern = Item {
        name("tin lantern")
        adjectives("tin")
        lightSource
    }

    // MARK: - Things on the floor

    /// No `description`, so examining it reaches ``GameText/nothingSpecial``,
    /// and not `scenery`, so the room lists it through ``GameText/itemHere``.
    let scales = Item {
        name("scales")
        adjectives("brass")
        plural
    }

    let rod = Item {
        name("brass rod")
        adjectives("brass")
    }

    // MARK: - People, plural and singular

    /// Plural people who take no orders. A common noun rather than a proper
    /// one: a proper plural in English carries its article inside the name
    /// ("the Wilsons"), and a name may not begin with a noise word — the
    /// bootstrap refuses it, because stripping "the" would make the word
    /// untypeable.
    let hands = Actor {
        name("stable hands")
        adjectives("stable")
        plural
    }

    /// The singular twin of the stable hands.
    let butler = Actor {
        name("butler")
    }

    /// Plural people who *do* take orders, so an unanswerable order reaches
    /// ``GameText/doesNotKnowHow`` — the one line on `GameText` proper that has
    /// taken a ``GameText/Noun`` all along, and therefore the control: it agrees
    /// correctly today, and must still agree after everything around it moves.
    let twins = Actor {
        name("twins")
        plural
        takesOrders
    }

    var map: WorldMap {
        player.starts(in: yard)
        key.startsHeld
        gates.lockedBy(key)
        chest.lockedBy(key)
        yard.north(shed, via: gates)
        shed.south(yard, via: gates)

        crates.starts(in: yard)
        jar.starts(in: yard)
        bins.starts(in: yard)
        chest.starts(in: yard)
        hamper.starts(in: yard)
        weights.starts(inside: hamper)
        glassCase.starts(in: yard)
        pins.starts(inside: glassCase)
        lamps.starts(in: yard)
        lantern.starts(in: yard)
        scales.starts(in: yard)
        rod.starts(in: yard)
        hands.starts(in: yard)
        butler.starts(in: yard)
        twins.starts(in: yard)
    }
}

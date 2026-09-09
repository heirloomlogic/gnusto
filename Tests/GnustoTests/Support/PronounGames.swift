import Gnusto

/// Exercises the pronoun binding: "it" follows the last direct object the
/// player named, across rooms and across refused actions, "them" follows a
/// plural one, and "him"/"her" follow the people.
///
/// The cast is arranged for the gendered pronouns: the study holds one person
/// of each gender, so a word with nobody named yet has exactly one thing to
/// fall back on, and the hall holds two women, so there the word has to be
/// bound by a mention before it names anybody.
struct PronounGame: Game {
    let title = "Pronoun Practice"
    let intro = "A study and a hall."

    let study = Location {
        name("Study")
        description("A book-lined study. The hall is north.")
    }

    let hall = Location {
        name("Hall")
        description("A bare hall. The study is south.")
    }

    let lantern = Item {
        name("tin lantern")
        adjectives("tin")
        description("A dented tin lantern.")
    }

    let hook = Item {
        name("iron hook")
        adjectives("iron")
        scenery
        description("A hook bolted to the wall.")
    }

    let stairs = Item {
        name("stone stairs")
        adjectives("stone")
        plural
        scenery
        description("Worn stone stairs, going nowhere.")
    }

    let gloves = Item {
        name("leather gloves")
        adjectives("leather")
        plural
        description("A pair of cracked leather gloves.")
    }

    let shelves = Item {
        name("oak shelves")
        adjectives("oak")
        plural
        container
        startsOpen
        description("Three sagging oak shelves.")
    }

    let warden = Actor {
        name("night warden")
        adjectives("night")
        pronoun(.he)
        description("A tall man with a ring of keys.")
    }

    let cook = Actor {
        name("cook")
        pronoun(.she)
        description("A broad woman in a flour-dusted apron.")
    }

    let matron = Actor {
        name("matron")
        pronoun(.she)
        description("The matron, watching the door.")
    }

    let laundress = Actor {
        name("laundress")
        pronoun(.she)
        takesOrders
        description("The laundress, up to her elbows in grey water.")
    }

    var rules: Rules {
        // Somebody has to answer an order, or the turn is unhandled and rolls
        // its own pronoun binding back with everything else it did.
        laundress.before(.jump) {
            try reply("The laundress hops once, obligingly, and returns to the tub.")
        }
    }

    var map: WorldMap {
        player.starts(in: study)
        warden.starts(in: study)
        cook.starts(in: study)
        matron.starts(in: hall)
        laundress.starts(in: hall)
        lantern.starts(in: study)
        hook.starts(in: study)
        stairs.starts(in: study)
        gloves.starts(in: study)
        shelves.starts(in: study)
        study.north(hall)
        hall.south(study)
    }
}

/// An item that claims a reserved parser word as a synonym — the bootstrap
/// warns, because the pronoun check runs first and the word can never reach
/// the item's lexicon.
struct ReservedWordGame: Game {
    let title = "Reserved Words"
    let intro = ""

    let cell = Location {
        name("Cell")
        description("A bare cell.")
    }

    let golem = Item {
        name("clay golem")
        adjectives("clay")
        synonyms("it")
    }

    /// The workaround the ``pronoun(_:)`` trait replaces: a game used to spend
    /// a synonym on the word, and the word now belongs to the parser.
    let hag = Actor {
        name("bog hag")
        adjectives("bog")
        synonyms("her")
    }

    var map: WorldMap {
        player.starts(in: cell)
        golem.starts(in: cell)
        hag.starts(in: cell)
    }
}

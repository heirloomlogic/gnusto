import Gnusto

/// Exercises the pronoun binding: "it" follows the last direct object the
/// player named, across rooms and across refused actions.
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

    var map: WorldMap {
        player.starts(in: study)
        lantern.starts(in: study)
        hook.starts(in: study)
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

    var map: WorldMap {
        player.starts(in: cell)
        golem.starts(in: cell)
    }
}

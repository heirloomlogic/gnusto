import Gnusto
import GnustoConversation

/// A hall holding one of each kind of name, so a single transcript can show the
/// article rule choosing correctly at every site: a proper-named person, a
/// common-noun person, a proper-named thing, and common-noun things that share
/// a noun with two of them.
///
/// Arthur and the carved figure both answer to "figure", and Excalibur and the
/// wooden sword both answer to "sword" — the two disambiguations the article
/// rule has to get right in one sentence, since each names a bare name and an
/// articled one side by side.
struct NamedCastGame: Game {
    let title = "Named Cast"
    let intro = "A bare hall."

    let talk = Conversation()

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let landing = Location {
        name("Landing")
        description("A landing.")
    }

    /// Two hops from the hall, which is one more than FOLLOW searches.
    let attic = Location {
        name("Attic")
        description("An attic.")
    }

    /// No `description` and no `firstSight`, so both stock lines that would
    /// have articled him — `actorHere` and `nothingSpecial` — are reached.
    let arthur = Actor {
        name("Arthur")
        properName
        synonyms("arthur", "figure", "man")
    }

    /// The control: a person the engine should still article.
    let troll = Actor {
        name("troll")
        synonyms("troll", "man")
    }

    /// Two rooms off, so FOLLOW gives up and names him — `lostThem` is
    /// reachable from nowhere else, and the follow verb's parser scope
    /// considers actors who aren't in the room.
    let mordred = Actor {
        name("Mordred")
        properName
        synonyms("mordred")
    }

    let lantern = Item {
        name("brass lantern")
        adjectives("brass")
    }

    let figure = Item {
        name("carved figure")
        adjectives("carved")
    }

    let excalibur = Item {
        name("Excalibur")
        properName
        synonyms("excalibur", "sword")
    }

    let woodenSword = Item {
        name("wooden sword")
        adjectives("wooden")
    }

    let chest = Item {
        name("chest")
        container
        openable
    }

    var content: GameContents { talk }

    var rules: Rules {
        talk.topics(of: arthur) {
            topic("grail", reply: "\"I have looked,\" he says.")
        }
    }

    var map: WorldMap {
        hall.north(landing)
        landing.south(hall)
        landing.up(attic)
        // The way back down, so the player can go and meet Mordred and return.
        // FOLLOW names the people it has been introduced to; two rooms off and
        // never seen, he is nobody. (#332)
        attic.down(landing)
        player.starts(in: hall)
        arthur.starts(in: hall)
        troll.starts(in: hall)
        mordred.starts(in: attic)
        lantern.starts(in: hall)
        figure.starts(in: hall)
        woodenSword.starts(in: hall)
        chest.starts(in: hall)
        excalibur.starts(inside: chest)
    }
}

/// A game whose capitalized names are *not* declared `properName`, so the
/// bootstrap's warning has something to fire on — and whose location name is
/// capitalized like every location name, so it can be shown not to.
struct UndeclaredProperNameGame: Game {
    let title = "Undeclared"
    let intro = "A hall."

    let orangeGroveAvenue = Location {
        name("Orange Grove Avenue")
        description("A wide street.")
    }

    let arthur = Actor {
        name("Arthur")
        description("A man.")
    }

    let sword = Item {
        name("Elvish sword")
        adjectives("elvish")
    }

    /// The common-noun control: no warning for this one.
    let lantern = Item {
        name("brass lantern")
        adjectives("brass")
    }

    var map: WorldMap {
        player.starts(in: orangeGroveAvenue)
        arthur.starts(in: orangeGroveAvenue)
        sword.starts(in: orangeGroveAvenue)
        lantern.starts(in: orangeGroveAvenue)
    }
}

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

    let plinth = Item {
        name("plinth")
        surface
    }

    let grail = Item {
        name("Grail")
        properName
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
        plinth.startsHeld
        grail.starts(on: plinth)
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

/// A hall of names whose spelling and sound disagree, so one transcript shows
/// the declared article reaching every site the first-letter rule reaches.
///
/// The hour glass is the "an" case a vowel test gets wrong, the unicorn the "a"
/// case it gets wrong the other way, and the lantern is the control that
/// declares nothing.
struct DeclaredArticleGame: Game {
    let title = "Declared Article"
    let intro = "A bare hall."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let hourGlass = Item {
        name("hour glass")
        article("an")
        adjectives("hour")
    }

    let unicorn = Item {
        name("unicorn")
        article("a")
    }

    /// Actors share the item trait vocabulary, and their listing line is
    /// indefinite too, so the trait has to reach a person as well as a prop.
    let heiress = Actor {
        name("heiress")
        article("an")
    }

    /// The control: no declared article, so the first letter still decides.
    let lantern = Item {
        name("brass lantern")
        adjectives("brass")
    }

    /// The other control: a vowel the first letter gets right on its own.
    let apple = Item {
        name("apple")
    }

    let chest = Item {
        name("chest")
        container
        openable
    }

    var map: WorldMap {
        player.starts(in: hall)
        hourGlass.starts(in: hall)
        unicorn.starts(in: hall)
        heiress.starts(in: hall)
        lantern.starts(in: hall)
        apple.starts(in: hall)
        chest.starts(in: hall)
    }
}

/// A game that declares an article the engine can never print, so both warnings
/// about a dead article have something to fire on.
struct ContradictoryArticleGame: Game {
    let title = "Contradictory"
    let intro = "A hall."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    /// A proper name takes no article at all.
    let excalibur = Item {
        name("Excalibur")
        properName
        article("an")
    }

    /// A plural name takes "some".
    let rails = Item {
        name("rails")
        plural
        article("a")
    }

    var map: WorldMap {
        player.starts(in: hall)
        excalibur.starts(in: hall)
        rails.starts(in: hall)
    }
}

/// A game whose declared article is not a word, which is fatal alongside every
/// other blank author-facing text rather than merely ineffective.
struct BlankArticleGame: Game {
    let title = "Blank Article"
    let intro = "A hall."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let hourGlass = Item {
        name("hour glass")
        article("  ")
        adjectives("hour")
    }

    let sandGlass = Item {
        name("sand glass")
        article("")
        adjectives("sand")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hourGlass.starts(in: hall)
        sandGlass.starts(in: hall)
    }
}

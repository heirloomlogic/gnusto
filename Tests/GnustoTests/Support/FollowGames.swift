import Gnusto

/// Four rooms in a line, a walker who can be put anywhere, a statue that is
/// not going anywhere, and two awkward exits — a shut door and a false
/// condition — so FOLLOW can be shown to refuse in exactly the words GO uses.
///
/// The walker is moved by a custom verb rather than a timetable: this suite is
/// about the *verb*, and a schedule would make every test a timing puzzle.
struct FollowLab: Game {
    let title = "Follow Lab"
    let intro = "A corridor."

    /// Whether the trapdoor's condition passes.
    @Global var hatchOpen = false

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let study = Location {
        name("Study")
        description("A study.")
    }

    let attic = Location {
        name("Attic")
        description("An attic.")
    }

    /// Reachable from the hall only through a door that starts shut.
    let pantry = Location {
        name("Pantry")
        description("A pantry.")
    }

    /// Reachable from the hall only through a condition that starts false.
    let vault = Location {
        name("Vault")
        description("A vault.")
    }

    /// Reachable two ways: a permanently shut conditional and a plain exit.
    let crypt = Location {
        name("Crypt")
        description("A crypt.")
    }

    /// Off the map: no exit leads here, which is how a game parks a character
    /// who hasn't entered the story yet.
    let limbo = Location {
        name("Limbo")
        description("Nowhere.")
    }

    /// Two exits from the hall lead here, so the compass-order tie-break has
    /// something to break.
    let porch = Location {
        name("Porch")
        description("A porch.")
    }

    let walker = Actor {
        name("walker")
        synonyms("walker", "person")
        description("The walker.")
    }

    /// Carries a `before(.follow)` rule of his own, which is the escape hatch
    /// a game buys a longer pursuit with — and only reachable because FOLLOW
    /// puts its target in the *direct object* slot.
    let porter = Actor {
        name("porter")
        synonyms("porter", "person")
        description("The porter.")
    }

    let statue = Item {
        name("statue")
        description("A statue.")
        scenery
    }

    let pantryDoor = Item {
        name("pantry door")
        synonyms("door")
        description("A pantry door.")
        openable
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("send", .directObject, intent: Intent("send"))
        SyntaxRule("unbar", intent: Intent("unbar"))
    }

    var rules: Rules {
        // `send <room noun>` puts the walker there, so a test can place him
        // without waiting on a clock.
        world.before(Intent("send")) {
            guard let target = command.directObject else { return }
            switch target.name {
            case "study marker": walker.move(to: study)
            case "attic marker": walker.move(to: attic)
            case "pantry marker": walker.move(to: pantry)
            case "vault marker": walker.move(to: vault)
            case "limbo marker": walker.move(to: limbo)
            case "crypt marker": walker.move(to: crypt)
            case "porch marker": walker.move(to: porch)
            default: walker.vanish()
            }
            try reply("Sent.")
        }
        porter.before(.follow) {
            try reply("The porter turns a corner you did not know was there.")
        }
        world.before(Intent("unbar")) {
            hatchOpen = true
            try reply("Unbarred.")
        }
    }

    /// Nouns the `send` verb keys on. Kept off-stage in a room the player
    /// never enters, so they never clutter a description.
    let studyMarker = Item { name("study marker") }
    let atticMarker = Item { name("attic marker") }
    let pantryMarker = Item { name("pantry marker") }
    let vaultMarker = Item { name("vault marker") }
    let porchMarker = Item { name("porch marker") }
    let elsewhereMarker = Item { name("elsewhere marker") }
    let limboMarker = Item { name("limbo marker") }
    let cryptMarker = Item { name("crypt marker") }

    var map: WorldMap {
        hall.north(study)
        study.south(hall)
        study.north(attic)
        attic.south(study)

        hall.east(pantry, via: pantryDoor)
        hall.west(vault, when: { hatchOpen }, otherwise: "The vault is barred.")

        // The crypt has two ways in: a conditional one whose gate is always
        // shut, and a plain one. Whichever sorts first in `Direction.allCases`,
        // FOLLOW must take the plain one.
        hall.northeast(crypt, when: { false }, otherwise: "The crypt gate is barred.")
        hall.up(crypt)

        // Two ways onto the porch. `Direction.allCases` order decides, and the
        // point of the test is that it decides the same way every run.
        hall.down(porch)
        hall.south(porch)

        player.starts(in: hall)
        walker.starts(in: hall)
        porter.starts(in: study)
        statue.starts(in: hall)

        studyMarker.startsHeld
        atticMarker.startsHeld
        pantryMarker.startsHeld
        vaultMarker.startsHeld
        porchMarker.startsHeld
        elsewhereMarker.startsHeld
        limboMarker.startsHeld
        cryptMarker.startsHeld
    }
}

/// A game with one person, one thing, and nothing else — for `<actor>, <words>`
/// addressing, where what matters is that an order is *not* carried out.
struct Antechamber: Game {
    let title = "Antechamber"
    let intro = "An antechamber."

    let room = Location {
        name("Antechamber")
        description("An antechamber.")
    }

    let usher = Actor {
        name("usher")
        description("The usher.")
    }

    /// A second person, so a bare greeting has a crowd to be ambiguous in.
    let page = Actor {
        name("page")
        description("The page.")
    }

    let lamp = Item {
        name("lamp")
        description("A lamp.")
    }

    var map: WorldMap {
        player.starts(in: room)
        usher.starts(in: room)
        page.starts(in: room)
        lamp.starts(in: room)
    }
}

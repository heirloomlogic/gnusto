import Gnusto

struct BlankStaticProseGame: Game {
    let title = "Blank static prose"
    let intro = ""

    let emptyRoom = Location {
        name("Empty Room")
        description("")
    }

    let whitespaceRoom = Location {
        name("Whitespace Room")
        description(" \n\t")
    }

    let emptyDescription = Item {
        name("empty description")
        description("")
    }

    let whitespaceDescription = Item {
        name("whitespace description")
        description(" \n\t")
    }

    let emptyFirstSight = Item {
        name("empty first sight")
        firstSight("")
    }

    let whitespaceFirstSight = Actor {
        name("whitespace first sight")
        firstSight(" \n\t")
    }

    let conditionalDescription = Item {
        name("conditional description")
        openable
        description(when: \.isOpen, "", otherwise: " \n")
    }

    let conditionalFirstSight = Item {
        name("conditional first sight")
        lightSource
        firstSight(when: \.isLit, " \t", otherwise: "")
    }

    var map: WorldMap {
        player.starts(in: emptyRoom)
        emptyRoom.north(whitespaceRoom)
        emptyDescription.starts(in: emptyRoom)
        whitespaceDescription.starts(in: emptyRoom)
        emptyFirstSight.starts(in: emptyRoom)
        whitespaceFirstSight.starts(in: emptyRoom)
        conditionalDescription.starts(in: emptyRoom)
        conditionalFirstSight.starts(in: emptyRoom)
    }
}

struct OptionalAndNonblankProseGame: Game {
    let title = "Optional and nonblank prose"
    let intro = ""

    let hall = Location { name("Hall") }
    let annex = Location {
        name("Annex")
        description("An annex.")
    }
    let plainStone = Item { name("plain stone") }
    let describedStone = Item {
        name("described stone")
        description("A described stone.")
        firstSight("A described stone lies here.")
    }
    let hatch = Item {
        name("hatch")
        openable
        description(when: \.isOpen, "The hatch is open.", otherwise: "The hatch is shut.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        plainStone.starts(in: hall)
        describedStone.starts(in: hall)
        hatch.starts(in: hall)
        hall.north(blocked: "The arch is sealed.")
        hall.east(annex, when: { false }, otherwise: "The gate is shut.")
    }
}

struct BlankExitProseGame: Game {
    let title = "Blank exit prose"
    let intro = ""

    let hall = Location { name("Hall") }
    let annex = Location { name("Annex") }

    var map: WorldMap {
        player.starts(in: hall)
        hall.north(blocked: "")
        hall.south(blocked: " \n\t")
        hall.east(annex, when: { false }, otherwise: "")
        hall.west(annex, when: { false }, otherwise: " \t")
    }
}

struct BlankDescribeAfterChangeGame: Game {
    let title = "Blank describe after change"
    let intro = ""

    @Global var proseIsBlank = false

    let hall = Location {
        name("Hall")
        description("A hall.")
    }
    let relic = Item { name("relic") }

    var rules: Rules {
        relic.describe { proseIsBlank ? "" : "The relic is intact." }
        relic.before(.touch) {
            proseIsBlank = true
            try reply("The inscription fades.")
        }
    }

    var map: WorldMap {
        player.starts(in: hall)
        relic.starts(in: hall)
    }
}

struct BlankPresenceAfterChangeGame: Game {
    let title = "Blank presence after change"
    let intro = ""

    @Global var proseIsBlank = false

    let hall = Location {
        name("Hall")
        description("A hall.")
    }
    let sentry = Actor { name("sentry") }

    var rules: Rules {
        sentry.presence { proseIsBlank ? " \n\t" : "A sentry stands here." }
        world.before(.wait) {
            proseIsBlank = true
            try reply("Time passes.")
        }
    }

    var map: WorldMap {
        player.starts(in: hall)
        sentry.starts(in: hall)
    }
}

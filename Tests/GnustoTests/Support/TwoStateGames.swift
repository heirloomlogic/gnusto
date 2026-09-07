import Gnusto

/// One world declared two ways. `compact` puts each two-state text in the
/// entity's own trait block — `description(when:_:otherwise:)`,
/// `firstSight(when:_:otherwise:)` — and otherwise it is the `describe { … }`
/// / `presence { … }` rule the trait replaces. Every transcript must match.
struct TwoStateGame: Game {
    let title = "Two State"
    let intro = ""
    let compact: Bool

    let hall = Location {
        name("Hall")
        description("A bare hall. A cellar lies south, and a closet east.")
    }
    let cellar: Location
    let lamp: Item
    let chest: Item
    let gem: Item
    let sentry: Actor
    let annex: TwoStateAnnex

    init() {
        self.init(compact: true)
    }

    init(compact: Bool) {
        self.compact = compact
        cellar = Location {
            name("Cellar")
            dark
            if compact {
                description(
                    when: \.isLit, Self.cellarLit, otherwise: Self.cellarDark)
            }
        }
        lamp = Item {
            name("brass lamp")
            adjectives("brass")
            lightSource
            if compact {
                description(when: \.isLit, Self.lampOn, otherwise: Self.lampOff)
            }
        }
        chest = Item {
            name("chest")
            container
            openable
            if compact {
                description(when: \.isOpen, Self.chestOpen, otherwise: Self.chestShut)
                firstSight(when: \.isOpen, Self.chestOpenHere, otherwise: Self.chestShutHere)
            }
        }
        gem = Item {
            name("gem")
            hidden
            if compact {
                description(when: \.isRevealed, Self.gemFound, otherwise: Self.gemUnseen)
            }
        }
        sentry = Actor {
            name("sentry")
            if compact {
                description(
                    when: \Actor.isUnconscious, Self.sentryDown, otherwise: Self.sentryUp)
                firstSight(
                    when: \Actor.isUnconscious, Self.sentryDownHere, otherwise: Self.sentryUpHere)
            }
        }
        annex = TwoStateAnnex(compact: compact)
    }

    var content: GameContents { annex }

    var map: WorldMap {
        hall.south(cellar)
        hall.east(annex.closet)
        player.starts(in: hall)
        lamp.starts(in: hall)
        chest.starts(in: hall)
        gem.starts(in: hall)
        sentry.starts(in: hall)
    }

    var rules: Rules {
        if !compact {
            cellar.describe { cellar.isLit ? Self.cellarLit : Self.cellarDark }
            lamp.describe { lamp.isLit ? Self.lampOn : Self.lampOff }
            chest.describe { chest.isOpen ? Self.chestOpen : Self.chestShut }
            chest.presence { chest.isOpen ? Self.chestOpenHere : Self.chestShutHere }
            gem.describe { gem.isRevealed ? Self.gemFound : Self.gemUnseen }
            sentry.describe { sentry.isUnconscious ? Self.sentryDown : Self.sentryUp }
            sentry.presence { sentry.isUnconscious ? Self.sentryDownHere : Self.sentryUpHere }
        }
        hall.before(.jump) {
            gem.reveal()
            try reply("A gem winks up at you from between the flagstones.")
        }
        sentry.before(.attack) {
            sentry.isUnconscious = true
            try reply("The sentry folds up without a word.")
        }
        lamp.before(.touch) {
            lamp.description = "Scuffed where you rubbed it."
            try reply("You rub the lamp.")
        }
    }

    static let cellarLit = "A low cellar, its walls sweating in the lamplight."
    static let cellarDark = "A cellar you cannot see."
    static let lampOn = "The lamp burns with a steady yellow flame."
    static let lampOff = "A brass lamp, unlit."
    static let chestOpen = "The chest stands open, and empty."
    static let chestShut = "A squat chest, its lid down."
    static let chestOpenHere = "An open chest gapes in the corner."
    static let chestShutHere = "A squat chest sits in the corner."
    static let gemFound = "A gem, winking."
    static let gemUnseen = "You have not found it yet."
    static let sentryDown = "The sentry is out cold."
    static let sentryUp = "A sentry, watching you."
    static let sentryDownHere = "A sentry lies unconscious on the floor."
    static let sentryUpHere = "A sentry stands at the door."
}

/// The bundle half of ``TwoStateGame``: a namespaced item carrying the trait,
/// to prove the lowering finds a bundle's proxy the way it finds the game's.
struct TwoStateAnnex: GameContent {
    let compact: Bool
    let closet = Location {
        name("Closet")
        description("A closet.")
    }
    let box: Item

    init(compact: Bool) {
        self.compact = compact
        box = Item {
            name("box")
            container
            openable
            if compact {
                description(when: \.isOpen, Self.boxOpen, otherwise: Self.boxShut)
            }
        }
    }

    var map: WorldMap {
        box.starts(in: closet)
    }

    var rules: Rules {
        if !compact {
            box.describe { box.isOpen ? Self.boxOpen : Self.boxShut }
        }
    }

    static let boxOpen = "The box is open."
    static let boxShut = "The box is shut."
}

import Gnusto

struct NonFiniteDefaultGlobalGame: Game {
    let title = "Non-Finite Default"
    let intro = "A room."

    let room = Location { name("Room") }
    @Global var tide: Double

    init() {
        self._tide = Global(wrappedValue: .nan)
    }

    init(_ invalid: NonFiniteDouble) {
        self._tide = Global(wrappedValue: invalid.value)
    }

    var map: WorldMap {
        player.starts(in: room)
    }
}

struct NonFiniteAssignmentGlobalGame: Game {
    let title = "Non-Finite Assignment"
    let intro = "A room."

    let invalid: NonFiniteDouble
    let room = Location { name("Room") }
    @Global var tide = 0.0

    init() {
        self.invalid = .nan
    }

    init(_ invalid: NonFiniteDouble) {
        self.invalid = invalid
    }

    var map: WorldMap {
        player.starts(in: room)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("poison", intent: Intent("poison"))
    }

    var rules: Rules {
        world.before(Intent("poison")) {
            tide = invalid.value
            try reply("The tide changes.")
        }
    }
}

struct FiniteDoubleGlobalGame: Game {
    let title = "Finite Tide"
    let intro = "A room."

    let room = Location { name("Room") }
    @Global var tide = 1.25

    var map: WorldMap {
        player.starts(in: room)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("raise", intent: Intent("raise"))
        SyntaxRule("drain", intent: Intent("drain"))
        SyntaxRule("measure", intent: Intent("measure"))
    }

    var rules: Rules {
        world.before(Intent("raise")) {
            tide = 3.5
            try reply("The tide rises.")
        }
        world.before(Intent("drain")) {
            tide = -8.75
            try reply("The tide falls.")
        }
        world.before(Intent("measure")) {
            try reply("The tide is \(tide).")
        }
    }
}

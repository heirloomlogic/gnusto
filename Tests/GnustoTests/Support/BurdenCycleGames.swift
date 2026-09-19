import Gnusto

/// A rule-built containment cycle that reaches Burden through both its public total and the carrying-cap rule.
struct BurdenCycleGame: Game {
    let title = "Burden Cycle"
    let intro = ""

    let load = Burden(carryCap: 17)

    var content: GameContents { load }

    let room = Location {
        name("Room")
        description("A room.")
    }

    let outer = Item {
        name("outer box")
        container
        trait(.weight, 7)
    }

    let inner = Item {
        name("inner box")
        container
        trait(.weight, 11)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("weigh", intent: Intent("weigh"))
    }

    var rules: Rules {
        world.before(Intent("weigh")) {
            makeCycle()
            try reply("The boxes weigh \(outer.burden).")
        }
        // Host rules are filed before content rules. Moving the boxes here
        // means Burden's world-level TAKE guard sees the malformed graph.
        world.before(.take) {
            makeCycle()
        }
    }

    var map: WorldMap {
        player.starts(in: room)
        outer.starts(in: room)
        inner.starts(in: room)
    }

    private func makeCycle() {
        outer.move(inside: inner)
        inner.move(inside: outer)
    }
}

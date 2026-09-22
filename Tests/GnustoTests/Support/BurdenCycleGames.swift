@testable import Gnusto

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
        force(outer, inside: inner)
        force(inner, inside: outer)
    }

    /// Writes the placement straight into the world state, which is what it
    /// takes to build a cycle now that `move(inside:)` traps on one. `Burden`
    /// totals through `ContainmentIndex.closure(under:)`, whose `visited` set
    /// is what makes the walk terminate on a cyclic graph, and these tests are
    /// what holds that guard — so the fixture goes on building the malformed
    /// graph and reaches past the author-facing trap to do it.
    private func force(_ item: Item, inside container: Item) {
        let (frame, id) = item.resolved
        let containerID = container.id
        frame.with { $0.state.place(id, .inside(containerID)) }
    }
}

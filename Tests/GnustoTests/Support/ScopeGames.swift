import Gnusto

/// Every containment shape the engine draws a line between, in one lit room —
/// plus a dark room and a room the player never stands in.
///
/// `probe` reports ``Item/isReachable`` and ``Item/isVisible`` for each of them
/// in one turn. It has to: parser scope *is* the visible set, so `examine
/// clinker` in another room answers "You can't see any such thing" and a test
/// of "not visible" would never get as far as asking the proxy.
struct ScopeLab: Game {
    let title = "Scope Lab"
    let intro = "A workshop, a cellar below, a yard beyond."

    let workshop = Location {
        name("Workshop")
        description("Benches and boxes.")
    }

    /// Never lit, and nothing here is a light source: what the player can reach
    /// in the dark is what they were already holding.
    let cellar = Location {
        name("Cellar")
        description("Black as a bag.")
        dark
    }

    let yard = Location {
        name("Yard")
        description("Open sky.")
    }

    // MARK: - The workshop

    let spanner = Item {
        name("spanner")
    }

    let bench = Item {
        name("bench")
        surface
        scenery
    }

    /// On the bench: the case every hand-rolled copy of this predicate got
    /// wrong, because a `surface` is not a `container` and so is never `isOpen`.
    let mug = Item {
        name("tin mug")
        adjectives("tin")
    }

    let crate = Item {
        name("crate")
        container
        openable
    }

    let nut = Item {
        name("walnut")
    }

    let jar = Item {
        name("glass jar")
        adjectives("glass")
        container
        openable
        transparent
    }

    let pearl = Item {
        name("pearl")
    }

    /// No `openable`, so always open — the outer shell of the two-deep case.
    let basket = Item {
        name("basket")
        container
    }

    let pouch = Item {
        name("pouch")
        container
        openable
        startsOpen
    }

    /// Two containers deep. `Item/holds(_:)` tests one level, so every
    /// hand-rolled predicate stops short of it; the engine's walk does not.
    let bead = Item {
        name("bead")
    }

    let warden = Actor {
        name("warden")
    }

    /// In somebody else's hands: visible, and never reachable.
    let baton = Item {
        name("baton")
    }

    // MARK: - Elsewhere

    let clinker = Item {
        name("clinker")
    }

    let barrow = Item {
        name("barrow")
    }

    /// The items `probe` reports on, one per containment shape.
    private var probes: [Item] {
        [spanner, mug, nut, pearl, bead, baton, clinker, barrow]
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("probe", intent: Intent("probe"))
    }

    var rules: Rules {
        world.before(Intent("probe")) {
            // The warden goes through `Actor`'s own pair rather than `probes`,
            // so the forwarding is covered too.
            let rows =
                probes.map { ($0.name, $0.isReachable, $0.isVisible) }
                + [(warden.name, warden.isReachable, warden.isVisible)]
            try reply(
                rows
                    .map { name, reach, sight in
                        "\(name): \(reach ? "reachable" : "out of reach"), \(sight ? "visible" : "unseen")"
                    }
                    .joined(separator: "\n"))
        }
    }

    var map: WorldMap {
        workshop.down(cellar)
        cellar.up(workshop)
        workshop.east(yard)
        yard.west(workshop)

        player.starts(in: workshop)
        spanner.startsHeld

        bench.starts(in: workshop)
        mug.starts(on: bench)

        crate.starts(in: workshop)
        nut.starts(inside: crate)

        jar.starts(in: workshop)
        pearl.starts(inside: jar)

        basket.starts(in: workshop)
        pouch.starts(inside: basket)
        bead.starts(inside: pouch)

        warden.starts(in: workshop)
        baton.starts(heldBy: warden)

        clinker.starts(in: cellar)
        barrow.starts(in: yard)
    }
}

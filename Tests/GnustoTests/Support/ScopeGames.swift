import Gnusto

/// Every containment shape the engine draws a line between, in one lit room —
/// plus a dark room and a room the player never stands in.
///
/// `probe` reports ``Item/isReachable`` and ``Item/isVisible`` for each of them
/// in one turn. It has to: parser scope *is* the visible set, so `examine
/// clinker` in another room answers "You can't see any such thing" and a test
/// of "not visible" would never get as far as asking the proxy.
///
/// `reach` asks the same question from somebody else's position —
/// ``Item/isReachable(from:)`` — for the warden standing in the lit workshop
/// and the sentry standing in the pitch-dark cellar. `owns` asks the question
/// that is not about scope at all: ``Actor/possesses(_:)`` beside its
/// one-level form, ``Actor/holds(_:)``.
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

    /// A bag on the warden's belt, and the flask in it. `holds(_:)` stops at
    /// the bag; possession does not.
    let holster = Item {
        name("holster")
        container
    }

    let flask = Item {
        name("flask")
    }

    // MARK: - Elsewhere

    /// Standing in the dark, where the player's own reach set stops at their
    /// hands — and his does not.
    let sentry = Actor {
        name("sentry")
    }

    /// In the sentry's hands, so it survives his being sent nowhere at all.
    let truncheon = Item {
        name("truncheon")
    }

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

    /// What `locate` reports on. Deliberately not ``probes``: having a room is
    /// not a scope question, so this list adds the three things scope has no
    /// answer for — the flask three links up a chain that runs through a pair
    /// of hands, the truncheon in a room the player is not standing in, and
    /// the barrow in one they have never been to.
    private var placed: [Item] {
        [spanner, mug, nut, bead, baton, flask, truncheon, clinker, barrow]
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("probe", intent: Intent("probe"))
        SyntaxRule("reach", intent: Intent("reach"))
        SyntaxRule("owns", intent: Intent("owns"))
        SyntaxRule("locate", intent: Intent("locate"))
        SyntaxRule("banish", intent: Intent("banish"))
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

        world.before(Intent("reach")) {
            func row(_ who: String, _ named: String, _ reaches: Bool) -> String {
                "\(who) reaches \(named): \(reaches ? "yes" : "no")"
            }
            // The player and the sentry go through the player-proxy and
            // `Actor` forms, so those spellings are covered alongside `Item`'s.
            try reply(
                ((probes + [truncheon]).map { row("warden", $0.name, $0.isReachable(from: warden)) }
                    + [
                        row("warden", "the player", player.item.isReachable(from: warden)),
                        row("warden", sentry.name, sentry.isReachable(from: warden)),
                    ]
                    + [spanner, clinker, barrow, truncheon].map {
                        row("sentry", $0.name, $0.isReachable(from: sentry))
                    })
                    .joined(separator: "\n"))
        }

        // Possession is not reach: it walks up rather than down, and it does not
        // care what room anybody is standing in. Reported beside `holds`, which
        // is its one-level form.
        world.before(Intent("owns")) {
            func row(_ who: Actor, _ item: Item) -> String {
                """
                \(who.name) owns \(item.name): \(who.possesses(item) ? "yes" : "no"), \
                holds: \(who.holds(item) ? "yes" : "no")
                """
            }
            try reply(
                ([baton, flask, holster, spanner, mug].map { row(warden, $0) }
                    + [row(sentry, truncheon)])
                    .joined(separator: "\n"))
        }

        // Which room, rather than whether anybody can see or touch it. The
        // walk goes up through hands, surfaces and containers alike, so a
        // shut crate, a dark cellar and somebody else's holster all still
        // answer with a room.
        world.before(Intent("locate")) {
            func row(_ named: String, _ room: Location?) -> String {
                "\(named): \(room?.name ?? "nowhere")"
            }
            try reply(
                (placed.map { row($0.name, $0.location) }
                    + [
                        row(warden.name, warden.location),
                        row("me", player.item.location),
                    ])
                    .joined(separator: "\n"))
        }

        world.before(Intent("banish")) {
            sentry.vanish()
            try reply("The sentry is nowhere at all now.")
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
        holster.starts(heldBy: warden)
        flask.starts(inside: holster)

        sentry.starts(in: cellar)
        truncheon.starts(heldBy: sentry)

        clinker.starts(in: cellar)
        barrow.starts(in: yard)
    }
}

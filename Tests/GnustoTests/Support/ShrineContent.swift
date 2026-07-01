import Gnusto

/// Phase 4b worked example — a *content-bearing* plugin. Unlike the logic-only
/// ``CommercePlugin``, ``ShrineContent`` conforms to ``GameContent`` and ships
/// its **own** region — a shrine room, an offering bowl, a temple bell, and a
/// private visit counter — which the bootstrap namespaces under the bundle's
/// type name so nothing collides with the host. It *also* exposes a host-facing
/// rule factory (``offering(of:merit:credit:)``) that hooks a host item, exactly
/// like a ``GamePlugin``. One importable unit: owned content plus logic over the
/// host's world.
struct ShrineContent: GameContent {
    /// The intent the `donate` verb emits, shared so host rules can name it.
    static let donate = Intent("donate")

    /// The shrine's own room.
    let shrine = Location {
        name("Stone Shrine")
        description("A hushed stone shrine. A worn bowl waits on the altar.")
    }

    /// A scenery fixture the shrine owns.
    let offeringBowl = Item {
        name("offering bowl")
        adjectives("offering", "worn")
        description("A worn stone bowl for offerings.")
        scenery
    }

    /// Deliberately shares the `bell` property label with the host's `bell`, to
    /// prove namespacing (`ShrineContent.bell` vs the host's bare `bell`) keeps
    /// the two from colliding — a clash that was fatal before Phase 4b.
    let bell = Item {
        name("temple bell")
        adjectives("temple")
        description("A green-bronze temple bell, long silent.")
        scenery
    }

    /// The bundle's own `@Global` — namespaced like its entities, so a plugin's
    /// private state can't collide with the host's either.
    @Global var visits = 0

    /// Bundle-internal geography: the bowl and bell belong to the shrine.
    var map: WorldMap {
        offeringBowl.starts(in: shrine)
        bell.starts(in: shrine)
    }

    /// The plugin's player-typeable vocabulary.
    var verbs: [SyntaxRule] {
        SyntaxRule("donate", slots: .direct, intent: Self.donate)
    }

    /// A self-contained, bundle-owned rule: entering the shrine counts the
    /// visit in the bundle's own `@Global` and adds a line of ambiance. It keys
    /// on the *namespaced* shrine ID, proving bundle rules resolve against the
    /// namespace transparently. It uses `say` (augment the turn's output) rather
    /// than `reply` (which would *replace* the automatic room description), so
    /// the shrine's own name and description still print on entry.
    var rules: Rules {
        shrine.onEnter {
            visits += 1
            say("[shrine] Incense drifts past; this is visit #\(visits).")
        }
    }

    /// Host-facing factory: lets the player `donate` a *host* item at the shrine,
    /// crediting a host-owned merit counter with the item's `value` trait. The
    /// closures read and mutate the host's world under the live turn, exactly as
    /// a logic-only plugin's factory does.
    @RuleBuilder
    func offering(
        of item: Item,
        merit: @escaping @Sendable () -> Int,
        credit: @escaping @Sendable (Int) -> Void
    ) -> Rules {
        item.before(Self.donate) {
            let value = item.trait("value", as: Int.self) ?? 0
            credit(value)
            try reply(
                "You lay the \(item.name) in the offering bowl. "
                    + "Your merit rises to \(merit()).")
        }
    }
}

/// The host game for ``ShrineContent``: it lists the shrine plugin in `content`
/// (registering the plugin's namespaced region), owns the merit counter and the
/// donated coin, wires the plaza↔shrine exit across the namespace boundary, and
/// splices the plugin's `donate` verb and `offering` factory over its own item
/// and global. Its own `bell` shares a label with the plugin's without clashing.
struct PilgrimGame: Game {
    let title = "The Pilgrim"
    let intro = "A sunlit plaza before a shrine."

    /// The content-bearing plugin, stored as a plain property and listed below.
    let shrineKit = ShrineContent()

    /// The host owns the merit counter; the plugin only reads and credits it.
    @Global var merit = 0

    let plaza = Location {
        name("Temple Plaza")
        description("A sunlit plaza. A path leads north to a shrine.")
    }

    /// The host's donatable item — placed into the *plugin's* room below, a
    /// cross-namespace placement wired at the top level.
    let coin = Item {
        name("brass coin")
        adjectives("brass")
        description("A heavy brass coin.")
        trait("value", 7)
    }

    /// Shares the `bell` property label with ``ShrineContent``; the two stay
    /// distinct because the plugin's is namespaced.
    let bell = Item {
        name("hand bell")
        adjectives("hand")
        description("A small brass hand bell.")
        scenery
    }

    /// Registering the plugin brings in its namespaced shrine region.
    var content: GameContents {
        shrineKit
    }

    var map: WorldMap {
        player.starts(in: plaza)
        bell.starts(in: plaza)
        coin.starts(in: shrineKit.shrine)  // host item into the plugin's room
        plaza.north(shrineKit.shrine)  // host → plugin exit
        shrineKit.shrine.south(plaza)  // plugin → host exit
    }

    var verbs: [SyntaxRule] {
        shrineKit.verbs
    }

    var rules: Rules {
        shrineKit.offering(
            of: coin,
            merit: { merit },
            credit: { merit += $0 })
    }
}

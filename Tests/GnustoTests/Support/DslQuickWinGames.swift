import Gnusto

// MARK: - require

/// Exercises `require(_:else:)`: a rule that refuses via `require` instead of
/// the longhand `guard … else { try refuse(…) }`.
struct RequireGame: Game {
    let title = "Require"
    let intro = ""

    let cloakroom = Location {
        name("Cloakroom")
        description("A small cloakroom.")
    }

    let foyer = Location {
        name("Foyer")
        description("A grand foyer.")
    }

    let cloak = Item {
        name("velvet cloak")
        wearable
    }

    var map: WorldMap {
        cloakroom.east(foyer)
        foyer.west(cloakroom)
        player.starts(in: cloakroom)
        cloak.startsHeld
    }

    var rules: Rules {
        cloak.before(.drop) {
            try require(
                player.location == cloakroom,
                else: "This isn't the best place to leave a smart cloak lying around.")
        }
    }
}

// MARK: - TraitKey

extension TraitKey<Int> {
    /// Distinct from `CustomStateGames.swift`'s shared `.price` (no default,
    /// used across several fixtures): this key exists only to exercise the
    /// defaulted-subscript overload in isolation.
    static let bulkPrice = Self("bulkPrice")
    static let heftInPounds = Self("heftInPounds", default: 1)
}

/// Exercises the typed `TraitKey` subscript: a present trait, an absent one,
/// and a defaulted one.
struct TraitKeyGame: Game {
    let title = "TraitKey"
    let intro = ""

    let shop = Location {
        name("Shop")
        description("A small shop.")
    }

    /// Has a `.bulkPrice` trait but no `.heftInPounds` — the defaulted key
    /// falls back.
    let lantern = Item {
        name("brass lantern")
        trait(.bulkPrice, 5)
    }

    /// Has neither trait, so `.bulkPrice` reads `nil` through the optional
    /// subscript.
    let sign = Item {
        name("iron sign")
    }

    var map: WorldMap {
        player.starts(in: shop)
        lantern.starts(in: shop)
        sign.starts(in: shop)
    }

    var rules: Rules {
        lantern.before(.examine) {
            // Unannotated, exactly as the brief's acceptance shape
            // (`let cost = lantern[.price]`).
            let price = lantern[.bulkPrice]
            let weight = lantern[default: .heftInPounds]
            try reply("price=\(price as Int?) weight=\(weight)")
        }
        sign.before(.examine) {
            let price = sign[.bulkPrice]
            try reply("price=\(price as Int?)")
        }
    }
}

// MARK: - Closure descriptions

/// The egg `trophyCaseItem`'s description closure checks for — the exact
/// authoring shape from the brief (`trophyCase.holds(egg) ? … : …`),
/// including the self-reference (`trophyCaseItem` naming itself inside its
/// own closure). This only compiles because both are **file-scope** `let`s:
/// a *stored-property* initializer can't reference `self` or a sibling
/// stored property (the restriction `lockable(with:)` works around via the
/// same idiom — see `ContainerGames.swift`'s `pantryKey`), but a top-level
/// `let` is lazily initialized, so a closure captured inside it can name the
/// binding itself — by the time the closure actually runs (mid-turn, well
/// after module initialization), the global already has a value. So: an
/// item declared as a *stored property inside a `Game`/`GameContent`*
/// cannot describe itself this way, but one hoisted to file scope (which is
/// what a description needing self-reference should do) can.
private let eggItem = Item {
    name("jeweled egg")
}

private let trophyRoom = Location {
    name("Trophy Room")
    description("A quiet trophy room.")
}

private let trophyCaseItem = Item {
    name("trophy case")
    surface
    description {
        trophyCaseItem.holds(eggItem)
            ? "The trophy case gleams, holding a jeweled egg."
            : "The trophy case stands empty."
    }
}

/// Exercises live closure descriptions on an item: the trophy case's
/// description reflects whether it currently holds the egg, re-evaluated on
/// every examine rather than fixed at declaration time. Taking the egg off
/// the case (a `surface`) is what flips the closure's result.
struct TrophyCaseGame: Game {
    let title = "TrophyCase"
    let intro = ""

    let room = trophyRoom
    let trophyCase = trophyCaseItem
    let egg = eggItem

    var map: WorldMap {
        player.starts(in: room)
        trophyCase.starts(in: room)
        egg.starts(on: trophyCase)
    }

    var rules: Rules {
        // Lets the runtime-override-beats-closure precedence test flip the
        // trophy case's description to a fixed string regardless of the
        // egg's location.
        trophyCase.before(Intent("seal")) {
            trophyCase.description = "The case has been sealed shut."
            try reply("You seal the case.")
        }
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("seal", slots: .direct, intent: Intent("seal"))
    }
}

/// A tiny content bundle that owns nothing but a `@Global` flag. `@Global`
/// must live as a stored property of a `Game`/`GameContent` type (the
/// bootstrap discovers it by reflecting over that instance; a bare
/// file-scope `@Global var` isn't legal Swift at all — property wrappers
/// require a containing declaration). Splitting the flag into its own bundle
/// lets a file-scope item closure reference it as `lampFlag.lit` — an
/// *other* declaration's property, not `self`'s — exactly as `eggItem` above
/// is other to `trophyCaseItem`.
struct LampFlag: GameContent {
    @Global var lit = false
}

private let lampFlag = LampFlag()

/// A `@Global`-driven variant of the closure-description fixture: the lamp's
/// description reflects `lampFlag.lit`, which a `light`/`douse` pair of
/// custom verbs toggle — the "examine before/after a `@Global` flips"
/// transcript shape named in the brief.
private let lampItem = Item {
    name("brass lamp")
    description {
        lampFlag.lit ? "The brass lamp is burning brightly." : "The brass lamp sits unlit."
    }
}

struct LampGame: Game {
    let title = "Lamp"
    let intro = ""

    let room = Location {
        name("Cellar")
        description("A dark cellar.")
    }

    let lamp = lampItem

    /// Registers `lampFlag`'s namespaced `lit` global with the bootstrap.
    var content: GameContents {
        lampFlag
    }

    var map: WorldMap {
        player.starts(in: room)
        lamp.starts(in: room)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("light", slots: .direct, intent: Intent("light"))
        SyntaxRule("douse", slots: .direct, intent: Intent("douse"))
    }

    var rules: Rules {
        lamp.before(Intent("light")) {
            lampFlag.lit = true
            try reply("The lamp is now lit.")
        }
        lamp.before(Intent("douse")) {
            lampFlag.lit = false
            try reply("The lamp is now dark.")
        }
    }
}

/// Exercises the ambiguous-declaration diagnostic: an item with both a
/// static `description(...)` and a closure `description { ... }`.
struct AmbiguousDescriptionGame: Game {
    let title = "Ambiguous"
    let intro = ""

    let room = Location {
        name("Room")
        description("A room.")
    }

    let widget = Item {
        name("widget")
        description("A plain widget.")
        description { "A shifting widget." }
    }

    var map: WorldMap {
        player.starts(in: room)
        widget.starts(in: room)
    }
}

// MARK: - GameMain

/// A trivial fixture proving `GameMain` compiles when a `Game` opts in.
/// Never invoked as `@main` (that would require stdin); tests call the
/// factored `run(world:io:)` directly with a `ScriptedIOHandler`.
struct MainableGame: Game, GameMain {
    let title = "Mainable"
    let intro = "Welcome."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    var map: WorldMap {
        player.starts(in: room)
    }
}

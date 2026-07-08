import Gnusto

extension Intent {
    #verb("seal", ["seal", .directObject])
    // `light`/`douse` deliberately reclaim rows the built-in turnOn/turnOff
    // also claim, same as the raw SyntaxRule form they replace (last-wins).
    #verb("light", ["light", .directObject])
    #verb("douse", ["douse", .directObject])
}

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

// MARK: - Describe rules

/// Exercises live `describe` rules on an item: the trophy case's description
/// reflects whether it currently holds the egg, re-evaluated on every examine
/// rather than fixed at declaration time. Taking the egg off the case (a
/// `surface`) is what flips the rule's result. Both entities are plain stored
/// properties; the rule reads its own `trophyCase` freely because a `rules`
/// block is a computed property.
struct TrophyCaseGame: Game {
    let title = "TrophyCase"
    let intro = ""

    let room = Location {
        name("Trophy Room")
        description("A quiet trophy room.")
    }

    let trophyCase = Item {
        name("trophy case")
        surface
    }

    let egg = Item {
        name("jeweled egg")
    }

    var map: WorldMap {
        player.starts(in: room)
        trophyCase.starts(in: room)
        egg.starts(on: trophyCase)
    }

    var rules: Rules {
        trophyCase.describe {
            trophyCase.holds(egg)
                ? "The trophy case gleams, holding a jeweled egg."
                : "The trophy case stands empty."
        }

        // Lets the runtime-override-beats-rule precedence test flip the
        // trophy case's description to a fixed string regardless of the
        // egg's location.
        trophyCase.before(.seal) {
            trophyCase.description = "The case has been sealed shut."
            try reply("You seal the case.")
        }
    }

    var verbs: [SyntaxRule] {
        .seal
    }
}

/// A tiny content bundle that owns nothing but a `@Global` flag. `@Global`
/// must live as a stored property of a `Game`/`GameContent` type (the
/// bootstrap discovers it by reflecting over that instance; a bare
/// file-scope `@Global var` isn't legal Swift at all — property wrappers
/// require a containing declaration). Splitting the flag into its own bundle
/// lets `LampGame`'s describe rule read it as `lampFlag.lit`.
struct LampFlag: GameContent {
    @Global var lit = false
}

/// A `@Global`-driven variant of the describe-rule fixture: the lamp's
/// description reflects `lampFlag.lit`, which a `light`/`douse` pair of
/// custom verbs toggle — the "examine before/after a `@Global` flips"
/// transcript shape named in the brief.
struct LampGame: Game {
    let title = "Lamp"
    let intro = ""

    let room = Location {
        name("Cellar")
        description("A dark cellar.")
    }

    let lamp = Item {
        name("brass lamp")
    }

    let lampFlag = LampFlag()

    /// Registers `lampFlag`'s namespaced `lit` global with the bootstrap.
    var content: GameContents {
        lampFlag
    }

    var map: WorldMap {
        player.starts(in: room)
        lamp.starts(in: room)
    }

    var verbs: [SyntaxRule] {
        [.light, .douse]
    }

    var rules: Rules {
        lamp.describe {
            lampFlag.lit ? "The brass lamp is burning brightly." : "The brass lamp sits unlit."
        }
        lamp.before(.light) {
            lampFlag.lit = true
            try reply("The lamp is now lit.")
        }
        lamp.before(.douse) {
            lampFlag.lit = false
            try reply("The lamp is now dark.")
        }
    }
}

/// Exercises the ambiguous-declaration diagnostic: an item with both a
/// static `description(...)` trait and a `describe { ... }` rule.
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
    }

    var map: WorldMap {
        player.starts(in: room)
        widget.starts(in: room)
    }

    var rules: Rules {
        widget.describe { "A shifting widget." }
    }
}

/// Exercises the double-describe diagnostic: one item with two `describe`
/// rules is ambiguous and rejected by the bootstrap.
struct DoubleDescribeGame: Game {
    let title = "DoubleDescribe"
    let intro = ""

    let room = Location {
        name("Room")
        description("A room.")
    }

    let widget = Item {
        name("widget")
    }

    var map: WorldMap {
        player.starts(in: room)
        widget.starts(in: room)
    }

    var rules: Rules {
        widget.describe { "A shifting widget." }
        widget.describe { "A different widget." }
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

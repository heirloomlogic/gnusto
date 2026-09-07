import Gnusto

// The verbs a custom game invents when all it wants is a sentence. Each is
// answered by an `action(…)` *line* rather than a closure, which is the only
// spelling that reaches the stub path — and with it the reach guard, the
// object's rendered name and the `yourself`/`somebodyElse` guards.
extension Intent {
    /// Guarded on purpose: you cannot work a winch you cannot lay a hand on.
    #verb("winch", ["winch", .directObject])
    /// Unguarded on purpose — the twin of `winch`, and the regression test for
    /// the default. A custom intent has no reach requirement today, so adopting
    /// the line spelling must not invent one: Dungeon's basket is raised from
    /// the far end of a shaft, and a default that tightened would have broken
    /// the walkthrough silently.
    #verb("chant", ["chant", .directObject])
    /// Names what it is aimed at, so it wants the number and the two guards.
    #verb("scold", ["scold", .directObject])
    /// Used with an object or without one, so one declaration owns both halves.
    #verb("whistle", ["whistle"], ["whistle", "at", .directObject])
}

/// The default-line fixture: one room, one verb per shape, and everything the
/// three factories have to answer for.
///
/// The jar is the engine's own reach case — shut and transparent, so the cog
/// inside is in scope for the parser and out of arm's reach for anything that
/// has to touch it. The grille is the other one, a declared
/// ``Item/reach(otherwise:)`` rule, which settles at stage 0 and therefore only
/// fires at all if the line's `reach:` column is read there too.
struct DefaultLineGame: Game {
    let title = "Default Lines"
    let intro = "A workshop, and a jar you can see into."

    let workshop = Location {
        name("Workshop")
        description("A workshop with a jar on the bench.")
    }

    let jar = Item {
        name("glass jar")
        adjectives("glass")
        container
        openable
        transparent
    }

    let cog = Item {
        name("brass cog")
        adjectives("brass")
        description("A small brass cog.")
    }

    /// Behind a grille: visible, and refused by its own reach rule.
    let crank = Item {
        name("iron crank")
        adjectives("iron")
        description("An iron crank behind a grille.")
    }

    /// Honestly plural, so a line whose verb agrees has to agree in the plural.
    let bellows = Item {
        name("bellows")
        adjectives("leather")
        description("A pair of leather bellows.")
        plural
    }

    let porter = Actor {
        name("night porter")
        adjectives("night")
        description("The night porter, waiting to be told something.")
    }

    var verbs: [SyntaxRule] {
        [.winch, .chant, .scold, .whistle]
    }

    var actions: [IntentAction] {
        action(.winch, reach: .directObject, say: "The winch does not answer to that.")
        action(.chant, say: "Nothing answers the chant.")
        action(.scold, naming: { "\($0.sentenceCased) \($0.verb("takes", "take")) no notice." })
        action(.whistle, orBare: "You whistle at nobody in particular.", guardsActors: true) {
            "You whistle at \($0), which changes nothing."
        }
    }

    var rules: Rules {
        crank.reach(otherwise: "The grille is in the way.") { false }
        // The line is a floor, so one entity promotes itself above it the
        // ordinary way, exactly as it would above a stub verb's.
        bellows.before(.winch) {
            try reply("The bellows wheeze, and the winch is none the wiser.")
        }
        // Stage 5, which a `reply` unwinds and a `say` does not. The line above
        // is a floor, so this still gets its turn.
        workshop.after(.whistle) {
            say("The workshop swallows the note.")
        }
    }

    var map: WorldMap {
        player.starts(in: workshop)
        jar.starts(in: workshop)
        cog.starts(inside: jar)
        crank.starts(in: workshop)
        bellows.starts(in: workshop)
        porter.starts(in: workshop)
    }
}

/// A game that writes a default *line* for an intent the engine already answers
/// with one. It works, and it warns: `text.stubs.squeeze` is the shorter road
/// and keeps the verb's own rows, so a row here is almost always somebody who
/// only wanted to change the words. (#233, #404)
struct StubLineOverrideGame: Game {
    let title = "Stub Line Override"
    let intro = "A room with a sponge."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    let sponge = Item {
        name("damp sponge")
        adjectives("damp")
    }

    var actions: [IntentAction] {
        action(.squeeze, say: "The sponge weeps, and so do you.")
    }

    var map: WorldMap {
        player.starts(in: room)
        sponge.starts(in: room)
    }
}

import Gnusto

/// A content bundle: the attic region of ``BundleGame``, with its own room,
/// item, rules, and a bundle-local verb — all declared in a type separate from
/// the game struct. The bootstrap discovers these stored declarations by
/// reflecting over the bundle instance the game lists in its `content` block.
struct AtticContent: GameContent {
    let hall = Location {
        name("Attic Hall")
        description("A dim attic hall under a sloped roof.")
    }

    let trunk = Item {
        name("steamer trunk")
        adjectives("steamer")
        description("A battered steamer trunk bound in iron.")
    }

    var map: WorldMap {
        trunk.starts(in: hall)
    }

    var rules: Rules {
        trunk.before(.examine) {
            try reply("[attic] The trunk is bound in iron straps.")
        }
        trunk.before(Intent("rummage")) {
            try reply("[attic] You rummage through the trunk and find lint.")
        }
    }

    /// A verb contributed by the bundle, proving bundle verbs reach the parser
    /// and their rules fire just like a game's own.
    var verbs: [SyntaxRule] {
        SyntaxRule("rummage", slots: .direct, intent: Intent("rummage"))
    }
}

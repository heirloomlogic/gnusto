import Gnusto

/// Fixture for ``Item/replace(with:)``. A salvage yard whose press turns each of
/// its objects into that object's own wreckage, with one pair per placement a
/// thing can be in — on the floor, in your hands, inside a sack, on a bench,
/// worn, and offstage — so a single fixture can watch the swap from all five
/// `Placement` cases without the swaps interfering with each other.
struct SalvageYardGame: Game {
    let title = "Salvage Yard"
    let intro = "Everything here is one good knock from being something else."

    let yard = Location {
        name("Salvage Yard")
        description("Cramped, orderly, and very quiet.")
    }

    let sack = Item {
        name("canvas sack")
        adjectives("canvas")
        container
        startsOpen
    }

    let bench = Item {
        name("oak bench")
        adjectives("oak")
        surface
    }

    // One pair per placement. The first of each is what gets replaced; the
    // second is what takes its place.

    let vase = Item { name("glass vase") }
    let shards = Item { name("heap of shards") }

    let flask = Item { name("tin flask") }
    let dents = Item { name("dented flask") }

    let bulb = Item { name("clear bulb") }
    let filament = Item { name("burnt filament") }

    let dish = Item { name("china dish") }
    let chips = Item { name("chipped dish") }

    /// Never placed, so `replace` has an offstage source to read.
    let ghost = Item { name("pale ghost") }
    let echo = Item { name("faint echo") }

    let cloak = Item {
        name("wool cloak")
        adjectives("wool")
        wearable
    }
    let rags = Item { name("moth-eaten rags") }

    /// A container with something in it, for the contents question: the nail
    /// leaves play with the crate rather than following the splinters.
    let crate = Item {
        name("pine crate")
        adjectives("pine")
        container
        startsOpen
    }
    let nail = Item { name("bent nail") }
    let splinters = Item { name("pile of splinters") }

    /// A vehicle, for the passenger question.
    let raft = Item {
        name("cork raft")
        adjectives("cork")
        enterable
        container
    }
    let flotsam = Item { name("scrap of flotsam") }

    var map: WorldMap {
        player.starts(in: yard)

        sack.starts(in: yard)
        bench.starts(in: yard)
        crate.starts(in: yard)
        raft.starts(in: yard)

        vase.starts(in: yard)
        flask.startsHeld
        bulb.starts(inside: sack)
        dish.starts(on: bench)
        cloak.startsWorn
        nail.starts(inside: crate)
        // ghost, and every replacement, start offstage.
    }

    /// Every pair the press can wreck, named once. The `wreck` rules and the
    /// `survey` report are both derived from this, so adding a placement to the
    /// fixture is one edit rather than two.
    private var pairs: [(from: (String, Item), to: (String, Item))] {
        [
            (("vase", vase), ("shards", shards)),
            (("flask", flask), ("dents", dents)),
            (("bulb", bulb), ("filament", filament)),
            (("dish", dish), ("chips", chips)),
            (("cloak", cloak), ("rags", rags)),
            (("crate", crate), ("splinters", splinters)),
            (("raft", raft), ("flotsam", flotsam)),
        ]
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("wreck", .directObject, intent: Intent("wreck"))
        SyntaxRule("haunt", intent: Intent("haunt"))
        SyntaxRule("negate", intent: Intent("negate"))
        SyntaxRule("survey", intent: Intent("survey"))
    }

    var rules: Rules {
        // Each one replies, so the turn finishes rather than falling through to
        // stage 4's "You can't do that" — which would skip the rest of the turn
        // with the swap already made.
        for pair in pairs {
            pair.from.1.before(Intent("wreck")) {
                pair.from.1.replace(with: pair.to.1)
                try reply("Wrecked.")
            }
        }

        // The offstage pair, which the player cannot name.
        world.before(Intent("haunt")) {
            ghost.replace(with: echo)
            try reply("The yard is no emptier than it was.")
        }

        // Replacing a thing with itself must not destroy it.
        world.before(Intent("negate")) {
            vase.replace(with: vase)
            try reply("Nothing happens, twice.")
        }

        world.before(Intent("survey")) {
            try reply(report)
        }

        // Reads the sack before and after a swap made in the same rule body, so
        // a test can watch `replace` invalidate the containment cache the way
        // every other mover does.
        bench.before(.examine) {
            let before = sack.contents.map(\.name).joined(separator: ",")
            bulb.replace(with: filament)
            let after = sack.contents.map(\.name).joined(separator: ",")
            try reply("before=[\(before)] after=[\(after)]")
        }
    }

    /// One machine-readable line naming where every tracked item is, what the
    /// room holds, whether the nail is still within reach, and what the player
    /// is riding. Read by every case in `ItemReplaceTests`.
    private var report: String {
        let tracked =
            pairs.flatMap { [$0.from, $0.to] } + [("ghost", ghost), ("echo", echo)]
        let placements = tracked.map { "\($0.0)=\(whereIs($0.1))" }.joined(separator: " ")
        let room = yard.contents.map(\.name).sorted().joined(separator: ",")
        // Indented, so `TextWrap` reads it as a form and keeps it one row per
        // field. This is a state dump routed through the transcript, not prose:
        // folded into a paragraph the artifact is still assertable but unreadable.
        return """
              \(placements)
              room=[\(room)]
              nailReachable=\(nail.isReachable)
              aboard=\(player.vehicle?.name ?? "none")
            """
    }

    /// Where one item is, in the fixture's own vocabulary. Worn is asked before
    /// held because ``Item/isHeld`` counts a worn item as carried. "gone" means
    /// none of the places this yard has, which for these items is
    /// `Placement.nowhere`.
    private func whereIs(_ item: Item) -> String {
        if item.isWorn { return "worn" }
        if item.isHeld { return "held" }
        if item.isIn(yard) { return "room" }
        if sack.holds(item) { return "sack" }
        if bench.holds(item) { return "bench" }
        return "gone"
    }
}

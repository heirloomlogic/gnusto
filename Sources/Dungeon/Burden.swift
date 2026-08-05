import Gnusto

extension TraitKey<Int> {
    /// How much an item counts against the carrying cap — the mainframe's
    /// `OSIZE`, used as-is wherever the source declares one. Defaulted to 5,
    /// so an item with no declared size still has weight.
    public static let weight = Self("weight", default: 5)
}

/// The carrying limit. Every takeable item has a ``TraitKey/weight``, and the
/// sum of everything in the player's hands — counted recursively, so a loaded
/// sack brings its contents along — may not exceed ``carryCap``. A `take` that
/// would tip the load over is refused before it happens.
///
/// A world-wide `before(.take)` rule with no rooms of its own, added to the
/// host's `content` like any other bundle.
struct DungeonBurden: GameContent {
    /// The mainframe's cap. Sizes are the source's `OSIZE` values, so this
    /// number means what it means there: the sword alone is 30, the coil of
    /// rope 10, the welcome mat 12.
    static let carryCap = 100

    var rules: Rules {
        world.before(.take) {
            guard let target = command.directObject else { return }
            let carried = player.inventory.reduce(0) { $0 + burdenWeight(of: $1) }
            try require(
                carried + burdenWeight(of: target) <= Self.carryCap,
                else: Prose.handsFull)
        }
    }
}

/// An item's own weight plus the weight of everything inside it, all the way
/// down — a full sack weighs its own 3 plus the garlic and the lunch.
///
/// Internal rather than `private` so a later region's load gate — the altar
/// crack, when the temple lands — can weigh the player's hands exactly the way
/// the carry cap does. (The Studio chimney is *not* one of those: it counts
/// things in hand rather than weighing them, which is the mainframe's own rule
/// and is recorded in `FIDELITY.md`.)
///
/// - Parameter item: the item to weigh.
/// - Returns: the item's total burden, contents included.
func burdenWeight(of item: Item) -> Int {
    item.contents.reduce(item[default: .weight]) { $0 + burdenWeight(of: $1) }
}

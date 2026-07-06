import Gnusto

extension TraitKey<Int> {
    /// How much an item counts toward the carrying cap. Defaulted to 5, so
    /// every takeable item has weight even without a declared one; heavy
    /// items (the coffin, the bar of gold) will override it in later regions.
    public static let weight = Self("weight", default: 5)
}

/// The carrying limit. Every takeable item has a `.weight` (default 5), and
/// the sum of everything in the player's hands — counted recursively, so a
/// loaded sack brings its contents' weight along — may not exceed
/// ``carryCap``. A `take` that would tip the load over is refused before it
/// happens.
///
/// This is a world-wide `before(.take)` rule with no rooms of its own, added
/// to the host's `content` like any other bundle. It reuses the T1 primitives
/// `player.inventory` and `Item.contents` to walk what's held.
struct ZorkBurden: GameContent {
    /// The most weight the player can hold at once. The original's cap is
    /// 100; at the default item weight of 5 that's twenty small things —
    /// ample for the current slice, tight enough that the loaded-down cases
    /// (and the chimney's stricter count gate) can be exercised.
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

/// An item's own weight plus the weight of everything it contains, all the
/// way down — a full sack weighs its own 5 plus the garlic and the lunch.
///
/// - Parameter item: the item to weigh.
/// - Returns: the item's total burden, contents included.
private func burdenWeight(of item: Item) -> Int {
    item.contents.reduce(item[default: .weight]) { $0 + burdenWeight(of: $1) }
}

extension TraitKey<Int> {
    /// How much an item counts against ``Burden``'s carrying cap. Defaulted to
    /// 5, so an item with no declared weight still has some; a game sets the
    /// heavy ones — `trait(.weight, 20)` — and leaves the rest.
    public static let weight = Self("weight", default: 5)
}

/// A carrying limit. Every takeable item has a ``TraitKey/weight``, and the sum
/// of everything in the player's hands — counted recursively, so a loaded sack
/// brings its contents along — may not exceed ``carryCap``. A `take` that would
/// tip the load over is refused before it happens.
///
/// A world-wide `before(.take)` rule with no rooms of its own, added to the
/// game's `content` like any other bundle:
///
/// ```swift
/// let burden = Burden(carryCap: 100)
///
/// var content: GameContents { burden }
/// ```
///
/// The refusal is ``GameText/handsFull``, re-voiced like any other stock line:
/// `text.handsFull = "You're holding too many things already!"`.
///
/// ``Item/burden`` and ``Player/burden`` weigh the way the cap weighs, so a
/// game's own load gates — a crack too narrow for a coffin, a rope that holds
/// for fewer turns the more you carry — ask the same question the cap does.
public struct Burden: GameContent {
    /// The most weight the player can hold at once.
    public let carryCap: Int

    /// Creates a carrying limit.
    ///
    /// - Parameter carryCap: the most weight the player can hold at once.
    public init(carryCap: Int) {
        self.carryCap = carryCap
    }

    /// The one rule: a `take` that would tip the load over the cap is refused
    /// before it happens.
    public var rules: Rules {
        world.before(.take) {
            guard let target = command.directObject else { return }
            try require(
                player.burden + target.burden <= carryCap,
                else: gameText.handsFull(target.definiteNoun))
        }
    }
}

extension Item {
    /// The item's own ``TraitKey/weight`` plus that of everything inside it, all
    /// the way down — a full sack weighs its own 5 plus the garlic and the
    /// lunch.
    public var burden: Int {
        contents.reduce(self[default: .weight]) { $0 + $1.burden }
    }
}

extension Player {
    /// Everything in the player's hands, weighed the way ``Burden`` weighs it:
    /// contents included, all the way down.
    public var burden: Int {
        inventory.reduce(0) { $0 + $1.burden }
    }
}

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
/// A number and no rules of its own, added to the game's `content` like any
/// other bundle:
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
/// **The cap is the last thing `take` asks, not the first.** It is the broadest
/// answer the verb has — "no room in your hands" — so every refusal that is
/// about *this* thing outranks it: taking yourself, taking a person, taking
/// what you already hold or wear, taking scenery, taking what you cannot
/// reach, taking the vehicle you are standing in, and any refusal the game
/// writes in a rule of its own. The cap is checked where `take` decides,
/// after all of those, which is why `Burden` declares no rule.
///
/// Because the cap is `take`'s own last question, a game that replaces the
/// verb wholesale with an `action(.take)` of its own owns the cap along with
/// every other refusal it just took responsibility for.
///
/// Weight already in the player's hands is not weighed twice. Taking something
/// out of a sack they are carrying does not change the load, so the cap has no
/// opinion about it however full the sack is.
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

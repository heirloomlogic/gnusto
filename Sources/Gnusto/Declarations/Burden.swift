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
/// **The cap is asked first and answers last.** The rule is world scope, so
/// it runs at stage 1 — ahead of the game's own `before(.take)` rules and
/// ahead of `take` itself. That is what holds the cap for a game that replaces
/// the verb with an `action(.take)` of its own, and it is what stops a
/// `before(.take)` rule that changes the world from committing its change and
/// then being told the player's hands are full.
///
/// Running first would make "no room in your hands" answer for every refusal
/// `take` owns, which is the broad line printed over the specific one. So the
/// rule consults `take`'s own ladder before it speaks, and says nothing
/// whenever `take` has a more particular answer: taking yourself, taking a
/// person, taking what you already hold or wear, taking scenery, taking what
/// you cannot reach, taking the vehicle you are standing in. An order given to
/// somebody else is not weighed at all — the cap is about the player's hands.
///
/// A refusal the *game* writes in a `before(.take)` rule of its own is stage 3
/// and so is printed only if the cap passed. Put it in a `reach { … }` rule to
/// have it answer first.
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

    /// The one rule: a `take` that would tip the load over the cap is refused
    /// before it happens — unless `take` has a more specific refusal of its
    /// own, in which case that one is the answer and this says nothing.
    public var rules: Rules {
        world.before(.take) {
            // Somebody else's arms are not the player's hands.
            guard command.actor == nil, let target = command.directObject else { return }
            // Weight already in the player's hands is not weighed twice:
            // lifting the garlic out of the sack they are carrying changes
            // the load by nothing, however full the sack is.
            // Read outside the `frame.with { … }` below: a proxy resolves
            // through the frame, and the lock is not reentrant.
            let id = target.id
            let frame = Ctx.current
            guard !frame.with({ $0.state.isPossession(id, of: .player) }) else { return }
            guard player.burden + target.burden > carryCap else { return }
            // Over the cap — but only say so where `take` would otherwise have
            // lifted it. Every line `take` owns is about this particular
            // thing, and so outranks the broadest answer the verb has.
            guard DefaultActions.takeRefusal(for: target, frame: frame) == nil else { return }
            try refuse(gameText.handsFull(target.definiteNoun))
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

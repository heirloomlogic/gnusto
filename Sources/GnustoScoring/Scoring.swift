import Gnusto

extension TraitKey<Int> {
    /// Points awarded the first time this treasure is taken.
    public static let takeValue = Self("takeValue")

    /// Points awarded the first time this treasure lands in the trophy case.
    public static let depositValue = Self("depositValue")
}

/// Treasure scoring: typed point values on items, an award-once register,
/// and take/deposit wiring for a trophy case. Add it to a game's `content`
/// block, put values on the treasures, and splice one factory call into
/// the rules:
///
/// ```swift
/// let scoring = Scoring()
///
/// let idol = Item { name("jade idol"); trait(.takeValue, 5); trait(.depositValue, 8) }
///
/// var content: GameContents { scoring }
/// var rules: Rules {
///     scoring.treasures([idol], into: trophyCase)
/// }
/// ```
///
/// The engine's own `score` verb, status line, and end-of-game epilogue do
/// the reporting; this plugin only moves the number. Points are paid **once
/// per register** and never taken back — re-taking a dropped treasure or
/// re-depositing a re-stolen one is a silent no-op, unlike the original
/// Zork's in-case accounting, which deducted on removal.
///
/// `maxScore` stays the host's responsibility (the engine reads it at
/// bootstrap, before any rule can run): sum your declared values.
public struct Scoring: GameContent {
    /// Register names already paid out. A wrapper struct rather than a bare
    /// `Set` so the `GlobalValue` conformance is owned here, not declared
    /// retroactively on a standard-library type.
    struct Claimed: Codable, Sendable, GlobalValue {
        var names: Set<String> = []
    }

    @Global var claimed = Claimed()

    public init() {}

    /// Awards `points` exactly once per register name; later calls with the
    /// same name are silent no-ops, as is a zero-point award. Callable from
    /// any rule body:
    ///
    /// ```swift
    /// world.before(solveIntent) { scoring.awardOnce("puzzle", points: 5) }
    /// ```
    public func awardOnce(_ register: String, points: Int) {
        guard points != 0, !claimed.names.contains(register) else { return }
        claimed.names.insert(register)
        player.score += points
    }

    /// For each treasure: the first `take` pays its `.takeValue`, and the
    /// first arrival inside `trophyCase` pays its `.depositValue`. Register
    /// keys derive from the item's display name ("take.green gem"), so
    /// treasures wired here need unique names. Splice into the host's rules:
    ///
    /// ```swift
    /// scoring.treasures([painting, egg], into: trophyCase)
    /// ```
    @RuleBuilder
    public func treasures(_ items: [Item], into trophyCase: Item) -> Rules {
        for item in items {
            item.after(.take) {
                awardOnce("take.\(item.name)", points: item[.takeValue] ?? 0)
            }
            item.after(.putIn) {
                // The after-rule fires for *any* container; only the trophy
                // case pays.
                guard trophyCase.holds(item) else { return }
                awardOnce("deposit.\(item.name)", points: item[.depositValue] ?? 0)
            }
        }
    }
}

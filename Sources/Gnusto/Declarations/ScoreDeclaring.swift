/// Content that can total the points it pays out, so the bootstrap can check a
/// game's ``Game/maxScore`` against what the game is actually able to award.
///
/// `maxScore` is read at bootstrap, before any rule has run, so on its own it is
/// nothing but the author's arithmetic: add a third award and forget the total,
/// and the game ships with a maximum it can never reach — or a ceiling the player
/// can score straight past. A `GameContent` that knows its own award table can
/// conform here, and the bootstrap will compare the two and warn when they
/// disagree.
///
/// ```swift
/// extension Bounty: ScoreDeclaring {
///     public func declaredMaxScore(items: [Item]) -> Int? {
///         awards.values.reduce(0, +)
///     }
/// }
/// ```
///
/// The check is non-fatal: nothing breaks at runtime, and a game that means to
/// declare an unreachable ceiling stays playable. Content that cannot total
/// itself returns `nil` and is skipped, so the check is opt-in by declaration.
public protocol ScoreDeclaring {
    /// The points this content can pay over a complete playthrough, or `nil`
    /// when it declares nothing and the check should be skipped.
    ///
    /// Called once at bootstrap, inside the registration frame, so it may read
    /// item traits (`item[.takeValue]`) exactly as a rule body would.
    ///
    /// - Parameter items: every item in the assembled world, including actors
    ///   and the player — enough to total values declared as traits rather than
    ///   in the content's own table.
    /// - Returns: the total the content can award, or `nil` to opt out.
    func declaredMaxScore(items: [Item]) -> Int?
}

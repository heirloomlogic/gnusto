/// Which object slots a verb needs within arm's reach, as opposed to merely in
/// view. Declared by every row of both halves of the standard table — ``CoreVerb``
/// and ``StubVerb`` — so the answer is stated once per verb and derived from
/// there.
///
/// Parser scope is the *visible* set, which admits what can be seen through the
/// glass of a shut jar or in somebody else's hands. Much of the table is fine
/// with that — you can smell a fire across a room, count coins behind glass,
/// examine a thing you will never touch — and much of it is nonsense at a
/// distance, so the answer is per verb rather than a blanket guard.
///
/// Three cases and not a `Bool` because the two-slot shapes disagree with each
/// other: `give X to Y` and `put X in Y` have to reach the recipient, and
/// `throw X at Y` must *not* have to reach the target, which is the whole point
/// of throwing. Nothing wants the indirect object alone: the two-slot verbs that
/// care about the container also want the thing going into it, and a direct
/// object already in the player's hands passes for free.
enum Reach: Sendable {
    /// Works at a distance — or takes no object at all.
    case notNeeded
    /// The direct object must be reachable.
    case directObject
    /// Both objects must be reachable.
    case bothObjects

    /// A declared `reach { … }` rule: the predicate and the line it refuses
    /// with, kept together so the two can't drift apart in the rule table.
    struct Rule: Sendable {
        let allows: @Sendable () -> Bool
        /// `nil` falls back to ``GameText/cantReach``.
        let refusal: String?
    }

    /// The slots this requirement names, out of a command that filled some of
    /// them. Optionals, so the one array is the only allocation: a slot the
    /// command didn't fill is nothing to check, since `wave` and `wave <object>`
    /// are one intent and only the second has anything to reach.
    func slots(of command: Command) -> [Item?] {
        switch self {
        case .notNeeded: []
        case .directObject: [command.directObject]
        case .bothObjects: [command.directObject, command.indirectObject]
        }
    }
}

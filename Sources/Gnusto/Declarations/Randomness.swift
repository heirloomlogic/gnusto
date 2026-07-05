/// All randomness in a game flows through one seedable stream that lives in
/// `WorldState`: the same seed replays the same game on every platform, and
/// save/restore resumes the stream exactly where it left off.

extension WorldState {
    /// Advances the stream and returns its next raw value — SplitMix64:
    /// a golden-ratio increment, then a 64-bit finalizing mix. Pure integer
    /// arithmetic, so identical on every platform.
    mutating func nextRandom() -> UInt64 {
        rngState &+= 0x9E37_79B9_7F4A_7C15
        var mixed = rngState
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

/// A uniform draw from the range, for rule bodies:
/// `if random(1...6) == 6 { … }`.
///
/// Reduction is by modulo — its bias is far below anything a game can
/// notice, and it keeps the stream's arithmetic simple.
///
/// - Parameter range: the range to draw from.
/// - Returns: a uniform value within the range.
public func random(_ range: ClosedRange<Int>) -> Int {
    let span = UInt64(range.upperBound &- range.lowerBound) &+ 1
    let draw = Ctx.current.with { $0.state.nextRandom() }
    return range.lowerBound &+ Int(draw % span)
}

/// One of the options, uniformly: `say(oneOf("Thud.", "Clang."))`.
///
/// - Parameter options: the choices to draw from.
/// - Returns: one option, chosen uniformly.
public func oneOf(_ options: String...) -> String {
    oneOf(options)
}

/// One of the options, uniformly, from an array.
///
/// - Parameter options: the choices to draw from.
/// - Returns: one option, chosen uniformly.
public func oneOf(_ options: [String]) -> String {
    guard !options.isEmpty else {
        fatalError("Gnusto: oneOf(…) needs at least one option.")
    }
    return options[random(0...(options.count - 1))]
}

/// True `percent` times out of a hundred: `if chance(30) { … }`.
///
/// - Parameter percent: the odds, out of a hundred.
/// - Returns: `true` with the given probability.
public func chance(_ percent: Int) -> Bool {
    random(1...100) <= percent
}

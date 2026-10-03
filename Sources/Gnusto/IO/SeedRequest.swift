import Foundation

/// What `GNUSTO_SEED` asked of the random stream.
///
/// A game draws every random value — combat rolls, roaming actors, `oneOf`
/// prose — from one seeded stream (`WorldState/rngState`), so pinning the seed
/// makes a whole session replay identically. `play(_:_:seed:)` already does
/// that in the test suite; this is the same knob for a built binary, so a
/// transcript a tester records by hand becomes a reproducer someone else can
/// replay.
///
/// It is also what the suite's own `cachedWorld` falls back to for a `play`
/// call that pins no seed, which is what makes `GNUSTO_SEED=7 swift test`
/// reproducible and a sweep across seeds able to find tests that only pass by
/// luck. See <doc:TestingYourGame>.
///
/// A bad value is reported rather than ignored. The variable exists for
/// reproducibility, so silently handing back a random stream after a typo
/// would defeat the one thing it is for.
public enum SeedRequest: Equatable, Sendable {
    /// `GNUSTO_SEED` was unset, empty, or whitespace: seed randomly, as ever.
    case unset

    /// A seed to pin the stream to.
    case pinned(UInt64)

    /// A value that isn't a `UInt64`, kept verbatim so the complaint can quote
    /// what the operator actually typed.
    case invalid(String)

    /// Reads `GNUSTO_SEED`, tolerating the stray whitespace a shell wrapper or
    /// a copied-and-pasted value tends to bring with it.
    ///
    /// - Parameter environment: the environment to read `GNUSTO_SEED` from.
    public init(environment: [String: String]) {
        let value = environment["GNUSTO_SEED", default: ""]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .unset
            return
        }
        self = UInt64(trimmed).map { .pinned($0) } ?? .invalid(value)
    }

    /// The seed to hand `GameWorld`, or `nil` to let it pick one at random.
    public var value: UInt64? {
        guard case .pinned(let seed) = self else { return nil }
        return seed
    }

    /// What to tell the operator on standard error, or `nil` when there is
    /// nothing to say.
    public var complaint: String? {
        guard case .invalid(let value) = self else { return nil }
        return """
            Ignoring GNUSTO_SEED=\(value): expected a whole number from 0 to \
            \(UInt64.max). Seeding at random instead.
            """
    }
}

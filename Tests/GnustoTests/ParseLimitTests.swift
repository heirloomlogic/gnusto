import GnustoTestSupport
import Testing

@testable import CloakOfDarkness
@testable import Gnusto

/// How long a line the parser will read, and what it does with a longer one.
///
/// Issue #503: several loops in `StandardParser` walk token positions and none
/// of them is linear, so a long enough line costs seconds and the game accepts
/// nothing for the duration — at a terminal, and on a play-test server over
/// JSON-RPC, which has no turn timeout to cut it short. The fix is one cap on
/// the line, taken at the parse entry, which is what all of those loops are
/// reached from. `StandardParser.tokenLimit` names the loops and carries the
/// measurements.
///
/// The tests below pin the two things a cap has to get right: that it stands
/// well clear of any sentence a player writes, and that the line past it is
/// answered cheaply rather than worked on.
struct ParseLimitTests {
    /// `ParserTests`' own fixture — the same Cloak of Darkness parser and the
    /// same three visible items — so a boundary line here is a line that suite
    /// would read.
    private static let scope = ParserTests.fullScope

    /// `take cloak and cloak and … cloak` — one verb, then `nouns` nouns with a
    /// conjunction between each pair, which is `2 * nouns` tokens. A real
    /// sentence at any length, which is what makes it usable on both sides of
    /// the cap; naming one thing over and over keeps the answer the same too.
    private static func repeatedList(nouns: Int) -> String {
        "take " + Array(repeating: "cloak", count: nouns).joined(separator: " and ")
    }

    /// A wall-clock bound, loose by three orders of magnitude: every parse
    /// below returns in well under a millisecond, so half a second is a margin
    /// no loaded runner is going to eat.
    private static let bound = Duration.milliseconds(500)

    /// How long `work` took, so a test can assert the answer and the cost
    /// together — a speed-up bought by reading the line differently has to fail
    /// as loudly as a slow one.
    private static func timed<T>(_ work: () -> T) -> (result: T, elapsed: Duration) {
        let start = ContinuousClock.now
        let result = work()
        return (result, ContinuousClock.now - start)
    }

    // MARK: - The boundary

    /// A line of exactly `tokenLimit` tokens is read, and read normally. The
    /// list names one thing over and over, so the answer is the plain TAKE the
    /// two-word line gives — the cap is a length check and changes no reading.
    @Test func aLineAtTheLimitParsesNormally() throws {
        let parser = try ParserTests.makeParser()
        let line = Self.repeatedList(nouns: StandardParser.tokenLimit / 2)
        #expect(parser.tokenize(line).count == StandardParser.tokenLimit)

        let parsed = try parser.parse(line, scope: Self.scope).get()
        #expect(parsed.intent == .take)
        #expect(parsed.directObject == EntityID("cloak"))
    }

    /// Past it, the same sentence is refused. `unmatchedSyntax` is the "I
    /// didn't understand that sentence" line, and like every parse failure it
    /// costs no turn.
    @Test func aLineOverTheLimitIsRefused() throws {
        let parser = try ParserTests.makeParser()
        let line = Self.repeatedList(nouns: StandardParser.tokenLimit / 2 + 1)
        #expect(parser.tokenize(line).count > StandardParser.tokenLimit)

        #expect(parser.parse(line, scope: Self.scope) == .failure(.unmatchedSyntax))
    }

    /// The cap has to sit far enough above real play that no player meets it.
    /// This is the longest command typed anywhere in this repository — tests,
    /// demo games, walkthroughs, the committed play-test routes. Nine words,
    /// and seven tokens once the articles are dropped as noise, which is what
    /// the cap counts.
    @Test func theLongestSentenceThisRepositoryTypesIsWellUnderTheLimit() throws {
        let parser = try ParserTests.makeParser()
        let line = "put the velvet cloak onto the small brass hook"
        #expect(parser.tokenize(line).count == 7)
        #expect(7 < StandardParser.tokenLimit / 10)

        let parsed = try parser.parse(line, scope: Self.scope).get()
        #expect(parsed.intent == .putOn)
    }

    // MARK: - Cost

    /// The two shapes #503 measured, at lengths that used to cost seconds:
    /// `give` is the recipient-first row, whose every split resolves both
    /// halves, and `take` is one long noun phrase walked by the resolver.
    ///
    /// Two lengths, and they ascend: the loop stops at the first to bust the
    /// bound, so a regression fails here in well under a second at two hundred
    /// tokens rather than hanging at twenty thousand.
    @Test(arguments: ["give", "take"])
    func aPathologicalLineIsRefusedInBoundedTime(_ verb: String) throws {
        let parser = try ParserTests.makeParser()

        for count in [200, 20_000] {
            let line =
                verb + " "
                + Array(repeating: "cloak hook", count: count / 2).joined(separator: " ")
            let (result, elapsed) = Self.timed { parser.parse(line, scope: Self.scope) }

            guard result == .failure(.unmatchedSyntax) else {
                Issue.record("\(count) tokens of \(verb) parsed as \(result)")
                return
            }
            guard elapsed < Self.bound else {
                Issue.record("\(count) tokens of \(verb) took \(elapsed), over \(Self.bound)")
                return
            }
        }
    }

    /// The other half of the claim: what the cap *admits*. The worst shape at
    /// the limit is the recipient-first row, every split of which resolves —
    /// so a line of exactly `tokenLimit` tokens in that shape is the ceiling a
    /// line has to be written to reach, and it is still cheap. The bound is
    /// the same loose half-second, which is two orders of magnitude above the
    /// measurement in ``StandardParser/tokenLimit``; this pins the order, not
    /// the figure.
    @Test func theWorstLineTheCapAdmitsIsStillCheap() throws {
        let parser = try ParserTests.makeParser()
        let pairs = Array(repeating: "cloak hook", count: (StandardParser.tokenLimit - 2) / 2)
        let line = "give " + pairs.joined(separator: " ") + " cloak"
        #expect(parser.tokenize(line).count == StandardParser.tokenLimit)

        let (_, elapsed) = Self.timed { parser.parse(line, scope: Self.scope) }
        #expect(elapsed < Self.bound)
    }

    // MARK: - The other door

    /// `GameWorld.resolve(_:)` — the play-test seam that reports which entity
    /// answers to a noun — calls `StandardParser.resolve` directly, so a phrase
    /// arriving there never met the parse entry's cap. It is capped in the
    /// resolver as well. Nothing a game declares can answer to a phrase that
    /// long, so "nothing in scope" is the true answer and not merely the cheap
    /// one.
    @Test func anOversizedNounPhraseNamesNothing() throws {
        let parser = try ParserTests.makeParser()
        let phrase = Array(repeating: "cloak", count: StandardParser.tokenLimit + 1)

        let (result, elapsed) = Self.timed { parser.resolve(phrase, in: Self.scope) }

        #expect(result == .failure(.notInScope))
        #expect(elapsed < Self.bound)
        // And the short phrase the seam actually gets still answers.
        #expect(parser.resolve(["velvet", "cloak"], in: Self.scope) == .success(EntityID("cloak")))
    }

    // MARK: - At the prompt

    /// End to end: the line is refused in the game's own words, costs no turn,
    /// and the next command runs as though nothing had happened.
    @Test func anOversizedLineCostsNoTurn() async throws {
        let line = Self.repeatedList(nouns: StandardParser.tokenLimit)
        let transcript = try await play(OperaHouse(), [line, "look"])
        #expect(transcript.contains("I didn't understand that sentence."))
        #expect(transcript.contains("Foyer of the Opera House"))
    }
}

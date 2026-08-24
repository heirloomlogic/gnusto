import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// The Phase 10.2 systems layer on the Zork slice: the custom verb pack and
/// its stage-4 defaults, the score-rank ladder, the weight/burden rules
/// (including the chimney's count gate), and the liquid handling on the
/// bottle. As everywhere in this suite, the assertions anchor on event lines,
/// never prose bodies.
struct Zork1SystemsTests {
    // MARK: - Score ranks

    @Test func scoreLineNamesTheRank() async throws {
        let transcript = try await play(Zork1(), ["score"])
        // A fresh game scores zero and earns the lowest rank; the score line
        // itself still reads exactly as the engine's, so old assertions hold.
        expectInOrder(
            transcript,
            [
                "Your score is 0 of a possible 350",
                "This gives you the rank of Beginner.",
            ])
    }

    @Test func rankClimbsWithTheScore() async throws {
        // The kitchen (10) and cellar (25) visit awards total 35 — past the
        // 25-point threshold, so the rank ticks up from Beginner.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "score",
            ])
        expectInOrder(
            transcript,
            [
                "Your score is 35 of a possible 350",
                "This gives you the rank of Amateur Adventurer.",
            ])
    }

    // MARK: - The verb pack

    @Test func customVerbsParseAndAnswer() async throws {
        // The pack teaches the parser words the engine has never heard; until a
        // region gives them real mechanics, each answers with its polite
        // stage-4 default rather than "I didn't understand that."
        //
        // Only Zork's *own* verbs are here. The engine's stub verbs used to be
        // re-skinned in this same block and were tested alongside them; they are
        // `text.stubs` now, and `Zork1ProseTests` covers them. (#242)
        let transcript = try await play(
            Zork1(),
            ["wind mailbox", "inflate mailbox", "launch mailbox", "echo", "fix mailbox"])
        expectInOrder(
            transcript,
            [
                "isn't something you can wind",
                "How can you inflate that?",
                "That's pretty weird.",
                "Your voice comes back to you",
                "doesn't need fixing",
            ])
    }

    /// `raise` and `lower` are `V-LOWER`'s one routine (`gverbs.zil:902`,
    /// `:1131`), which names the thing. They used to answer "Nothing here rises
    /// to the occasion." and "There's nothing here to lower." — a claim about
    /// the room from a row that never read one, and false in the Dome Room with
    /// the rope over the rail. Both frames are here: the mailbox in an open
    /// field, and the rope that is the room's whole mechanism. (#325)
    @Test func raiseAndLowerNameWhatTheyAreAimedAt() async throws {
        let transcript = try await play(
            Zork1(), ["raise mailbox", "lower mailbox", "raise me"])
        expectInOrder(
            transcript,
            [
                "Playing in this way with the small mailbox has no effect.",
                "Playing in this way with the small mailbox has no effect.",
                // And the guard a row skips, written back: `DefaultActions.run`
                // answers `yourself` before an override is consulted, so a row
                // that widened its sentence to name its object would otherwise
                // say "Playing in this way with yourself…". (#325)
                "Do that to something else!",
            ])
        #expect(!transcript.contains("Nothing here rises to the occasion."))
        #expect(!transcript.contains("There's nothing here to lower."))
        #expect(!transcript.contains("with yourself"))
    }

    @Test func turnWithOutspecifiesTurnOn() async throws {
        // "turn … with …" (specificity 22) must not be shadowed by the
        // built-in "turn on" (21): the first routes to the custom turnWith
        // default, the second still works the light switch.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take lantern", "take sword",
                "turn lantern with sword",
                "turn on lantern",
            ])
        expectInOrder(
            transcript,
            [
                // `V-TURN` (`gverbs.zil:1506`), which `TURN OBJECT WITH OBJECT`
                // reaches in the source (`gsyntax.zil:505`). The invented
                // "Nothing here turns with that." went with #325 — it was a
                // claim about the room, and the bolt is in one of them.
                "This has no effect.",
                "The brass lantern is now on.",
            ])
        #expect(!transcript.contains("Nothing here turns with that."))
    }

    // MARK: - Burden & the chimney gate

    @Test func chimneyRefusesTooFullHands() async throws {
        // The chimney climbs with the lamp plus at most one other thing in hand:
        // the lamp rides free, but a second non-lamp item is one too many. The
        // load is lantern + sword + knife — the lantern free, so sword + knife
        // is the two-item overload; dropping the knife lets the climb through.
        // All non-treasures, so the roaming thief has nothing to lift and the
        // item count stays fixed without pinning a seed. The drop names the
        // "nasty knife" in full so
        // it stays unambiguous even when the thief wanders in with his own
        // blade — otherwise "knife" would raise a disambiguation prompt.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "up",
                "take knife", "down", "west",
                "take lantern", "take sword", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east", "north",
                "up",
                "drop nasty knife",
                "up",
            ])
        expectInOrder(
            transcript,
            [
                "Studio",
                // Three in hand: refused, still in the Studio.
                "You can't get up there with what you're carrying",
                "Dropped.",
                // Two in hand: the climb goes through to the Kitchen.
                "Kitchen",
            ])
    }

    @Test func normalTakesAreNotBurdened() async throws {
        // The weight cap is generous (100, at 5 per item); an ordinary
        // handful never trips it.
        let transcript = try await play(
            Zork1(),
            ["south", "east", "open window", "west", "take all"])
        #expect(!transcript.contains("holding too many things"))
        expectInOrder(transcript, ["brown sack: Taken.", "glass bottle: Taken."])
    }

    // MARK: - Liquids

    @Test func looseWaterCannotBeCarried() async throws {
        let transcript = try await play(
            Zork1(),
            ["south", "east", "open window", "west", "take bottle", "open bottle", "take water"])
        expectInOrder(transcript, ["The water slips through your fingers."])
    }

    @Test func drinkingEmptiesTheBottle() async throws {
        // Open the bottle, drink the water (the bottle empties), and a second
        // drink finds no water left to name.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west",
                "take bottle", "open bottle",
                "drink water", "drink water",
            ])
        expectInOrder(
            transcript,
            [
                "rather thirsty",
                "You can't see any such thing.",
            ])
    }

    @Test func fillingNeedsAWaterSource() async throws {
        // With the bottle emptied and no water source in this slice, filling
        // reports there's nothing to fill from (the reservoir arrives later).
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west",
                "take bottle", "open bottle", "drink water",
                "fill bottle",
            ])
        expectInOrder(transcript, ["There's no water here to fill it from."])
    }

    // MARK: - Climb

    @Test func climbingTheTreeReachesThePerch() async throws {
        // `climb tree` now reaches Up a Tree — the perch `up` already led to —
        // where the word used to fall through to "I didn't understand."
        let transcript = try await play(
            Zork1(),
            ["north", "north", "climb tree"])
        expectInOrder(transcript, ["Forest Path", "Up a Tree"])
    }

    @Test func climbingNothingClimbableIsPolitelyRefused() async throws {
        // Away from a climbable, the verb still parses — no parse error — and
        // answers with its stage-4 default rather than "I didn't understand."
        // Since #242 the default is `V-CLIMB-ON`'s own line, which names the
        // thing; bare `climb` keeps the sentence this game used to give both.
        let transcript = try await play(Zork1(), ["climb mailbox", "climb"])
        expectInOrder(
            transcript,
            [
                "You can't climb onto the small mailbox.",
                "Not without something to climb.",
            ])
    }

    /// The bare half of `climb`, in the frame that refuted it. It used to say
    /// "There's nothing here worth climbing. Try up or down." everywhere,
    /// including the Forest Path — whose own description is *one particularly
    /// large tree with some low branches*, and whose tree
    /// ``climbingTheTreeReachesThePerch`` proves you can climb. It also
    /// recommended two exits that West of House does not have. The line is about
    /// the player now, so both frames get the same true sentence. (#325)
    @Test func bareClimbDoesNotSurveyARoomItNeverRead() async throws {
        let transcript = try await play(Zork1(), ["climb", "north", "north", "climb"])
        #expect(!transcript.contains("nothing here worth climbing"))
        #expect(!transcript.contains("Try up or down"))
        expectInOrder(transcript, ["West of House", "Forest Path"])
        #expect(occurrences(of: "Not without something to climb.", in: transcript) == 2)
    }

    // MARK: - Diagnose

    @Test func diagnoseReportsPerfectHealthWhileUnscathed() async throws {
        // A fresh adventurer, never yet killed, is in perfect health.
        let transcript = try await play(Zork1(), ["diagnose"])
        expectInOrder(transcript, ["perfect health"])
    }

    @Test func diagnoseCountsYourDeaths() async throws {
        // Linger in the dark and the grue rolls each turn until it takes you (a
        // survivable first death); wake in the lit forest — where the dice can't
        // reach you — and diagnose: the toll now reads one death, with one
        // resurrection still in hand. Seed 0: the grue lands within these looks.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "push rug", "open trap door", "down",
                "look", "look", "look", "look", "look",  // the grue's dice land (death #1)
                "diagnose",
            ],
            seed: 0)
        let report = turnOutput(of: "diagnose", in: transcript)
        expectInOrder(report, ["killed once", "one more time"])
    }

    /// Bare `turn bolt` is the engine's stub verb, promoted so the bolt points
    /// at the tool it needs instead of answering the generic "doesn't turn".
    /// The original had no bare `turn`, so this line is ours — see `FIDELITY.md`.
    @Test func turningTheBoltBareHandedPointsAtTheTool() async throws {
        let transcript = try await play(
            Zork1(),
            Zork1Tests.approachTheChargedDam + ["turn bolt"],
            seed: 39)
        let turn = turnOutput(of: "turn bolt", in: transcript)
        #expect(turn.contains("Your bare hands aren't enough."))
        #expect(!turn.contains("doesn't turn"))
    }
}

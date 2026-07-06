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
                "This earns you the rank of Wanderer.",
            ])
    }

    @Test func rankClimbsWithTheScore() async throws {
        // The kitchen (10) and cellar (25) visit awards total 35 — past the
        // 25-point threshold, so the rank ticks up from Wanderer.
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
                "This earns you the rank of Trespasser.",
            ])
    }

    // MARK: - The verb pack

    @Test func customVerbsParseAndAnswer() async throws {
        // The pack teaches the parser these words; until a region gives them
        // real mechanics, each answers with its polite stage-4 default rather
        // than "I didn't understand that."
        let transcript = try await play(
            Zork1(),
            ["xyzzy", "plugh", "pray", "wave", "echo", "smell", "hello", "dig"])
        expectInOrder(
            transcript,
            [
                "The word hangs in the air a moment",
                "The word hangs in the air a moment",
                "Your prayers echo unanswered",
                "You wave it about",
                "Your voice comes back to you",
                "You smell nothing you could put a name to",
                "Nobody here returns your greeting",
                "You scrabble at the ground",
            ])
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
                "Nothing here turns with that.",
                "The brass lantern is now on.",
            ])
    }

    // MARK: - Burden & the chimney gate

    @Test func chimneyRefusesTooFullHands() async throws {
        // The chimney climbs only with a couple of things in hand. Three
        // items is one too many; dropping back to two lets the climb through.
        // The load is lantern + sword + knife — all non-treasures, so the
        // roaming thief has nothing to lift and the item count stays fixed
        // without pinning a seed.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "up",
                "take knife", "down", "west",
                "take lantern", "take sword", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east", "north",
                "up",
                "drop knife",
                "up",
            ])
        expectInOrder(
            transcript,
            [
                "Studio",
                // Three in hand: refused, still in the Studio.
                "The chimney is too tight to climb",
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
        #expect(!transcript.contains("as much as you can manage"))
        expectInOrder(transcript, ["brown sack: Taken.", "glass bottle: Taken."])
    }

    // MARK: - Liquids

    @Test func looseWaterCannotBeCarried() async throws {
        let transcript = try await play(
            Zork1(),
            ["south", "east", "open window", "west", "take bottle", "open bottle", "take water"])
        expectInOrder(transcript, ["The water slips between your fingers."])
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
                "You drink the water. The bottle is empty now.",
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
}

import Testing

@testable import Gnusto

/// Phase 6 pronouns: "it" follows the last direct object the player named.
struct PronounTests {
    @Test func itFollowsTheLastNamedObject() async throws {
        let transcript = try await play(
            PronounGame(), ["take lantern", "drop it", "x it"])
        expectInOrder(transcript, ["Taken.", "Dropped.", "A dented tin lantern."])
    }

    @Test func unboundItExplainsItself() async throws {
        let transcript = try await play(PronounGame(), ["x it", "score"])
        expectInOrder(
            transcript,
            [
                "I don't know what \"it\" refers to.",
                // A parse-level reply is free: the score probe still reads
                // zero turns taken.
                "in 0 turns",
            ])
    }

    @Test func staleBindingIsOutOfScope() async throws {
        let transcript = try await play(
            PronounGame(), ["x lantern", "north", "x it"])
        expectInOrder(
            transcript,
            ["A dented tin lantern.", "Hall", "You can't see any such thing."])
    }

    @Test func refusedActionsStillBind() async throws {
        // Naming the thing is what binds, not succeeding at the action.
        let transcript = try await play(
            PronounGame(), ["take hook", "x it"])
        expectInOrder(
            transcript,
            ["You can't take that.", "A hook bolted to the wall."])
    }

    @Test func reservedSynonymWarns() throws {
        let (definition, _) = try Bootstrap.build(ReservedWordGame())
        #expect(definition.warnings.contains { $0.contains("reserved") && $0.contains("it") })
    }
}

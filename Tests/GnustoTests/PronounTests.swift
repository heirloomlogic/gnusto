import GnustoTestSupport
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

    // MARK: - "them" for one plural thing

    @Test func themFollowsOnePluralObject() async throws {
        // The repro from #403: a plural thing is one thing, and the pronoun
        // English gives it is "them".
        let transcript = try await play(
            PronounGame(), ["x stairs", "x them"])
        expectInOrder(
            transcript,
            ["Worn stone stairs, going nowhere.", "Worn stone stairs, going nowhere."])
    }

    @Test func aSolePluralReferentTakesAVerbThatRefusesGroups() async throws {
        // EXAMINE is not in `multiObjectIntents`, and used to refuse the word
        // outright rather than read it as the one thing it named.
        let transcript = try await play(PronounGame(), ["take gloves", "x them"])
        expectInOrder(transcript, ["Taken.", "A pair of cracked leather gloves."])
        #expect(!transcript.contains("multiple objects"))
    }

    @Test func aSolePluralReferentAlsoTakesAGroupVerb() async throws {
        let transcript = try await play(PronounGame(), ["take gloves", "drop them"])
        expectInOrder(transcript, ["Taken.", "Dropped."])
    }

    @Test func aSolePluralReferentFillsTheIndirectSlot() async throws {
        // The indirect slot never accepts a group, so this is the other half
        // of the same word: "them" naming one thing belongs there too.
        let transcript = try await play(
            PronounGame(),
            ["take lantern", "x shelves", "put lantern in them", "look in shelves"])
        expectInOrder(
            transcript,
            [
                "Three sagging oak shelves.",
                "You put the tin lantern in the oak shelves.",
                "In the oak shelves is a tin lantern.",
            ])
    }

    @Test func aRealGroupIsStillAGroup() async throws {
        // Two things is a group, and a group still cannot be examined.
        let transcript = try await play(
            PronounGame(), ["take lantern and gloves", "x them"])
        #expect(transcript.contains("multiple objects"))
    }

    @Test func aPluralBindingOutlastsTheGroupThatCameFirst() async throws {
        // Naming one plural thing rebinds the word, the way naming one thing
        // rebinds "it".
        let transcript = try await play(
            PronounGame(), ["take lantern and gloves", "x stairs", "x them"])
        expectInOrder(
            transcript, ["Worn stone stairs, going nowhere.", "Worn stone stairs, going nowhere."])
    }

    @Test func unboundThemExplainsItself() async throws {
        // The same answer "it" gives, for every verb — not "you can't use
        // multiple objects with examine", which is what a bare unbound word
        // used to earn from anything outside `multiObjectIntents`.
        let transcript = try await play(PronounGame(), ["x them", "drop them", "score"])
        expectInOrder(
            transcript,
            [
                "I don't know what \"them\" refers to.",
                "I don't know what \"them\" refers to.",
                "in 0 turns",
            ])
    }

    @Test func aStalePluralBindingIsOutOfScope() async throws {
        let transcript = try await play(
            PronounGame(), ["x stairs", "north", "x them"])
        expectInOrder(
            transcript,
            ["Worn stone stairs, going nowhere.", "Hall", "You can't see any such thing."])
    }

    @Test func reservedSynonymWarns() throws {
        let (definition, _) = try Bootstrap.build(ReservedWordGame())
        #expect(definition.warnings.contains { $0.contains("reserved") && $0.contains("it") })
    }
}

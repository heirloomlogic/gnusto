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
        // Quoted, because a bare "it" is satisfied by the word "item" that
        // opens every one of these warnings.
        let (definition, _) = try Bootstrap.build(ReservedWordGame())
        #expect(
            definition.warnings.contains {
                $0.contains("reserved") && $0.contains("\"it\"") && $0.contains("golem")
            })
    }

    @Test func aGenderedPronounIsReservedToo() throws {
        // The word the `pronoun(_:)` trait replaces. A game that spends a
        // synonym on it is told the parser gets there first.
        let (definition, _) = try Bootstrap.build(ReservedWordGame())
        #expect(
            definition.warnings.contains {
                $0.contains("reserved") && $0.contains("\"her\"") && $0.contains("hag")
            })
    }

    // MARK: - "it" after a group

    @Test func itFollowsTheLastObjectOfAGroup() async throws {
        // #445: the group loop bound "them" and left "it" wherever the last
        // single-object command had put it, so `x hook`, `take all`, `x it`
        // examined the hook again — a thing the group never touched.
        let transcript = try await play(PronounGame(), ["x hook", "take all", "x it"])
        expectInOrder(
            transcript,
            [
                "A hook bolted to the wall.",
                "tin lantern: Taken.",
                "A dented tin lantern.",
            ])
    }

    @Test func itFollowsTheLastObjectOfAList() async throws {
        let transcript = try await play(
            PronounGame(), ["take gloves and lantern", "x it"])
        expectInOrder(transcript, ["tin lantern: Taken.", "A dented tin lantern."])
    }

    // MARK: - "him" and "her"

    @Test func aGenderedPronounNamesTheOnePersonInViewWhoAnswersToIt() async throws {
        // Nobody named yet, and one of each in the room: the word has exactly
        // one thing it could mean, so it means it. This is what the games that
        // used to spend a synonym on "her" were buying.
        let transcript = try await play(PronounGame(), ["x her", "x him"])
        expectInOrder(
            transcript,
            ["A broad woman in a flour-dusted apron.", "A tall man with a ring of keys."])
    }

    @Test func aGenderedPronounWithTwoCandidatesWaitsToBeBound() async throws {
        let transcript = try await play(PronounGame(), ["north", "x her", "score"])
        expectInOrder(
            transcript,
            [
                "I don't know what \"her\" refers to.",
                // A parse-level reply, so the walk is the only turn spent.
                "in 1 turn",
            ])
    }

    @Test func namingSomebodyBindsTheirPronoun() async throws {
        let transcript = try await play(
            PronounGame(), ["north", "x matron", "x her", "x laundress", "x her"])
        expectInOrder(
            transcript,
            [
                "The matron, watching the door.",
                "The matron, watching the door.",
                "The laundress, up to her elbows in grey water.",
                "The laundress, up to her elbows in grey water.",
            ])
    }

    @Test func theRecipientSlotBindsToo() async throws {
        // "it" binds from the direct object alone; a person named as the
        // recipient of a gift has been referred to just as squarely.
        let transcript = try await play(
            PronounGame(),
            ["take lantern", "north", "x matron", "give lantern to laundress", "x her"])
        expectInOrder(
            transcript,
            [
                "The matron, watching the door.",
                "The laundress, up to her elbows in grey water.",
            ])
    }

    @Test func theAddressSlotBindsToo() async throws {
        // The order itself is nobody's business here — what binds is being
        // spoken to. (A *failed* parse binds nothing, as it does for "it":
        // there is no command to have named anybody. And an order that names
        // somebody else, `laundress, x matron`, leaves the word on the matron:
        // the object slot binds after the address, and the last one bound is
        // the one the word means.)
        let transcript = try await play(
            PronounGame(),
            ["north", "x matron", "laundress, jump", "x her"])
        expectInOrder(
            transcript,
            [
                "The matron, watching the door.",
                "The laundress, up to her elbows in grey water.",
            ])
    }

    @Test func aGenderedPronounDoesNotCrossGenders() async throws {
        // The warden is the only man in the study, and naming the cook does
        // not make "him" mean her.
        let transcript = try await play(PronounGame(), ["x cook", "x him"])
        expectInOrder(
            transcript,
            ["A broad woman in a flour-dusted apron.", "A tall man with a ring of keys."])
    }

    @Test func aStaleGenderedBindingIsOutOfScope() async throws {
        // Bound to the cook, who is a room away, and the hall's two women give
        // the word nothing to fall back to. She is known and simply not here.
        let transcript = try await play(PronounGame(), ["x cook", "north", "x her"])
        expectInOrder(
            transcript,
            ["A broad woman in a flour-dusted apron.", "Hall", "You can't see any such thing."])
    }

    @Test func aPossessiveBelongsToWhatFollowsIt() async throws {
        // "her" alone is a person; in front of more words it is a possessive,
        // and the phrase behind it names the thing meant. "his" and "their"
        // are the same word class and have no pronoun half to protect.
        let transcript = try await play(
            PronounGame(), ["take her gloves", "x her lantern", "x his hook", "x their stairs"])
        expectInOrder(
            transcript,
            [
                "Taken.",
                "A dented tin lantern.",
                "A hook bolted to the wall.",
                "Worn stone stairs, going nowhere.",
            ])
    }

    @Test func aPersonCanBeAddressedByPronoun() async throws {
        // `resolveAddressee` reads "him"/"her" where it deliberately will not
        // read "it": the gendered words name a person by construction.
        let transcript = try await play(
            PronounGame(), ["north", "x laundress", "her, jump"])
        expectInOrder(
            transcript,
            [
                "The laundress, up to her elbows in grey water.",
                "The laundress hops once, obligingly, and returns to the tub.",
            ])
    }

    /// #445 round 3: `resolveAddressee`'s pronoun branch reported why nobody
    /// was addressed and `parse` threw the answer away, binding the call with
    /// `if case .success`. The hall holds two women, so the word is bound to
    /// nobody, and the address said "I didn't understand that sentence" where
    /// `x her` on the same state says which word it was.
    @Test func addressingAnUnboundPronounSaysSo() async throws {
        let transcript = try await play(PronounGame(), ["north", "her, jump"])
        expectInOrder(transcript, ["Hall", #"I don't know what "her" refers to."#])
        #expect(!transcript.contains("I didn't understand that sentence."))
    }

    /// The other half: bound, and a room away. The word names somebody, and
    /// she is simply not here — the same answer `x her` gives.
    @Test func addressingAStalePronounSaysSheIsNotHere() async throws {
        let transcript = try await play(PronounGame(), ["x cook", "north", "her, jump"])
        expectInOrder(
            transcript,
            [
                "A broad woman in a flour-dusted apron.",
                "Hall",
                "You can't see any such thing.",
            ])
        #expect(!transcript.contains("I didn't understand that sentence."))
    }

    /// A greeting to an unbound pronoun is the same failure: `her, hello` has
    /// nobody to greet, and says which word had nobody.
    @Test func greetingAnUnboundPronounSaysSo() async throws {
        let transcript = try await play(PronounGame(), ["north", "her, hello"])
        expectInOrder(transcript, ["Hall", #"I don't know what "her" refers to."#])
    }
}

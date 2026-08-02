import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import CloakOfDarkness
@testable import Fulminate
@testable import Gnusto
@testable import Gramarye
@testable import KindlyDeep
@testable import Lighthouse
@testable import Zork1

/// The one invariant this suite exists for: **a word an author declares is a
/// word the player can type.** Declarations and player input have to agree on
/// where one word ends and the next begins, or a declared word is dead the
/// moment it is written — accepted by bootstrap, unmatchable forever.
///
/// They agree because both go through ``Vocabulary/words(in:)``.
struct VocabularyTests {
    // MARK: - The shared splitter

    /// Pins `words(in:)` on its own — the possessive and punctuation rules,
    /// which is what a declaration depends on. `ParserTests` pins the same
    /// contract from the player's side, where noise words are dropped too.
    @Test(
        arguments: [
            ("lamp", ["lamp"]),
            ("Brass Lantern", ["brass", "lantern"]),  // case-folded, space-split
            ("half-moon table", ["half", "moon", "table"]),  // hyphen splits
            ("Mrs. Vane", ["mrs", "vane"]),  // the period goes
            ("master's", ["master"]),  // trailing possessive dropped
            ("Master's Spellbook", ["master", "spellbook"]),
            ("boys'", ["boys"]),  // plural possessive: the bare apostrophe splits
            ("don't", ["don", "t"]),  // only 's is a possessive
            ("it's", ["it"]),
            ("s", ["s"]),  // a bare s is a word, not a possessive
            ("o'clock", ["o", "clock"]),
            ("3.5", ["3", "5"]),
            ("!!!", []),  // nothing usable
            ("", []),
        ] as [(String, [String])])
    func wordsInPinsItsContract(phrase: String, expected: [String]) {
        #expect(Vocabulary.words(in: phrase) == expected)
    }

    // MARK: - What bootstrap makes of a declaration

    @Test func aPossessiveAdjectiveRegistersItsStem() throws {
        let (definition, _) = try Bootstrap.build(Gramarye())
        let spellbook = definition.vocabulary.itemLexicons[EntityID("spellbook")]
        #expect(spellbook?.adjectives.contains("master") == true)
        #expect(spellbook?.adjectives.contains("master's") == false)
    }

    @Test func aHyphenatedAdjectiveRegistersBothHalves() throws {
        let (definition, _) = try Bootstrap.build(Zork1())
        let egg = definition.vocabulary.itemLexicons[EntityID("ZorkAboveGround.egg")]
        #expect(egg?.adjectives.contains("jewel") == true)
        #expect(egg?.adjectives.contains("encrusted") == true)
    }

    /// The title in a proper name is display text, but its words still have to
    /// reach the lexicon — nobody types the period.
    @Test func anAbbreviatedTitleInANameBecomesAnAdjective() throws {
        let vocabulary = try Bootstrap.build(Fulminate()).0.vocabulary
        #expect(vocabulary.itemLexicons[EntityID("constance")]?.adjectives.contains("mrs") == true)
        #expect(vocabulary.displayNames[EntityID("constance")] == "Mrs. Vane")
    }

    /// A synonym is a noun phrase, and is split the way a name is: the last
    /// word is the noun, the words in front of it are adjectives.
    @Test func aMultiWordSynonymSplitsLikeAName() throws {
        let (definition, _) = try Bootstrap.build(PhraseSynonymGame())
        let lexicon = definition.vocabulary.itemLexicons[EntityID("lantern")]
        #expect(lexicon?.nouns.contains("torch") == true)
        #expect(lexicon?.adjectives.contains("carriage") == true)
        #expect(lexicon?.nouns.contains("carriage") == false)
    }

    // MARK: - The words normalizing can't save

    @Test func anAdjectiveWithNoLettersOrDigitsIsRejected() {
        #expect {
            try Bootstrap.build(PunctuationAdjectiveGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains("adjective \"---\"")
                && bootstrapError.description.contains("no letters or digits")
        }
    }

    @Test func aSynonymMadeOfNothingButFillerIsRejected() {
        #expect {
            try Bootstrap.build(FillerSynonymGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains("\"that\"")
                && bootstrapError.description.contains("untypeable")
        }
    }

    // MARK: - The sweep

    /// Every game the repo ships, checked the only way that stays true: walk
    /// the assembled vocabulary and confirm each word is one the tokenizer can
    /// hand back. Bootstrap now rejects the ways a declaration can fail this,
    /// so the sweep should pass by construction — which is the point. It fails
    /// the day something starts registering author strings without going
    /// through the splitter, which is exactly how #102 happened, and no
    /// transcript test would notice.
    @Test func noShippedGameHasAWordThePlayerCannotType() throws {
        let definitions: [(String, GameDefinition)] = [
            ("CloakOfDarkness", try Bootstrap.build(OperaHouse()).0),
            ("Lighthouse", try Bootstrap.build(Lighthouse()).0),
            ("Gramarye", try Bootstrap.build(Gramarye()).0),
            ("Fulminate", try Bootstrap.build(Fulminate()).0),
            ("Zork1", try Bootstrap.build(Zork1()).0),
            ("KindlyDeep", try Bootstrap.build(KindlyDeep()).0),
        ]
        for (title, definition) in definitions {
            let parser = StandardParser(
                vocabulary: definition.vocabulary, syntaxRules: definition.syntaxRules)
            for (id, lexicon) in definition.vocabulary.itemLexicons {
                for word in lexicon.nouns.union(lexicon.adjectives) {
                    #expect(
                        parser.tokenize(word) == [word],
                        "\(title): \"\(id)\" answers to \"\(word)\", which no token can equal")
                }
            }
            for word in definition.vocabulary.verbWords.union(definition.vocabulary.prepositions) {
                #expect(
                    parser.tokenize(word) == [word],
                    "\(title): the verb table declares \"\(word)\", which no token can equal")
            }
        }
    }

    // MARK: - In play

    /// The line issue #102 was filed on: `master's spellbook` is the last
    /// sentence of Gramarye's intro, so it is the first thing a player tries.
    @Test func gramaryeAnswersToThePhraseItsIntroPrints() async throws {
        let transcript = try await play(
            Gramarye(), ["x master's spellbook", "x master spellbook", "x the leather book"])
        #expect(!transcript.contains("I don't know the word"))
        #expect(!transcript.contains("You can't see any such thing"))
        #expect(transcript.contains("The master's working book"))
    }

    @Test func fulminateAnswersToATitleWithAPeriod() async throws {
        let transcript = try await play(Fulminate(), ["x mrs. vane", "x dr. pike"])
        #expect(!transcript.contains("I don't know the word"))
    }

    @Test func zork1AnswersToItsHyphenatedAdjectives() async throws {
        let transcript = try await play(
            Zork1(), ["x jewel-encrusted egg", "x white house"])
        #expect(!transcript.contains("I don't know the word"))
    }
}

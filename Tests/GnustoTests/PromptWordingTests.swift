import GnustoTestSupport
import Testing

@testable import Gnusto

/// The questions the parser asks when a slot is empty, and the one it used to
/// ask when nothing was (#445, "Prompts").
///
/// Three defects, one suite. A prompt read back the row's own leading words, so
/// an abbreviation came out as a question in a language nobody speaks. A bare
/// greeting had no row to match but `hello <object>`, so saying hello to a room
/// asked what you wanted to hello. And a row with a trailing particle asked for
/// a second object it does not have, which is a question no answer completes.
struct PromptWordingTests {
    // MARK: - The question says a word

    /// `x`, `l at` and `examine` are one verb, and it is called examine. The
    /// first two used to ask "What do you want to x?" and "What do you want to
    /// l at?"
    @Test(arguments: ["x", "examine", "inspect", "l at", "look at"])
    func everySpellingOfExamineAsksInTheSameWord(_ command: String) async throws {
        let turn = turnOutput(of: command, in: try await play(CoreLab(), [command]))
        #expect(turn.contains("What do you want to examine?"))
    }

    /// And the question is answerable, which is the point of asking it: the
    /// next line completes the command the abbreviation began.
    @Test func theExamineQuestionIsAnsweredByTheNextLine() async throws {
        let transcript = try await play(CoreLab(), ["x", "rod"])
        expectInOrder(transcript, ["What do you want to examine?", "A plain brass rod."])
    }

    /// A display verb is stated per *verb*, and only where the rows need one —
    /// so every other verb still asks in the words the player typed. FIND and
    /// SEARCH are one intent and two questions; so are PUT and HANG.
    @Test(
        arguments: [
            ("search", "What do you want to search?"),
            ("find", "What do you want to find?"),
            ("look in", "What do you want to look in?"),
            ("look for", "What do you want to look for?"),
            ("hang cloak", "What do you want to hang the velvet cloak on?"),
            ("get in", "What do you want to get in?"),
        ])
    func aVerbWithoutAnAbbreviationAsksInItsOwnWords(
        _ command: String, _ question: String
    ) async throws {
        let turn = turnOutput(of: command, in: try await play(CoreLab(), [command]))
        #expect(turn.contains(question))
    }

    /// The invariant behind all of it, asked of the whole shipped table: a row
    /// that can prompt has a display verb made of words. A one-letter word is
    /// an abbreviation — `x`, `l` — and no verb of any language this engine
    /// prints in is spelled with one, so the day a row leads with one, the
    /// answer is its verb's `displayVerb:` column. No stub verb needs one
    /// today, which is why ``StubVerb`` has no such column: this test is what
    /// says when to add it.
    @Test func everyPromptSpeaksAWord() {
        let promptingRows = SyntaxRule.standardTable.filter {
            $0.literalWords.count < $0.elements.count
        }
        for rule in promptingRows {
            let words = rule.displayVerb.split(separator: " ")
            #expect(!words.isEmpty, "\(rule.patternDescription) prompts with nothing at all")
            for word in words {
                #expect(
                    word.count > 1,
                    "\(rule.patternDescription) prompts with the abbreviation \"\(word)\"")
            }
        }
    }

    /// And the same invariant asked of a *game's* rows, where a test cannot
    /// reach: the bootstrap warns about a custom row that would prompt in an
    /// abbreviation, and stays quiet about the one that gave itself a display
    /// verb. Without it a game's `#verb` leaked exactly what `x` leaked, with
    /// nothing to say so.
    @Test func aCustomRowThatWouldPromptInAnAbbreviationWarns() throws {
        let (definition, _) = try Bootstrap.build(AbbreviatedVerbGame())
        let warnings = definition.warnings.filter { $0.contains("What do you want to") }
        #expect(warnings.count == 1, "\(definition.warnings)")
        #expect(warnings.first?.contains("What do you want to k?") == true)
    }

    // MARK: - A bare greeting

    /// `hello` and `hi` matched `hello <object>` and nothing else, so a player
    /// who said hello to a room was asked what they wanted to hello. GREET has
    /// read the room since it was written — and `GameWorld` has folded a bare
    /// greeting into the one person standing in it for as long — so these two
    /// rows are what reach the rat.
    @Test(arguments: ["hello", "hi", "greet"])
    func aBareGreetingReachesTheOnePersonInTheRoom(_ command: String) async throws {
        let turn = turnOutput(of: command, in: try await play(CoreLab(), [command]))
        #expect(turn.contains("The grey rat nods, and says nothing."))
        #expect(!turn.contains("What do you want to"))
    }

    /// And an empty room is the other half of the same branch.
    @Test func aBareGreetingInAnEmptyRoomSaysSo() async throws {
        let transcript = try await play(CoreLab(), ["north", "hello"])
        #expect(turnOutput(of: "hello", in: transcript).contains("There's nobody here to greet."))
    }

    // MARK: - A trailing particle

    /// `pick lamp` asked "What do you want to pick the oil lamp up?" — a
    /// question about a second object the row does not have, so no answer to it
    /// could ever parse. The particle is read as understood instead.
    @Test(
        arguments: [
            ("pick rod", "Taken."),
            ("pick the brass rod", "Taken."),
        ])
    func aTrailingParticleIsUnderstood(_ command: String, _ answer: String) async throws {
        let turn = turnOutput(of: command, in: try await play(CoreLab(), [command]))
        #expect(turn.contains(answer))
        #expect(!turn.contains("What do you want to"))
        #expect(!turn.contains("I didn't understand"))
    }

    /// The same on a verb whose particle changes the meaning. Two rows can
    /// claim `switch <object>`, and the table's order settles it: ON is the
    /// reading, which is what a player reaching for a dark lamp means.
    @Test func switchingWithoutTheParticleTurnsItOn() async throws {
        let transcript = try await play(CoreLab(), ["turn off lamp", "switch lamp"])
        #expect(turnOutput(of: "switch lamp", in: transcript).contains("The oil lamp is now on."))
    }

    /// A shorter row for the same word still wins, because the implied particle
    /// is the weakest reading there is: `turn the lamp` is the TURN stub, not
    /// `turn the lamp on`.
    @Test func aRowThatReallyMatchesBeatsTheImpliedParticle() async throws {
        let turn = turnOutput(of: "turn lamp", in: try await play(CoreLab(), ["turn lamp"]))
        #expect(!turn.contains("is now on"))
        #expect(!turn.contains("is now off"))
    }

    /// And so does a near miss, which is the ordering the shape needs: `put the
    /// cloak` is owed the question from the row that has somewhere to put it,
    /// not a silent WEAR from `put <object> on`.
    @Test func aNearMissBeatsTheImpliedParticle() async throws {
        let turn = turnOutput(of: "put cloak", in: try await play(CoreLab(), ["put cloak"]))
        #expect(turn.contains("What do you want to put the velvet cloak on?"))
    }

    /// `put the cloak on` still means WEAR, which is the row the near miss
    /// above stands in front of — so the two readings have not traded places.
    @Test func theParticleTypedOutIsStillTheRowItAlwaysWas() async throws {
        let turn = turnOutput(of: "put cloak on", in: try await play(CoreLab(), ["put cloak on"]))
        #expect(turn.contains("You put on the velvet cloak."))
    }

    /// A phrase that names nothing invents no reading — and says what was wrong
    /// with it. The row used to decline outright, so `pick the gramophone` came
    /// out as "That sentence isn't one I recognize" when the trouble was the
    /// gramophone.
    @Test func anObjectThatIsNotThereReportsItselfRatherThanTheGrammar() async throws {
        let transcript = try await play(CoreLab(), ["pick the gramophone", "pick the note"])
        #expect(
            turnOutput(of: "pick the gramophone", in: transcript)
                .contains("I don't know the word \"gramophone\"."))
        #expect(!transcript.contains("I didn't understand"))
    }
}

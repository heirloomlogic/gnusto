import GnustoTestSupport
import Testing

@testable import Gnusto

/// A study with one lamp, one verb nothing answers, and nothing else — the
/// smallest world in which AGAIN can be watched repeating a turn, declining to
/// repeat itself, and forgetting a line the world never acted on.
private struct StudyGame: Game {
    let title = "Study"
    let intro = "A study, and one lamp in it."

    let study = Location {
        name("Study")
        description("Books to the ceiling.")
    }

    let lamp = Item {
        name("oil lamp")
    }

    var map: WorldMap {
        player.starts(in: study)
        lamp.starts(in: study)
    }

    /// A word the parser knows and nothing in the game answers, which is the
    /// one shape of turn that never happened. Deliberately not a stub verb: a
    /// stub prints a line and costs a move, and would be a perfectly ordinary
    /// thing to say AGAIN of.
    var verbs: [SyntaxRule] {
        SyntaxRule("frobnicate", intent: Intent("frobnicate"))
    }
}

/// Two lamps of different metals — the smallest world in which the parser has
/// to ask which one, and the player can mistype the answer.
private struct LampRoomGame: Game {
    let title = "Lamp Room"
    let intro = "Two lamps on a shelf."

    let lampRoom = Location {
        name("Lamp Room")
        description("Shelves of lamps.")
    }

    let brassLamp = Item {
        name("brass lamp")
        description("Tarnished brass.")
    }

    let oilLamp = Item {
        name("oil lamp")
        description("Sooty glass.")
    }

    /// Something to take that is neither lamp, so a fresh TAKE typed while the
    /// question is open has an object of its own.
    let key = Item {
        name("iron key")
        description("A plain iron key.")
    }

    var map: WorldMap {
        player.starts(in: lampRoom)
        brassLamp.starts(in: lampRoom)
        oilLamp.starts(in: lampRoom)
        key.starts(in: lampRoom)
    }
}

struct AgainAndOopsTests {
    // MARK: - AGAIN

    @Test func againRepeatsTheLastCommandAndCostsWhatItCosts() async throws {
        let transcript = try await play(StudyGame(), ["take lamp", "again"])
        let again = turnOutput(of: "again", in: transcript)
        // The TAKE really ran a second time, and said what a second TAKE says.
        #expect(again.contains("You already have that."))
    }

    @Test func gIsTheSameVerb() async throws {
        let transcript = try await play(StudyGame(), ["take lamp", "g"])
        #expect(turnOutput(of: "g", in: transcript).contains("You already have that."))
    }

    @Test func nothingToRepeatBeforeAnyCommandHasRun() async throws {
        let transcript = try await play(StudyGame(), ["again"])
        #expect(turnOutput(of: "again", in: transcript).contains("There's nothing to repeat."))
    }

    /// AGAIN never records itself, so a second one repeats the same command
    /// rather than repeating the repeat — and cannot loop.
    @Test func againAfterAgainRepeatsTheSameCommand() async throws {
        let transcript = try await play(StudyGame(), ["x lamp", "again", "g"])
        #expect(turnOutput(of: "again", in: transcript).contains("nothing special"))
        #expect(turnOutput(of: "g", in: transcript).contains("nothing special"))
    }

    /// A meta verb is not a command AGAIN can be said of: asking for your score
    /// leaves the last real command standing.
    @Test func aMetaVerbDoesNotDisplaceTheLastCommand() async throws {
        let transcript = try await play(StudyGame(), ["x lamp", "score", "version", "again"])
        #expect(turnOutput(of: "again", in: transcript).contains("nothing special"))
    }

    /// A turn nothing answered never happened, so it never becomes the thing
    /// AGAIN repeats — the same rule the "it" binding follows.
    @Test func aTurnNothingAnsweredIsNotRepeated() async throws {
        let transcript = try await play(StudyGame(), ["x lamp", "frobnicate", "again"])
        #expect(turnOutput(of: "frobnicate", in: transcript).contains("You can't do that."))
        #expect(turnOutput(of: "again", in: transcript).contains("nothing special"))
    }

    /// A parse error is not a command either.
    @Test func aParseErrorIsNotRepeated() async throws {
        let transcript = try await play(StudyGame(), ["x lamp", "frotz", "again"])
        #expect(turnOutput(of: "again", in: transcript).contains("nothing special"))
    }

    /// A refusal is a turn the game understood and answered, so AGAIN repeats
    /// it — and says the same thing again, which is what a player who typed it
    /// twice would have got.
    @Test func aRefusedCommandIsRepeatedAsItStands() async throws {
        let transcript = try await play(StudyGame(), ["open lamp", "again"])
        #expect(turnOutput(of: "open lamp", in: transcript).contains("You can't open that."))
        #expect(turnOutput(of: "again", in: transcript).contains("You can't open that."))
    }

    /// The memory is world state, so UNDO rolls it back with the turn that set
    /// it: AGAIN after an UNDO repeats the command *before* the one undone,
    /// and here there was none. It is also the proof that AGAIN can never
    /// repeat an UNDO, a SAVE or a RESTORE — none of the six the engine
    /// answers ahead of the pipeline is ever recorded.
    @Test func undoRollsBackWhatAgainWouldRepeat() async throws {
        let transcript = try await play(StudyGame(), ["take lamp", "undo", "again"])
        #expect(turnOutput(of: "undo", in: transcript).contains("Previous turn undone."))
        #expect(turnOutput(of: "again", in: transcript).contains("There's nothing to repeat."))
    }

    /// Re-parsed rather than replayed: the words are read against the room as
    /// it stands, so "it" means what it means this turn.
    @Test func againReadsItsPronounAfresh() async throws {
        let transcript = try await play(StudyGame(), ["x it", "x lamp", "again"])
        #expect(turnOutput(of: "x it", in: transcript).contains("I don't know what \"it\" refers to."))
        #expect(turnOutput(of: "again", in: transcript).contains("nothing special"))
    }

    // MARK: - OOPS

    @Test func oopsMendsTheWordAndRunsTheLine() async throws {
        let transcript = try await play(StudyGame(), ["take lampp", "oops lamp"])
        #expect(
            turnOutput(of: "take lampp", in: transcript)
                .contains("I don't know the word \"lampp\"."))
        #expect(turnOutput(of: "oops lamp", in: transcript).contains("Taken."))
    }

    /// The word is replaced where it stood rather than appended, and the rest
    /// of the line runs as typed. `put lamp on shellf`, mended with `lamp`, is
    /// `put lamp on lamp` — refused by the *action*, which is the proof that
    /// the whole sentence was read again and the correction landed in the
    /// second slot rather than the first.
    @Test func oopsMendsAWordInTheMiddleOfTheLine() async throws {
        let transcript = try await play(
            StudyGame(), ["take lamp", "put lamp on shellf", "oops lamp"])
        #expect(
            turnOutput(of: "oops lamp", in: transcript)
                .contains("You can\'t put something on itself."))
    }

    @Test func oopsWithNoMisheardWordSaysSo() async throws {
        let transcript = try await play(StudyGame(), ["x lamp", "oops lamp"])
        #expect(
            turnOutput(of: "oops lamp", in: transcript).contains("There's nothing to correct."))
    }

    /// The two ways OOPS can come to nothing say different things, because a
    /// player who cannot tell them apart types it twice.
    @Test func bareOopsAsksForTheWord() async throws {
        let transcript = try await play(StudyGame(), ["take lampp", "oops"])
        #expect(
            turnOutput(of: "oops", in: transcript)
                .contains("You'll have to say which word you meant."))
    }

    @Test func bareOopsWithNothingToCorrectSaysThatInstead() async throws {
        let transcript = try await play(StudyGame(), ["x lamp", "oops"])
        #expect(turnOutput(of: "oops", in: transcript).contains("There's nothing to correct."))
    }

    /// A correction that still doesn't parse is a parse error like any other:
    /// free, and it leaves *its* misheard word to be mended in turn.
    @Test func aFailedCorrectionIsFreeAndCorrectableItself() async throws {
        let transcript = try await play(
            StudyGame(), ["score", "take lampp", "oops grue", "oops lamp", "score"])
        #expect(turnOutput(of: "oops grue", in: transcript).contains("I don't know the word \"grue\"."))
        #expect(turnOutput(of: "oops lamp", in: transcript).contains("Taken."))
        // One move for the TAKE and nothing for the three lines that failed.
        let scores = transcript.components(separatedBy: "> score")
        #expect(scores[1] != scores[2])
    }

    /// OOPS mends the line just typed and nothing older: any line in between
    /// spends the context.
    @Test func anInterveningLineSpendsTheCorrection() async throws {
        let transcript = try await play(StudyGame(), ["take lampp", "look", "oops lamp"])
        #expect(
            turnOutput(of: "oops lamp", in: transcript).contains("There's nothing to correct."))
    }

    /// Asking *which* word is a question, not a spend: the line the engine
    /// just offered to mend has to still be there on the next one, or the
    /// question it asked was one the player could not answer.
    @Test func bareOopsKeepsTheWordItAskedAbout() async throws {
        let transcript = try await play(StudyGame(), ["take lampp", "oops", "oops lamp"])
        #expect(
            turnOutput(of: "oops", in: transcript)
                .contains("You'll have to say which word you meant."))
        #expect(turnOutput(of: "oops lamp", in: transcript).contains("Taken."))
    }

    /// A typo *in the answer to a question* is mended in the whole line the
    /// answer was spliced into, not in the answer alone: `oops brass` after a
    /// mistyped answer to "Which lamp?" runs `x brass`, not `brass`.
    @Test func oopsMendsATypoInAnAnswerAgainstTheWholeLine() async throws {
        let transcript = try await play(LampRoomGame(), ["x lamp", "bras", "oops brass"])
        #expect(turnOutput(of: "x lamp", in: transcript).contains("Which"))
        #expect(turnOutput(of: "bras", in: transcript).contains("I don't know the word \"bras\"."))
        #expect(turnOutput(of: "oops brass", in: transcript).contains("Tarnished brass."))
    }

    /// A *fresh command* typed while a question is open is mended as itself.
    /// The line opens with a verb, so it was never an answer: it falls through
    /// and is parsed as a new sentence, and that sentence — not the one it
    /// would have made spliced into the question — is what OOPS mends.
    @Test func oopsMendsAFreshCommandTypedWhileAQuestionIsOpen() async throws {
        let transcript = try await play(LampRoomGame(), ["x lamp", "take keyy", "oops key"])
        #expect(turnOutput(of: "x lamp", in: transcript).contains("Which"))
        #expect(
            turnOutput(of: "take keyy", in: transcript)
                .contains("I don't know the word \"keyy\"."))
        #expect(turnOutput(of: "oops key", in: transcript).contains("Taken."))
    }
}

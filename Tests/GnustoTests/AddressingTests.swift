import Gnusto
import GnustoTestSupport
import Testing

/// `<actor>, <words>` — the one place a comma changes who a sentence is aimed
/// at. It reads first, ahead of the separator reading `ConjunctionTests` pins.
///
/// The engine has no system for one character to act on another's word, so the
/// only order it can honour is a greeting; everything else is heard and
/// declined. The test that matters most is ``anOrderIsDeclinedRatherThanObeyed``:
/// a naive addressee field would have run the command as the *player*, which
/// is worse than not understanding the sentence at all.
struct AddressingTests {
    @Test(arguments: ["usher, hello", "usher, hi", "usher,"])
    func addressingSomebodyWithAGreetingGreetsThem(_ command: String) async throws {
        let transcript = try await play(Antechamber(), [command])
        #expect(transcript.contains("The usher nods, and says nothing."))
    }

    @Test func anOrderIsDeclinedRatherThanObeyed() async throws {
        let transcript = try await play(
            Antechamber(), ["usher, take the lamp", "inventory", "look"])
        #expect(transcript.contains("The usher has no intention of taking orders from you."))
        #expect(!transcript.contains("Taken."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("You are empty-handed."))
        // And the lamp never moved.
        #expect(turnOutput(of: "look", in: transcript).contains("There is a lamp here."))
    }

    /// An order costs nothing, like every other thing the parser could not
    /// turn into an action.
    @Test func anOrderCostsNoTurn() async throws {
        let transcript = try await play(Antechamber(), ["usher, take the lamp", "score"])
        #expect(transcript.contains("in 0 turns"))
    }

    /// A line that was *only* punctuation used to tokenize to nothing and be
    /// answered with the beg line. Now that the comma survives tokenization it
    /// has to be caught a second time, after the strip — everything below that
    /// point assumes a first token, and reading one off an empty list traps.
    @Test(arguments: [",", ",,", "the,"])
    func aLineOfNothingButCommasIsAnEmptyLine(_ input: String) async throws {
        let transcript = try await play(Antechamber(), [input, "look"])
        // Whatever it says, it must still be running afterwards.
        #expect(transcript.contains("An antechamber."))
    }

    @Test func addressingSomethingInanimateFallsBackToTodaysBehaviour() async throws {
        let transcript = try await play(Antechamber(), ["lamp, hello"])
        #expect(transcript.contains("I didn't understand that sentence."))
    }

    @Test func addressingSomebodyWhoIsntHereFallsBackToTodaysBehaviour() async throws {
        let transcript = try await play(Antechamber(), ["butler, hello"])
        #expect(transcript.contains("I don't know the word \"butler\"."))
    }

    /// A comma whose prefix names nobody falls through to the separator
    /// reading — but one at the end of a phrase has nothing on the far side of
    /// it to separate, so it is punctuation and drops out.
    @Test func acommaThatAddressesNobodyIsStillNoise() async throws {
        let transcript = try await play(Antechamber(), ["take the lamp,", "inventory"])
        #expect(transcript.contains("Taken."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("lamp"))
    }

    @Test func aGreetingByNameReachesTheActorsOwnRules() async throws {
        // Fulminate authors greetings for its whole cast and answers all four
        // spellings with the same line; proven end to end in `FulminateTests`.
        let transcript = try await play(Antechamber(), ["usher, hello", "greet usher"])
        #expect(transcript.contains("The usher nods, and says nothing."))
        #expect(turnOutput(of: "greet usher", in: transcript).contains("nods, and says nothing"))
    }

    /// And so does the longhand. "say hello to the troll" is what a player types
    /// at a person, and a game without `GnustoConversation` — which mints these
    /// two rows for itself — answered it with "That sentence isn't one I
    /// recognize." Bare SAY stays nobody's verb: these are three-word patterns,
    /// so a game that owns the word outright keeps it.
    @Test func sayHelloToSomebodyIsAGreetingToo() async throws {
        let transcript = try await play(
            Antechamber(), ["say hello to usher", "say hi to the usher"])
        #expect(
            turnOutput(of: "say hello to usher", in: transcript)
                .contains("The usher nods, and says nothing."))
        #expect(
            turnOutput(of: "say hi to the usher", in: transcript)
                .contains("The usher nods, and says nothing."))
    }

    // MARK: - Bare greetings

    @Test func greetingSomethingInanimateIsRefused() async throws {
        let transcript = try await play(Antechamber(), ["greet lamp"])
        #expect(transcript.contains("The lamp is unlikely to answer."))
    }

    /// A bare hello in a crowd stays unaddressed — the engine will not pick
    /// one of three people for you.
    @Test func aBareGreetInACrowdAddressesTheRoom() async throws {
        let transcript = try await play(Antechamber(), ["greet"])
        #expect(transcript.contains("You say hello to the room in general."))
    }

    /// But with exactly one person in the room it can only have meant them, so
    /// it is filled in and reaches that actor's own rules.
    @Test func aBareGreetWithOnePersonPresentGreetsThem() async throws {
        let transcript = try await play(FollowLab(), ["greet"])
        #expect(transcript.contains("The walker nods, and says nothing."))
        #expect(!transcript.contains("room in general"))
    }
}

import GnustoTestSupport
import Testing

@testable import Gnusto

/// Exclusions: `take all but the sword` is the escape hatch when `take all`
/// would pick up the one thing the player wants left alone. The word is
/// claimed only behind a multi-object keyword, which is what keeps it
/// available to an item that has `but` among its own words.
struct ExclusionTests {
    // MARK: - The form itself

    @Test func allButOneThingTakesEverythingElse() async throws {
        let transcript = try await play(VaultGame(), ["take all but the coin"])
        expectInOrder(
            transcript,
            [
                "cup and saucer: Taken.",
                "gray feather: Taken.",
            ])
        #expect(!transcript.contains("brass coin:"))
        #expect(!transcript.contains("I don't know the word"))
    }

    @Test func exceptIsTheSameWordAsBut() async throws {
        let transcript = try await play(VaultGame(), ["take everything except the coin"])
        #expect(transcript.contains("gray feather: Taken."))
        #expect(!transcript.contains("brass coin:"))
    }

    @Test func anExclusionListLeavesOutEveryMemberOfIt() async throws {
        let transcript = try await play(
            VaultGame(), ["take all except the coin and the feather"])
        #expect(transcript.contains("cup and saucer: Taken."))
        #expect(!transcript.contains("brass coin:"))
        #expect(!transcript.contains("gray feather:"))
    }

    @Test func dropAllButWorksAgainstHeldItems() async throws {
        // Held: the sack and the worn cloak. `drop all` drops both.
        let transcript = try await play(VaultGame(), ["drop all but the cloak"])
        #expect(transcript.contains("leather sack: Dropped."))
        #expect(!transcript.contains("velvet cloak:"))
    }

    @Test func themTakesAnExclusionToo() async throws {
        let transcript = try await play(
            VaultGame(), ["take coin and feather", "drop them but the coin"])
        expectInOrder(
            transcript,
            [
                "brass coin: Taken.",
                "gray feather: Dropped.",
            ])
        #expect(!transcript.contains("brass coin: Dropped."))
    }

    @Test func anExclusionFillsTheDirectSlotOfATwoObjectVerb() async throws {
        let transcript = try await play(
            VaultGame(), ["take all but the idol", "put all but the sack in sack"])
        let putting = turnOutput(of: "put all but the sack in sack", in: transcript)
        #expect(putting.contains("brass coin: You put the brass coin in the leather sack."))
        #expect(!putting.contains("leather sack:"))
    }

    // MARK: - Forgiveness

    @Test func excludingSomethingThatWasNeverInTheSetIsNotAnError() async throws {
        // The statue is scenery, so `take all` never offered it; the sack is
        // already held. Excepting either changes nothing and says nothing.
        let transcript = try await play(
            VaultGame(), ["take all but the statue", "score"])
        expectInOrder(
            transcript,
            [
                "brass coin: Taken.",
                "gray feather: Taken.",
                // The command ran, so it cost its one turn.
                "in 1 turn",
            ])
        #expect(!transcript.contains("statue:"))
        #expect(!transcript.contains("You can't see any such thing"))
    }

    @Test func aTrailingExclusionWordIsForgiven() async throws {
        let transcript = try await play(VaultGame(), ["take all but"])
        #expect(transcript.contains("brass coin: Taken."))
        #expect(transcript.contains("gray feather: Taken."))
    }

    @Test func anExclusionThatEmptiesTheGroupSaysSoAndCostsNothing() async throws {
        // Only the sack and the worn cloak are held; excepting both leaves
        // nothing, and "You aren't carrying anything" would be a lie.
        let transcript = try await play(
            VaultGame(), ["drop all but the sack and the cloak", "score"])
        expectInOrder(transcript, ["That leaves nothing at all.", "in 0 turns"])
        #expect(!transcript.contains("You aren't carrying anything."))
    }

    /// The same subtraction, spelled the other way: `put all in the sack` takes
    /// the sack out of the group it is the destination for, and a player whose
    /// hands hold nothing else is not a player carrying nothing.
    @Test func theContainerEmptyingItsOwnGroupSaysSoToo() async throws {
        let transcript = try await play(VaultGame(), ["drop cloak", "put all in sack"])
        let putting = turnOutput(of: "put all in sack", in: transcript)
        #expect(putting.contains("That leaves nothing at all."))
        #expect(!putting.contains("You aren't carrying anything."))
    }

    @Test func anEmptyRoomStillGetsItsOwnAnswer() async throws {
        // Nothing was on offer in the first place, so the exception is not
        // what emptied the group and must not be blamed for it. The cloak is
        // worn, so it is nameable in the bare closet.
        let transcript = try await play(VaultGame(), ["north", "take all but the cloak"])
        #expect(transcript.contains("There is nothing here to take."))
        #expect(!transcript.contains("That leaves nothing at all."))
    }

    // MARK: - Turn accounting

    @Test func anExclusionCostsExactlyOneTurn() async throws {
        let transcript = try await play(VaultGame(), ["take all but the coin", "score"])
        #expect(occurrences(of: "Tick.", in: transcript) == 1)
        #expect(transcript.contains("in 1 turn"))
    }

    // MARK: - The negatives

    @Test func aNameContainingAnExclusionWordIsStillOneThing() async throws {
        // `last but one ticket` is one item's declared phrase. Nothing in
        // front of the `but` is a keyword, so the split never fires.
        let transcript = try await play(
            VaultGame(), ["take last but one ticket", "inventory"])
        expectInOrder(transcript, ["Taken.", "last but one ticket"])
        #expect(!transcript.contains("You can't see any such thing"))
        #expect(!transcript.contains("ticket:"))
    }

    @Test func aNameContainingAnExclusionWordCanStillBeExcepted() async throws {
        let transcript = try await play(VaultGame(), ["take all but one ticket"])
        #expect(transcript.contains("brass coin: Taken."))
        #expect(!transcript.contains("ticket: Taken."))
    }

    @Test func anExclusionInTheIndirectSlotRefuses() async throws {
        let transcript = try await play(VaultGame(), ["put coin in all but the sack"])
        #expect(transcript.contains("You can't use multiple objects there."))
    }

    @Test func aKeywordInsideAnExclusionRefuses() async throws {
        let transcript = try await play(VaultGame(), ["take all but everything"])
        #expect(transcript.contains("You can't use multiple objects there."))
    }

    @Test func anUnknownWordInAnExclusionNamesThatWord() async throws {
        let transcript = try await play(VaultGame(), ["take all but zzyzx"])
        #expect(transcript.contains("I don't know the word \"zzyzx\"."))
    }

    @Test func somethingOutOfSightInAnExclusionSaysSo() async throws {
        let transcript = try await play(VaultGame(), ["north", "take all but the coin", "score"])
        // The room is bare and the coin is back in the vault: the phrase names
        // nothing here, and nothing runs.
        #expect(transcript.contains("You can't see any such thing"))
        #expect(transcript.contains("in 1 turn"))
    }

    @Test func exclusionIsRefusedForVerbsThatTakeOneObject() async throws {
        let transcript = try await play(VaultGame(), ["open all but the sack", "score"])
        expectInOrder(
            transcript,
            [
                "You can't use multiple objects with \"open\".",
                "in 0 turns",
            ])
    }
}

import GnustoTestSupport
import Testing

@testable import Gnusto

/// Conjunction lists: `take the bottle and the sack` names several objects in
/// the direct slot and runs the same per-object expansion `take all` does.
/// The negatives matter as much as the positives — a phrase that already
/// names something must never be re-read as a list.
struct ConjunctionTests {
    // MARK: - The list itself

    @Test func twoObjectsJoinedByAndAreBothTaken() async throws {
        let transcript = try await play(VaultGame(), ["take coin and feather"])
        expectInOrder(
            transcript,
            [
                "brass coin: Taken.",
                "gray feather: Taken.",
            ])
        #expect(!transcript.contains("I don't know the word"))
    }

    @Test func threeObjectsRunOneAfterAnother() async throws {
        let transcript = try await play(VaultGame(), ["take coin and feather and idol"])
        expectInOrder(
            transcript,
            [
                "brass coin: Taken.",
                "gray feather: Taken.",
                "cursed idol: The idol refuses to budge.",
            ])
    }

    @Test func aListKeepsTheOrderThePlayerTyped() async throws {
        // "all" sorts by display name; a list the player wrote out reads back
        // in the order they wrote it, feather before coin.
        let transcript = try await play(VaultGame(), ["take feather and coin"])
        expectInOrder(
            transcript,
            [
                "gray feather: Taken.",
                "brass coin: Taken.",
            ])
    }

    @Test func aListFillsTheDirectSlotOfATwoObjectVerb() async throws {
        let transcript = try await play(
            VaultGame(), ["take coin and feather", "put coin and feather in sack"])
        expectInOrder(
            transcript,
            [
                "brass coin: You put the brass coin in the leather sack.",
                "gray feather: You put the gray feather in the leather sack.",
            ])
    }

    @Test func aListIsNotFilteredTheWayAllIs() async throws {
        // "take all" skips the scenery statue. Naming it is a different act:
        // the player asked for that thing, so the refusal is spoken.
        let transcript = try await play(VaultGame(), ["take statue and coin"])
        expectInOrder(transcript, ["marble statue:", "brass coin: Taken."])
    }

    @Test func duplicatesCollapseToOneObject() async throws {
        let transcript = try await play(VaultGame(), ["take coin and coin"])
        #expect(transcript.contains("Taken."))
        #expect(!transcript.contains("brass coin: Taken."))
    }

    @Test func aTrailingConjunctionIsForgiven() async throws {
        let transcript = try await play(VaultGame(), ["take coin and"])
        #expect(transcript.contains("Taken."))
        #expect(!transcript.contains("brass coin:"))
    }

    @Test func themRecallsAnExplicitList() async throws {
        let transcript = try await play(
            VaultGame(), ["take coin and feather", "drop them"])
        expectInOrder(
            transcript,
            [
                "gray feather: Taken.",
                "brass coin: Dropped.",
                "gray feather: Dropped.",
            ])
    }

    // MARK: - Turn accounting

    @Test func aListCostsExactlyOneTurn() async throws {
        let transcript = try await play(VaultGame(), ["take coin and feather", "score"])
        let ticks = transcript.components(separatedBy: "Tick.").count - 1
        #expect(ticks == 1)
        #expect(transcript.contains("in 1 turn"))
    }

    @Test func aRefusedListIsFree() async throws {
        let transcript = try await play(VaultGame(), ["open coin and feather", "score"])
        expectInOrder(
            transcript,
            [
                "You can't use multiple objects with \"open\".",
                "in 0 turns",
            ])
    }

    // MARK: - The negatives

    @Test func aNameContainingTheConjunctionIsStillOneThing() async throws {
        // `cup and saucer` is one item's declared phrase. Resolving the whole
        // phrase happens first, so the split never gets a chance to mangle it.
        let transcript = try await play(VaultGame(), ["take cup and saucer", "inventory"])
        expectInOrder(transcript, ["Taken.", "cup and saucer"])
        #expect(!transcript.contains("You can't see any such thing"))
        #expect(!transcript.contains("saucer:"))
    }

    @Test func aListInTheIndirectSlotRefuses() async throws {
        let transcript = try await play(VaultGame(), ["put coin in sack and idol"])
        #expect(transcript.contains("You can't use multiple objects there."))
    }

    @Test func aMultiObjectKeywordInsideAListRefuses() async throws {
        let transcript = try await play(VaultGame(), ["take coin and all"])
        #expect(transcript.contains("You can't use multiple objects there."))
    }

    @Test func aConjunctionIsNotACommandSeparator() async throws {
        // "take the sword and go north" is two commands in English and one
        // unparseable noun phrase here. It must not move the player.
        let transcript = try await play(VaultGame(), ["take coin and go north", "look"])
        expectInOrder(transcript, ["You can't see any such thing", "Vault"])
        #expect(!transcript.contains("Closet"))
    }

    @Test func anUnknownWordInAListNamesThatWord() async throws {
        let transcript = try await play(VaultGame(), ["take coin and zzyzx"])
        #expect(transcript.contains("I don't know the word \"zzyzx\"."))
    }

    @Test func somethingOutOfSightInAListSaysSo() async throws {
        // The sack is held and resolves; the coin was left behind in the vault.
        // A member nobody can see answers for itself, and the whole list is off.
        let transcript = try await play(VaultGame(), ["north", "take sack and coin", "score"])
        expectInOrder(
            transcript,
            [
                "You can't see any such thing",
                // Only "north" was a turn; the unresolvable list was free.
                "in 1 turn",
            ])
    }

    @Test func allStillExpandsAndIncludesTheAndNamedItem() async throws {
        let transcript = try await play(VaultGame(), ["take all"])
        expectInOrder(
            transcript,
            [
                "brass coin: Taken.",
                "cup and saucer: Taken.",
                "cursed idol: The idol refuses to budge.",
                "gray feather: Taken.",
            ])
    }

    // MARK: - Questions inside a list

    @Test func anAmbiguousMemberAsksAndTheAnswerSplicesBackIntoTheList() async throws {
        let transcript = try await play(
            LanternShopGame(), ["take rusty lantern and lantern", "small"])
        expectInOrder(
            transcript,
            [
                "Which do you mean: the brass lantern or the rusty lantern "
                    + "or the small brass lantern?",
                "rusty lantern: Taken.",
                "small brass lantern: Taken.",
            ])
    }
}

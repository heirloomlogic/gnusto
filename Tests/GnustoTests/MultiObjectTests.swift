import GnustoTestSupport
import Testing

@testable import Gnusto

/// Phase 6 multi-object commands: "all" and "them" expand in the world and
/// run the pipeline once per object with labeled result lines.
struct MultiObjectTests {
    @Test func takeAllLabelsEachObjectAndRunsRulesPerObject() async throws {
        let transcript = try await play(VaultGame(), ["take all"])
        // Name-sorted lines; the statue (scenery) is skipped entirely; the
        // idol's before-rule refusal shows on its own line while the rest
        // are taken.
        expectInOrder(
            transcript,
            [
                "brass coin: Taken.",
                "cursed idol: The idol refuses to budge.",
                "gray feather: Taken.",
            ])
        #expect(!transcript.contains("statue:"))
    }

    @Test func eachTurnRulesFireOncePerTypedCommand() async throws {
        let transcript = try await play(VaultGame(), ["take all"])
        let ticks = transcript.components(separatedBy: "Tick.").count - 1
        #expect(ticks == 1)
    }

    @Test func takeAllWithNothingLeftIsFreeAndExplains() async throws {
        let transcript = try await play(
            VaultGame(), ["north", "take all", "score"])
        expectInOrder(
            transcript,
            [
                "There is nothing here to take.",
                // Only "north" consumed a turn; the empty "take all" was free.
                "in 1 turn",
            ])
    }

    @Test func dropAllIncludesWornItems() async throws {
        let transcript = try await play(VaultGame(), ["drop all"])
        expectInOrder(
            transcript,
            [
                "leather sack: Dropped.",
                "velvet cloak: (first taking off the velvet cloak) Dropped.",
            ])
    }

    @Test func putAllInSkipsTheContainerItself() async throws {
        let transcript = try await play(VaultGame(), ["put all in sack"])
        expectInOrder(
            transcript,
            ["velvet cloak:", "You put the velvet cloak in the leather sack."])
        #expect(!transcript.contains("sack: You can't put"))
    }

    @Test func multiObjectRefusedForOtherVerbs() async throws {
        let transcript = try await play(VaultGame(), ["open all", "score"])
        expectInOrder(
            transcript,
            [
                "You can't use multiple objects with \"open\".",
                "in 0 turns",
            ])
    }

    @Test func allInTheIndirectSlotRefuses() async throws {
        let transcript = try await play(VaultGame(), ["put coin in all"])
        expectInOrder(transcript, ["You can't use multiple objects there."])
    }

    @Test func themRecallsTheLastGroup() async throws {
        let transcript = try await play(
            VaultGame(), ["take all", "drop them"])
        expectInOrder(
            transcript,
            [
                "brass coin: Taken.",
                "brass coin: Dropped.",
                "gray feather: Dropped.",
            ])
        // The idol was never taken, so dropping the group refuses it.
        expectInOrder(transcript, ["cursed idol: You aren't carrying that."])
    }

    @Test func unboundThemExplainsItself() async throws {
        let transcript = try await play(VaultGame(), ["drop them"])
        expectInOrder(transcript, ["I don't know what \"them\" refers to."])
    }

    // MARK: - What `take all` may offer (#267)

    /// The question `TAKE ALL` asks is "what could I pick up here", not "what
    /// can I name" — and both directions of that walk in one turn. The water is
    /// in the canteen and the canteen is in your hand, so offering it would
    /// only earn a refusal by name; the wafer is a level down inside a crate
    /// the player is *not* carrying, and stays fair game.
    @Test func takeAllSkipsWhatYouCarryAtAnyDepthAndNotWhatYouDont() async throws {
        let transcript = try await play(NestedAllGame(), ["take all", "look in canteen"])
        let taking = turnOutput(of: "take all", in: transcript)
        #expect(taking.contains("brass key: Taken."))
        #expect(taking.contains("dry wafer: Taken."))
        #expect(!taking.contains("water"))
        #expect(!taking.contains("canteen:"))
        // Still where it was: nothing tried to move it.
        #expect(turnOutput(of: "look in canteen", in: transcript).contains("quantity of water"))
    }

    /// A shut transparent case shows its contents without letting the player
    /// touch them, and `all` is the reachable set, so the medal stays out.
    @Test func takeAllSkipsWhatIsBehindGlass() async throws {
        let transcript = try await play(NestedAllGame(), ["take all", "examine medal"])
        #expect(!turnOutput(of: "take all", in: transcript).contains("medal"))
        // Not a scope regression: it is still perfectly nameable.
        #expect(turnOutput(of: "examine medal", in: transcript).contains("bronze medal"))
    }

    /// Opening the case is the whole difference — the same medal, now reachable.
    @Test func openingTheGlassMakesItsContentsTakable() async throws {
        let transcript = try await play(NestedAllGame(), ["open showcase", "take all"])
        #expect(turnOutput(of: "take all", in: transcript).contains("bronze medal: Taken."))
    }

    /// Lifting from somebody else's hands is a plugin's job (stealing). The
    /// engine's `all` should not volunteer the attempt.
    @Test func takeAllSkipsWhatSomebodyElseIsHolding() async throws {
        let transcript = try await play(NestedAllGame(), ["take all", "examine ledger"])
        #expect(!turnOutput(of: "take all", in: transcript).contains("ledger"))
        #expect(turnOutput(of: "examine ledger", in: transcript).contains("Columns of numbers"))
    }

    /// `DROP ALL` is the opposite question and keeps its opposite answer: what
    /// you hold, direct children only. Emptying the canteen onto the floor is
    /// not what anybody typed.
    @Test func dropAllDropsWhatYouHoldAndNotItsContents() async throws {
        let transcript = try await play(NestedAllGame(), ["drop all", "look in canteen"])
        let dropping = turnOutput(of: "drop all", in: transcript)
        #expect(dropping.contains("tin canteen: Dropped."))
        #expect(!dropping.contains("water"))
        #expect(turnOutput(of: "look in canteen", in: transcript).contains("quantity of water"))
    }

    /// The subtraction is of the live inventory, not of a starting one — and
    /// it is the *carrying* that excluded the water, not the canteen. Put the
    /// canteen down and both come back, exactly as the crate's wafer does.
    @Test func whatYouPutDownBecomesTakableAgain() async throws {
        let transcript = try await play(NestedAllGame(), ["drop canteen", "take all"])
        let taking = turnOutput(of: "take all", in: transcript)
        #expect(taking.contains("tin canteen: Taken."))
        #expect(taking.contains("quantity of water: Taken."))
    }
}

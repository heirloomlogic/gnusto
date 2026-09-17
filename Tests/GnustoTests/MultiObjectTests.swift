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

    /// `take all of them` is `take all`: the tail restates the group the
    /// keyword already stands for. It used to come back "You can\'t see any
    /// such thing." Read where the keyword is read rather than by dropping
    /// `of` from the line — the word is one two core rows spell and one an
    /// item may own. Issue #445.
    @Test func allOfThemIsAll() async throws {
        let transcript = try await play(VaultGame(), ["take all of them"])
        expectInOrder(
            transcript,
            [
                "brass coin: Taken.",
                "cursed idol: The idol refuses to budge.",
                "gray feather: Taken.",
            ])
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

    /// The question `TAKE ALL` asks is "what could I pick up off the floor
    /// here", not "what can I name". The water is in the canteen and the
    /// canteen is in your hand; the wafer is a level down inside a crate. Both
    /// are packed, and `all` does not unpack anything (#267, #510).
    @Test func takeAllSweepsTheFloorAndNotWhatIsPackedOnIt() async throws {
        let transcript = try await play(NestedAllGame(), ["take all", "look in crate"])
        let taking = turnOutput(of: "take all", in: transcript)
        #expect(taking.contains("brass key: Taken."))
        #expect(taking.contains("wooden crate: Taken."))
        #expect(!taking.contains("dry wafer"))
        #expect(!taking.contains("water"))
        #expect(!taking.contains("canteen:"))
        // Still where it was: nothing tried to move it.
        #expect(turnOutput(of: "look in crate", in: transcript).contains("dry wafer"))
    }

    /// A shut transparent case shows its contents without letting the player
    /// touch them, and `all` is the reachable set, so the medal stays out.
    @Test func takeAllSkipsWhatIsBehindGlass() async throws {
        let transcript = try await play(NestedAllGame(), ["take all", "examine medal"])
        #expect(!turnOutput(of: "take all", in: transcript).contains("medal"))
        // Not a scope regression: it is still perfectly nameable.
        #expect(turnOutput(of: "examine medal", in: transcript).contains("bronze medal"))
    }

    /// Naming the container is how you sweep one: `take all from the crate`
    /// empties the crate and nothing else, and `from` reads a carried container
    /// as readily as one standing here. Opening the case is still the whole
    /// difference — a shut one has nothing in reach to sweep.
    @Test func takeAllFromAContainerSweepsThatContainerInstead() async throws {
        let transcript = try await play(
            NestedAllGame(),
            [
                "take all from crate", "take all from canteen", "take all from showcase",
                "open showcase", "take all from showcase",
            ])
        let crate = turnOutput(of: "take all from crate", in: transcript)
        #expect(crate.contains("dry wafer: Taken."))
        #expect(!crate.contains("brass key"))
        #expect(turnOutput(of: "take all from canteen", in: transcript).contains("quantity of water: Taken."))
        #expect(!turnOutput(of: "take all from showcase", in: transcript).contains("medal"))
        #expect(turnOutput(ofLast: "take all from showcase", in: transcript).contains("bronze medal: Taken."))
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

    /// The sweep reads the live floor, not a starting one: put the canteen down
    /// and `all` picks it up again — with the water still inside it.
    @Test func whatYouPutDownBecomesTakableAgain() async throws {
        let transcript = try await play(NestedAllGame(), ["drop canteen", "take all", "look in canteen"])
        let taking = turnOutput(of: "take all", in: transcript)
        #expect(taking.contains("tin canteen: Taken."))
        #expect(!taking.contains("quantity of water: Taken."))
        #expect(turnOutput(of: "look in canteen", in: transcript).contains("quantity of water"))
    }

    /// The round trip, which is the whole of #510: TAKE ALL and DROP ALL are
    /// each other's inverse, so two commands leave the room exactly as it was
    /// rather than emptying every open container onto the floor.
    @Test func takeAllThenDropAllLeavesEveryContainerPacked() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take all", "drop all", "look in crate", "look in canteen"])
        let dropping = turnOutput(of: "drop all", in: transcript)
        #expect(dropping.contains("wooden crate: Dropped."))
        #expect(!dropping.contains("dry wafer"))
        #expect(turnOutput(of: "look in crate", in: transcript).contains("dry wafer"))
        #expect(turnOutput(of: "look in canteen", in: transcript).contains("quantity of water"))
    }
}

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

    // MARK: - TAKE ALL in the dark (#518)

    /// A dark room's contents are dropped from the reachable set the same way
    /// the parser's own scope drops them, so the pre-fix answer was "There is
    /// nothing here to take" in a cellar holding a rock in plain (if
    /// unlit) view — a claim the player has no way to tell from a genuinely
    /// empty room. `examine` already has its own way of saying "I can't tell
    /// you" instead of asserting a look that could not have happened; TAKE ALL
    /// now says its room's version of the same thing.
    @Test func takeAllInTheDarkReportsTheDarknessInsteadOfClaimingTheRoomIsEmpty() async throws {
        let transcript = try await play(CaveGame(), ["take rock", "north", "drop rock", "take all"])
        let taking = turnOutput(of: "take all", in: transcript)
        #expect(taking.contains("It is pitch black. You can't see a thing."))
        #expect(!taking.contains("nothing here"))
    }

    /// The ordinary lit-room answer is unchanged: a truly empty *lit* room
    /// still gets "There is nothing here to take", not the dark line.
    @Test func takeAllInAnEmptyLitRoomStillSaysNothingHere() async throws {
        let transcript = try await play(EternalFlameGame(), ["take brazier", "take all"])
        #expect(turnOutput(of: "take all", in: transcript).contains("There is nothing here to take."))
    }

    /// A carried *lit* light source means the room is not dark, so TAKE ALL
    /// sees the room exactly as it would with the sun still up.
    @Test func aCarriedLitLightSourceMeansTakeAllSeesTheRoom() async throws {
        let transcript = try await play(
            CaveGame(), ["take rock", "north", "drop rock", "south", "take torch", "north", "take all"])
        let taking = turnOutput(of: "take all", in: transcript)
        #expect(taking.contains("gray rock: Taken."))
        #expect(!taking.contains("pitch black"))
    }

    /// The lit empty answer is a remark about the phrase and stays free
    /// (`takeAllWithNothingLeftIsFreeAndExplains`). The dark one is a remark
    /// about the room, the same one LOOK makes, so it is charged the same way
    /// LOOK is: four typed commands, four turns.
    @Test func takeAllInTheDarkCostsATurn() async throws {
        let transcript = try await play(
            CaveGame(), ["take rock", "north", "drop rock", "take all", "score"])
        #expect(turnOutput(of: "score", in: transcript).contains("in 4 turns"))
    }

    /// And because the turn is charged, its timers tick. `NightfallGame` warns
    /// on the first dark turn, spares the second and kills on the third, so a
    /// player who answers the dark with TAKE ALL is eaten on schedule instead
    /// of standing in a grue's larder for free.
    @Test func takeAllInTheDarkLetsTheTimersRun() async throws {
        let transcript = try await play(
            NightfallGame(), ["north", "take all", "take all", "quit"])
        #expect(!turnOutput(of: "take all", in: transcript).contains("finds you"))
        expectInOrder(
            turnOutput(ofLast: "take all", in: transcript),
            [
                "Something in the dark finds you before you find it.",
                "*** You have died ***",
            ])
    }

    /// The dark turn answers about the room, so it names no group — and a
    /// group it never named is a group it must not rebind. THEM still means
    /// the two things the player took before walking into the cave. (#518)
    @Test func takeAllInTheDarkLeavesThemBoundToTheLastGroup() async throws {
        let transcript = try await play(
            CaveGame(), ["take lamp and rock", "north", "take all", "south", "drop them"])
        let dropping = turnOutput(of: "drop them", in: transcript)
        #expect(dropping.contains("tin lamp: Dropped."))
        #expect(dropping.contains("gray rock: Dropped."))
        #expect(!dropping.contains("refers to"))
    }

    // MARK: - TAKE ALL FROM a named holder (#507)

    /// The whole of #507's group half: the crate's wafer is what `take all
    /// from crate` means, and neither the key on the floor beside it nor the
    /// mug on the counter is. A surface is a holder on the same terms, and
    /// `off` is the row that says so.
    @Test func takeAllFromAHolderTakesOnlyWhatThatHolderHas() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take all from crate", "take all off counter"])
        let fromCrate = turnOutput(of: "take all from crate", in: transcript)
        #expect(fromCrate.contains("dry wafer: Taken."))
        #expect(!fromCrate.contains("brass key"))
        #expect(!fromCrate.contains("chipped mug"))
        let offCounter = turnOutput(of: "take all off counter", in: transcript)
        #expect(offCounter.contains("chipped mug: Taken."))
        #expect(!offCounter.contains("brass key"))
    }

    /// Naming the holder is naming the thing, so the depth subtraction that
    /// keeps TAKE ALL from re-offering a carried sack's contents goes with
    /// it: emptying a sack you are holding is exactly what was asked for.
    @Test func takeAllFromACarriedContainerEmptiesIt() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take all from canteen", "look in canteen"])
        #expect(
            turnOutput(of: "take all from canteen", in: transcript)
                .contains("quantity of water: Taken."))
        #expect(
            turnOutput(of: "look in canteen", in: transcript)
                .contains("The tin canteen is empty."))
    }

    /// A shut container reports itself shut rather than bare — `lookIn`'s
    /// answer to the same question about the same thing. The showcase is
    /// transparent, so the medal is in plain sight and the "empty" line would
    /// have been visibly false. Opening it is the whole difference.
    @Test func takeAllFromAShutContainerSaysItIsShutUntilItIsOpened() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take all from showcase", "open showcase", "take all from showcase"])
        let shut = turnOutput(of: "take all from showcase", in: transcript)
        #expect(shut.contains("The glass showcase is closed."))
        #expect(!shut.contains("medal"))
        #expect(
            turnOutput(ofLast: "take all from showcase", in: transcript)
                .contains("bronze medal: Taken."))
    }

    /// Lifting from somebody else's hands stays a plugin's job, and the
    /// refusal is the one SEARCH gives — not "there is nothing there", which
    /// is false of a clerk holding a ledger.
    @Test func takeAllFromAPersonIsRefusedAsAPerson() async throws {
        let transcript = try await play(NestedAllGame(), ["take all from clerk"])
        let taking = turnOutput(of: "take all from clerk", in: transcript)
        #expect(taking.contains("bored clerk would have something to say"))
        #expect(!taking.contains("ledger: Taken."))
    }

    /// An empty holder, and one that is no sort of holder at all, share an
    /// answer: there is nothing to be had either way.
    @Test func takeAllFromSomethingWithNothingInItSaysSo() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take wafer", "take all from crate", "take all from key"])
        #expect(
            turnOutput(of: "take all from crate", in: transcript)
                .contains("There is nothing there to take."))
        #expect(
            turnOutput(of: "take all from key", in: transcript)
                .contains("There is nothing there to take."))
    }

    /// Asking your own pockets for more of what is in them is SEARCH's
    /// question about yourself, and gets SEARCH's answer.
    @Test func takeAllFromYourselfPatsYouDown() async throws {
        let transcript = try await play(NestedAllGame(), ["take all from me"])
        #expect(
            turnOutput(of: "take all from me", in: transcript)
                .contains("You pat yourself down"))
    }

    /// The dark still answers first. A chest carried into the dark is in
    /// scope and empty, and the empty answer is the one thing the player
    /// cannot have checked — so #518's line outranks #507's.
    @Test func takeAllFromAHolderInTheDarkStillReportsTheDark() async throws {
        let transcript = try await play(
            CaveGame(),
            [
                "take torch", "north", "open chest", "take chest", "drop torch", "east",
                "take all from chest",
            ])
        let taking = turnOutput(of: "take all from chest", in: transcript)
        #expect(taking.contains("It is pitch black. You can't see a thing."))
        #expect(!taking.contains("nothing there"))
    }

    /// And a holder the dark has taken out of scope never reaches the group
    /// at all: the parser refuses the noun, the way it does for any unlit
    /// room's contents.
    @Test func takeAllFromAHolderTheDarkHidesIsRefusedByScope() async throws {
        let transcript = try await play(
            CaveGame(), ["take rock", "north", "drop rock", "take all from rock"])
        let taking = turnOutput(of: "take all from rock", in: transcript)
        #expect(taking.contains("You can't see any such thing."))
        #expect(!taking.contains("nothing there to take"))
    }

    /// And a group that named nothing still leaves THEM alone, the way the
    /// dark turn does — the refused `take all from clerk` must not rebind it.
    @Test func takeAllFromAHolderThatOffersNothingLeavesThemAlone() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take key and mug", "take all from clerk", "drop them"])
        let dropping = turnOutput(of: "drop them", in: transcript)
        #expect(dropping.contains("brass key: Dropped."))
        #expect(dropping.contains("chipped mug: Dropped."))
        #expect(!dropping.contains("refers to"))
    }

    // MARK: - TAKE X FROM a named holder (#507)

    /// The other half of #507: the container named after `from` is a claim
    /// about where the thing is, and a wrong claim is corrected instead of
    /// being quietly granted.
    /// The refusal costs a turn, the way every other `take` refusal does.
    @Test func takeFromTheWrongContainerRefuses() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take key from crate", "inventory", "score"])
        #expect(
            turnOutput(of: "take key from crate", in: transcript)
                .contains("You don't find the brass key there."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("tin canteen"))
        #expect(!turnOutput(of: "inventory", in: transcript).contains("brass key"))
        #expect(turnOutput(of: "score", in: transcript).contains("in 2 turns"))
    }

    /// The right container still works, on a surface as well as inside a box.
    @Test func takeFromTheRightHolderWorks() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take wafer from crate", "take mug off counter"])
        #expect(turnOutput(of: "take wafer from crate", in: transcript).contains("Taken."))
        #expect(turnOutput(of: "take mug off counter", in: transcript).contains("Taken."))
    }

    /// A thing one level further down is still in the sack that holds the box
    /// that holds it, so the claim is true and the take runs.
    @Test func takeFromAHolderReachesThroughNesting() async throws {
        let transcript = try await play(
            NestedAllGame(),
            ["take mug", "put mug in canteen", "put canteen in crate", "take mug from crate"])
        #expect(turnOutput(of: "take mug from crate", in: transcript).contains("Taken."))
    }

    /// Somebody else's hands count as theirs: the refusal is about reach, not
    /// about the ledger being somewhere else.
    @Test func takeFromAPersonWhoDoesHoldItRefusesForReach() async throws {
        let transcript = try await play(NestedAllGame(), ["take ledger from clerk"])
        #expect(
            turnOutput(of: "take ledger from clerk", in: transcript)
                .contains("You can't reach the leather ledger."))
    }

    /// The correction comes before the verb's own complaints, so a player who
    /// has the wrong idea about where a thing is hears that rather than
    /// "You already have that" from the thing in their own hand.
    @Test func theWrongHolderIsAnsweredBeforeTheThingIsInspected() async throws {
        let transcript = try await play(
            NestedAllGame(), ["take key", "take key from crate"])
        let taking = turnOutput(of: "take key from crate", in: transcript)
        #expect(taking.contains("You don't find the brass key there."))
        #expect(!taking.contains("already have"))
    }

    /// Taking a thing out of itself is the same wrong claim.
    @Test func takeSomethingFromItselfRefuses() async throws {
        let transcript = try await play(NestedAllGame(), ["take crate out of crate"])
        #expect(
            turnOutput(of: "take crate out of crate", in: transcript)
                .contains("You don't find the wooden crate there."))
    }

    /// A list keeps the clause, so each thing the player named is checked
    /// against the holder they named it from.
    @Test func aListInheritsTheFromClause() async throws {
        let transcript = try await play(NestedAllGame(), ["take wafer and key from crate"])
        let taking = turnOutput(of: "take wafer and key from crate", in: transcript)
        #expect(taking.contains("dry wafer: Taken."))
        #expect(taking.contains("brass key: You don't find the brass key there."))
    }
}

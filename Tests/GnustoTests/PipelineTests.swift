import GnustoTestSupport
import Testing

@testable import Gnusto

struct PipelineTests {
    @Test func stagesRunInOrder() async throws {
        let transcript = try await play(OrderProbeGame(), ["take widget"])
        expectInOrder(
            transcript,
            [
                "[worldBefore]",
                "[locEachBefore]",
                "[locBefore]",
                "[itemBefore]",
                "Taken.",
                "[itemAfter]",
                "[locAfter]",
                "[locEachAfter]",
                "[worldAfter]",
            ])
    }

    @Test func refuseSkipsDefaultAndAftersButNotEachTurn() async throws {
        let transcript = try await play(OrderProbeGame(), ["drop widget", "take widget"])
        let refusedTurn = turnOutput(of: "take widget", in: transcript)

        expectInOrder(refusedTurn, ["[itemBefore]", "[refused]", "[locEachAfter]"])
        #expect(!refusedTurn.contains("Taken."))
        #expect(!refusedTurn.contains("[itemAfter]"))
        #expect(!refusedTurn.contains("[locAfter]"))
        // World time still passes on refused turns.
        #expect(refusedTurn.contains("[locEachAfter]"))
    }

    @Test func metaIntentsSkipRulesAndClock() async throws {
        let transcript = try await play(OrderProbeGame(), ["score", "score"])
        let scoreTurn = turnOutput(of: "score", in: transcript)
        #expect(!scoreTurn.contains("[locEachBefore]"))
        #expect(!scoreTurn.contains("[locEachAfter]"))
        // The clock didn't advance: both score reports say 0 turns.
        #expect(transcript.contains("in 0 turns"))
        #expect(!transcript.contains("in 1 turn"))
    }

    @Test func parseErrorsDoNotConsumeATurn() async throws {
        let transcript = try await play(
            OrderProbeGame(), ["frotz", "take grue", "score"])
        let frotzTurn = turnOutput(of: "frotz", in: transcript)
        #expect(!frotzTurn.contains("[locEachBefore]"))
        #expect(transcript.contains("in 0 turns"))
    }

    @Test func replyPreemptsTheDefaultAction() async throws {
        let transcript = try await play(OrderProbeGame(), ["examine widget"])
        let turn = turnOutput(of: "examine widget", in: transcript)
        #expect(turn.contains("blunders=0"))
        #expect(!turn.contains("You see nothing special"))
    }

    /// #523, site A — the single-command turn. `performStages` read the room
    /// once, before the world's each-turn rules, and looked the location
    /// `beforeEachTurn`, `before` and `after` rules up against that reading.
    @Test func eachTurnMoveRedirectsTheTurnsLocationRules() async throws {
        let transcript = try await play(DriftProbeGame(), ["look"])
        let turn = turnOutput(of: "look", in: transcript)

        expectInOrder(
            turn,
            [
                "[current]",
                "[raft-each-before]",
                "[raft-before]",
                "[raft-after]",
            ])
        #expect(!turn.contains("[dock-each-before]"))
        #expect(!turn.contains("[dock-before]"))
        #expect(!turn.contains("[dock-after]"))
    }

    /// #523, site B — the same reading in `runUpkeepBefore`, which is where a
    /// multi-object command runs its once-per-turn upkeep, ahead of the
    /// per-object loop.
    @Test func eachTurnMoveRedirectsUpkeepOnAMultiObjectTurn() async throws {
        let transcript = try await play(DriftProbeGame(), ["take all"])
        let turn = turnOutput(of: "take all", in: transcript)

        expectInOrder(
            turn,
            [
                "[current]",
                "[raft-each-before]",
                "There is nothing here to take.",
            ])
        #expect(!turn.contains("[dock-each-before]"))
    }

    /// The reading moved past the *whole* of stage 1, not only its each-turn
    /// half, so a `world.before` rule that moves the player redirects the
    /// turn\'s location rules exactly as a `world.beforeEachTurn` one does.
    /// That is wider than #523 asked for, and pinned here so it is not silent.
    @Test func aWorldBeforeMoveRedirectsTheTurnsLocationRules() async throws {
        let transcript = try await play(WorldBeforeDriftProbeGame(), ["look"])
        let turn = turnOutput(of: "look", in: transcript)

        expectInOrder(
            turn,
            [
                "[sluice]",
                "[barge-enter]",
                "[barge-each-before]",
                "[barge-before]",
                "[barge-after]",
            ])
        #expect(!turn.contains("[quay-each-before]"))
        #expect(!turn.contains("[quay-before]"))
        #expect(!turn.contains("[quay-after]"))
    }

    /// The one place the two readings disagree, and it is the shape of the
    /// multi-object turn rather than a choice: `runUpkeepBefore` runs ahead of
    /// the object loop and the world\'s `.before` rules run *inside* it, once
    /// per object, so no reading taken in the upkeep could see a move they have
    /// not made yet. From the first object on, the same rule applies as ever.
    ///
    /// Passes on both sides of #523's fix: it pins the asymmetry, not the fix.
    @Test func aWorldBeforeMoveDoesNotRedirectMultiObjectUpkeep() async throws {
        let transcript = try await play(WorldBeforeDriftProbeGame(), ["take all"])
        let turn = turnOutput(of: "take all", in: transcript)

        expectInOrder(
            turn,
            [
                "[quay-each-before]",
                "barrel: [sluice]",
                "You can\'t reach the barrel.",
                "sack: You can\'t reach the sack.",
            ])
        #expect(!turn.contains("[barge-each-before]"))
    }

    /// `proceed()` from a stage-1 rule runs stage 4 inside stage 1, so the walk
    /// it makes is a stage-1 move and the turn\'s `after` rules belong to the
    /// room it walked *into*. The second, unwrapped `go north` is the control:
    /// stage 4\'s own walk happens after the reading and leaves it alone, which
    /// is why an ordinary `go north` runs the `after` rules of the room it left.
    @Test func proceedFromAStageOneRuleMovesTheTurnsRoom() async throws {
        let transcript = try await play(ProceedWalkProbeGame(), ["go north", "go north"])

        let wrapped = turnOutput(of: "go north", in: transcript)
        expectInOrder(wrapped, ["[wrap-in]", "[wrap-out]", "[pound-after]"])
        #expect(!wrapped.contains("[lock-after]"))
        #expect(!wrapped.contains("[basin-after]"))

        let plain = turnOutput(ofLast: "go north", in: transcript)
        #expect(plain.contains("[pound-after]"))
        #expect(!plain.contains("[basin-after]"))
        #expect(!plain.contains("[wrap-in]"))
    }

    /// The `stage` that stage 2\'s location `before` lookup is keyed on moved
    /// with the reading, so a stage-1 rule that walks the *addressee* out of the
    /// room redirects that lookup too. Also wider than #523 asked for.
    @Test func aWorldBeforeMoveRedirectsTheAddresseesLocationRules() async throws {
        let transcript = try await play(OrderDriftProbeGame(), ["robot, wait"])
        let turn = turnOutput(of: "robot, wait", in: transcript)

        expectInOrder(turn, ["[shunt]", "[pit-before]", "[robot-waits]"])
        #expect(!turn.contains("[gantry-before]"))
    }

    /// An each-turn rule that kills the player is the last one that turn: the
    /// rule after it neither prints below the death banner nor scores. (#607)
    @Test func anEachTurnDeathStopsTheEachTurnRulesAfterIt() async throws {
        let transcript = try await play(EachTurnDeathGame(), ["jump"])
        let turn = turnOutput(of: "jump", in: transcript)

        expectInOrder(turn, ["[rule-one-kills]", "*** You have died ***", "Your score is 0, in 1 turn."])
        #expect(!turn.contains("[rule-two]"))
    }

    /// A location each-turn rule that wins the game stops the world's each-turn
    /// rules too, so a world rule that would kill the player cannot turn the
    /// win into a death. (#607)
    @Test func anEachTurnWinCannotBeOverwrittenByALaterDeath() async throws {
        let world = try cachedWorld(EachTurnWinGame(), seed: 1)
        _ = await world.begin()
        let result = await world.perform("jump")

        #expect(result.output.contains("[you-win]"))
        #expect(!result.output.contains("[world-kills]"))
        #expect(!result.output.contains("*** You have died ***"))
        #expect(result.isFinished)
    }

    /// A world `after` rule is skipped on a take that a `before` rule refused,
    /// that the default action refused, or that a `before` rule answered with
    /// `reply`, as item and location `after` rules are. The each-turn rules
    /// still run on all three. (#606)
    @Test func aWorldAfterRuleSkipsATakeThatDidNotSucceed() async throws {
        let transcript = try await play(
            WorldAfterProbeGame(), ["take statue", "take pillar", "take urn"])

        for (command, answer) in [
            ("take statue", "The statue will not budge."),
            ("take pillar", "You can't take that."),
            ("take urn", "You lift the urn and set it back."),
        ] {
            let turn = turnOutput(of: command, in: transcript)
            #expect(turn.contains(answer), "\(command)")
            #expect(!turn.contains("[WORLD-AFTER"), "\(command)")
            #expect(!turn.contains("[LOCATION-AFTER]"), "\(command)")
            expectInOrder(turn, ["[LOCATION-EACH]", "[WORLD-EACH]"])
        }
    }

    /// A world `after` rule runs in stage 5, after the location's `after`
    /// rules and before any each-turn rule. (#606)
    @Test func aWorldAfterRuleRunsAfterTheLocationsAfterRules() async throws {
        let transcript = try await play(WorldAfterProbeGame(), ["take coin"])

        expectInOrder(
            turnOutput(of: "take coin", in: transcript),
            ["Taken.", "[LOCATION-AFTER]", "[WORLD-AFTER coin]", "[LOCATION-EACH]", "[WORLD-EACH]"])
    }

    /// On a multi-object take a world `after` rule runs once for each object
    /// that was taken, and sees that object's command. (#606)
    @Test func aWorldAfterRuleRunsForEachObjectTaken() async throws {
        let transcript = try await play(WorldAfterProbeGame(), ["take coin and statue"])
        let turn = turnOutput(of: "take coin and statue", in: transcript)

        expectInOrder(turn, ["[WORLD-AFTER coin]", "The statue will not budge.", "[WORLD-EACH]"])
        #expect(!turn.contains("[WORLD-AFTER statue]"))
    }
}

/// The #606 fixture: a statue a `before` rule refuses, a scenery pillar the
/// default action refuses, an urn a `before` rule answers with `reply`, and a
/// coin that can be taken. Each kind of rule prints its own marker.
private struct WorldAfterProbeGame: Game {
    let title = "World After Probe"
    let intro = "A hall."

    let hall = Location {
        name("Hall")
        description("A marble hall.")
    }

    let statue = Item {
        name("statue")
    }

    let pillar = Item {
        name("pillar")
        scenery
    }

    let urn = Item {
        name("urn")
    }

    let coin = Item {
        name("coin")
    }

    var map: WorldMap {
        player.starts(in: hall)
        statue.starts(in: hall)
        pillar.starts(in: hall)
        urn.starts(in: hall)
        coin.starts(in: hall)
    }

    var rules: Rules {
        statue.before(.take) { try refuse("The statue will not budge.") }
        urn.before(.take) { try reply("You lift the urn and set it back.") }
        world.after(.take) { say("[WORLD-AFTER \(command.directObject?.name ?? "none")]") }
        hall.after(.take) { say("[LOCATION-AFTER]") }
        hall.afterEachTurn { say("[LOCATION-EACH]") }
        world.afterEachTurn { say("[WORLD-EACH]") }
    }
}

/// Two world each-turn rules: the first kills the player, the second prints a
/// marker and scores, so a transcript shows whether the second ran.
private struct EachTurnDeathGame: Game {
    let title = "Each-Turn Death"
    let intro = "A cell."

    let cell = Location {
        name("Cell")
        description("A bare cell.")
    }

    var map: WorldMap {
        player.starts(in: cell)
    }

    var rules: Rules {
        world.afterEachTurn { try die("[rule-one-kills]") }
        world.afterEachTurn {
            say("[rule-two]")
            player.score += 5
        }
    }
}

/// A location each-turn rule that wins the game, and a world each-turn rule —
/// which stage 6 runs after the location's — that kills the player.
private struct EachTurnWinGame: Game {
    let title = "Each-Turn Win"
    let intro = "A summit."

    let summit = Location {
        name("Summit")
        description("The top of the mountain.")
    }

    var map: WorldMap {
        player.starts(in: summit)
    }

    var rules: Rules {
        summit.afterEachTurn {
            say("[you-win]")
            try end(won: true)
        }
        world.afterEachTurn { try die("[world-kills]") }
    }
}

import Gnusto
import GnustoScoring

/// The endgame's seams. ``DungeonEndgame`` owns thirty-two rooms and everything
/// inside them; what is here is everything that reaches out of the bundle —
/// which is the whole of the way in and the whole of the way it is scored.
///
/// - The Land of the Living Dead's east passage into the Tomb, which is a
///   ``DungeonTemple`` room's exit.
/// - **The herald**, armed by a score test and nothing else. `SCORE-BLESS`
///   (`rooms.394:794`) arms it at `SCORE-MAX`, and the ten a death costs is
///   forgiven — so the test is the score *plus* ten for every death behind you.
/// - **The marble door's two outward turns**: shutting it arms the crypt's fuse
///   and suspends the grue, and opening it undoes both.
/// - **The transition out of the dark crypt**, which empties your hands and
///   puts back a refilled ``DungeonHouse/lantern`` and the ``DungeonHouse/sword``.
/// - **The six room values.** Four of the six rooms can be arrived at by a rule
///   rather than by an exit, and a rule that assigns `player.location` fires no
///   `onEnter` — so those four are paid the way `LIGHT-SHAFT` and the Top of
///   Well already are.
/// - **The sword's glow**, re-armed against the Guardians, and what examining
///   the blade says about it.
/// - **The thief's daemons**, switched off for good.
///
/// Its own file rather than more of `Dungeon.swift`, which is eleven hundred
/// lines before this arrives — `Dungeon+Thief.swift` and
/// `Dungeon+Palantir.swift`'s arrangement exactly.
extension Dungeon {
    /// The score that arms the herald: the whole of the main dungeon, with the
    /// ten points a death costs handed back for each death.
    static let scoreThatArmsTheHerald = 616

    /// The last seam in the game, and the only one into the endgame: the Land
    /// of the Living Dead opens east on the Tomb.
    @MapBuilder var milestoneNineMap: WorldMap {
        templeQuarter.landOfTheLivingDead.east(endgame.tomb)
        endgame.tomb.west(templeQuarter.landOfTheLivingDead)
    }

    /// The way it is paid for, and the way it ends. The way *in* is a daemon
    /// rather than a rule: see ``Dungeon/endgameTimers``.
    @RuleBuilder var endgameRules: Rules {
        cryptDoorRules
        endgameScoringRules
        swordGlowRules
    }

    /// What the blade says about itself when it is examined. Host-wired for
    /// `maze.gratingRoom.describe`'s reason: the sword is a ``DungeonHouse``
    /// item and the danger it is reading is ``DungeonEndgame``'s, so neither
    /// bundle can write this rule.
    ///
    /// It reads ``swordGlowStrength`` live rather than
    /// ``DungeonEndgame/swordGlow``, which is the *last announced* value.
    /// Examining is a question about now; the record is a record of what has
    /// already been said, and is a tick behind whenever the two could differ —
    /// a rule that walks the box or the player is over before the daemon runs.
    @RuleBuilder private var swordGlowRules: Rules {
        house.sword.describe {
            switch swordGlowStrength {
            case 2: "\(Prose.sword)\n\n\(Prose.swordExaminedBright)"
            case 1: "\(Prose.sword)\n\n\(Prose.swordExaminedFaint)"
            default: Prose.sword
            }
        }
    }

    /// The two turns of the marble door that reach outside the bundle: the
    /// crypt's fuse is the host's timer, and the grue is the host's plugin.
    /// Everything else the door does is ``DungeonEndgame/cryptRules``.
    @RuleBuilder private var cryptDoorRules: Rules {
        // Shut the door on yourself and the endgame starts counting.
        //
        // **And the grue goes out with the light.** This is the one room in the
        // game whose solution is to stand in the dark on purpose, and the
        // plugin's schedule would start rolling dice on the third dark turn —
        // against a three-turn fuse that re-arms if the room is lit when it
        // fires, so a player who shut the door with the lamp still burning
        // could be eaten while doing exactly the right thing. There are no
        // grues in the Crypt. They come straight back if the door is opened
        // again on this side of the transition, so the main dungeon's dark is
        // as dangerous as it ever was.
        //
        // `suspended` rather than `stopDaemon("grue")`, which is what this was
        // and what the plugin now documents against: stopping the daemon
        // *freezes* the dark-turn count, so a player who reached the Tomb two
        // turns into the dark would walk back out of the Crypt onto a dice turn
        // having never been warned. Suspending resets it, so the warning turn
        // survives the round trip.
        endgame.cryptDoor.after(.close) {
            guard player.location == endgame.crypt else { return }
            dangerousDark.suspended = true
            startFuse("endgame.crypt")
        }
        endgame.cryptDoor.after(.open) {
            guard !endgame.pastTheCrypt else { return }
            stopFuse("endgame.crypt")
            dangerousDark.suspended = false
        }
    }

    /// The six room values. Four are ordinary first-visit awards; the Top of
    /// Stairs and the Treasury are not, and each says why where it stands.
    @RuleBuilder private var endgameScoringRules: Rules {
        scoring.visit(endgame.crypt, register: "crypt")
        scoring.visit(endgame.narrowCorridor, register: "narrowCorridor")

        // Both of these are reached by a rule as well as by an exit — the Inside
        // Mirror only by stepping through the mirror, the Dungeon Entrance by
        // stepping out of the box as well as by walking north out of the
        // hallway. Every one of those rules walks the player in with
        // `enter(_:)`, so `onEnter` fires on every route into both and a plain
        // first-visit award is all either needs. Two `Bool`s and two
        // `afterEachTurn` rules stood in for that until #201 gave the engine a
        // teleport that runs the destination's rules.
        scoring.visit(endgame.insideMirror, register: "insideMirror")
        scoring.visit(endgame.dungeonEntrance, register: "dungeonEntrance")

        // The Top of Stairs is not here, and that is the choice rather than an
        // omission: the crypt's transition is the only way to first arrive
        // there, and it is the game putting you somewhere rather than you
        // walking in — so it banks its own ten. See ``crossIntoTheEndgame()``.

        // And the end of it. An `afterEachTurn` rather than an `onEnter` so the
        // room describes itself first and the game ends on the last paragraph
        // rather than ahead of it.
        endgame.treasury.afterEachTurn {
            scoring.awardOnce("treasuryOfZork")
            say(Prose.treasuryEnding)
            try end(won: true)
        }
    }

    /// The herald's fuse, the crypt's, and the sword's daemon.
    @TimerBuilder var endgameTimers: [TimedEvent] {
        // `SCORE-BLESS`. A daemon rather than a rule on the actions that can
        // move the score, and the difference is not taste: the deposit value of
        // a treasure is credited by the `Scoring` plugin's own `item.after`
        // rule, and a `world.after` rule on the same turn reads the score
        // *before* that has run. The last treasure of the run would arm nothing.
        //
        // It draws no randomness and stops itself the moment it fires, so the
        // seeded stream and every pinned transcript are untouched.
        daemon("endgame.blessing", autostart: true) {
            guard player.score + 10 * deaths >= Self.scoreThatArmsTheHerald else { return }
            stopDaemon("endgame.blessing")
            startFuse("endgame.herald")
        }

        // Fifteen turns after the last point is banked, whatever the player is
        // doing and wherever they are standing.
        fuse("endgame.herald", after: 15) {
            endgame.endgameBegun = true
            say(Prose.heraldArrives)
        }

        // Three turns of a shut crypt with no light in it. Lit when it fires,
        // it re-arms; left, it does not.
        fuse("endgame.crypt", after: 3) {
            guard player.location == endgame.crypt else { return }
            guard !player.location.isLit else {
                say(Prose.cryptFuseRearms)
                startFuse("endgame.crypt")
                return
            }
            try crossIntoTheEndgame()
        }

        // The elvish sword against the Guardians, which is the warning system
        // and the only one there is. Started by the transition, because before
        // it there is nothing for the sword to warn about.
        daemon("endgame.swordGlow") {
            // The danger, not your grip on it. This read `sword.isHeld` and
            // took an unheld sword for a sword in no danger, so putting it
            // down one room from the Guardians announced that the light had
            // gone out — a sentence about the blade, on a turn when only the
            // player's hands had moved. A blade lying on the floor of the room
            // you are standing in is a blade you can watch, which is
            // ``DungeonHouse/timers``' question about the lantern.
            guard house.sword.isVisible else {
                // And a blade three rooms behind you says nothing at all. Its
                // light did not go out; there is nobody there to see it. The
                // record goes back to nothing without printing, so the next
                // sight of the sword reports what it is doing then.
                endgame.swordGlow = 0
                return
            }
            let glow = swordGlowStrength
            // Only on a change. A blade that reports the same thing every turn
            // for twenty turns is furniture, not a warning.
            guard glow != endgame.swordGlow else { return }
            endgame.swordGlow = glow
            switch glow {
            case 2: say(Prose.swordGlowsBrightly)
            case 1: say(Prose.swordGlowsFaintly)
            default: say(Prose.swordStopsGlowing)
            }
        }
    }

    /// How near the Guardians the player is: 2 in their own room or in the box
    /// while it stands there, 1 one room away, 0 anywhere else.
    var swordGlowStrength: Int {
        let here = player.location

        // Everything answerable from the room alone is answered first. Reading
        // `endgame.box` is a JSON decode and this runs every turn from the
        // crypt onward, so it is reached only where the answer depends on where
        // the box is standing — which is only from inside it.
        if here == endgame.hallwayG || here == endgame.narrowGEast { return 2 }
        if here == endgame.narrowGWest { return 2 }
        if here == endgame.narrowDEast || here == endgame.narrowDWest { return 2 }
        if here == endgame.hallwayC || here == endgame.hallwayD { return 1 }
        if here == endgame.narrowCEast || here == endgame.narrowCWest { return 1 }
        guard here == endgame.insideMirror else { return 0 }

        let berth = endgame.box.berth
        if berth == MirrorBox.guardedBerth { return 2 }
        return abs(berth - MirrorBox.guardedBerth) == 1 ? 1 : 0
    }

    /// The transition. Everything in your hands goes, the lamp comes back full
    /// and dark, the sword comes back with it, the thief is finished, and you
    /// are standing at the top of a staircase you have never seen.
    func crossIntoTheEndgame() throws {
        endgame.pastTheCrypt = true

        for item in player.inventory { item.vanish() }

        // The lamp, refilled to the mainframe's 350 turns and switched off.
        // `DungeonHouse` owns what that means, fuses included.
        house.refillTheLantern()
        house.lantern.moveToPlayer()
        house.sword.moveToPlayer()

        // He has no business here, and the source switches him off rather than
        // fencing him out.
        stopDaemon("thief.roams")
        stopDaemon("thief.steals")
        stopDaemon("thief.stashes")
        startDaemon("endgame.swordGlow")

        scoring.awardOnce("topOfStairs")

        say(Prose.cryptTransition)
        // `arrive(at:)` rather than `enter(_:)`, now that the two are different
        // moves: this is the game putting you somewhere, not you walking there.
        // Nothing at the top of the stairs answers an arrival, which is why the
        // award above is banked here instead.
        arrive(at: endgame.topOfStairs)
    }
}

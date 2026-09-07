import GnustoTestSupport
import Testing

@testable import Gnusto

/// `description(when:_:otherwise:)` and `firstSight(when:_:otherwise:)`: the
/// trait form of a `describe { }` / `presence { }` rule that is one `if` on
/// one of the entity's own Bools.
struct TwoStateDescriptionTests {
    // MARK: - The trait is the rule, said in the trait block

    @Test(arguments: [
        ["x lamp", "turn on lamp", "x lamp", "turn off lamp", "x lamp"],
        ["x chest", "look", "open chest", "x chest", "look", "take chest", "look", "x chest"],
        ["x gem", "jump", "x gem"],
        ["x sentry", "look", "attack sentry", "x sentry", "look"],
        ["south", "look", "north", "take lamp", "turn on lamp", "south", "look"],
        ["east", "x box", "open box", "x box", "close box", "x box"],
        ["x lamp", "touch lamp", "x lamp", "undo", "x lamp"],
    ])
    func traitMatchesTheRuleItReplaces(commands: [String]) async throws {
        let compact = try await playTwoState(TwoStateGame(compact: true), commands)
        let explicit = try await playTwoState(TwoStateGame(compact: false), commands)
        #expect(compact == explicit)
    }

    @Test func bothTextsPrintAsTheBoolChanges() async throws {
        let transcript = try await playTwoState(
            TwoStateGame(compact: true),
            ["x lamp", "turn on lamp", "examine lamp", "look", "open chest", "look", "x chest"])
        #expect(turnOutput(of: "x lamp", in: transcript).contains(TwoStateGame.lampOff))
        #expect(turnOutput(of: "examine lamp", in: transcript).contains(TwoStateGame.lampOn))
        #expect(turnOutput(of: "look", in: transcript).contains(TwoStateGame.chestShutHere))
        #expect(transcript.contains(TwoStateGame.chestOpenHere))
        #expect(turnOutput(of: "x chest", in: transcript).contains(TwoStateGame.chestOpen))
    }

    @Test func actorKeyPathReadsTheActor() async throws {
        let transcript = try await playTwoState(
            TwoStateGame(compact: true), ["look", "attack sentry", "x sentry", "l"])
        #expect(turnOutput(of: "look", in: transcript).contains(TwoStateGame.sentryUpHere))
        #expect(turnOutput(of: "x sentry", in: transcript).contains(TwoStateGame.sentryDown))
        #expect(turnOutput(of: "l", in: transcript).contains(TwoStateGame.sentryDownHere))
    }

    @Test func locationTraitFollowsTheLight() async throws {
        let transcript = try await playTwoState(
            TwoStateGame(compact: true),
            ["take lamp", "turn on lamp", "south", "turn off lamp", "look"])
        #expect(turnOutput(of: "south", in: transcript).contains(TwoStateGame.cellarLit))
        #expect(!turnOutput(of: "look", in: transcript).contains(TwoStateGame.cellarDark))
    }

    @Test func runtimeAssignmentStillWins() async throws {
        let overridden = try await playTwoState(TwoStateGame(compact: true), ["touch lamp", "x lamp"])
        #expect(turnOutput(of: "x lamp", in: overridden).contains("Scuffed where you rubbed it."))
        // UNDO rewinds the turn that assigned it, and the trait answers again.
        let undone = try await playTwoState(
            TwoStateGame(compact: true), ["touch lamp", "undo", "x lamp"])
        #expect(turnOutput(of: "x lamp", in: undone).contains(TwoStateGame.lampOff))
    }

    @Test func emptyTextFallsThroughToTheStockLine() async throws {
        struct BlankGame: Game {
            let title = "Blank"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let hatch = Item {
                name("hatch")
                openable
                description(when: \.isOpen, "", otherwise: "A hatch, shut.")
            }
            var map: WorldMap {
                player.starts(in: room)
                hatch.starts(in: room)
            }
        }
        let transcript = try await play(BlankGame(), ["x hatch", "open hatch", "examine hatch"])
        #expect(turnOutput(of: "x hatch", in: transcript).contains("A hatch, shut."))
        #expect(
            turnOutput(of: "examine hatch", in: transcript)
                .contains("You see nothing special about the hatch."))
    }

    // MARK: - Exclusions

    @Test func traitBesideTheRuleItReplacesIsFatal() throws {
        struct DoubledGame: Game {
            let title = "Doubled"
            let intro = ""
            let room = Location {
                name("Room")
                description(when: \.isLit, "Lit.", otherwise: "Dark.")
            }
            let lamp = Item {
                name("lamp")
                lightSource
                description(when: \.isLit, "On.", otherwise: "Off.")
                firstSight(when: \.isLit, "A lit lamp is here.", otherwise: "A lamp is here.")
            }
            var map: WorldMap {
                player.starts(in: room)
                lamp.starts(in: room)
            }
            var rules: Rules {
                room.describe { "Live." }
                lamp.describe { "Live." }
                lamp.presence { "Live." }
            }
        }
        let diagnostics = try bootstrapDiagnostics(DoubledGame())
        #expect(
            diagnostics.contains {
                $0.contains("item \"lamp\" declares both a static description(…) and a describe")
            })
        #expect(
            diagnostics.contains {
                $0.contains("item \"lamp\" declares both a static firstSight(…) and a presence")
            })
        #expect(
            diagnostics.contains {
                $0.contains("location \"room\" declares both a static description(…) and a describe")
            })
    }

    @Test func traitBesideTheStaticTextIsFatal() throws {
        struct TwiceGame: Game {
            let title = "Twice"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
                description(when: \.isLit, "Lit.", otherwise: "Dark.")
            }
            let lamp = Item {
                name("lamp")
                lightSource
                description("A lamp.")
                description(when: \.isLit, "On.", otherwise: "Off.")
                firstSight("A lamp is here.")
                firstSight(when: \.isLit, "A lit lamp is here.", otherwise: "A lamp is here.")
            }
            var map: WorldMap {
                player.starts(in: room)
                lamp.starts(in: room)
            }
        }
        let diagnostics = try bootstrapDiagnostics(TwiceGame())
        #expect(
            diagnostics.contains {
                $0.contains("item \"lamp\" declares both description(…) and description(when:_:otherwise:)")
            })
        #expect(
            diagnostics.contains {
                $0.contains("item \"lamp\" declares both firstSight(…) and firstSight(when:_:otherwise:)")
            })
        #expect(
            diagnostics.contains {
                $0.contains(
                    "location \"room\" declares both description(…) and description(when:_:otherwise:)")
            })
    }

    @Test func actorKeyPathOnAnItemIsFatal() throws {
        struct NotAPersonGame: Game {
            let title = "Not a person"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let statue = Item {
                name("statue")
                description(when: \Actor.isUnconscious, "Toppled.", otherwise: "Upright.")
            }
            var map: WorldMap {
                player.starts(in: room)
                statue.starts(in: room)
            }
        }
        let diagnostics = try bootstrapDiagnostics(NotAPersonGame())
        #expect(
            diagnostics.contains {
                $0.contains("item \"statue\" declares description(when: \\Actor.isUnconscious, …)")
                    && $0.contains("is not an actor")
            })
    }

    // MARK: - The dead branch

    @Test func aBoolTheItemCannotChangeWarns() throws {
        struct DeadBranchGame: Game {
            let title = "Dead branch"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let slab = Item {
                name("slab")
                description(when: \.isOpen, "Open.", otherwise: "Shut.")
            }
            let candle = Item {
                name("candle")
                firstSight(when: \.isLit, "A candle burns here.", otherwise: "A candle lies here.")
            }
            let pebble = Item {
                name("pebble")
                description(when: \.isTouched, "Handled.", otherwise: "Untouched.")
            }
            var map: WorldMap {
                player.starts(in: room)
                slab.starts(in: room)
                candle.starts(in: room)
                pebble.starts(in: room)
            }
        }
        let (definition, _) = try Bootstrap.build(DeadBranchGame())
        #expect(
            definition.warnings.contains {
                $0.contains("item \"slab\" declares description(when: \\.isOpen, …) but is not openable")
                    && $0.contains("one of its two texts never prints")
            })
        #expect(
            definition.warnings.contains {
                $0.contains("item \"candle\" declares firstSight(when: \\.isLit, …) but is not a lightSource")
            })
        #expect(!definition.warnings.contains { $0.contains("pebble") })
    }

    @Test func aBoolTheItemDoesChangeDoesNotWarn() throws {
        let (definition, _) = try Bootstrap.build(TwoStateGame(compact: true))
        #expect(!definition.warnings.contains { $0.contains("never prints") })
    }

    @Test func theTraitCountsAsTextForTheFlagsThatNeedSome() throws {
        struct FlaggedGame: Game {
            let title = "Flagged"
            let intro = ""
            let room = Location {
                name("Room")
                dark
                alwaysDescribed
                description(when: \.isLit, "Lit.", otherwise: "Dark.")
            }
            let lamp = Item {
                name("lamp")
                lightSource
                alwaysListed
                firstSight(when: \.isLit, "A lit lamp is here.", otherwise: "A lamp is here.")
            }
            var map: WorldMap {
                player.starts(in: room)
                lamp.starts(in: room)
            }
        }
        let (definition, _) = try Bootstrap.build(FlaggedGame())
        #expect(!definition.warnings.contains { $0.contains("alwaysDescribed") })
        #expect(!definition.warnings.contains { $0.contains("alwaysListed") })
    }
}

private func bootstrapDiagnostics(_ game: some Game) throws -> [String] {
    do {
        _ = try Bootstrap.build(game)
        Issue.record("expected a BootstrapError")
        return []
    } catch let error as BootstrapError {
        return error.diagnostics
    }
}

// `play` caches by game type, but this fixture varies its declarations per
// instance. Build each world afresh so the comparison exercises both forms.
private func playTwoState(
    _ game: TwoStateGame, _ commands: [String], seed: UInt64 = 0
) async throws -> String {
    let world = try GameWorld(game: game, seed: seed)
    let io = ScriptedIOHandler(lines: commands)
    await REPL(world: world, io: io).run()
    return io.transcript
}

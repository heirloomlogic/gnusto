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
        ["east", "x box", "open box", "x box", "close box", "x box"],
        ["x lamp", "touch lamp", "x lamp", "undo", "x lamp"],
    ])
    func traitMatchesTheRuleItReplaces(commands: [String]) async throws {
        let compact = try await play(fresh: TwoStateGame(compact: true), commands, seed: 0)
        let explicit = try await play(fresh: TwoStateGame(compact: false), commands, seed: 0)
        #expect(compact == explicit)
    }

    @Test func eachTextPrintsForItsState() async throws {
        let transcript = try await play(
            fresh: TwoStateGame(compact: true),
            [
                "x lamp", "turn on lamp", "examine lamp", "look", "open chest", "x chest",
                "attack sentry", "x sentry", "l",
            ], seed: 0)
        #expect(turnOutput(of: "x lamp", in: transcript).contains(TwoStateGame.lampOff))
        #expect(turnOutput(of: "examine lamp", in: transcript).contains(TwoStateGame.lampOn))
        #expect(turnOutput(of: "look", in: transcript).contains(TwoStateGame.chestShutHere))
        #expect(turnOutput(of: "look", in: transcript).contains(TwoStateGame.sentryUpHere))
        #expect(turnOutput(of: "x chest", in: transcript).contains(TwoStateGame.chestOpen))
        #expect(turnOutput(of: "x sentry", in: transcript).contains(TwoStateGame.sentryDown))
        #expect(turnOutput(of: "l", in: transcript).contains(TwoStateGame.chestOpenHere))
        #expect(turnOutput(of: "l", in: transcript).contains(TwoStateGame.sentryDownHere))
    }

    @Test func runtimeAssignmentStillWins() async throws {
        let overridden = try await play(
            fresh: TwoStateGame(compact: true), ["touch lamp", "x lamp"], seed: 0)
        #expect(turnOutput(of: "x lamp", in: overridden).contains("Scuffed where you rubbed it."))
        // UNDO rewinds the turn that assigned it, and the trait answers again.
        let undone = try await play(
            fresh: TwoStateGame(compact: true), ["touch lamp", "undo", "x lamp"], seed: 0)
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
                description("A room.")
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
                lamp.describe { "Live." }
                lamp.presence { "Live." }
            }
        }
        let diagnostics = try bootstrapDiagnostics(DoubledGame())
        // Named by the trait the author wrote, so it can be grepped for.
        #expect(
            diagnostics.contains {
                $0.contains(
                    "item \"lamp\" declares both a static description(when:_:otherwise:) and a describe")
            })
        #expect(
            diagnostics.contains {
                $0.contains(
                    "item \"lamp\" declares both a static firstSight(when:_:otherwise:) and a presence")
            })
    }

    @Test func traitBesideTheStaticTextIsFatal() throws {
        struct TwiceGame: Game {
            let title = "Twice"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
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
            let watcher = Actor {
                name("watcher")
                firstSight(when: \Actor.isRevealed, "A watcher steps out.", otherwise: "Nobody.")
            }
            var map: WorldMap {
                player.starts(in: room)
                slab.starts(in: room)
                candle.starts(in: room)
                pebble.starts(in: room)
                watcher.starts(in: room)
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
        // The root spelled out reaches the same gate as the implied one.
        #expect(
            definition.warnings.contains {
                $0.contains("item \"watcher\" declares firstSight(when: \\Actor.isRevealed, …) but is not hidden")
            })
        // Any item can be touched, so on the examine channel the pair is live.
        #expect(!definition.warnings.contains { $0.contains("pebble") })
    }

    @Test func aBoolTheListingChannelCannotReachWarns() throws {
        struct ListingGame: Game {
            let title = "Listing"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let coin = Item {
                name("coin")
                firstSight(when: \.isTouched, "The coin you dropped.", otherwise: "A coin lies here.")
            }
            let token = Item {
                name("token")
                alwaysListed
                firstSight(when: \.isTouched, "The token you dropped.", otherwise: "A token lies here.")
            }
            let locket = Item {
                name("locket")
                firstSight(when: \.isHeld, "You carry the locket.", otherwise: "A locket glints.")
            }
            let ghost = Item {
                name("ghost")
                description(when: \.isVisible, "A ghost.", otherwise: "Nothing.")
            }
            var map: WorldMap {
                player.starts(in: room)
                coin.starts(in: room)
                token.starts(in: room)
                locket.starts(in: room)
                ghost.starts(in: room)
            }
        }
        let (definition, _) = try Bootstrap.build(ListingGame())
        #expect(
            definition.warnings.contains {
                $0.contains("item \"coin\" declares firstSight(when: \\.isTouched, …) but is not alwaysListed")
            })
        #expect(!definition.warnings.contains { $0.contains("\"token\"") })
        #expect(
            definition.warnings.contains {
                $0.contains("item \"locket\" declares firstSight(when: \\.isHeld, …) but is never listed")
            })
        #expect(
            definition.warnings.contains {
                $0.contains("item \"ghost\" declares description(when: \\.isVisible, …) but is only described")
            })
    }

    @Test func aBoolTheItemDoesChangeDoesNotWarn() throws {
        let (definition, _) = try Bootstrap.build(TwoStateGame(compact: true))
        #expect(!definition.warnings.contains { $0.contains("never prints") })
    }

    // MARK: - The checks that read the slot

    @Test func theTraitCountsAsTextForTheFlagThatNeedsSome() throws {
        struct FlaggedGame: Game {
            let title = "Flagged"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
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
        #expect(!definition.warnings.contains { $0.contains("alwaysListed") })
    }

    @Test func oneSentenceOnBothChannelsIsStillCaught() throws {
        struct SharedLineGame: Game {
            let title = "Shared line"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let lantern = Item {
                name("lantern")
                lightSource
                firstSight("A lantern lies here.")
                description(when: \.isLit, "It burns.", otherwise: "A lantern lies here.")
            }
            var map: WorldMap {
                player.starts(in: room)
                lantern.starts(in: room)
            }
        }
        let (definition, _) = try Bootstrap.build(SharedLineGame())
        #expect(
            definition.warnings.contains {
                $0.contains("item \"lantern\" gives one sentence to firstSight(…) and description(…)")
            })
    }

    @Test func aBuriedListingLineIsNamedAsTheTrait() throws {
        struct BuriedGame: Game {
            let title = "Buried"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let chest = Item {
                name("chest")
                container
            }
            let box = Item {
                name("box")
                container
            }
            let gem = Item {
                name("gem")
                hidden
                firstSight(when: \.isRevealed, "A gem, found.", otherwise: "A gem, lost.")
            }
            var map: WorldMap {
                player.starts(in: room)
                chest.starts(in: room)
                box.starts(inside: chest)
                gem.starts(inside: box)
            }
        }
        let (definition, _) = try Bootstrap.build(BuriedGame())
        #expect(
            definition.warnings.contains {
                $0.contains("item \"gem\" declares firstSight(when:_:otherwise:) but the map places it")
            })
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

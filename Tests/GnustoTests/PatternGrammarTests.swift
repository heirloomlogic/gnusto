import GnustoTestSupport
import Testing

@testable import Gnusto

/// Phase 6 pattern grammar: `SyntaxRule` rows as free-form patterns of
/// literal words and slots.
struct PatternGrammarTests {
    static func makeParser() throws -> StandardParser {
        let (definition, _) = try Bootstrap.build(WorkshopGame())
        return StandardParser(
            vocabulary: definition.vocabulary,
            syntaxRules: definition.syntaxRules)
    }

    static let scope = Scope(visibleItems: [
        EntityID("lamp"), EntityID("rug"), EntityID("gnome"), EntityID("crate"),
        EntityID("ironCrate"), EntityID("onSwitch"),
    ])

    @Test func twoObjectsAroundAPreposition() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("give lamp to gnome", scope: Self.scope).get()
        #expect(parsed.intent == Intent("give"))
        #expect(parsed.directObject == EntityID("lamp"))
        #expect(parsed.indirectObject == EntityID("gnome"))
        #expect(parsed.preposition == "to")
    }

    @Test(arguments: [
        "turn lamp on",
        "turn on lamp",
        "turn the brass lamp on",
        "turn on the brass lamp",
    ])
    func particleOnEitherSideOfTheObject(_ input: String) throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse(input, scope: Self.scope).get()
        #expect(parsed.intent == Intent("turnOn"))
        #expect(parsed.directObject == EntityID("lamp"))
    }

    @Test func multiWordVerbBeatsShorterRows() throws {
        let parser = try Self.makeParser()

        let under = try parser.parse("look under rug", scope: Self.scope).get()
        #expect(under.intent == Intent("lookUnder"))
        #expect(under.directObject == EntityID("rug"))

        // The standard rows sharing the "look" verb word are unaffected.
        let at = try parser.parse("look at rug", scope: Self.scope).get()
        #expect(at.intent == .examine)
        let bare = try parser.parse("look", scope: Self.scope).get()
        #expect(bare.intent == .look)
    }

    @Test func missingSecondObjectAsksForIt() throws {
        let parser = try Self.makeParser()
        let result = parser.parse("give lamp", scope: Self.scope)
        #expect(
            result
                == .failure(
                    .missingIndirect(
                        verb: "give", objectName: "the brass lamp", preposition: "to",
                        prefix: ["give", "lamp", "to"])))
    }

    @Test func customShapesWorkEndToEnd() async throws {
        let transcript = try await play(
            WorkshopGame(),
            ["give lamp to gnome", "turn lamp on", "look under rug"])
        expectInOrder(
            transcript,
            [
                "The gnome accepts your gift with a stony nod.",
                "The lamp hums to life.",
                "Only dust under there.",
            ])
    }

    // MARK: - Direction slots

    /// Adding any `["verb", .direction]` row makes the **bare** verb parse
    /// instead of asking, because the empty-direction branch returns success
    /// with a nil direction (`StandardParser.fit`'s `.direction` case). So a game that
    /// buys `push north` gives up core `push`'s "What do you want to push?"
    /// game-wide, and its own rule has to answer in the gap. Issue #151.
    @Test func aDirectionRowMakesTheBareVerbParseInsteadOfAsking() async throws {
        let transcript = try await play(WorkshopGame(), ["push", "push north"])
        expectInOrder(
            transcript,
            [
                "Push it which way? North, south, east or west.",
                "You put your shoulder to whatever lies north.",
            ])
        #expect(!transcript.contains("What do you want to push?"))
    }

    /// The control for the row above: `turn` carries object rows and no
    /// direction row, so the bare verb still asks for its noun.
    @Test func aVerbWithoutADirectionRowStillAsks() async throws {
        let transcript = try await play(WorkshopGame(), ["turn"])
        #expect(transcript.contains("What do you want to turn"))
    }

    /// A literal word may sit beside a direction slot even though an object
    /// slot may not, so the wordier phrasings can be bought back one spelling
    /// at a time — and each really does reach the intent with its direction.
    @Test(arguments: ["push north", "push crate north"])
    func aLiteralWordMaySitBesideADirectionSlot(_ input: String) throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse(input, scope: Self.scope).get()
        #expect(parsed.intent == Intent("shove"))
        #expect(parsed.direction == .north)
    }

    /// The sharp edge behind that workaround. A literal is matched, never
    /// resolved, so naming the crate leaves `Command.directObject` exactly
    /// where the bare row left it — nil. The rule is handed the same command
    /// either way and cannot tell that a noun was typed at all. Issue #151.
    @Test func theNounInALiteralRowIsDecorative() throws {
        let parser = try Self.makeParser()
        let named = try parser.parse("push crate north", scope: Self.scope).get()
        let bare = try parser.parse("push north", scope: Self.scope).get()
        #expect(named.directObject == nil)
        #expect(bare.directObject == nil)
    }

    /// What a literal row does *not* buy: anything not spelled out as a row.
    /// `box` is a declared synonym on the crate and `wooden` an adjective the
    /// bootstrap derives from its name — the parser answers to both wherever
    /// an object *slot* asks, as the `examine` half of each pair shows — but a
    /// literal row matches text, so neither reaches this pattern. The player
    /// names a thing standing in front of them and is told it isn't there,
    /// which is the cost #151 records in the player's own words.
    @Test(arguments: [("box", "push box north"), ("wooden crate", "push wooden crate north")])
    func adjectivesAndSynonymsStopAtThePattern(_ noun: String, _ input: String) throws {
        let parser = try Self.makeParser()
        let examined = try parser.parse("examine \(noun)", scope: Self.scope).get()
        #expect(examined.directObject == EntityID("crate"))
        #expect(parser.parse(input, scope: Self.scope) == .failure(.notInScope))
    }

    // MARK: - A noun and a direction

    /// The shape #151 bought: `.directObject` immediately before a trailing
    /// direction slot. The direction takes exactly one token and ends the
    /// pattern, so the noun phrase is everything before the last token — and it
    /// resolves like any other, which is the whole difference from the literal
    /// row above.
    @Test func anObjectSlotMaySitBeforeATrailingDirection() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("shift wooden crate north", scope: Self.scope).get()
        #expect(parsed.intent == Intent("shift"))
        #expect(parsed.directObject == EntityID("crate"))
        #expect(parsed.direction == .north)
    }

    /// The counterpart to `adjectivesAndSynonymsStopAtThePattern`, on the same
    /// two words. `box` is a synonym and `wooden` an adjective, and both now
    /// reach a rule that can tell which crate was named — where the literal row
    /// answers "You can't see any such thing" to the identical sentence.
    @Test(arguments: ["shift box north", "shift wooden crate north"])
    func adjectivesAndSynonymsReachAnObjectSlotBesideADirection(_ input: String) throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse(input, scope: Self.scope).get()
        #expect(parsed.directObject == EntityID("crate"))
        #expect(parsed.direction == .north)
    }

    /// Pronouns reach it too — the phrase is handed to the same `resolve` every
    /// other object slot uses, so `it` is whatever was last named.
    @Test func aPronounFillsTheObjectSlotBesideADirection() throws {
        let parser = try Self.makeParser()
        var scope = Self.scope
        scope.pronounIt = EntityID("crate")
        let parsed = try parser.parse("shift it north", scope: scope).get()
        #expect(parsed.directObject == EntityID("crate"))
        #expect(parsed.direction == .north)
    }

    /// Disambiguation reaches it too, and the answer is spliced *ahead* of the
    /// noun rather than appended — so the direction on the end of the line
    /// survives the round trip.
    @Test func anAmbiguousNounBesideADirectionAsksWhichOne() throws {
        let parser = try Self.makeParser()
        let result = parser.parse("shift crate north", scope: Self.scope)
        guard case .failure(.ambiguous(let names, let prefix, let suffix)) = result else {
            Issue.record("expected an ambiguity, got \(result)")
            return
        }
        #expect(names.contains("the wooden crate"))
        #expect(names.contains("the iron crate"))
        #expect(prefix == ["shift"])
        #expect(suffix == ["crate", "north"])
    }

    @Test func theAmbiguityIsAnsweredOnTheNextLine() async throws {
        let transcript = try await play(WorkshopGame(), ["shift crate north", "iron"])
        // The two names come out of a set, so only their presence is pinned.
        #expect(transcript.contains("Which do you mean:"))
        #expect(transcript.contains("the wooden crate"))
        #expect(transcript.contains("You shove the iron crate north."))
    }

    /// A noun with the direction left off. The phrase resolves, so the row asks
    /// for the half that is missing instead of quietly declining — and because
    /// a direction slot ends its pattern, the answer appends. However many
    /// words the noun took: what decides is that the line does not end in a
    /// direction, not how much is left over.
    @Test(arguments: [["shift", "box"], ["shift", "wooden", "crate"]])
    func anObjectWithNoDirectionAsksWhichWay(_ tokens: [String]) throws {
        let parser = try Self.makeParser()
        let result = parser.parse(tokens.joined(separator: " "), scope: Self.scope)
        #expect(
            result
                == .failure(
                    .missingDirection(
                        verb: "shift", objectName: "the wooden crate", prefix: tokens)))
        guard case .failure(let error) = result else { return }
        #expect(
            error.playerMessage(GameText())
                == "Which way do you want to shift the wooden crate?")
    }

    @Test func theDirectionQuestionIsAnsweredOnTheNextLine() async throws {
        let transcript = try await play(WorkshopGame(), ["shift box", "north"])
        expectInOrder(
            transcript,
            [
                "Which way do you want to shift the wooden crate?",
                "You shove the wooden crate north.",
            ])
    }

    /// A noun that isn't here fails on the noun, exactly as it would without a
    /// direction on the end. No "Which way?" for something that isn't there.
    @Test func anObjectThatIsNotHereFailsOnTheObject() throws {
        let parser = try Self.makeParser()
        #expect(parser.parse("shift anvil north", scope: Self.scope) == .failure(.unknownWord("anvil")))
    }

    /// Unlike a bare direction row, the new shape displaces nothing: the verb
    /// alone still asks for its object, which is what core `push <object>`
    /// already does. Issue #151's second complaint, answered by construction.
    @Test func theBareVerbStillAsksForItsObject() throws {
        let parser = try Self.makeParser()
        #expect(
            parser.parse("shift", scope: Self.scope)
                == .failure(.missingObject(verb: "shift", prefix: ["shift"])))
    }

    /// One token left and it *is* a direction — `shift north` — leaves the row
    /// with no noun to bind. It declines rather than matching with a nil
    /// object, which is what lets a bare-direction row for the same verb win
    /// instead. `Dungeon`'s Royal Puzzle carries all three shapes on one intent
    /// on the strength of this.
    @Test func aBareDirectionDoesNotSatisfyTheObjectSlot() throws {
        let parser = try Self.makeParser()
        #expect(parser.parse("shift north", scope: Self.scope) == .failure(.unmatchedSyntax))
    }

    /// An order carries the question back to the person it was aimed at, the
    /// same round trip the other three question cases get.
    @Test func theDirectionQuestionSurvivesAnOrder() throws {
        let parser = try Self.makeParser()
        let scope = Scope(
            visibleItems: Self.scope.visibleItems,
            visibleActors: [EntityID("gnome")],
            orderTakers: [EntityID("gnome"): Self.scope.visibleItems])
        let result = parser.parse("gnome, shift box", scope: scope)
        #expect(
            result
                == .failure(
                    .missingDirection(
                        verb: "shift", objectName: "the wooden crate",
                        prefix: ["gnome", ",", "shift", "box"])))
    }

    /// A custom row may share a **verb word** with a core intent as long as it
    /// does not share a shape, and the bootstrap says nothing about it — which
    /// is what lets `push <direction>` sit beside core `push <object>` without
    /// the override warning a real core-verb override earns.
    @Test func sharingACoreVerbWordButNotItsShapeIsSilent() throws {
        let (definition, _) = try Bootstrap.build(WorkshopGame())
        #expect(definition.warnings.isEmpty, "\(definition.warningReport ?? "no report")")
    }

    // MARK: - A slot's token width

    /// A trailing literal is at the *end* of the line, so that is where the
    /// noun phrase stops. Searching forward for the first `on` instead hands
    /// the pattern the switch's own adjective and leaves a noun with no slot
    /// to sit in, and the row misses a sentence it can place. Issue #215.
    @Test func aTrailingLiteralSplitsFromTheEndNotTheFirstOccurrence() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("turn the on switch on", scope: Self.scope).get()
        #expect(parsed.intent == Intent("turnOn"))
        #expect(parsed.directObject == EntityID("onSwitch"))
    }

    @Test func theSwitchIsTurnedOnEndToEnd() async throws {
        let transcript = try await play(WorkshopGame(), ["turn the on switch on"])
        #expect(transcript.contains("The switch clicks over."))
    }

    /// What a trailing-literal row does with a line that stops short of the
    /// particle, unchanged by the move to counting back: the phrase resolves,
    /// so the row asks for the rest and the answer belongs after the word the
    /// player never typed. Both lengths, because they take different routes —
    /// `wind lamp` leaves the slot nothing at all, while `wind brass lamp`
    /// leaves it a phrase and a suffix that isn't there.
    @Test(arguments: [["wind", "lamp"], ["wind", "brass", "lamp"]])
    func aTrailingLiteralRowStillAsksForTheParticle(_ tokens: [String]) throws {
        let parser = try Self.makeParser()
        #expect(
            parser.parse(tokens.joined(separator: " "), scope: Self.scope)
                == .failure(
                    .missingIndirect(
                        verb: "wind", objectName: "the brass lamp", preposition: "up",
                        prefix: tokens + ["up"])))
    }

    /// A direction slot no longer has to end its pattern: what places the noun
    /// is the *width* of everything behind it, and a literal word is one token
    /// like the direction is.
    @Test func aLiteralMayFollowTheDirectionSlot() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("wedge the wooden crate north hard", scope: Self.scope).get()
        #expect(parsed.intent == Intent("wedge"))
        #expect(parsed.directObject == EntityID("crate"))
        #expect(parsed.direction == .north)
    }

    /// Nor does the object slot have to stand *immediately* before the
    /// direction. A literal between them adds one to the width and nothing
    /// else.
    @Test func aLiteralMaySitBetweenTheObjectSlotAndTheDirection() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("hurl the wooden crate at north", scope: Self.scope).get()
        #expect(parsed.intent == Intent("hurl"))
        #expect(parsed.directObject == EntityID("crate"))
        #expect(parsed.direction == .north)
    }

    /// And the slot a direction closes need not be the *direct* object. The
    /// first slot is closed by its literal, the second by the width behind it.
    @Test func aDirectionMayCloseTheSecondObjectSlot() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("lob box at gnome north", scope: Self.scope).get()
        #expect(parsed.intent == Intent("lob"))
        #expect(parsed.directObject == EntityID("crate"))
        #expect(parsed.indirectObject == EntityID("gnome"))
        #expect(parsed.direction == .north)
    }

    @Test func theWiderShapesReachTheirRules() async throws {
        let transcript = try await play(
            WorkshopGame(),
            ["wedge box north hard", "hurl box at south", "lob box at gnome east"])
        expectInOrder(
            transcript,
            [
                "You wedge the wooden crate north, hard.",
                "You hurl the wooden crate off south.",
                "You lob the wooden crate at the garden gnome, who ducks east.",
            ])
    }

    /// The shape width cannot place, and the reason the `openSlot` search
    /// survives: a variable-width slot behind this one leaves nothing to count
    /// back from, so a literal has to close it — and `put the coin in the box`
    /// still splits on the first `in`.
    @Test func aVariableWidthSuffixStillNeedsALiteralToCloseTheSlot() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("give the brass lamp to gnome", scope: Self.scope).get()
        #expect(parsed.directObject == EntityID("lamp"))
        #expect(parsed.indirectObject == EntityID("gnome"))
    }

    @Test func malformedPatternsAreFatalTogether() {
        #expect {
            _ = try Bootstrap.build(BadPatternsGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.diagnostics.joined(separator: "\n")
            return bootstrapError.diagnostics.count >= 3
                && text.contains("must start with a literal word")
                && text.contains("literal word between")
                && text.contains("direction")
        }
    }
}

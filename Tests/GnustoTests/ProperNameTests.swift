import GnustoTestSupport
import Testing

@testable import Gnusto

/// The article rule: the engine renders a noun phrase — "the troll", "a troll",
/// "Mrs. Vane" — and hands the finished phrase to the stock line, so no
/// template puts an article in front of a name it can't see.
///
/// The tests come in pairs wherever a line can name either kind, because the
/// bug this replaces was a template getting one of the two right and being
/// wrong about the other forever.
struct ProperNameTests {
    // MARK: - The room listing

    /// `actorHere` ran the name through `indefinite(_:)` from a `static`, so
    /// "An Arthur is here." was the one broken line no game could re-skin.
    @Test func aProperNamedActorIsListedWithoutAnArticle() async throws {
        let transcript = try await play(NamedCastGame(), ["look"])
        #expect(transcript.contains("Arthur is here."))
        #expect(!transcript.contains("An Arthur"))
    }

    @Test func aCommonNounActorIsStillArticled() async throws {
        let transcript = try await play(NamedCastGame(), ["look"])
        #expect(transcript.contains("A troll is here."))
    }

    @Test func loosePropsKeepTheirArticlesAndProperNamedOnesDont() async throws {
        let transcript = try await play(NamedCastGame(), ["look"])
        #expect(transcript.contains("There is a brass lantern here."))
        #expect(transcript.contains("There is a chest here."))
    }

    /// Both halves of a container listing: the contents take the indefinite
    /// form, the container itself the definite one.
    @Test func containerListingsArticleEachSideSeparately() async throws {
        let transcript = try await play(
            NamedCastGame(), ["open chest", "look in chest"])
        #expect(transcript.contains("Opening the chest reveals Excalibur."))
        #expect(transcript.contains("In the chest is Excalibur."))
        #expect(!transcript.contains("an Excalibur"))
        #expect(!transcript.contains("the Excalibur"))
    }

    @Test func theInventoryListsAProperNameBare() async throws {
        let transcript = try await play(
            NamedCastGame(), ["open chest", "take excalibur", "take lantern", "i"])
        let inventory = turnOutput(of: "i", in: transcript)
        #expect(inventory.contains("Excalibur"))
        #expect(inventory.contains("a brass lantern"))
        #expect(!inventory.contains("an Excalibur"))
    }

    // MARK: - The lines that name a person

    /// The issue's headline acceptance, one command each.
    @Test func theStockPersonLinesNameAProperNameBare() async throws {
        let transcript = try await play(
            NamedCastGame(),
            ["x arthur", "take arthur", "search arthur", "hello arthur", "follow arthur"])
        #expect(transcript.contains("You see nothing special about Arthur."))
        #expect(transcript.contains("Arthur would take exception to that."))
        #expect(transcript.contains("Arthur would have something to say about that."))
        #expect(transcript.contains("Arthur nods, and says nothing."))
        #expect(transcript.contains("Arthur is right here."))
    }

    /// The same five sites for a common noun, which have to be unchanged — the
    /// whole refactor is meant to be invisible to a game without proper names.
    @Test func theStockPersonLinesStillArticleACommonNoun() async throws {
        let transcript = try await play(
            NamedCastGame(),
            ["x troll", "take troll", "search troll", "hello troll", "follow troll"])
        #expect(transcript.contains("You see nothing special about the troll."))
        #expect(transcript.contains("The troll would take exception to that."))
        #expect(transcript.contains("The troll would have something to say about that."))
        #expect(transcript.contains("The troll nods, and says nothing."))
        #expect(transcript.contains("The troll is right here."))
    }

    /// `notTakingOrders` is written by the *parser*, which has no turn frame,
    /// so it renders from the vocabulary rather than the definition.
    @Test func addressingAProperNamedPersonNamesThemBare() async throws {
        let transcript = try await play(
            NamedCastGame(), ["arthur, take lantern", "troll, take lantern"])
        #expect(transcript.contains("Arthur has no intention of taking orders from you."))
        #expect(transcript.contains("The troll has no intention of taking orders from you."))
    }

    @Test func followingSomebodyOutOfSightNamesThemBare() async throws {
        let transcript = try await play(NamedCastGame(), ["follow mordred"])
        #expect(transcript.contains("You have no idea which way Mordred went."))
    }

    /// `cantFollowThat` and `cantGreetThat` are the two lines Fulminate had to
    /// leave articled, because they can only ever name a thing. They still can.
    @Test func followingOrGreetingAThingStillArticlesIt() async throws {
        let transcript = try await play(
            NamedCastGame(), ["follow lantern", "hello lantern"])
        #expect(transcript.contains("The brass lantern isn't going anywhere."))
        #expect(transcript.contains("The brass lantern is unlikely to answer."))
    }

    /// The same two lines, aimed at a proper-named *thing* — the case that
    /// used to be unfixable, since one template served both.
    @Test func followingOrGreetingAProperNamedThingNamesItBare() async throws {
        let transcript = try await play(
            NamedCastGame(), ["open chest", "follow excalibur", "hello excalibur"])
        #expect(transcript.contains("Excalibur isn't going anywhere."))
        #expect(transcript.contains("Excalibur is unlikely to answer."))
    }

    // MARK: - One sentence, both kinds

    /// The acceptance criterion no per-line override could ever have met: a
    /// bare name and an articled one in the same sentence.
    @Test func aDisambiguationArticlesEachCandidateSeparately() async throws {
        let transcript = try await play(
            NamedCastGame(), ["open chest", "x figure", "x sword"])
        #expect(transcript.contains("Which do you mean: Arthur or the carved figure?"))
        #expect(transcript.contains("Which do you mean: Excalibur or the wooden sword?"))
    }

    /// Sorted by the bare name, not the rendered phrase — otherwise every
    /// common noun files under "the" and the order stops reading alphabetical.
    @Test func disambiguationOrderIgnoresTheArticle() async throws {
        let transcript = try await play(NamedCastGame(), ["x man"])
        #expect(transcript.contains("Which do you mean: Arthur or the troll?"))
    }

    // MARK: - Stub verbs and plugins

    /// Arthur and the troll reach the naming stubs' person line rather than
    /// its object line, and it renders their names by the same rule: the
    /// article is the engine's, chosen from `properName`.
    @Test func stubVerbsNameAProperNameBare() async throws {
        let transcript = try await play(
            NamedCastGame(), ["eat arthur", "eat troll", "pull lantern"])
        #expect(transcript.contains("Arthur is a person, and would rather you didn't."))
        #expect(transcript.contains("The troll is a person, and would rather you didn't."))
        #expect(transcript.contains("The brass lantern doesn't budge."))
        #expect(!transcript.contains("is not food"))
    }

    /// The conversation layer keeps its own lines, and the same rule applies —
    /// this is why Fulminate re-skinned `Conversation` as well as `GameText`.
    @Test func conversationLinesNameAProperNameBare() async throws {
        let transcript = try await play(
            NamedCastGame(), ["ask arthur about weather", "ask troll about weather"])
        #expect(transcript.contains("Arthur has nothing to say about that."))
        #expect(transcript.contains("The troll has nothing to say about that."))
    }

    // MARK: - Yourself

    /// The player is `properName` too, so a line reached with the player in
    /// the object slot can't say "the yourself". `X ME` and the four self
    /// lines answer ahead of it; this is the floor under them.
    @Test func thePlayerIsNeverArticled() async throws {
        let transcript = try await play(NamedCastGame(), ["x me", "take me", "eat me"])
        #expect(!transcript.contains("the yourself"))
        #expect(!transcript.contains("The yourself"))
    }

    // MARK: - The bootstrap warning

    /// Not inferred from the capital — declared. But an author who meant a
    /// proper name shouldn't have to find out from a transcript.
    @Test func aCapitalizedNameWithoutTheTraitWarns() throws {
        let (definition, _) = try Bootstrap.build(UndeclaredProperNameGame())
        #expect(definition.warnings.contains { $0.contains("Arthur") })
        #expect(definition.warnings.contains { $0.contains("Elvish sword") })
    }

    /// The two false positives the warning has to stay clear of: a room name,
    /// which the engine never articles, and a lower-case common noun.
    @Test func theWarningSkipsLocationsAndCommonNouns() throws {
        let (definition, _) = try Bootstrap.build(UndeclaredProperNameGame())
        #expect(!definition.warnings.contains { $0.contains("Orange Grove Avenue") })
        #expect(!definition.warnings.contains { $0.contains("brass lantern") })
    }

    @Test func declaringTheTraitSilencesTheWarning() throws {
        let (definition, _) = try Bootstrap.build(NamedCastGame())
        #expect(definition.warnings.isEmpty, "\(definition.warningReport ?? "no report")")
    }

    // MARK: - The helpers themselves

    @Test func theArticleHelpersRenderBothKinds() {
        #expect(GameText.definite("troll") == "the troll")
        #expect(GameText.definite("Mrs. Vane", proper: true) == "Mrs. Vane")
        #expect(GameText.indefinite("troll") == "a troll")
        #expect(GameText.indefinite("axe") == "an axe")
        #expect(GameText.indefinite("Mrs. Vane", proper: true) == "Mrs. Vane")
    }

    /// `sentenceCase` is what lets one template open on either kind: "the
    /// troll" has to be capitalized and "Mrs. Vane" must be left alone.
    @Test func sentenceCaseCapitalizesOnlyTheArticle() {
        #expect(GameText.sentenceCase("the troll") == "The troll")
        #expect(GameText.sentenceCase("Mrs. Vane") == "Mrs. Vane")
        #expect(GameText.sentenceCase("") == "")
    }

    /// `list` joins phrases the caller has already articled, so a listing can
    /// mix the two — which `indefiniteList`, articling bare names itself,
    /// could not.
    @Test func listJoinsAlreadyRenderedPhrases() {
        #expect(GameText.list([]) == "")
        #expect(GameText.list(["Excalibur"]) == "Excalibur")
        #expect(GameText.list(["Excalibur", "a coin"]) == "Excalibur and a coin")
        #expect(
            GameText.list(["Excalibur", "a coin", "an axe"])
                == "Excalibur, a coin, and an axe")
    }
}

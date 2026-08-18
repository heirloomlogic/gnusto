/// What a ``GameText/Line`` can be about.
///
/// A line's subject is a *type*, and this protocol closes the set of them:
/// ``GameText/Line``'s parameter is constrained to it, so a shape nobody has
/// classified does not compile. Before it, an unclassified shape compiled,
/// shipped, and failed a reflection sweep that had to be taught every new arm
/// by hand, in three files.
///
/// The one requirement is the sweep's, and that is the point rather than a
/// leak. `GnustoTestSupport` walks every stock line looking for one a game left
/// in the engine's voice, and it can only do that if it can *print* each line —
/// which means having something to hand it. A subject that cannot supply its
/// own examples cannot be swept, so the compiler says so where the subject is
/// written, rather than a runtime fallback saying it after the line has shipped
/// unchecked.
///
/// Two protocols refine it, on independent axes, and together they say how a
/// line about each subject may be *written*: ``DroppableSubject`` is a fixed
/// sentence, ``NamedSubject`` is a closure over the subject.
public protocol LineSubject: Sendable {
    /// Examples, enough to print every sentence a line about this subject can
    /// produce.
    ///
    /// Where the subject holds a ``GameText/Noun``, that means both numbers —
    /// a plural one is what catches a template that hard-codes its agreement,
    /// and ``GameText/Noun/samples`` is where the pair is spelled.
    static var samples: [Self] { get }
}

/// A subject a line is allowed to leave unsaid.
///
/// ``GameText/Line`` is `ExpressibleByStringLiteral` **only** where its subject
/// is one of these, and that conditional is the taxonomy's spine. A line about
/// a thing in the world may legitimately decline to name it —
/// `text.putItemIn = "Done."` prints no names and is still true, and
/// ``GameText/Holding`` says in as many words that a game may want exactly that.
/// A line whose entire content is what it was handed may not: `text.unknownWord
/// = "Eh?"` would drop the word the sentence exists to quote.
///
/// That rule used to be a paragraph of prose plus a label on a list in a test.
/// It is a conformance now: ``GameText/Word``, ``GameText/Prompt``,
/// ``GameText/Choices``, ``GameText/Banner`` and ``GameText/Score`` are
/// ``LineSubject``s and deliberately not `DroppableSubject`s.
public protocol DroppableSubject: LineSubject {}

/// A subject a line may be written as a closure over — `.naming { … }`.
///
/// The other axis, and almost every subject is on it. The two that are not have
/// a *better* spelling rather than none: ``GameText/Nothing`` has nothing to
/// hand a closure, so it takes ``GameText/Line/live(_:)``, and `Noun?` takes
/// ``GameText/Line/naming(orBare:_:)``, which asks for both halves so a game
/// cannot re-voice the naming half and leave the bare one in the engine's
/// words.
///
/// One conformance rather than one copied factory per subject: `naming` is
/// declared once, over this protocol, so subject number thirteen costs a token
/// on a conformance list instead of a pasted block.
public protocol NamedSubject: LineSubject {}

/// Any stock line, whatever it is about.
///
/// The marker exists so that "is this value one of the engine's lines?" is one
/// question with one answer. Asking it used to mean a disjunction of casts, one
/// arm per subject type, which had to be extended in lockstep with the subjects
/// — and a `Line` over a subject nobody added an arm for failed the sweep
/// rather than being classified by it.
public protocol StockLine: Sendable {
    /// Every sentence this line can print, rendered from its subject's own
    /// examples.
    var samples: [String] { get }
}

extension GameText {
    /// The subject of a line that has none.
    ///
    /// A nominal stand-in for `Void`, and not a bottom type despite the name:
    /// it has exactly one value, the way `()` does. It is nominal because
    /// `Void` is a tuple and Swift will not let a tuple conform to anything, so
    /// `Line<Void>` could be neither swept nor classified nor gated — the one
    /// shape most stock lines use would have had to sit outside every rule the
    /// others obey.
    public struct Nothing: DroppableSubject {
        /// The single value, since a line about nothing prints one sentence.
        public static var samples: [Self] { [Self()] }
    }

    /// One stock line, in whichever shape the game wants it: a fixed sentence,
    /// a sentence assembled when it prints, or one that names the thing it is
    /// about.
    ///
    /// ```swift
    /// text.stubs.dig = "You have nothing to dig with."
    /// text.stubs.burn = .naming { "You have no way to set fire to \($0)." }
    /// ```
    ///
    /// The type exists so that those two are the **same slot**. Before it,
    /// every line was declared as one or the other, and which one it got was
    /// the engine's own prose showing through the API: `dig` was a `String`
    /// because the engine's dig line happens to name nothing, so no game could
    /// write one that did without an engine change — and that change broke
    /// every game which had already assigned the old shape, whether it wanted
    /// the name or not. Widening a line is now the business of the game that
    /// wants it, and costs the games that don't nothing.
    ///
    /// `Object` says what the line is about. A line whose every parser row
    /// carries a direct object takes a ``GameText/Noun`` and is written with
    /// ``naming(_:)``. One that also answers a bare command — `smell`, `climb`,
    /// `wake` — takes `Noun?` and is written with ``naming(orBare:_:)``, which
    /// asks for both halves so neither can be left in the engine's voice by
    /// accident. A verb with no object slot at all takes ``Nothing``: there is
    /// no name to hand it, but there is still a *turn* to write it in, which is
    /// what ``live(_:)`` is for.
    ///
    /// Which subjects exist is ``LineSubject``; how a line about each may be
    /// *written* is the two protocols refining it — ``DroppableSubject`` for a
    /// fixed sentence, ``NamedSubject`` for a closure. All three are protocols
    /// rather than lists in a doc comment, because a list in a doc comment is a
    /// list somebody has to remember to edit.
    ///
    /// The shape is therefore about what the sentence is *given*, never about
    /// how it is *built*. Every one of them takes a string literal, so the
    /// fixed spelling of any line is the same three tokens whatever slot it
    /// sits in.
    ///
    /// The object arrives as a ``GameText/Noun`` and never as a bare string,
    /// for the reason `Noun` exists: it carries its own number, so "The rails
    /// is not food." — a game's honest plural made ungrammatical by a
    /// template's assumption — cannot be written. Interpolating one prints its
    /// phrase, so a line with no verb to agree reads exactly as it would have
    /// with a `String`.
    public struct Line<Object: LineSubject>: Sendable {
        private let body: @Sendable (Object) -> String

        /// The private door both `naming` factories come through, so that every
        /// public way to build a line is one a game should be using. A raw
        /// closure taking the object is not among them: the whole point of
        /// ``naming(orBare:_:)`` is that it will not let you write half a line.
        fileprivate init(_ body: @escaping @Sendable (Object) -> String) {
            self.body = body
        }

        /// Renders the line for one object. The engine calls this; a game
        /// assigns the line and never calls it.
        ///
        /// - Parameter object: what the line is about.
        /// - Returns: the sentence to print.
        public func callAsFunction(_ object: Object) -> String {
            body(object)
        }
    }
}

extension GameText.Line: StockLine {
    /// Every sentence this line can print, rendered from the subject's own
    /// examples.
    public var samples: [String] {
        Object.samples.map { self($0) }
    }
}

extension GameText.Line where Object: NamedSubject {
    /// A line that names what it is about.
    ///
    /// ```swift
    /// stubs.smash = .naming {
    ///     "\($0.sentenceCased) \($0.verb("is", "are")) made of sterner stuff."
    /// }
    /// text.putItemIn = .naming { "You tuck \($0.item) into \($0.holder)." }
    /// ```
    ///
    /// One factory over the protocol rather than one per subject. Where the
    /// subject is a ``GameText/Noun`` — alone or inside a role struct — it
    /// arrives as a *rendered noun phrase* ("the troll", "Mrs. Vane"): the
    /// article is the engine's, chosen from the `properName` trait, so a
    /// template that writes its own says "the Mrs. Vane". Open on
    /// ``GameText/Noun/sentenceCased`` rather than capitalizing by hand, and
    /// reach for ``GameText/Noun/verb(_:_:)`` wherever a verb has to agree.
    ///
    /// - Parameter line: builds the sentence from whatever the line is about.
    /// - Returns: the line.
    public static func naming(
        _ line: @escaping @Sendable (Object) -> String
    ) -> Self {
        .init(line)
    }
}

extension GameText.Line where Object: DroppableSubject {
    /// A fixed line held in a constant rather than written in place:
    /// `stubs.drink = .init(Prose.cantDrinkThat)`. A line written as a
    /// literal needs no initializer at all.
    ///
    /// It sits alongside the literal conformance rather than on the type,
    /// because it is the same facility spelled differently: a line that ignores
    /// what it was handed. A subject a line may not drop may not be dropped
    /// through this door either.
    ///
    /// - Parameter text: the sentence, whatever the line turns out to be
    ///   about.
    public init(_ text: String) {
        self.init { _ in text }
    }
}

extension GameText.Line: ExpressibleByUnicodeScalarLiteral,
    ExpressibleByExtendedGraphemeClusterLiteral, ExpressibleByStringLiteral,
    ExpressibleByStringInterpolation
where Object: DroppableSubject {
    /// A fixed line, written where it is read. Most lines in most games are
    /// this one, and the conformance is here so they pay no ceremony for a
    /// facility they never use.
    ///
    /// It is conditional on ``DroppableSubject`` because the facility is not
    /// harmless everywhere: a fixed sentence is a sentence that ignores what it
    /// was handed, which is a legitimate thing to want from a line about a
    /// thing in the world and never a legitimate thing to want from a line
    /// whose whole content is the word it was quoting.
    ///
    /// - Parameter text: the sentence.
    public init(stringLiteral text: String) {
        self.init(text)
    }

    /// The interpolated form, so a line assembled out of a game's own constants
    /// is written the way any other string is rather than failing on a protocol
    /// the author has never heard of.
    ///
    /// - Parameter stringInterpolation: the assembled sentence.
    public init(stringInterpolation: DefaultStringInterpolation) {
        self.init(String(stringInterpolation: stringInterpolation))
    }
}

extension GameText.Line where Object == GameText.Nothing {
    /// A line that is assembled when it prints rather than when it is written.
    ///
    /// ```swift
    /// text.pitchBlack = .live {
    ///     lantern.isOn ? "The dark presses in anyway." : "It is pitch black."
    /// }
    /// ```
    ///
    /// This is the liveness axis, and it is the same argument ``naming(_:)``
    /// makes about names. A line that says nothing about a particular thing is
    /// not thereby a line that says nothing about the *world*: `cantGoThatWay`
    /// could depend on which wall the player just walked into, and `timePasses`
    /// on what the player can hear while it does. Which of the engine's own
    /// lines happen to want that is the engine's business, and not a shape for
    /// it to press onto every game.
    ///
    /// - Parameter line: builds the sentence at the moment it prints. It is
    ///   handed nothing: whatever it consults, it reaches for itself.
    /// - Returns: the line.
    public static func live(_ line: @escaping @Sendable () -> String) -> Self {
        .init { _ in line() }
    }

    /// Renders the line. The engine calls this; a game assigns the line and
    /// never calls it.
    ///
    /// The no-argument spelling is here so that a line about nothing is *called*
    /// about nothing. Without it every read site would say
    /// `text.taken(.init())`, which is a generic parameter leaking into prose
    /// code that has no reason to know the shape exists.
    ///
    /// - Returns: the sentence to print.
    public func callAsFunction() -> String {
        self(GameText.Nothing())
    }
}

extension GameText.Noun: DroppableSubject, NamedSubject {
    /// The singular fixture every sweep renders with. Every subject that holds
    /// a noun builds its own samples out of this and ``samplePlural``, so the
    /// pair is spelled once for the whole taxonomy.
    public static let sampleSingular = Self("the brass lantern")

    /// The plural fixture — what catches a template that hard-codes its
    /// agreement, since "The rails is not food." is the defect ``GameText/Noun``
    /// exists to make unwritable.
    public static let samplePlural = Self("the rails", plural: true)

    /// Both numbers, so an agreement a template hard-codes is caught.
    public static var samples: [Self] { [sampleSingular, samplePlural] }
}

extension Optional: LineSubject, DroppableSubject where Wrapped == GameText.Noun {
    /// Both numbers and the bare case, so a game that re-voices the naming half
    /// and leaves the bare half in the engine's words is caught.
    public static var samples: [Self] { GameText.Noun.samples + [nil] }
}

extension GameText.Line where Object == GameText.Noun? {
    /// A line for a verb the player may use with an object or without one:
    /// `smell` and `smell the troll` are a single intent, and a single slot has
    /// to answer both.
    ///
    /// ```swift
    /// stubs.climb = .naming(orBare: "There's nothing here worth climbing.") {
    ///     "You can't climb onto \($0)."
    /// }
    /// ```
    ///
    /// Both halves are required, and asking for them separately is the point. A
    /// game that wrote only the naming half would leave the engine's narrator
    /// answering the bare command — the very defect a stub floor exists to
    /// close, one command deeper than the floor's author was looking. The bare
    /// half is a `String` rather than a second closure because it has no object
    /// to be about; there is nothing lost by saying so, and the alternative
    /// spelling — one closure over the optional, `$0.map { … } ?? …` — shadows
    /// `$0` with a second `$0` three tokens later.
    ///
    /// The player takes the bare half too. "It smells like yourself." is not a
    /// sentence, and where a line that always names its object defers to
    /// ``GameText/StubReplies/yourself``, a line that owns a nameless half
    /// already has the better answer.
    ///
    /// - Parameters:
    ///   - bare: the sentence for a command that named nothing.
    ///   - line: builds the sentence when the player did name something.
    /// - Returns: the line.
    public static func naming(
        orBare bare: String,
        _ line: @escaping @Sendable (GameText.Noun) -> String
    ) -> Self {
        .init { $0.map(line) ?? bare }
    }
}

// MARK: - Lines about two things

extension GameText {
    /// A thing and what holds it: what the player put down, and the box, the
    /// table or the hamper it went into.
    ///
    /// A ``Line`` is about *one* object, and a sentence about two needs some way
    /// to say which is which. The roles are a type rather than a pair, because
    /// the pair spelling — a tuple, `$0` and `$1` — leaves the API unable to
    /// answer the only question an author actually asks at the call site: which
    /// one is the container? `\($0.holder)` answers it; `\($1)` does not.
    ///
    /// One struct serves every line whose two things stand in this relation,
    /// rather than one apiece — which is also what lets `RoomDescriber` keep
    /// handing ``GameText/itemOnSurface`` and ``GameText/itemInContainer`` to
    /// one helper as a value. Another such line should cost no edit here.
    ///
    /// A `Line` over one of these is `ExpressibleByStringLiteral`, so a
    /// two-object line will take a fixed sentence — `text.putItemIn = "Done."`
    /// — and print it without either name. For these that is a legitimate thing
    /// for a game to want, and the sentence it prints is still true. It is not
    /// legitimate for a line whose whole content is the thing it was handed,
    /// which is why these are ``DroppableSubject``s and ``GameText/Word`` and
    /// its neighbours are not.
    ///
    /// ```swift
    /// text.putItemIn = .naming { "You tuck \($0.item) into \($0.holder)." }
    /// ```
    ///
    /// Both arrive as ``Noun`` for the reason one does — and for a second reason
    /// a one-object line never has. A sentence about two things has two things
    /// its verb might agree with, and it is rarely the one the sentence names
    /// first: ``GameText/itemOnSurface`` reads "On the table are the rails",
    /// where the verb agrees with the rails and the template names the table.
    /// While these were a pair of strings there was no way to write that
    /// sentence at all.
    public struct Holding: DroppableSubject, NamedSubject {
        /// What was placed, or what is being listed. Several things joined by
        /// ``GameText/Noun/list(_:)`` arrive here as one, so a line about a
        /// container and everything in it uses this slot like any other — and
        /// `\($0.item.verb("is", "are"))` agrees with the whole list.
        public let item: Noun
        /// What holds it — the container, or the surface it rests on.
        public let holder: Noun

        /// Both arrangements, because a line about two things has two things
        /// its verb might agree with and the wording rarely agrees with the one
        /// it names first. One order would let a template that hard-codes the
        /// *other* agreement through.
        public static var samples: [Self] {
            [
                .init(item: Noun.sampleSingular, holder: Noun.samplePlural),
                .init(item: Noun.samplePlural, holder: Noun.sampleSingular),
            ]
        }
    }

    /// Everything the player is carrying, and which of it is being worn.
    ///
    /// The odd one out among the role structs, and the reason is the worn flag.
    /// The other lines about several things take them as one ``Noun/list(_:)``
    /// and never look at the parts; this line has something to say about each
    /// part, so it cannot join them before the game has had its say. A game that
    /// wants "wearing" rather than "(being worn)", or wants the worn things last,
    /// needs them still separable — and that is exactly what a bare `[Noun]`
    /// would have thrown away.
    ///
    /// ```swift
    /// text.inventorySentence = .naming {
    ///     "You have " + GameText.list($0.entries.map {
    ///         $0.isWorn ? "\($0.noun), worn" : "\($0.noun)"
    ///     }) + "."
    /// }
    /// ```
    public struct Carried: DroppableSubject, NamedSubject {
        /// One thing in hand.
        public struct Entry: Sendable {
            /// What it is.
            public let noun: Noun
            /// Whether the player is wearing it rather than holding it.
            public let isWorn: Bool
        }

        /// What the player is carrying, in the order the listing should read.
        /// Never empty — ``GameText/emptyHanded`` answers that case instead.
        public let entries: [Entry]

        /// One hand holding both numbers, one of them worn, so a template that
        /// hard-codes either the agreement or the worn note is caught.
        public static var samples: [Self] {
            [
                .init(entries: [
                    .init(noun: Noun.sampleSingular, isWorn: false),
                    .init(noun: Noun.samplePlural, isWorn: true),
                ])
            ]
        }
    }

    /// Something offered, and whoever is being offered it.
    ///
    /// ```swift
    /// stubs.give = .naming {
    ///     "\($0.recipient.sentenceCased) \($0.recipient.verb("doesn't", "don't")) want \($0.gift)."
    /// }
    /// ```
    public struct Gift: DroppableSubject, NamedSubject {
        /// What is being handed over.
        public let gift: Noun
        /// Who is being handed it.
        public let recipient: Noun

        /// Both arrangements, for the reason ``Holding/samples`` gives.
        public static var samples: [Self] {
            [
                .init(gift: Noun.sampleSingular, recipient: Noun.samplePlural),
                .init(gift: Noun.samplePlural, recipient: Noun.sampleSingular),
            ]
        }
    }

    /// A place, and the thing the player is riding through it.
    ///
    /// The odd one out, and the asymmetry is the point: ``place`` is a plain
    /// `String` and deliberately not a ``Noun``. A `Noun`'s whole promise is
    /// that it knows its own number, and a location has none to know — the
    /// engine never articles a location, `Location` carries no `plural` trait,
    /// and `TurnFrame.isPlural(_:)` answers for items only. Wrapping a room
    /// title in a `Noun` would hand every game a ``Noun/verb(_:_:)`` that
    /// silently answers "is" for a room called The Rails: the very defect
    /// `Noun` exists to make unwritable, running backwards. A title is a title;
    /// the thing beside it is a noun.
    ///
    /// ```swift
    /// text.locationInVehicle = .naming { "\($0.place), aboard \($0.vehicle)" }
    /// ```
    public struct Aboard: DroppableSubject, NamedSubject {
        /// The location's own name, unarticled.
        public let place: String
        /// What the player is aboard.
        public let vehicle: Noun

        /// A ride in both numbers.
        public static var samples: [Self] {
            Noun.samples.map { .init(place: "Rail Yard", vehicle: $0) }
        }
    }
}

extension GameText.Line where Object == GameText.Holding {
    /// Renders the line for a thing and its holder.
    ///
    /// The engine calls this; a game assigns the line and never calls it. It
    /// takes the two separately, rather than leaving callers to build a
    /// ``GameText/Holding``, so that a call site reads the way it read when
    /// these lines were two-argument closures.
    ///
    /// - Parameters:
    ///   - item: what was placed, or what is being listed.
    ///   - holder: what holds it.
    /// - Returns: the sentence to print.
    public func callAsFunction(_ item: GameText.Noun, _ holder: GameText.Noun) -> String {
        self(.init(item: item, holder: holder))
    }
}

extension GameText.Line where Object == GameText.Carried {
    /// Renders the line. See ``GameText/Line/callAsFunction(_:_:)-(Noun,Noun)``
    /// for why it takes the parts rather than the role struct.
    ///
    /// - Parameter entries: what the player is carrying, in listing order.
    /// - Returns: the sentence to print.
    public func callAsFunction(_ entries: [GameText.Carried.Entry]) -> String {
        self(.init(entries: entries))
    }
}

extension GameText.Line where Object == GameText.Gift {
    /// Renders the line. See ``GameText/Line/callAsFunction(_:_:)-(Noun,Noun)``
    /// for why it takes the two separately.
    ///
    /// - Parameters:
    ///   - gift: what is being handed over.
    ///   - recipient: who is being handed it.
    /// - Returns: the sentence to print.
    public func callAsFunction(_ gift: GameText.Noun, _ recipient: GameText.Noun) -> String {
        self(.init(gift: gift, recipient: recipient))
    }
}

extension GameText.Line where Object == GameText.Aboard {
    /// Renders the line.
    ///
    /// - Parameters:
    ///   - place: the location's own name, unarticled.
    ///   - vehicle: what the player is aboard.
    /// - Returns: the sentence to print.
    public func callAsFunction(_ place: String, _ vehicle: GameText.Noun) -> String {
        self(.init(place: place, vehicle: vehicle))
    }
}

// MARK: - Lines about what is not in the world

extension GameText {
    /// A fragment of what the player typed, quoted back at them.
    ///
    /// ```swift
    /// text.unknownWord = .naming { "There is no \"\($0)\" in this house." }
    /// ```
    ///
    /// The first of the subjects that are ``LineSubject``s and deliberately not
    /// ``DroppableSubject``s. `text.unknownWord = "Eh?"` parses as English and
    /// throws away the only thing the sentence was for; the type is what stops
    /// it, so ``GameText/unknownWord`` is written with `naming` or not at all.
    ///
    /// Being undroppable used to mean being a raw closure — outside the sweep,
    /// outside the taxonomy, and named in a hand-kept list in a test file. It is
    /// one missing conformance now.
    public struct Word: NamedSubject, CustomStringConvertible {
        /// The fragment being quoted: the word the player typed, or the verb
        /// phrase the parser matched it to.
        public let word: String

        /// The word itself, so a template interpolates `\($0)` and not
        /// `\($0.word)`.
        public var description: String { word }

        /// One word. There is no second case: the line either quotes what it
        /// was handed or it does not, and a plural noun proves nothing about a
        /// word with no number.
        public static var samples: [Self] { [.init(word: "frotz")] }
    }

    /// A verb the parser understood, and the part of the sentence it still
    /// wants.
    ///
    /// One struct for the whole `missing…` family, on the same grounds
    /// ``Holding`` is one struct for every line about a thing and its holder:
    /// they stand in one relation, and another prompt should cost no edit here.
    /// The parts are plain `String`s rather than ``Noun``s because they are read
    /// off ``Vocabulary`` before anything has been resolved — there is no entity
    /// yet to have a number.
    ///
    /// ```swift
    /// text.missingObject = .naming { "What would you like to \($0.verb)?" }
    /// ```
    public struct Prompt: NamedSubject {
        /// The verb phrase, as the pattern spells it: "take", "pick up".
        public let verb: String
        /// What the player did name, or `nil` where the row's object slot is
        /// itself optional and they named nothing.
        public let object: String?
        /// The word introducing the missing part — "in", "about" — or empty
        /// where the row has none.
        public let preposition: String

        /// The bare prompt, the one with an object, and the one with both — so
        /// a template that assumes either part is present is caught.
        public static var samples: [Self] {
            [
                .init(verb: "take", object: nil, preposition: ""),
                .init(verb: "put", object: "the coin", preposition: ""),
                .init(verb: "ask", object: "the troll", preposition: "about"),
            ]
        }
    }

    /// The things one noun phrase turned out to match.
    ///
    /// A list of *words*, not of things: the parser writes this line before it
    /// has resolved anything, so the names are what the vocabulary spells rather
    /// than rendered noun phrases. That is why it is not
    /// ``Noun/list(_:)`` — there is no number to carry and nothing to agree.
    ///
    /// ```swift
    /// text.ambiguous = .naming {
    ///     "Which do you mean: \($0.names.joined(separator: ", or "))?"
    /// }
    /// ```
    public struct Choices: NamedSubject {
        /// The names to offer, in the order to offer them.
        public let names: [String]

        /// A two-way choice. Every ambiguity the parser raises has at least
        /// two, and a template that joins them cannot tell three from two.
        public static var samples: [Self] {
            [.init(names: Noun.samples.map(\.phrase))]
        }
    }

    /// The game's own name, and the line under it.
    ///
    /// ```swift
    /// text.banner = .naming { "\($0.title) — \($0.tagline)" }
    /// ```
    public struct Banner: NamedSubject {
        /// The game's title.
        public let title: String
        /// The subtitle, or empty where the game declared none.
        public let tagline: String

        /// A banner with a tagline and one without, so a template that always
        /// writes the separator prints a dangling one here.
        public static var samples: [Self] {
            [
                .init(title: "Zork", tagline: "The Great Underground Empire"),
                .init(title: "Zork", tagline: ""),
            ]
        }
    }

    /// Where the player stands in a game that keeps score.
    ///
    /// ```swift
    /// text.scoreLine = .naming { "\($0.score) points, \($0.moves) turns." }
    /// ```
    public struct Score: NamedSubject {
        /// Points earned so far.
        public let score: Int
        /// The most the game can award, or zero where it declares no maximum.
        public let maxScore: Int
        /// Turns taken.
        public let moves: Int

        /// A scored game on turn one and an unscored one later, so a template
        /// that hard-codes either "turn" or "of a possible" is caught.
        public static var samples: [Self] {
            [
                .init(score: 0, maxScore: 350, moves: 1),
                .init(score: 7, maxScore: 0, moves: 12),
            ]
        }
    }
}

extension GameText.Line where Object == GameText.Word {
    /// Renders the line for one word.
    ///
    /// - Parameter word: what the player typed.
    /// - Returns: the sentence to print.
    public func callAsFunction(_ word: String) -> String {
        self(.init(word: word))
    }
}

extension GameText.Line where Object == GameText.Prompt {
    /// Renders the prompt. The defaults are what makes one call site serve all
    /// four `missing…` lines: a verb alone, a verb and its object, or both plus
    /// the word introducing the part still missing.
    ///
    /// - Parameters:
    ///   - verb: the verb phrase.
    ///   - object: what the player named, or `nil` where they named nothing.
    ///   - preposition: the word introducing the missing part, or empty where
    ///     the row has none.
    /// - Returns: the sentence to print.
    public func callAsFunction(
        _ verb: String, _ object: String? = nil, _ preposition: String = ""
    ) -> String {
        self(.init(verb: verb, object: object, preposition: preposition))
    }
}

extension GameText.Line where Object == GameText.Choices {
    /// Renders the line for a set of candidates.
    ///
    /// - Parameter names: the names to offer.
    /// - Returns: the sentence to print.
    public func callAsFunction(_ names: [String]) -> String {
        self(.init(names: names))
    }
}

extension GameText.Line where Object == GameText.Banner {
    /// Renders the banner.
    ///
    /// - Parameters:
    ///   - title: the game's title.
    ///   - tagline: the subtitle, or empty.
    /// - Returns: the sentence to print.
    public func callAsFunction(_ title: String, _ tagline: String) -> String {
        self(.init(title: title, tagline: tagline))
    }
}

extension GameText.Line where Object == GameText.Score {
    /// Renders the report.
    ///
    /// - Parameters:
    ///   - score: points earned.
    ///   - maxScore: the most the game awards, or zero.
    ///   - moves: turns taken.
    /// - Returns: the sentence to print.
    public func callAsFunction(_ score: Int, _ maxScore: Int, _ moves: Int) -> String {
        self(.init(score: score, maxScore: maxScore, moves: moves))
    }
}

extension GameText {
    /// One stock line, in whichever of its two shapes the game wants it: a
    /// fixed sentence, or a sentence that names the thing it is about.
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
    /// `Object` says whether the line is *always* about something. A line whose
    /// every parser row carries a direct object takes a ``GameText/Noun`` and
    /// is written with ``naming(_:)``. One that also answers a bare command —
    /// `smell`, `climb`, `wake` — takes `Noun?` and is written with
    /// ``naming(orBare:_:)``, which asks for both halves so neither can be
    /// left in the engine's voice by accident. A verb with no object slot at
    /// all is not a `Line`; it is a plain `String`, because there is nothing
    /// for a closure to be handed, and a slot that offers one is an invitation
    /// to write prose that can never print.
    ///
    /// The object arrives as a ``GameText/Noun`` and never as a bare string,
    /// for the reason `Noun` exists: it carries its own number, so "The rails
    /// is not food." — a game's honest plural made ungrammatical by a
    /// template's assumption — cannot be written. Interpolating one prints its
    /// phrase, so a line with no verb to agree reads exactly as it would have
    /// with a `String`.
    public struct Line<Object: Sendable>: Sendable {
        private let body: @Sendable (Object) -> String

        /// A fixed line held in a constant rather than written in place:
        /// `stubs.drink = .init(Prose.cantDrinkThat)`. A line written as a
        /// literal needs no initializer at all.
        ///
        /// - Parameter text: the sentence, whatever the line turns out to be
        ///   about.
        public init(_ text: String) {
            body = { _ in text }
        }

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

extension GameText.Line: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    /// A fixed line, written where it is read. Most lines in most games are
    /// this one, and the conformance is here so they pay no ceremony for a
    /// facility they never use.
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

extension GameText.Line where Object == GameText.Noun {
    /// A line that names what it is about. Every parser row behind one of these
    /// carries a direct object, so there is always a name to give.
    ///
    /// ```swift
    /// stubs.smash = .naming {
    ///     "\($0.sentenceCased) \($0.verb("is", "are")) made of sterner stuff."
    /// }
    /// ```
    ///
    /// - Parameter line: builds the sentence from the object's rendered noun
    ///   phrase — "the troll", "Mrs. Vane". The article is the engine's, chosen
    ///   from the `properName` trait, so a line that writes its own says "the
    ///   Mrs. Vane"; open on ``GameText/Noun/sentenceCased`` rather than
    ///   capitalizing by hand, for the same reason.
    /// - Returns: the line.
    public static func naming(
        _ line: @escaping @Sendable (GameText.Noun) -> String
    ) -> Self {
        .init(line)
    }
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
    /// One struct serves all four placement lines rather than one apiece,
    /// because their roles really are the same two. That is also what lets
    /// `RoomDescriber` keep handing ``GameText/itemOnSurface`` and
    /// ``GameText/itemInContainer`` to one helper as a value.
    public struct Placement: Sendable {
        /// What was placed, or what is being listed.
        public let item: Noun
        /// What holds it — the container, or the surface it rests on.
        public let holder: Noun

        /// Creates a placement.
        ///
        /// - Parameters:
        ///   - item: what was placed.
        ///   - holder: what holds it.
        public init(item: Noun, holder: Noun) {
            self.item = item
            self.holder = holder
        }
    }

    /// Something offered, and whoever is being offered it.
    public struct Gift: Sendable {
        /// What is being handed over.
        public let gift: Noun
        /// Who is being handed it.
        public let recipient: Noun

        /// Creates a gift.
        ///
        /// - Parameters:
        ///   - gift: what is being handed over.
        ///   - recipient: who is being handed it.
        public init(gift: Noun, recipient: Noun) {
            self.gift = gift
            self.recipient = recipient
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
    public struct Aboard: Sendable {
        /// The location's own name, unarticled.
        public let place: String
        /// What the player is aboard.
        public let vehicle: Noun

        /// Creates a place-and-vehicle pair.
        ///
        /// - Parameters:
        ///   - place: the location's own name.
        ///   - vehicle: what the player is aboard.
        public init(place: String, vehicle: Noun) {
            self.place = place
            self.vehicle = vehicle
        }
    }
}

extension GameText.Line where Object == GameText.Placement {
    /// A line about a thing and what holds it, naming both.
    ///
    /// ```swift
    /// text.putItemIn = .naming { "You tuck \($0.item) into \($0.holder)." }
    /// ```
    ///
    /// Both arrive as ``GameText/Noun`` for the reason one does — and for a
    /// second reason a one-object line never has. A sentence about two things
    /// has two things its verb might agree with, and it is rarely the one the
    /// sentence names first: ``GameText/itemOnSurface`` reads "On the table are
    /// the rails", where the verb agrees with the rails and the template names
    /// the table. While these were a pair of strings there was no way to write
    /// that sentence at all.
    ///
    /// - Parameter line: builds the sentence from the two rendered nouns.
    /// - Returns: the line.
    public static func naming(
        _ line: @escaping @Sendable (GameText.Placement) -> String
    ) -> Self {
        .init(line)
    }

    /// Renders the line for a thing and its holder.
    ///
    /// The engine calls this; a game assigns the line and never calls it. It
    /// takes the two separately, rather than leaving callers to build a
    /// ``GameText/Placement``, so that a call site reads the way it read when
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

extension GameText.Line where Object == GameText.Gift {
    /// A line about something offered and whoever is being offered it.
    ///
    /// ```swift
    /// stubs.give = .naming {
    ///     "\($0.recipient.sentenceCased) \($0.recipient.verb("doesn't", "don't")) want \($0.gift)."
    /// }
    /// ```
    ///
    /// - Parameter line: builds the sentence from the gift and the recipient.
    /// - Returns: the line.
    public static func naming(
        _ line: @escaping @Sendable (GameText.Gift) -> String
    ) -> Self {
        .init(line)
    }

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
    /// A line about where the player is and what they are riding.
    ///
    /// ```swift
    /// text.locationInVehicle = .naming { "\($0.place), aboard \($0.vehicle)" }
    /// ```
    ///
    /// - Parameter line: builds the sentence from the place and the vehicle.
    /// - Returns: the line.
    public static func naming(
        _ line: @escaping @Sendable (GameText.Aboard) -> String
    ) -> Self {
        .init(line)
    }

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

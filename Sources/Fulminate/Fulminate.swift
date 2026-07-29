import Gnusto
import GnustoClock
import GnustoConversation

extension Intent {
    /// Put a name in the record: `accuse mrs. vane`. There is no taking it
    /// back — an accusation you can take back costs nothing, and a clock you
    /// can outlast is scenery.
    #verb("accuse", ["accuse", .directObject])
}

/// What the player has worked out, in the order the case wants it worked out:
/// the cook's testimony kills the alibi, the receipt breaks the boarder, the
/// boarder gives up the lie he told the mother, and the glove breaks her.
/// The ledger and the letters retire the two lurid explanations on the way.
extension Fact {
    /// Mrs. Kettle saw Teague come through her kitchen — the drugstore alibi
    /// is dead.
    static let kettleSawTeague = Fact("kettleSawTeague")
    /// The receipt is stamped 6:05: he went to the drugstore *after*, to buy
    /// the alibi, and he has admitted it.
    static let teagueRecanted = Fact("teagueRecanted")
    /// The keystone: Teague told Constance her son had gone out. Knowing this
    /// is what separates the full ending from the partial one.
    static let teagueLied = Fact("teagueLied")
    /// The ledger's last four pages: notebooks were going up the arroyo a few
    /// pages at a time.
    static let notebooksSold = Fact("notebooksSold")
    /// The glove has been shown to Constance, and she has stopped trying.
    static let constanceBroke = Fact("constanceBroke")
    /// The letters have been read in front of Delphine; the red herring dies.
    static let delphineCleared = Fact("delphineCleared")
}

/// A one-evening mystery on a wall clock: a rocketry man dies in his own
/// carriage house at 5:46, the county coroner is due at 6:50, and what he
/// writes down is what happened.
///
/// This is the demo game for the engine's mystery-genre work (issue #40). It
/// proves the parts an exploration adventure never needed — a time-of-day
/// clock, NPCs who keep a timetable, and conversation about abstract subjects
/// — by making each of them load-bearing rather than decorative. The story
/// and its mechanics contract live in `docs/games/fulminate.md`; read that
/// before rewriting any of the prose here, since several beats are carrying a
/// tested engine behavior.
///
/// The evening is complete: the house, the clock, five suspects on their
/// rounds, the interrogation, the evidence chain, and an accusation that ends
/// the game one of three ways.
///
/// Original: Julian Vane is fictional. The setting borrows the shape of a real
/// 1952 Pasadena explosion; the crime, the household, and every person in it
/// are invented, and no accusation here is made of anyone who lived. Every
/// character is a type of the period, never a portrait of a person.
@main
struct Fulminate: Game, GameMain {
    let title = "Fulminate"
    let tagline = "Pasadena, June 1952."
    let intro = """
        The letter said somebody had been in his lab and nothing had been taken, and that the second part was what \
        worried him. It was signed with a fountain pen that had been going dry.

        The streetcar puts you on Orange Grove at half past five. Millionaire's Row, they used to call it, back when \
        the money was still here. The house is the fourth one down, and it was somebody's idea of a palace once.

        Mrs. Vane lets you in without asking who you are, which tells you something about the number of people who \
        come to this door.
        """

    /// Two minutes a turn, from half past five. Every alibi in this house is
    /// stated as a time, so the clock is not scenery — it is the instrument
    /// the case is measured with.
    let clock = Clock(
        startingAt: TimeOfDay(17, 30),
        minutesPerTurn: 2,
        timeIs: { "Your watch says \($0)." }
    )

    /// The interrogation layer. Its defaults prefix names with "The", which
    /// suits a butler and not a household of proper names.
    let talk = Conversation(
        nothingToSay: { "\($0) has nothing to say about that." },
        noInterest: { "\($0) looks at it and looks away." }
    )

    /// Whether the carriage house has gone up. Rooms and props read this to
    /// describe themselves on the right side of the evening.
    @Global var blastHappened = false

    /// Whether Teague is back from the drugstore. The receipt is in his coat
    /// pocket only after he has been out and bought the thing — searching the
    /// coat before ten past six turns up an empty pocket, which is the honest
    /// answer and also the more interesting one.
    @Global var teagueIsBack = false

    /// Whether the cellar has told the player once where the light lives.
    @Global var cellarHintGiven = false

    /// Whether the patrolman has the wreckage. Both gates that enforce it — the
    /// way in from the yard, and turning the debris over — read this rather than
    /// asking where he is standing, which is how the rest of the engine's demo
    /// games write a creature blocking a way (Zork's troll and cyclops gate on
    /// `trollDefeated` and `cyclopsSubdued`, not on their own placement).
    @Global var wreckageSealed = false

    /// Whether the player was standing in the yard when it went up. The
    /// aftermath lands a turn later, by which time they may have walked
    /// somewhere else — and "there is grass in your cuff" has to be about
    /// where they were knocked down, not where they are now.
    @Global var wasInTheYardForTheBlast = false

    /// Whether Delphine has declined a question in front of you yet.
    ///
    /// Deliberately not a `Fact`. Facts are what the player has worked out, and
    /// the six of them are the case; this only records that a line has been said
    /// out loud. Its two siblings — which tracked whether Constance and Delphine
    /// had had their one moment about Julian — retired when topic rows gained
    /// `again:`, which does the same job in the table.
    @Global var delphineHasDeflected = false

    /// The stock lines assume common nouns — "the Mrs. Vane is right here" —
    /// which suits a lantern and not a household of proper names. Same reason
    /// the `Conversation` above is re-skinned.
    var text: GameText {
        var text = GameText()
        text.following = { "(after \($0))" }
        text.alreadyFollowing = { "\($0) is right here." }
        text.cantFollowThat = { "The \($0) isn't going anywhere." }
        text.lostThem = { "You have no idea which way \($0) went." }
        text.greets = { "\($0) looks at you and does not answer." }
        text.cantGreetThat = { "The \($0) is unlikely to answer." }
        text.notTakingOrders = { "\($0) hears you out and goes on doing exactly what \($0) was doing." }
        // Three of them answer to "man" and three to "woman", so this line
        // gets read more often than you would think.
        text.ambiguous = { "Which do you mean: \($0.joined(separator: ", or "))?" }
        return text
    }

    /// Both ways out of the front hall refuse in the same words. A `static`
    /// rather than a stored property so the bootstrap's reflection walk, which
    /// looks for entities, doesn't have to step over it.
    private static let streetRefusal = """
        You came out here on a Tuesday because a man wrote you a letter. Walking back down the path now would make \
        that the last thing you ever did for him.
        """

    // MARK: - Rooms

    let frontHall = Location {
        name("Front Hall")
        description(
            """
            Black and white tile, worn through to the grout along the line people walk. A hat stand with one coat on \
            it, a half-moon table with the telephone, and a longcase clock in the corner that keeps better time than \
            the household does. The front door is east, the parlour west, the kitchen passage south, and the stairs \
            go up.
            """)
    }

    let parlour = Location {
        name("Parlour")
        description(
            """
            Furniture too big for the room and too good to sell, arranged around a cold grate. The lamp is not lit. \
            Mrs. Vane does not light it until it is properly dark, and her opinion of when that is differs from \
            everyone else's.
            """)
    }

    let kitchen = Location {
        name("Kitchen")
        description(
            """
            Scrubbed pine and a stove that has been going since before you got here. The back stairs come down at \
            the far end, which means anyone who uses them comes through here whether they meant to or not. There is a \
            drawer under the counter. The hall is north, the yard door west, and the cellar steps go down.
            """)
    }

    /// Unlit on purpose. It is where the case's least convenient piece of
    /// evidence ends up, and it is the room that proves an NPC crossing a dark
    /// room does it in silence.
    let cellar = Location {
        name("Cellar")
        description("Cold, and low enough that you walk it at a stoop. It smells like a cellar.")
        dark
    }

    let backYard = Location {
        name("Back Yard")
    }

    let carriageHouse = Location {
        name("Carriage House")
    }

    let landing = Location {
        name("Upstairs Landing")
        description("A runner going bald down the middle. The study is west, the boarder's room east.")
    }

    let study = Location {
        name("Vane's Study")
        description(
            """
            A desk with a green shade over the lamp, and every drawer standing open. Not ransacked. Searched by \
            somebody who fully intended to put it all back.
            """)
    }

    let boardersRoom = Location {
        name("Boarder's Room")
        description(
            """
            A typewriter with a sheet still in it, and a suitcase on the bed packed for a longer trip than anybody \
            has mentioned.
            """)
    }

    /// Off the map: no exit leads here and the player never sees it. It is
    /// where Teague is between a quarter to six and ten past, which is the
    /// point — there are questions you can only put to him inside a window.
    let street = Location {
        name("Orange Grove Avenue")
        description("Not a place you get to tonight.")
    }

    // MARK: - What you brought

    /// The `TIME` verb has been reading this since the first turn; it was
    /// simply not in the world. Worn rather than carried, and it stays worn —
    /// the clock is the instrument this case is measured with, and the player
    /// should not be able to put it down.
    ///
    /// Deliberately no `clock` synonym: `examine clock` in the hall has to go
    /// on meaning the longcase clock.
    let watch = Item {
        name("wristwatch")
        adjectives("wrist", "steel", "own")
        synonyms("watch", "wristwatch", "timepiece")
        wearable
    }

    // MARK: - The hall

    /// The house's timepiece. The player has a watch, but the clock is what
    /// everyone in this house means when they say a time — so it is the thing
    /// to examine when an account needs checking.
    let hallClock = Item {
        name("longcase clock")
        adjectives("longcase", "hall", "grandfather", "tall")
        synonyms("clock", "case")
        scenery
    }

    let telephone = Item {
        name("telephone")
        adjectives("black")
        synonyms("phone", "receiver")
        description("A black telephone on a half-moon table, with a pad beside it and nothing written on the pad.")
        scenery
    }

    let coat = Item {
        name("overcoat")
        adjectives("grey", "gray")
        // "pockets" because both refusals below point the player at them, and
        // a game that names a thing twice and then doesn't know the word for
        // it reads like a bug.
        synonyms("coat", "overcoat", "pocket", "pockets")
        description(
            """
            A grey overcoat on the hat stand, good once and not lately. It is nobody's idea of June wear, which is \
            presumably why it is still hanging here.
            """)
        container
    }

    /// Time-stamped 6:05. In this slice it is only a slip of paper; it becomes
    /// the case's hinge once there is somebody to put it in front of. Hidden
    /// until the coat is searched — a receipt you are handed on arrival is not
    /// evidence, it is a signpost.
    let receipt = Item {
        name("drugstore receipt")
        adjectives("drugstore", "paper", "small")
        synonyms("receipt", "slip", "ticket")
        description(
            """
            A register slip from the drugstore on Colorado. One Coca-Cola, five cents, and the time printed along \
            the bottom in that smeared purple ink they all use: 6:05.
            """)
        hidden
    }

    /// The nouns the hall's description puts on the page. A room that names a
    /// thing and then doesn't know the word for it reads like a bug, and the
    /// first thing a play-tester typed in this house was `X TILE`.
    let hallFloor = Item {
        name("tiled floor")
        adjectives("black", "white", "tiled", "checked", "hall")
        synonyms("tile", "tiles", "tiling", "floor", "grout")
        description(
            """
            Black and white, laid in a diamond, and worn through to the grout along the exact line between the front \
            door and the stairs. Nobody in this house has gone left or right in years.
            """)
        scenery
    }

    let hatStand = Item {
        name("hat stand")
        adjectives("hat", "oak", "bentwood")
        synonyms("stand", "hatstand", "rack", "hooks")
        description(
            """
            Oak, with six hooks and one coat on it. A house that rents its rooms puts up a stand this size and then \
            uses one hook of it.
            """)
        scenery
    }

    let hallTable = Item {
        name("half-moon table")
        adjectives("half", "moon", "marble", "telephone", "hall")
        synonyms("table")
        description(
            """
            Three legs and a marble top, and a ring in the marble where something round used to stand and doesn't now.
            """)
        scenery
    }

    let frontDoor = Item {
        name("front door")
        adjectives("front", "heavy", "panelled")
        synonyms("door", "doorway")
        description(
            """
            Heavy, panelled, with a fanlight over it that somebody painted shut a long while ago. It is the way you \
            came in.
            """)
        scenery
    }

    let frontStairs = Item {
        name("staircase")
        adjectives("front", "main", "bare")
        synonyms("stairs", "staircase", "stair", "banister")
        description(
            """
            Bare treads with the carpet rods still in them and no carpet in the rods. These are the ones a visitor \
            uses.
            """)
        scenery
    }

    // MARK: - The parlour

    let parlourFurniture = Item {
        name("furniture")
        adjectives("heavy", "good", "victorian")
        synonyms("furniture", "chair", "chairs", "armchair", "sofa", "settee", "suite")
        description(
            """
            Heavy pieces that came out of a bigger house than this one, too good to sell in 1931 and too good to sell \
            now. Mrs. Vane's chair is the only one that has taken the shape of a person.
            """)
        scenery
    }

    let grate = Item {
        name("grate")
        adjectives("cold", "iron", "empty")
        synonyms("grate", "fireplace", "hearth", "fender", "fire")
        description(
            """
            Swept, laid, and cold. Nothing has been burned in this room in months, in a house where the kitchen stove \
            has been going since before you got here.
            """)
        scenery
    }

    let parlourLamp = Item {
        name("standard lamp")
        adjectives("standard", "unlit", "fringed", "tall")
        synonyms("lamp", "shade")
        description(
            """
            A standard lamp with a fringed shade and a bulb that has been in it a while. Mrs. Vane does not light it \
            until it is properly dark. It is not properly dark.
            """)
        scenery
    }

    /// Constance's fallback line looks at this. A fallback that names a thing
    /// the game can't show you is the same defect as an unknown word.
    let wallpaper = Item {
        name("wallpaper")
        adjectives("faded", "papered")
        synonyms("wallpaper", "roses")
        description(
            """
            Cabbage roses gone the colour of tea, and one rectangle of them a shade lighter than the rest, where \
            something used to hang.
            """)
        scenery
    }

    // MARK: - The kitchen and the cellar

    let stove = Item {
        name("stove")
        adjectives("iron", "black")
        synonyms("stove", "range")
        description("Cast iron, lit, and putting out more heat than the evening asked for.")
        scenery
    }

    let drawer = Item {
        name("kitchen drawer")
        adjectives("kitchen", "counter")
        synonyms("drawer")
        description("The drawer under the counter, where a house keeps the things it needs twice a year.")
        scenery
        container
        openable
    }

    let flashlight = Item {
        name("flashlight")
        adjectives("dented", "tin")
        // Not "lamp": the parlour, the study and the carriage house each name
        // one, and the flashlight is in the player's hand for most of the
        // evening. A dented tin torch has the weaker claim on the word.
        synonyms("flashlight", "torch", "light")
        description("A dented tin flashlight. Shake it and it rattles, but it lights.")
        lightSource
    }

    /// A workman's glove with the fingers burned, in a cellar nobody has any
    /// business in. The evidence the case turns on, and the reason the
    /// flashlight exists.
    let glove = Item {
        name("scorched glove")
        adjectives("scorched", "burned", "canvas", "work")
        synonyms("glove")
        description(
            """
            A canvas work glove, left-handed, with the fingertips burned back to the lining. It is a small hand's \
            glove. It has been pushed behind the coal bin rather than dropped there.
            """)
    }

    let pineTable = Item {
        name("pine table")
        adjectives("scrubbed", "deal", "pine", "kitchen")
        synonyms("table", "board", "counter")
        description(
            """
            Deal, scrubbed pale over so many years that the grain stands up out of it. Mrs. Kettle's evening is laid \
            out along it in the order she means to use it.
            """)
        scenery
    }

    /// The reason anybody in this house can be placed anywhere: they come down
    /// these and land in front of the one person who never stops looking.
    let backStairs = Item {
        name("back stairs")
        adjectives("back", "narrow", "servants", "boxed")
        synonyms("stairs", "staircase", "stair")
        description(
            """
            Narrow, boxed in, and they turn twice on the way down. You would hear somebody on them from anywhere in \
            this room, and so would she.
            """)
        scenery
    }

    /// Shares the word "stairs" with the back stairs on purpose. A room with
    /// two flights in it should ask which one you meant.
    let cellarSteps = Item {
        name("cellar steps")
        adjectives("cellar", "stone", "worn")
        synonyms("steps", "stairs", "stair")
        description(
            """
            Stone, dished in the middle from use, going down into the dark. There is no switch at the top of them.
            """)
        scenery
    }

    let yardDoor = Item {
        name("yard door")
        adjectives("yard", "back", "glazed", "kitchen")
        synonyms("door")
        description(
            """
            Half-glazed, with a worn place at knee height where it has been pushed open by people carrying things.
            """)
        scenery
    }

    /// Named in the glove's own description, which made it the most
    /// conspicuous missing noun in the house.
    let coalBin = Item {
        name("coal bin")
        adjectives("coal", "plank", "wooden")
        synonyms("bin", "coalbin", "coal")
        description(
            """
            A plank bin with three winters of coal dust in it and no coal. The dust on the floor behind it has been \
            disturbed and then smoothed over, which takes longer than not doing it.
            """)
        scenery
    }

    // MARK: - The yard and the lab

    let dryGrass = Item {
        name("dry grass")
        adjectives("dry", "brown", "long")
        synonyms("grass", "lawn", "yard", "ground")
        scenery
    }

    /// The building from outside it. The room is `carriageHouse`; this is what
    /// the player is looking at from the yard, facing north.
    let carriageHouseOutside = Item {
        name("carriage house")
        adjectives("carriage", "brick", "old")
        synonyms("house", "shed", "lab", "laboratory", "workshop", "building")
        scenery
    }

    let toolRack = Item {
        name("tool rack")
        adjectives("tool", "iron", "wall")
        synonyms("rack", "tools", "tool")
        scenery
    }

    let cot = Item {
        name("cot")
        adjectives("army", "canvas", "folding")
        synonyms("cot", "bunk", "bed")
        scenery
    }

    /// The kitchen stove's flue, running up through the corner past the end of
    /// the bench where the can is sitting. The mechanism, in plain sight, from
    /// the first turn.
    let stovePipe = Item {
        name("stove pipe")
        adjectives("stove", "tin", "hot")
        synonyms("pipe", "stovepipe", "flue", "chimney")
        scenery
    }

    let gardenWall = Item {
        name("garden wall")
        adjectives("garden", "brick", "low")
        synonyms("wall", "brick")
        scenery
    }

    let workbench = Item {
        name("workbench")
        adjectives("long", "scarred")
        synonyms("bench", "workbench")
        scenery
    }

    /// The coroner's answer, sitting in plain sight where the stove's heat can
    /// reach it. It goes up with the carriage house.
    let can = Item {
        name("sealed can")
        adjectives("sealed", "paper", "unmarked")
        synonyms("can", "tin")
        description(
            """
            A paper-wrapped can about the size of a coffee tin, sealed and unlabelled, sitting on the bench end \
            nearest the stove pipe. Whatever is in it, that is not where it goes.
            """)
    }

    /// What the carriage house becomes. Hidden until the blast puts it there,
    /// and off limits once the patrolman is standing over it — the case will
    /// not be solved by sifting.
    let debris = Item {
        name("wreckage")
        adjectives("burned", "burnt", "charred")
        synonyms("wreckage", "debris", "rubble", "ruins")
        description(
            """
            Roof slates, black timber, and a smell with chemistry in it. If the evening has an answer, some of it is \
            in there, and none of it is coming out tonight.
            """)
        scenery
        hidden
    }

    let julian = Actor {
        name("Julian Vane")
        adjectives("julian", "mr", "mister")
        synonyms("vane", "julian", "man")
        description(
            """
            Forty-one and looks it from the side. Shirtsleeves, ink on two fingers, and the particular calm of a man \
            who has decided that whatever is wrong is now somebody else's to prove.
            """)
        firstSight("Julian Vane is at the bench with his back to the door.")
    }

    // MARK: - The household

    /// Her description and her presence line are both rules rather than
    /// traits: the first because the blast changes her, the second because she
    /// spends six minutes of the evening out of her chair and a woman in the
    /// back garden is not in her chair with the lamp unlit.
    let constance = Actor {
        name("Mrs. Vane")
        adjectives("mrs", "missus", "old", "constance")
        synonyms("vane", "constance", "mother", "woman")
    }

    let delphine = Actor {
        name("Delphine Marsh")
        adjectives("delphine", "miss", "young")
        synonyms("marsh", "delphine", "woman", "painter")
        description(
            """
            Thirty-four, in a man's shirt with paint on the cuff. She looks back at you a beat longer than most \
            people do, and it is not a challenge. She is taking a reading.
            """)
    }

    let teague = Actor {
        name("Howard Teague")
        adjectives("howard", "mr", "mister")
        synonyms("teague", "howard", "boarder", "man")
        description(
            """
            Fifty-six, Navy the first time around, in a jacket that was pressed this morning by somebody. He is the \
            most helpful person in this house, which is a thing worth noticing about a house where a man has just \
            died.
            """)
        firstSight("Howard Teague is here, being helpful.")
    }

    let pike = Actor {
        name("Dr. Pike")
        adjectives("dr", "doctor", "aldous")
        synonyms("pike", "aldous", "man")
        // He is in the parlour, the yard and the study across the evening, so
        // the hat is described by how long it has been on rather than by which
        // side of a door he is standing on.
        description(
            """
            Fifty, and he has not had the hat off since he came, because taking it off would mean he had arrived \
            somewhere. He would like very much to be back up the arroyo.
            """)
        firstSight("Dr. Pike is standing about with his hat on.")
    }

    /// Described by a rule: the line that makes her — she looked at it and went
    /// back to work — is a thing you can only say about a woman who has had a
    /// wreckage to look at.
    let kettle = Actor {
        name("Mrs. Kettle")
        adjectives("mrs", "missus", "iris", "cook")
        synonyms("kettle", "iris", "cook", "housekeeper", "woman")
        firstSight("Mrs. Kettle is here, keeping busy.")
    }

    /// Unscheduled, and stays that way — scenery with a topic table rather
    /// than a sixth timetable. He is why the player cannot dig the answer out
    /// of the debris, and he knows exactly one useful thing.
    let patrolman = Actor {
        name("patrolman")
        adjectives("young", "police")
        synonyms("patrolman", "officer", "policeman", "police", "cop")
        description(
            """
            Young enough to stand at attention beside a burned-down building. He has the wreckage, his orders, and a \
            notebook with everyone's name in it, and he is keeping all three.
            """)
        firstSight("A patrolman is posted at the wreckage, keeping everybody out of it.")
    }

    // MARK: - Upstairs

    let runner = Item {
        name("runner")
        adjectives("worn", "threadbare", "turkey")
        synonyms("runner", "carpet", "rug")
        description(
            """
            Turkey pattern, gone to string down the middle where everybody walks and perfectly good along both edges.
            """)
        scenery
    }

    let studyLamp = Item {
        name("desk lamp")
        adjectives("green", "shaded", "brass", "reading")
        synonyms("lamp", "shade")
        description(
            """
            Brass, with a green glass shade of the kind meant to keep the light off everything but the page. It is \
            switched off. Whoever went through these drawers did it without turning it on.
            """)
        scenery
    }

    let sheet = Item {
        name("sheet")
        adjectives("typed", "half", "foolscap")
        synonyms("sheet", "page", "story")
        description(
            """
            Half a page of a sea story: a destroyer, weather, and a man on a bridge who has just noticed something. \
            It stops in the middle of the word *torpe*.
            """)
        scenery
    }

    let bed = Item {
        name("bed")
        adjectives("iron", "made", "single")
        synonyms("bed", "bedstead", "mattress")
        description(
            """
            Made, and made properly, with the corners squared. Navy the first time around and it never comes off.
            """)
        scenery
        surface
    }

    let desk = Item {
        name("desk")
        adjectives("writing", "oak")
        synonyms("desk", "drawer", "drawers")
        scenery
        surface
    }

    let ledger = Item {
        name("ledger")
        adjectives("green", "cloth")
        synonyms("ledger", "book", "accounts")
        description(
            """
            A green cloth accounts book kept in a small hand. Most of it is the ordinary arithmetic of a man with no \
            money. The last four pages are a list of dates against page numbers, and page numbers are not money.
            """)
    }

    let letters = Item {
        name("bundle of letters")
        adjectives("lodge", "tied", "bundle")
        synonyms("letters", "letter", "bundle", "correspondence")
        description(
            """
            A dozen letters in three different hands, tied with grocer's string. They arrange meetings, they argue \
            about money, and they use a vocabulary that would look very bad read aloud in a courtroom and means \
            almost nothing in a parlour. Somebody has read them recently; the string is tied the wrong way round.
            """)
    }

    let typewriter = Item {
        name("typewriter")
        adjectives("portable", "royal")
        synonyms("typewriter", "machine")
        description(
            """
            A portable with a sheet still in it, stopped mid-sentence in the middle of a word. Whatever took him away \
            from it, he did not expect it to take long.
            """)
        scenery
    }

    let suitcase = Item {
        name("suitcase")
        adjectives("brown", "packed")
        synonyms("suitcase", "case", "bag", "luggage")
        description("Brown, scuffed at the corners, and packed. The strap is buckled. It has been packed a while.")
        container
    }

    // MARK: - The evening, written down

    // These five timetables are the case. Everything the household later says
    // about where it was is checked against them rather than against prose —
    // `clock.location(of:at:)` reads the same data that drove the movement, so
    // a schedule edit cannot leave a lie standing by accident.
    //
    // Computed rather than stored because a stored property initializer cannot
    // see `self`, and these have to name the rooms above.

    /// The boarder's evening, and the only one that goes near the lab. Down
    /// the back stairs at 5:36, into the carriage house at 5:38, back through
    /// the kitchen at 5:42 where Mrs. Kettle is standing over her pot, out the
    /// front door at 5:44 — and off the map until ten past six.
    var teagueDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: boardersRoom),
            Stop(
                at: TimeOfDay(17, 36), in: kitchen,
                departure: "Teague's door goes, and there are feet on the back stairs.",
                arrival: "Teague comes down the back stairs with his hat already on."),
            Stop(
                at: TimeOfDay(17, 38), in: carriageHouse,
                departure: "Teague lets himself out the yard door.",
                arrival: "Teague puts his head round the carriage house door and says something short."),
            Stop(
                at: TimeOfDay(17, 42), in: kitchen,
                departure: "Teague comes back out of the carriage house, not hurrying.",
                arrival: "Teague comes back through the kitchen and says nothing to anybody."),
            Stop(
                at: TimeOfDay(17, 44), in: frontHall,
                arrival: "Teague crosses the hall, says he is going for cigarettes, and goes."),
            Stop(at: TimeOfDay(17, 46), in: street),
            Stop(
                at: TimeOfDay(18, 10), in: frontHall,
                arrival: "The front door goes. Teague is back, with a paper bag and a great deal to say."
            ) {
                teagueIsBack = true
            },
            Stop(
                at: TimeOfDay(18, 30), in: boardersRoom,
                departure: "Teague goes up, saying he needs to sit down."),
        ])
    }

    /// The mother's evening: the parlour, six minutes in the yard after the
    /// blast, and the parlour again.
    var constanceDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: parlour),
            Stop(
                at: TimeOfDay(17, 48), in: backYard,
                arrival: """
                    Mrs. Vane comes out as far as the step and stops there. She does not call his name. She looks at \
                    the fire the way you would look at a bill you had been expecting for years.
                    """),
            Stop(
                at: TimeOfDay(17, 54), in: parlour,
                departure: "Mrs. Vane goes back inside without having said anything at all."),
        ])
    }

    /// The cook's evening: her kitchen, the yard, her kitchen. She is the one
    /// person here whose account will match the schedule.
    var kettleDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: kitchen),
            Stop(
                at: TimeOfDay(17, 48), in: backYard,
                arrival: """
                    Mrs. Kettle comes out drying her hands and does not stop drying them. "Oh, the boy," she says, \
                    once, and then does not say it again.
                    """),
            Stop(
                at: TimeOfDay(18, 0), in: kitchen,
                departure: "Mrs. Kettle goes back to her kitchen, on the grounds that somebody has to."
            ),
        ])
    }

    /// The partner's evening: the yard when it happens, then the study, then
    /// the cellar — where the dark makes her the one person whose movements
    /// the player can genuinely lose.
    var delphineDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: backYard),
            Stop(
                at: TimeOfDay(18, 2), in: study,
                departure: "Delphine goes inside.",
                arrival: "Delphine comes into the study and starts on the desk drawers."),
            // The arrival line is written even though the cellar is unlit, so
            // that the dark is doing the hiding rather than the prose being
            // absent. A player standing down there with the flashlight on
            // sees her; a player standing down there without it does not.
            Stop(
                at: TimeOfDay(18, 26), in: cellar,
                departure: "Delphine takes the cellar stairs down, and does not take a light.",
                arrival: "Delphine comes down the cellar steps and stops when she sees you."),
        ])
    }

    /// The visitor's evening: the parlour, the yard, and then the study, where
    /// what he wants is.
    var pikeDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: parlour),
            Stop(
                at: TimeOfDay(17, 48), in: backYard,
                arrival: """
                    Dr. Pike arrives in the yard holding his hat against his chest. He gets within thirty feet of the \
                    heat and no further, and his lips move on a word he does not let out.
                    """),
            Stop(
                at: TimeOfDay(18, 14), in: study,
                departure: "Dr. Pike goes back into the house.",
                arrival: "Dr. Pike lets himself into the study and is not pleased to find company."),
        ])
    }

    // MARK: - Composition

    var content: GameContents {
        clock
        talk
    }

    var verbs: [SyntaxRule] {
        [.accuse]
    }

    /// The accusation is the deadline's teeth: a wrong name ends the run. The
    /// deputy coroner does not argue — you spent your credibility, and the
    /// stamp comes down anyway. This is the default: the right name is a
    /// `before` rule on Constance, in the rules block.
    var actions: [IntentAction] {
        action(.accuse) {
            guard let accused = command.directObject else { return }
            try require(accused.isActor, else: "The record wants a name, and that is not one.")
            if !blastHappened {
                try reply("There is nothing to accuse anybody of. Not yet.")
            }
            say(
                """

                He hears you out. Then he writes *accidental* in the box marked cause, and the case is a page in a \
                drawer in a building in Los Angeles.
                """)
            try end(won: false)
        }
    }

    /// The five rounds, and the evening's three fixed points. Everything in
    /// the house moves except the three alarms, and those are what the player
    /// is racing.
    var timers: [TimedEvent] {
        clock.schedule(teague, daemonName: "teague.day", teagueDay)
        clock.schedule(constance, daemonName: "constance.day", constanceDay)
        clock.schedule(kettle, daemonName: "kettle.day", kettleDay)
        clock.schedule(delphine, daemonName: "delphine.day", delphineDay)
        clock.schedule(pike, daemonName: "pike.day", pikeDay)

        // 5:46. The inciting event, and the reason there is a case at all.
        clock.at(TimeOfDay(17, 46), named: "clock.blast") {
            blastHappened = true
            can.vanish()
            julian.vanish()
            debris.reveal()

            // Standing in the carriage house when it goes up is a way to end
            // the evening, though not the intended one.
            if player.location == carriageHouse {
                try die(
                    """
                    Vane says "hold this a moment" and you never learn what. The bench, the roof, and the better part \
                    of the garden wall arrive in the yard ahead of you.
                    """)
            }

            wasInTheYardForTheBlast = player.location == backYard
            say(
                wasInTheYardForTheBlast
                    ? """

                    There is no moment in which it is about to happen. The carriage house comes apart. There is no \
                    bang, particularly — more the sound of a door slamming in a cave — and then the ground hits you \
                    in the back and you work out, after a moment, that you are lying down. Slates come out of the sky \
                    and go into the grass edge-first. Twenty feet of the garden wall lies down with you. The heat \
                    arrives last and all at once and takes the hair off the back of your hand.
                    """
                    : """

                    Nothing leads up to it. Somewhere out behind the house something goes off with a flat, \
                    unimpressive thump, and every window and pane and loose sash in the place shivers at once, and \
                    then is still. The floor comes up an inch and puts itself back. Plaster lets go of the ceiling \
                    somewhere over your head. In the kitchen a shelf of crockery goes over, all of it, one long run \
                    of breakage, and after that the house is quieter than a house ought to be.
                    """)

            // Placed after the death check above, so a player who was standing
            // in the lab never schedules an aftermath they aren't alive for.
            startFuse("blast.after")
        }

        // The turn after. From the yard you are getting up off the grass; from
        // indoors you are finding out what a house sounds like when everybody
        // in it stops talking at the same moment.
        //
        // Fuses rather than alarms on purpose: the beat is relative to the
        // blast, not to a wall-clock time, and the mechanics contract pins the
        // count of load-bearing alarms at three. A fuse is decorative by
        // construction and doesn't touch that count.
        fuse("blast.after", after: 1) {
            // What happened to the player follows the player: a man who was
            // knocked flat in the yard and then walked into the kitchen still
            // has grass in his cuff. What is happening in a room stays in it.
            say(
                wasInTheYardForTheBlast
                    ? """

                    You get up. Your ears are holding one high thin note that has nothing to do with the evening. \
                    There is grass in your cuff and grit on your teeth, and the dust is coming down out of the air \
                    slowly, the way it does indoors.
                    """
                    : """

                    The house holds still for a count of three. Then a door goes somewhere above you, and another one \
                    below, and everybody in it is moving at once. The dust comes down the passage from the direction \
                    of the kitchen and settles on the hall table.
                    """)
            // The one thing only this turn can say about her: she did not go
            // down when it went. Her presence line carries the rest of the
            // evening, so this beat has to be about the moment, not the pose.
            if player.location == backYard, delphine.isIn(backYard) {
                say(
                    """

                    Delphine Marsh did not go down when it went. She did not even put a hand out.
                    """)
            }
            startFuse("blast.settling")
        }

        // And the second, which is the sound a building makes while it stops
        // being one. Out at the back it is a thing you watch happen; from
        // inside the house it is a noise from the wrong direction.
        fuse("blast.settling", after: 1) {
            say(
                player.location == backYard || player.location == carriageHouse
                    ? """

                    Something in the wreckage lets go and settles, and the note in your ears steps down one. It will \
                    be there tomorrow.
                    """
                    : """

                    Something out at the back lets go and settles, and the note in your ears steps down one. It will \
                    be there tomorrow.
                    """)
        }

        // 5:52. The radio car. Not one of the evening's three fixed points —
        // an errand between them — and deliberately not the turn the deadline
        // lands on the page either. He takes names and volunteers nothing;
        // what downtown told him is his to give and the player's to ask for.
        // The exposition lives in his topic table, which is what "learned, not
        // given" has to mean if it is going to mean anything.
        clock.at(TimeOfDay(17, 52), named: "clock.radioCar") {
            // He stands on the yard side of the gap, which is where a man
            // keeping people out of a building stands. The wreckage comes with
            // him: the player cannot be on both sides of that line across this
            // turn, so the move is unobservable, and it keeps the debris
            // answerable to somebody who is now barred from walking up to it.
            patrolman.move(to: backYard)
            debris.move(to: backYard)
            wreckageSealed = true

            // A player standing in it when he arrives is the first person he
            // puts out of it. Anything else would have him post himself at a
            // door with somebody already inside, which is not what posting is.
            if player.location == carriageHouse {
                say(
                    """

                    A radio car pulls up out front. A patrolman comes through the house, takes your name and writes \
                    it down, and walks you out of the wreckage with two fingers and no argument. Then he posts \
                    himself where the door used to be, with you on the other side of him.
                    """)
                player.location = backYard
                describeSurroundings()
                return
            }
            say(
                player.location == backYard
                    ? """

                    A radio car pulls up out front, and a patrolman comes through the house and out to the wreckage. \
                    He takes names, all of them, yours included, writes each one down, and posts himself where the \
                    door used to be. After that he has nothing to say, and looks at the fire instead.
                    """
                    : """

                    A car door goes out front. A patrolman works through the house taking names, yours included, and \
                    goes out back to stand at the wreckage. He does not say what happens next, and nobody in this \
                    house asks him.
                    """)
        }

        // 6:20. A voice from the lab's night desk, for a player who happens to
        // be standing near the telephone when it rings.
        clock.at(TimeOfDay(18, 20), named: "clock.telephone") {
            say(
                player.location == frontHall
                    ? """

                    The telephone rings. A man who does not give his name says he is the night desk up at the lab, \
                    that Dr. Pike signed out a car this afternoon and has not signed it back in, and that he would \
                    rather you heard it from him. Then he hangs up, having heard something in his own voice he did \
                    not care for.
                    """
                    : """

                    The telephone starts ringing in the front hall. It rings eleven times. Nobody in this house is \
                    answering telephones tonight.
                    """)
        }

        // 6:50. The deadline. The county man writes down what he is given,
        // and tonight he is being given nothing.
        clock.at(TimeOfDay(18, 50), named: "clock.coroner") {
            say(
                """

                The county man comes up the path at ten to seven, and he is not in a hurry, because nobody has given \
                him a reason to be. He looks at the wreckage for rather less time than you did. Then he writes \
                *accidental* in the box marked cause, and the whole of tonight becomes a page in a drawer in a \
                building in Los Angeles.
                """)
            try end(won: false)
        }
    }

    var rules: Rules {
        // The coat is a container with the case's hinge in it, not luggage.
        // Both refusals point at the pocket, because the pocket is the puzzle.
        coat.before(.take) {
            try refuse(
                """
                It isn't yours and the hall isn't private. Leave it on the stand. The pockets are another question.
                """)
        }

        coat.before(.wear) {
            try refuse("It is June, and it is not your coat.")
        }

        // Going through the pockets is what turns the receipt up. Searching a
        // coat in somebody else's hall is the sort of thing the player should
        // have to decide to do.
        // Before, not after: the default action would otherwise report the
        // pockets empty and then the rule would contradict it. And nothing is
        // there to find until Teague has been out and come back — a receipt
        // stamped 6:05 cannot be in a pocket at half past five.
        coat.before(.lookIn) {
            guard teagueIsBack, !receipt.isRevealed else { return }
            receipt.reveal()
            try reply("In the inside pocket there is a slip of register paper, folded once.")
        }

        // Rooms that read differently on the two sides of 5:46.
        backYard.describe {
            blastHappened
                ? """
                Dry grass, and a garden wall that is now shorter at the north end than the south. What is left of the \
                carriage house is standing in pieces, and some of it is still burning quietly because nobody has \
                thought to stop it.
                """
                : """
                Dry grass and a low brick wall that used to be taller. The carriage house stands at the north end \
                with its lamp burning and its door ajar.
                """
        }

        carriageHouse.describe {
            blastHappened
                ? """
                The roof is in the yard. Down one side there is the black stub of a bench, and down the other there \
                is not much worth naming. It is quieter in here than it should be.
                """
                : """
                Somebody's workshop and somebody else's chapel. A long scarred bench down one side under a rack of \
                tools, a cot down the other, and the stove pipe from the house running up through the corner, which \
                is a thing you notice and then stop noticing.
                """
        }

        hallClock.describe {
            // Reads the clock's own format, so the house clock and the
            // player's watch can never disagree about how to say a time.
            "The clock says \(clock.now.formatted(clock.format)). It has the confident tick of a clock that is right."
        }

        watch.describe {
            // Same source as the longcase clock, and the sentence about
            // setting it says in fiction why the two can never disagree. They
            // must not: every alibi in this house is a time, and a watch that
            // ran fast would make the case unmeasurable by the one instrument
            // the player owns.
            """
            Steel, on a strap you have replaced twice. You set it by the longcase clock on your way through the hall, \
            out of a habit from a job you don't have any more, and it says \(clock.now.formatted(clock.format)).
            """
        }

        // DROP, PUT ON and PUT IN each take a worn thing off first, so
        // refusing DOFF alone would leave three ways round it.
        watch.before(.doff) {
            try refuse("You would put it straight back on. Tonight is a night for knowing the time.")
        }

        watch.before(.drop, .putIn, .putOn) {
            try refuse("It has been on that wrist since 1943 and it is staying there.")
        }

        // The hall's front door is not latched, and "You can't open that" is
        // the wrong answer for a door that isn't.
        frontDoor.before(.open) {
            try reply(
                """
                It isn't latched. Mrs. Vane does not lock her front door in the afternoon, which is a thing you would \
                have told her about if tonight were an ordinary night.
                """)
        }

        // Not a container — the glove stays loose on the cellar floor — but
        // looking behind it is the obvious move and deserves an answer.
        coalBin.before(.lookIn) {
            try reply("Nothing in it but the dust, and the dust is the interesting part.")
        }

        // The play-tester went down in the dark, got the pitch-black line, and
        // never found the flashlight. Said once: a player who ignores it is
        // making a choice, and a player who reads it twice is being nagged.
        //
        // `afterEachTurn` rather than `onEnter`, which runs *before* the room
        // is described and would put the hint above "It is pitch black."
        cellar.afterEachTurn {
            guard !flashlight.isLit, !cellarHintGiven else { return }
            cellarHintGiven = true
            say(
                flashlight.isHeld
                    ? "There is a flashlight in your hand and it is switched off."
                    : """
                    You could stand here all evening and it would be exactly this useful. There is a drawer under the \
                    counter in the kitchen, and houses like this keep a light in it.
                    """)
        }

        dryGrass.describe {
            blastHappened
                ? """
                Brown grass with roof slates standing up out of it edge-first, and a scorched half-circle running out \
                from where the carriage house door used to be.
                """
                : """
                Brown by the middle of June and not cut since. There is one path worn through it, from the kitchen \
                door to the carriage house, and only that one.
                """
        }

        carriageHouseOutside.describe {
            blastHappened
                ? """
                Three walls, and the third one is being generous about it. The roof is in the grass between you and \
                what is left.
                """
                : """
                Brick below, board above, and a set of double doors somebody stopped using twenty years ago in favour \
                of the small one at the side. There is light in it and a smell of the stove.
                """
        }

        toolRack.describe {
            blastHappened
                ? "The rack is on the ground and most of the tools are not on the rack."
                : """
                Every tool on its own nail, with a pencil outline on the board behind it so a man can see at a glance \
                what is missing. Nothing is missing.
                """
        }

        cot.describe {
            blastHappened
                ? "The frame, and a smell of burnt ticking."
                : """
                An army cot with a blanket folded square on the end of it. Somebody sleeps out here often enough to \
                keep it made.
                """
        }

        stovePipe.describe {
            blastHappened
                ? """
                Three lengths of it in the grass. At the end that used to run past the bench, the tin is scorched \
                bright down one side.
                """
                : """
                Tin, coming up out of the corner and out through the roof, carrying the kitchen stove's heat past this \
                end of the bench. You would not keep a hand on it.
                """
        }

        gardenWall.describe {
            blastHappened
                ? "Four courses of brick where there were nine, and the missing five are distributed across the grass."
                : "Low brick, and losing an argument with the ivy."
        }

        workbench.describe {
            blastHappened
                ? "Charcoal in the shape of a bench."
                : """
                Tools laid out in the order a careful man uses them, and a scorch mark near the vice that is older \
                than tonight.
                """
        }

        // The patrolman's one job. Some of the answer is literally in the
        // debris, which is why nobody gets to sift it. Before he arrives you
        // get six minutes with it and it gives you nothing, which is the more
        // useful lesson.
        debris.before(.lookIn) {
            if wreckageSealed {
                try reply(
                    "\"Best keep back from there,\" the patrolman says, and puts a shoulder where you were going.")
            }
            try reply(
                """
                You turn over what the heat will let you touch and get soot to the elbow for it. Whatever the answer \
                is, it is not the kind you sift out.
                """)
        }

        // MARK: The household, described

        // Shock, from a quarter to six to the end, and her shock looks like
        // nothing at all. She is not grieving like a woman surprised by a
        // death.
        constance.describe {
            blastHappened
                ? """
                Seventy-one, upright, flat, terribly still. She is holding still the way a woman holds still when she \
                is doing arithmetic.
                """
                : """
                Seventy-one, upright in a chair that has taken the shape of her. She has the stillness of someone who \
                stopped expecting anything some years ago and has been managing on the arrangement since.
                """
        }

        // Six minutes of her evening are spent out of that chair, and the
        // presence line has to know it.
        constance.presence {
            constance.isIn(parlour)
                ? "Mrs. Vane is in her chair with the lamp unlit."
                : "Mrs. Vane is on the step and no further, watching it burn."
        }

        delphine.presence {
            blastHappened
                ? "Delphine Marsh is on her feet with her arms at her sides, looking at the fire."
                : "Delphine Marsh is here, not doing much."
        }

        kettle.describe {
            blastHappened
                ? """
                Sixty-two, and the only person here who has looked at the wreckage and then gone back to what she was \
                doing. She misses nothing and says most of it.
                """
                : """
                Sixty-two, and she has stood in this kitchen longer than the boarder has had his room and longer than \
                the son has had his shed. She misses nothing and says most of it.
                """
        }

        // MARK: The interrogation

        // Opening lines. Every way of saying hello — GREET, HELLO, TALK TO,
        // `delphine, hello` — arrives here, so the player never has to guess
        // which word this game wanted.
        talk.greeting(
            of: julian,
            again: "\"Mm,\" he says, to the clamp.",
            reply: "\"You're early,\" he says to the bench. \"That's all right. Nothing's early enough.\"")
        talk.greeting(
            of: constance,
            again: "Mrs. Vane has already said the one word she means to say to you.",
            reply: "\"Yes,\" says Mrs. Vane, to no question, and goes on looking at the grate.")
        talk.greeting(
            of: delphine,
            again: "\"We've met,\" she says, without unfolding her arms.",
            reply: "She looks at you a beat longer than she needs to. \"You'd be the letter,\" she says.")
        talk.greeting(
            of: teague,
            again: "\"Still here,\" he says, pleased about it.",
            reply: """
                "Teague," he says, and has your hand before you have offered it. "Anything you need in this house, \
                you come to me."
                """)
        talk.greeting(
            of: pike,
            again: "The hat comes down a degree, which is the whole of it.",
            reply: "\"Pike.\" He does not give you the hat, the hand, or the rest of the name.")
        talk.greeting(
            of: kettle,
            again: "\"You'll want something to do,\" she says. \"I haven't got it.\"",
            reply: "\"You'll be the one he wrote to.\" She does not stop what she is doing. \"He said.\"")
        talk.greeting(
            of: patrolman,
            again: "\"Sir.\" Exactly as before, and no more of it.",
            reply: "\"Sir.\" He has your name in the notebook already and no further use for you.")

        // The one place following somebody is worth more than the engine's
        // honest refusal. The core verb searches a single exit deep, and
        // Teague's 5:38 crossing goes kitchen → carriage house, which is two:
        // so the game buys the pursuit itself, and only as far as the yard,
        // because that is genuinely as far as you can see him go.
        teague.before(.follow) {
            guard player.location == kitchen, teague.isIn(carriageHouse) else { return }
            say("(after Teague, out through the yard door)")
            player.location = backYard
            describeSurroundings()
            try reply("Teague is across the grass and into the carriage house before you are off the step.")
        }

        // Julian is askable for the first eight turns, and only there — the
        // blast takes him out of scope, so the table needs no gate. A player
        // who spends the opening with the victim learns things a player who
        // wanders the garden does not.
        talk.topics(
            of: julian,
            fallback: "\"Later,\" he says, without turning round. \"You'll have all of it after six.\"",
            again: "\"You had that off me.\" He does not turn round. \"Six o'clock.\""
        ) {
            topic(
                "letter", "lab", "break in", "intruder", "somebody",
                reply: """
                    "Nothing taken." He lets that sit. "A thief takes. A man who takes nothing is coming back."
                    """)
            topic(
                "six", "appointment", "show", "tonight",
                reply: """
                    "At six." He nods at the bench. "You'll want to be sitting down for it, and I want better light \
                    than this."
                    """)
            topic(
                "delphine", "marsh",
                reply: """
                    "Delphine keeps her own counsel." He tightens a clamp. "It was the counsel I liked first."
                    """)
            topic(
                "teague", "boarder", "howard",
                reply: """
                    "Howard borrows things. They come back a little different." He almost smiles. "Most things don't \
                    come back at all."
                    """)
            topic(
                "pike", "arroyo", "notebooks", "fired", "associations",
                reply: """
                    "They let me go over the company I keep, and now they send a man out about the company I kept." \
                    He files at something small. "The notebooks are mine. Tell Pike I said so."
                    """)
            topic(
                "mother", "constance",
                reply: """
                    "My mother thinks this place took something from her." He sets the file down. "She's not wrong. \
                    We disagree about what."
                    """)
        }

        // Constance's table is nearly all refusals until the glove — every
        // investigative habit the player owns slides off a seventy-one-year-old
        // woman in an unlit parlour, which is why she is the answer.
        talk.topics(
            of: constance, fallback: "Mrs. Vane looks past you at the wallpaper.",
            again: "\"I have answered that.\" She has not moved at all."
        ) {
            // The lie. Note it matches her timetable exactly: the timetable is
            // where she was seen, and the can was placed before half past five.
            topic(
                "evening", "parlour", "alibi", "where",
                unless: .constanceBroke,
                reply: """
                    "I have been in the parlour all evening." She says it to the cold grate, in the voice of a woman \
                    reading a timetable.
                    """)
            topic(
                "evening", "parlour", "alibi", "where",
                knowing: .constanceBroke,
                reply: """
                    "I went out before you came. He was in the house at his supper." Her hands are still. "I put it \
                    where the heat would find it and I came back to my chair, and I have been in this chair since."
                    """)
            // Before 5:46 the question means something else entirely, and the
            // row used to answer "My son is dead in the garden" from turn one.
            topic(
                "julian", "son",
                unless: .constanceBroke,
                when: { !blastHappened },
                reply: "\"Julian is in the shed.\" She says it the way you would say the weather.")
            // And afterwards she is allowed one moment before she settles into
            // the sentence she will use for the rest of the evening.
            topic(
                "julian", "son",
                unless: .constanceBroke,
                again: "\"My son is dead in the garden.\" That is all she has on the subject.",
                reply: """
                    She takes a moment to find you, as though the question had come from another room. "My son," she \
                    says. Then nothing, for long enough that you consider asking it again. "He is dead in the \
                    garden." Her hands go back to the arms of the chair and stay there.
                    """)
            topic(
                "julian", "son",
                knowing: .constanceBroke,
                reply: """
                    "That shed had him twenty years before it killed him." She looks at the lamp she has not lit. "I \
                    meant to take it back. I believed he had gone out."
                    """)
            topic(
                "lab", "carriage house", "workshop", "shed",
                unless: .constanceBroke,
                reply: "\"I never went into it.\" It has the finish of a sentence said many times.")
            topic(
                "glove", "cellar",
                knowing: .constanceBroke,
                reply: "\"It is my glove,\" she says. \"You knew that when you carried it up the stairs.\"")
            topic(
                "teague", "boarder",
                knowing: .teagueLied,
                reply: """
                    "Mr. Teague told me Julian had gone out." She folds her hands. "So you see it mattered, what he \
                    said. It mattered more than he will ever let himself work out."
                    """)
        }

        // Everything about Delphine invites the wrong conclusion, and the
        // table lets the player reach it before the letters retire it.
        talk.topics(
            of: delphine,
            again: "\"You've had that from me.\" She doesn't look round."
        ) {
            // Her lie — that she doesn't know what's in the letters.
            topic(
                "letters", "lodge", "correspondence", "bundle",
                unless: .delphineCleared,
                reply: "\"Julian kept letters. Men keep letters.\" She shrugs. \"I wouldn't know what's in them.\"")
            topic(
                "letters", "lodge", "correspondence", "bundle",
                knowing: .delphineCleared,
                reply: """
                    "They argue about money and dress it in robes." She almost laughs, and doesn't. "The neighbors \
                    would be so disappointed."
                    """)
            topic(
                "desert", "rites", "sunday",
                reply: """
                    "We went out for the air," she says, and gives you the first half of a phrase, and waits. You \
                    know the second half. You keep it.
                    """)
            // She was standing in the yard when it happened and had nothing to
            // say about it, so the question fell to her fallback and read like
            // the parser had failed.
            topic(
                "yard", "garden", "outside", "evening", "where", "standing",
                reply: """
                    "I was out here." She lets that be the whole answer for a moment. "Looking at the light on the \
                    wall, if you want it written down somewhere."
                    """)
            topic(
                "julian", "vane",
                when: { blastHappened },
                again: """
                    "He wrote to somebody last week and slept better after." A beat. "That was you, I take it."
                    """,
                reply: """
                    "Don't." She says it quietly and without any heat in it. Then, after a while, in a voice she has \
                    had to go and find: "He wrote to somebody last week and slept better after. That was you." She \
                    looks at the wreckage. "You came out on the wrong Tuesday."
                    """)
            topic(
                "julian", "vane",
                reply: """
                    "He wrote to somebody last week and slept better after." A beat. "That was you, I take it."
                    """)
        }

        // Her fallback, with one turn of state on it. The bare version reads
        // like a parse error the first time you get it; the point is that she
        // heard the question and decided against it. `topics` stays quiet when
        // nothing matches and it has no `fallback:`, so this rule — declared
        // after the table — is what answers.
        delphine.before(.ask, .tell) {
            guard command.topic != nil else { return }
            if !delphineHasDeflected {
                delphineHasDeflected = true
                try reply(
                    """
                    She hears the question. She lets you watch her decide not to answer it, which is an answer of a \
                    kind. Then she goes back to looking at whatever she was looking at.
                    """)
            }
            try reply("She goes on looking at whatever she was looking at.")
        }

        // Teague's alibi dies in three stages: the cook's testimony kills it,
        // the receipt breaks him, and what he told Constance is the keystone
        // the full ending turns on.
        talk.topics(
            of: teague, fallback: "\"Couldn't tell you, friend.\"",
            again: "\"We've been over that, friend.\" He finds something else on his sleeve."
        ) {
            topic(
                "drugstore", "alibi", "evening", "colorado", "where",
                unless: .kettleSawTeague,
                reply: """
                    "Drugstore on Colorado. Left here about half past, walked down, had a Coca-Cola, walked back. \
                    Ask them, they know me."
                    """)
            topic(
                "drugstore", "alibi", "evening", "colorado", "where", "kitchen",
                knowing: .kettleSawTeague, unless: .teagueRecanted,
                reply: """
                    "Mrs. Kettle keeps a good kitchen and a better clock." He recrosses his legs. "A man can pass \
                    through a kitchen on his way to the drugstore. I'd check her arithmetic."
                    """)
            topic(
                "drugstore", "alibi", "evening", "colorado", "where", "kitchen",
                knowing: .teagueRecanted,
                reply: "\"You've got the slip,\" he says. \"I'm done selling you the drugstore.\"")
            topic(
                "constance", "vane", "old lady", "mother", "told",
                knowing: .teagueRecanted, learning: .teagueLied,
                reply: """
                    "I told the old lady he'd gone out. That's all I told her. I wanted half an hour in that lab and \
                    I didn't want her watching the yard while I had it." He looks at the window. "It wasn't a lie \
                    that was supposed to do anything."
                    """)
            topic(
                "constance", "vane", "old lady", "mother",
                unless: .teagueRecanted,
                reply: "\"The old lady? Keeps to her parlour.\" He finds something on his sleeve to straighten.")
            topic(
                "notebooks", "pages", "ledger",
                knowing: .notebooksSold,
                reply: """
                    "Call it salvage," he says, before you have put a name to it. "The lab wanted those pages once \
                    and wants them now, and the mails in between were me."
                    """)
            topic(
                "notebooks", "pages",
                reply: "\"Vane's notebooks? Wouldn't know. I write my own pages.\"")
            topic(
                "julian", "vane",
                knowing: .teagueRecanted,
                reply:
                    "\"He was all right. Let me alone, let the rent ride.\" He looks at his hands. \"He was all right.\""
            )
        }

        // Pike's lie has a second floor — the earlier visit was not about
        // notebooks — and the ledger only opens the first one.
        talk.topics(
            of: pike, fallback: "\"I don't see how that concerns me.\"",
            again: "\"I've given you that.\" The hat brim does not move."
        ) {
            topic(
                "visit", "house", "before", "first",
                unless: .notebooksSold,
                reply:
                    "\"My first time at the house. I had the address only this week.\" He adjusts the hat he has not taken off."
            )
            topic(
                "visit", "house", "before", "first",
                knowing: .notebooksSold,
                reply: """
                    "I have been here before." He says it like a man initialling a correction. "Not for notebooks. \
                    You were in that trade once. You can imagine the shape of the report I filed."
                    """)
            topic(
                "notebooks", "pages", "papers", "lab",
                reply: """
                    "The men we have now prefer the notebooks in order. I was sent to put them in order." He starts \
                    a surname, gets as far as the first vowel, and files it back where he keeps it.
                    """)
            topic(
                "julian", "vane",
                reply: """
                    "A capable man. Indiscreet." The hat brim comes down a degree. "Capable stopped being a defence \
                    some years ago."
                    """)
        }

        // Mrs. Kettle is the mechanism by which the schedule becomes
        // testimony. Her answers are not authored prose: each one reads the
        // person's timetable, so a schedule edit changes what she says with
        // it. This is the demonstration the whole game exists to make — see
        // the mechanics contract in `docs/games/fulminate.md`.
        talk.topics(
            of: kettle, fallback: "\"That I couldn't say.\"",
            again: "\"I've said my piece on that one.\" The pot gets another stir."
        ) {
            topic("teague", "boarder", "howard", learning: .kettleSawTeague) {
                let room = clock.location(of: teagueDay, at: TimeOfDay(17, 42))
                try reply(
                    """
                    "Mr. Teague come down my back stairs into the \(room.name.lowercased()) at eighteen minutes to \
                    six with his hat already on. I know because the pot goes on at a quarter to, and I was standing \
                    right there getting it ready."
                    """)
            }
            topic("constance", "mrs vane", "mother", "old lady") {
                let then = clock.location(of: constanceDay, at: TimeOfDay(17, 46))
                let after = clock.location(of: constanceDay, at: TimeOfDay(17, 50))
                try reply(
                    """
                    "Mrs. Vane was in the \(then.name.lowercased()) when it went, and stood out in the \
                    \(after.name.lowercased()) after with the rest of us. Then back in, without a word said."
                    """)
            }
            topic("delphine", "marsh", "miss") {
                let room = clock.location(of: delphineDay, at: TimeOfDay(17, 46))
                try reply(
                    """
                    "Miss Marsh was in the \(room.name.lowercased()) when it went. I'll say that for her, and she \
                    can do with it what she likes."
                    """)
            }
            topic("pike", "doctor", "visitor") {
                let then = clock.location(of: pikeDay, at: TimeOfDay(17, 46))
                let after = clock.location(of: pikeDay, at: TimeOfDay(17, 50))
                try reply(
                    """
                    "The doctor sat in the \(then.name.lowercased()) with his hat on from the minute he come. He was \
                    out in the \(after.name.lowercased()) after, holding it."
                    """)
            }
            // Julian keeps no timetable, so this one is hers alone.
            topic(
                "julian", "vane", "son",
                reply: """
                    "Mr. Julian had his supper at five and carried a plate of it out to the shed." The pot gets a \
                    stir it does not need. "I have fed that boy since he was eleven."
                    """)
        }

        // He stands at the wreckage from 5:52 on. He knows exactly one useful
        // thing and will not say it unless somebody asks him for it — the
        // deadline reaches the page here or not at all.
        talk.topics(
            of: patrolman, fallback: "\"Best keep back from there.\"",
            again: "\"Told you what I know about that.\""
        ) {
            topic(
                "coroner", "county", "deputy", "downtown", "deadline", "happens", "next", "now",
                reply: """
                    "County man's coming out from downtown. Deputy coroner." He looks at the wreckage rather than at \
                    you. "Due by ten of seven, they said. He writes it up and that's what it is. If you've got \
                    something for him, have it ready."
                    """)
            topic(
                "wreckage", "fire", "debris", "body", "vane", "julian",
                reply: """
                    "Not till the county man's been." He shifts his feet. "There's a man in there. I've seen where he \
                    is. That's the last I'll say about it."
                    """)
            topic(
                "names", "notebook", "statement", "report",
                reply: """
                    "I take names. I don't take statements." He taps the notebook without opening it. "You want to \
                    give something, give it to the county man, and don't be slow about it."
                    """)
        }

        // The four pieces of physical evidence, each of which flips a story.
        talk.shows(
            receipt, to: teague, learning: .teagueRecanted,
            reply: """
                He looks at it for a while. "Six-oh-five," he says. "Yeah." He sits down on the arm of the chair, \
                which is not his chair. "I went after. I needed to have been somewhere."
                """)
        talk.shows(
            glove, to: constance, learning: .constanceBroke,
            reply: """
                She takes it out of your hand, which you were not expecting, and turns it over once. "I have been \
                sitting here," she says, "trying to remember whether I put it back."
                """)
        talk.shows(
            ledger, to: pike, learning: .notebooksSold,
            reply: """
                He reads the last four pages without touching the book. "Dates and page numbers," he says, and sits \
                down, and takes his hat off at last. "I paid for those. I never asked whose hand did the copying."
                """)
        talk.shows(
            letters, to: delphine, learning: .delphineCleared,
            reply: """
                She unties the string and reads the top one through, all the way, before she hands it back. "Now \
                you've read them," she says. "So you know what they are not."
                """)

        // `ACCUSE CONSTANCE` wins the game. The two endings differ by one
        // learned fact — the keystone — because a player who never finds out
        // why she believed the lab was empty has solved the case without
        // understanding it. Every other name falls through to the default
        // action, which is the losing one.
        constance.before(.accuse) {
            if !blastHappened {
                try reply("There is nothing to accuse anybody of. Not yet.")
            }
            say(
                talk.knows(.teagueLied)
                    ? """

                    The county man writes for a long time. When he is finished he reads it back, and there are two \
                    names in it, and only one of them meant anything by it.
                    """
                    : """

                    The county man writes down her name and closes the book. He does not ask why, and you do not \
                    have an answer that would fit in the space provided.
                    """)
            try end(won: true)
        }
    }

    var map: WorldMap {
        frontHall.west(parlour)
        parlour.east(frontHall)

        frontHall.south(kitchen)
        kitchen.north(frontHall)

        kitchen.west(backYard)
        backYard.east(kitchen)

        kitchen.down(cellar)
        cellar.up(kitchen)

        // The lab is open for the three turns between the blast and the radio
        // car, and the police own it after that. Only the way in closes; the
        // way out never does.
        backYard.north(
            carriageHouse,
            when: { !wreckageSealed },
            otherwise: """
                The patrolman puts an arm across the gap without any particular force in it. "Nobody past me till the \
                county man's been."
                """)
        carriageHouse.south(backYard)

        frontHall.up(landing)
        landing.down(frontHall)

        landing.west(study)
        study.east(landing)

        landing.east(boardersRoom)
        boardersRoom.west(landing)

        // The street is not an option. A man wrote to you and is now dead in
        // his mother's back garden; leaving is the one thing you can't do.
        frontHall.east(blocked: Fulminate.streetRefusal)
        frontHall.out(blocked: Fulminate.streetRefusal)

        // The back stairs are the household's, not yours. Blocked rather than
        // absent, because the kitchen's description names them and the stock
        // "You can't go that way" reads like the game forgot.
        kitchen.up(
            blocked: """
                The back stairs are the household's. A man who came here on a letter goes up the front way, where \
                everybody can see him do it.
                """)

        player.starts(in: frontHall)
        watch.startsWorn

        hallClock.starts(in: frontHall)
        telephone.starts(in: frontHall)
        coat.starts(in: frontHall)
        receipt.starts(inside: coat)
        hallFloor.starts(in: frontHall)
        hatStand.starts(in: frontHall)
        hallTable.starts(in: frontHall)
        frontDoor.starts(in: frontHall)
        frontStairs.starts(in: frontHall)

        parlourFurniture.starts(in: parlour)
        grate.starts(in: parlour)
        parlourLamp.starts(in: parlour)
        wallpaper.starts(in: parlour)

        stove.starts(in: kitchen)
        drawer.starts(in: kitchen)
        flashlight.starts(inside: drawer)
        pineTable.starts(in: kitchen)
        backStairs.starts(in: kitchen)
        cellarSteps.starts(in: kitchen)
        yardDoor.starts(in: kitchen)

        glove.starts(in: cellar)
        coalBin.starts(in: cellar)

        gardenWall.starts(in: backYard)
        dryGrass.starts(in: backYard)
        carriageHouseOutside.starts(in: backYard)

        toolRack.starts(in: carriageHouse)
        cot.starts(in: carriageHouse)
        stovePipe.starts(in: carriageHouse)

        workbench.starts(in: carriageHouse)
        can.starts(in: carriageHouse)
        debris.starts(in: carriageHouse)
        julian.starts(in: carriageHouse)

        // Off the map until the radio car brings him at 5:52.
        patrolman.starts(in: street)

        // Everyone starts where their own timetable says they are at 5:30, so
        // the opening tableau and the schedule can't disagree.
        teague.starts(in: teagueDay.location(at: clock.start))
        constance.starts(in: constanceDay.location(at: clock.start))
        kettle.starts(in: kettleDay.location(at: clock.start))
        delphine.starts(in: delphineDay.location(at: clock.start))
        pike.starts(in: pikeDay.location(at: clock.start))

        runner.starts(in: landing)

        desk.starts(in: study)
        ledger.starts(in: study)
        letters.starts(in: study)
        studyLamp.starts(in: study)

        typewriter.starts(in: boardersRoom)
        suitcase.starts(in: boardersRoom)
        sheet.starts(in: boardersRoom)
        bed.starts(in: boardersRoom)
    }
}

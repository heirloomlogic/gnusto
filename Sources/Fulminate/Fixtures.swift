import Gnusto

/// The nouns Fulminate's own prose puts on the page.
///
/// A room that names a thing and then doesn't know the word for it reads like a
/// bug, and the 2026-07-31 play-test round counted 261 unknown-word replies over
/// 59 distinct words the game itself had printed. Most of those close as a
/// synonym on something that already exists; these are the ones with nothing to
/// hang on, so they get an item of their own. None is a puzzle, none is
/// takeable, and none is listed — they exist so that `X PASSAGE` gets an answer
/// instead of *I don't know the word "passage"*.
///
/// They live in a ``GameContent`` bundle for the reason ``Gramarye``'s do: five
/// more items would otherwise push the host file further past two thousand
/// lines. The host places them, because a bundle can only place into rooms and
/// onto people it can *name*, and both are ``Fulminate``'s.
///
/// What is **not** here is anything whose text reads host state. The yard's fire
/// and the carriage house's shell both change at 5:46, so both live in the host
/// with the globals they branch on.
///
/// On what is declared and what is derived: a `name` already contributes its
/// last word as a noun and every earlier word as an adjective, so `name("pot")`
/// needs no `synonyms("pot")`. The extra lines are for the words the prose
/// prints that the name doesn't reach — and the last word of a typed phrase has
/// to be a noun, which is why several words declared as adjectives elsewhere in
/// this game are declared as synonyms here.
struct Fixtures: GameContent {
    // MARK: - The front hall

    /// The hall's description sends the player south down it, and the aftermath
    /// of the blast sends the dust along it, and until now neither sentence had
    /// a word behind it.
    let hallPassage = Item {
        name("passage")
        adjectives("kitchen", "service", "narrow")
        synonyms("passageway", "corridor", "hallway")
        description(
            """
            It runs back past the foot of the stairs to the kitchen door. The shortest \
            distance in this house between the people who live in it and the people who \
            are paid to be in it, and worn accordingly.
            """)
        scenery
    }

    // MARK: - The kitchen

    /// Mrs. Kettle's evening is measured against this: the pot goes on at a
    /// quarter to six, which is how she can put a time to Teague coming down her
    /// back stairs. Her departure line and three of her replies name it.
    let pot = Item {
        name("pot")
        adjectives("iron", "black", "supper")
        synonyms("pan", "stockpot", "supper", "stew")
        description(
            """
            Big enough for a household, and filled tonight for one fewer than that. It \
            goes on at a quarter to six. Mrs. Kettle can tell you the time by it and, \
            given the smallest opening, will.
            """)
        scenery
    }

    // MARK: - The yard

    /// As far into the evening as Mrs. Vane intends to go. Her arrival line and
    /// her presence line both put her on it and no further.
    let backStep = Item {
        name("step")
        adjectives("kitchen", "stone", "back")
        synonyms("steps", "doorstep", "threshold")
        description(
            """
            One worn stone outside the kitchen door, and the last swept thing between the \
            house and the grass. Everybody in this house has come out onto it tonight and \
            most of them have gone further.
            """)
        scenery
    }

    // MARK: - Worn and carried

    /// Named in Dr. Pike's `firstSight`, in his description, in his arrival in
    /// the yard and in Mrs. Kettle's testimony — five sentences across three
    /// rooms, and until now not a word any of those rooms knew.
    ///
    /// Placed `heldBy` him rather than in a room, because he takes it with him:
    /// `Visibility` counts what an actor standing in the room is holding, and
    /// `RoomDescriber` does not list it, so the word answers wherever he is and
    /// no room listing changes.
    let pikeHat = Item {
        name("hat")
        adjectives("grey", "gray", "felt", "stiff")
        synonyms("fedora", "brim", "hatband")
        description(
            """
            Grey felt, blocked stiff, and a size that was right for him some years ago. \
            It has not been off his head since he came, on the reasoning that taking it \
            off would mean he had arrived somewhere.
            """)
    }

    /// The patrolman's one instrument, and the thing he taps instead of opening
    /// when the player asks him for a statement.
    let policeNotebook = Item {
        name("notebook")
        adjectives("police", "pocket", "black")
        synonyms("notepad", "pocketbook")
        description(
            """
            Black, pocket-sized, with an elastic round it and everybody's name in it \
            including yours. He has not opened it since he wrote you down and does not \
            intend to in front of you.
            """)
    }

    /// Neither of the two is going to be handed over, and both refusals are in
    /// the voice of the man holding it. Declared here rather than in the host
    /// because neither reads a global.
    var rules: Rules {
        pikeHat.before(.take) {
            try refuse(
                """
                It is on his head, and nothing about the way he is wearing it suggests he \
                is waiting to be asked for it.
                """)
        }

        policeNotebook.before(.take) {
            try refuse("\"That one stays with me,\" the patrolman says, and it does.")
        }
    }
}

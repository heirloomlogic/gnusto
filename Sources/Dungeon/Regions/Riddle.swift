import Gnusto

/// The two rooms between the Engravings Cave and the well: the Riddle Room,
/// whose stone door will not open for anything but the right word, and the
/// Pearl Room behind it.
///
/// **Neither room reached the trilogy.** Zork I kept the Engravings Cave and
/// stopped there; the passage southeast out of it, the riddle, the door and the
/// pearls are all mainframe-only, so every line here is written fresh.
///
/// The region is two rooms because it is a corridor rather than a country: it
/// is the *approach*, the one road from the built dungeon into the well and
/// everything above it. Its own verb — the answer to the riddle — lives here
/// with the door it opens, which is the convention milestone 4 settled.
///
/// The seams the host wires are the Engravings Cave's southeast passage in
/// (a ``DungeonTemple`` room) and the Pearl Room's east door out onto the
/// bottom of the well (a ``DungeonAlice`` room).
struct DungeonRiddle: GameContent {
    // MARK: - Rooms

    /// `RIDDL`. Down to the Engravings Cave, east through the stone door.
    /// Always described, because whether the door is open is a fact the room's
    /// long description carries and a brief re-entry would hide.
    let riddleRoom = Location {
        name("Riddle Room")
        alwaysDescribed
        dark
    }

    /// `MPEAR`. A former broom closet with the pearls in it.
    let pearlRoom = Location {
        name("Pearl Room")
        description(Prose.pearlRoom)
        dark
    }

    // MARK: - State

    /// The mainframe's `RIDDLE-FLAG`: whether the door has been talked open.
    /// Nothing shuts it again.
    @Global var riddleAnswered = false

    // MARK: - Items

    /// `SDOOR`. Scenery rather than an `openable` door, because the exit it
    /// guards is conditional on the answer and not on the door's state — the
    /// source's own arrangement, where `RIDDL`'s east exit tests `RIDDLE-FLAG`
    /// and the door object only describes itself.
    let stoneDoor = Item {
        name("stone door")
        adjectives("great", "stone", "dressed")
        synonyms("door", "doorway", "stone")
        scenery
        door
    }

    let riddleLintel = Item {
        name("inscription")
        adjectives("cut", "carved")
        synonyms("lintel", "words", "word", "writing", "riddle", "wall", "walls")
        description(Prose.riddleInscription)
        scenery
    }

    /// The pearls. The mainframe pays **9** to find and **5** to case, which is
    /// the one treasure in this milestone whose find is worth more than its
    /// deposit.
    let pearlNecklace = Item {
        name("pearl necklace")
        adjectives("pearl")
        synonyms("necklace", "pearls", "pearl", "string")
        firstSight(Prose.pearlNecklaceFirstSight)
        description(Prose.pearlNecklace)
        trait(.weight, 10)
        trait(.takeValue, 9)
        trait(.depositValue, 5)
    }

    let pearlRoomShelves = Item {
        name("shelves")
        adjectives("bare", "empty")
        synonyms("shelf", "brackets", "bracket", "closet", "broom", "brooms")
        description(Prose.pearlRoomShelves)
        scenery
        plural
    }

    // MARK: - Map

    var map: WorldMap {
        // Down is the Engravings Cave, a ``DungeonTemple`` room — host-wired.
        // East is the Pearl Room, through a door that is shut until the riddle
        // is answered; the source's refusal is the invisible force, not the
        // door.
        riddleRoom.east(
            pearlRoom, when: { riddleAnswered }, otherwise: Prose.riddleBarred)

        pearlRoom.west(riddleRoom)
        // East is the bottom of the well, a ``DungeonAlice`` room — host-wired.

        stoneDoor.starts(in: riddleRoom)
        riddleLintel.starts(in: riddleRoom)
        pearlNecklace.starts(in: pearlRoom)
        pearlRoomShelves.starts(in: pearlRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        riddleRoom.describe { "\(Prose.riddleRoom)\n\n\(doorState)" }

        stoneDoor.describe { doorState }

        // `read the door` reaches the lintel, because the words are cut into
        // the stone above it and a player who names the door means the writing
        // on it. `read the inscription` needs no rule: the engine's own `read`
        // prints the item's description, which is the inscription.
        stoneDoor.before(.read) { try reply(Prose.riddleInscription) }

        // The one word the door is listening for. ``Intent/answer`` takes a
        // topic slot, so every word reaches this rule and the door does the
        // rejecting — which is the point: a wrong word costs the same turn the
        // right one does, and the parser gives nothing away. Promoted above
        // ``DungeonSystems``'s game-wide default with `reply`, so the shrug for
        // rooms that are not listening never prints in the one that is.
        riddleRoom.before(.answer) {
            guard let topic = command.topic else { return }
            try require(!riddleAnswered, else: Prose.riddleAlreadyAnswered)
            try require(topic.text == Prose.riddleWord, else: Prose.riddleWrongWord)
            riddleAnswered = true
            try reply(Prose.riddleAnswered)
        }

        // Hands are no use on it, and neither is a blade.
        stoneDoor.before(.open, .push, .pull, .attack) { try reply(doorState) }
    }

    /// What the door looks like from this side of it, said in three places.
    private var doorState: String {
        riddleAnswered ? Prose.riddleDoorOpen : Prose.riddleDoorShut
    }
}

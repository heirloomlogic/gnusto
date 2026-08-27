import Gnusto
import GnustoActors

/// The Endgame — the thirty-one rooms `dung.355` flags `RENDGAME`, worth the
/// last hundred points, plus the Tomb of the Unknown Implementer that is their
/// front door.
///
/// The shape of it, in the order a player meets it:
///
/// 1. **The Tomb**, east of the Land of the Living Dead, with four heads on
///    poles in it and a crypt behind a marble door. The door does not open
///    until the herald has been; before that every verb on it is fatal.
/// 2. **The Crypt**, which is the one endgame room with no light of its own.
///    Shut the door, put the lamp out, and three turns later you are somewhere
///    else with a lantern and a sword and nothing else.
/// 3. **The mirror box**, an enormous rotating box standing in a north-south
///    hallway, which is the only way past the Guardians of Zork.
/// 4. **The Dungeon Master's quiz** at the wooden door, three questions drawn
///    from eight.
/// 5. **The prison**, four corridors round a slot that eight cells take turns
///    in, and the bronze door of the fourth one.
///
/// **The whole region is one bundle.** Splitting it three ways would have cost
/// three `GameContent` conformances to buy nothing a reader wants: the five
/// stages below are one place in the fiction and share the box's state. Every
/// `map` and `rules` member below is a sub-builder in an extension.
///
/// **The mirror box is the Royal Puzzle's architecture, lifted.** One
/// ``insideMirror`` `Location` for the inside of the box wherever it stands,
/// the box's bearing and berth in a `@Global` struct, and everything that would
/// be an exit written as a `before(.go)` rule at stage 3. That is not a
/// coincidence of shape: `dung.355` owns both regions' directions the same way,
/// with a `CEXIT` on a flag that is never set — `FCHMP` in the Royal Puzzle and
/// **`FROBOZZ` here**. Every one of the atlas's `conditional (FROBOZZ)` exits is
/// the mainframe's idiom for "the room function owns this direction", which is
/// why the declared exit counts below are short of the atlas's and why the
/// difference is exactly the `FROBOZZ` rows.
///
/// Seams host-wired in ``Dungeon``: the Land of the Living Dead's east passage
/// into the Tomb, the herald's fuse and the score test that arms it, the six
/// room values, the lamp and the sword the transition hands back, and the
/// thief's daemon being switched off for good. See `Dungeon+Endgame.swift`.
struct DungeonEndgame: GameContent {
    // MARK: - The Tomb and the Crypt

    /// `TOMB`. **Not** a `RENDGAME` room and carrying no `RVAL` — it is the
    /// front door rather than part of the house. Dark, and not sacred, so the
    /// thief can walk in.
    let tomb = Location {
        name("Tomb of the Unknown Implementer")
        alwaysDescribed
        dark
    }

    /// `CRYPT`. Five points, and the only endgame room the source gives no
    /// light bit — which is the whole of the puzzle in it.
    let crypt = Location {
        name("Crypt")
        description(Prose.crypt)
        dark
    }

    // MARK: - The stairs and the antechamber

    /// `TSTRS`. Ten points, and arrived at by the transition rather than by
    /// walking, which is why its award is not a ``Scoring/visit(_:register:)``.
    let topOfStairs = Location {
        name("Top of Stairs")
        description(Prose.topOfStairs)
    }

    /// `MRANT`. The red button that opens the mirror is here, three rooms away
    /// from the beam it answers to.
    let stoneRoom = Location {
        name("Stone Room")
        description(Prose.stoneRoom)
    }

    /// `MREYE`. The red beam crosses this floor, and anything left lying on it
    /// breaks the beam.
    let smallRoom = Location {
        name("Small Room")
        alwaysDescribed
    }

    // MARK: - The hallway

    /// `MRA`, `MRB`, `MRC`, `MRG`, `MRD` — five rooms of one hallway under one
    /// name, south to north. `MRG` is the Guardians'.
    private static func hallway() -> Location {
        Location {
            name("Hallway")
            alwaysDescribed
        }
    }

    let hallwayA = hallway()
    let hallwayB = hallway()
    let hallwayC = hallway()
    let hallwayG = hallway()
    let hallwayD = hallway()

    /// The six narrow rooms a player can stand in, east and west of the first
    /// three hallway rooms. Reached only by squeezing past the end of the box,
    /// which is a `before(.go)` rule and not an exit.
    ///
    /// `alwaysDescribed` because the box is in the description and the box
    /// moves: the room has to say where it is standing every time, not only the
    /// first time.
    private static func narrowRoom() -> Location {
        Location {
            name("Narrow Room")
            alwaysDescribed
        }
    }

    /// The four flanking `MRG` and `MRD`. The Guardians kill on arrival, so
    /// nothing here is ever described, entered from, or walked out of — they
    /// exist so the atlas's nought-exit rooms exist and the box has somewhere to
    /// be seen from. No `alwaysDescribed`: a flag with nothing to print is a
    /// bootstrap warning, and rightly.
    private static func neverSeenNarrowRoom() -> Location {
        Location {
            name("Narrow Room")
        }
    }

    let narrowAEast = narrowRoom()
    let narrowAWest = narrowRoom()
    let narrowBEast = narrowRoom()
    let narrowBWest = narrowRoom()
    let narrowCEast = narrowRoom()
    let narrowCWest = narrowRoom()
    let narrowGEast = neverSeenNarrowRoom()
    let narrowGWest = neverSeenNarrowRoom()
    let narrowDEast = neverSeenNarrowRoom()
    let narrowDWest = neverSeenNarrowRoom()

    /// `INMIR`. Fifteen points, and one `Location` for the inside of the box
    /// wherever the box is standing — the Royal Puzzle's answer to the same
    /// question, and for the same reason: there is no destination to compute,
    /// because every move inside stays in this room.
    let insideMirror = Location {
        name("Inside Mirror")
        alwaysDescribed
    }

    // MARK: - The Dungeon Master's end

    /// `FDOOR`. Fifteen points. The wooden door in its north wall is the quiz.
    ///
    /// Described by a rule, and `alwaysDescribed` because of it: most of its
    /// paragraph is state. See ``Prose/dungeonEntrance(doorOpen:)``. (#332)
    let dungeonEntrance = Location {
        name("Dungeon Entrance")
        alwaysDescribed
    }

    /// `BDOOR`. Twenty points, and where the Dungeon Master is standing when
    /// the door finally opens.
    let narrowCorridor = Location {
        name("Narrow Corridor")
        description(Prose.narrowCorridor)
    }

    // MARK: - The prison

    let southCorridor = Location {
        name("South Corridor")
        alwaysDescribed
    }

    let northCorridor = Location {
        name("North Corridor")
        alwaysDescribed
    }

    let eastCorridor = Location {
        name("East Corridor")
        description(Prose.eastCorridor)
    }

    let westCorridor = Location {
        name("West Corridor")
        description(Prose.westCorridor)
    }

    /// `PARAP`. The sundial that picks a cell and the button that brings it in.
    let parapet = Location {
        name("Parapet")
        description(Prose.parapet)
    }

    /// `CELL`. The cell currently docked in the slot the four corridors ring —
    /// whichever of the eight it is.
    let prisonCell = Location {
        name("Prison Cell")
        alwaysDescribed
    }

    /// `NCELL`. Cell four, once it has been rotated out of the slot with you
    /// inside it. The bronze door is in the far wall.
    let winningCell = Location {
        name("Prison Cell")
        description(Prose.winningCell)
    }

    /// `PCELL`. Any other cell, once it has been rotated out of the slot with
    /// you inside it. Nought exits, which is the atlas's way of saying so.
    let lostCell = Location {
        name("Prison Cell")
        description(Prose.lostCell)
    }

    /// `NIRVA`. Thirty-five points, no exits, and the end of the game.
    let treasury = Location {
        name("Treasury of Zork")
        description(Prose.treasury)
    }

    // MARK: - The Tomb's furniture

    /// `TOMB`, the object. A slab of marble that `HEAD-FUNCTION` answers for
    /// until the herald has been.
    let cryptDoor = Item {
        name("crypt door")
        adjectives("marble", "heavy")
        synonyms("crypt", "door", "slab")
        openable
        scenery
    }

    /// `HEADS`. Touching, taking, attacking, burning, opening or rubbing them
    /// costs you everything of value you are carrying and then your life.
    let heads = Item {
        name("set of heads")
        adjectives("severed", "poled")
        synonyms("heads", "head", "poles", "pole", "implementers")
        description(Prose.tombHeads)
        scenery
    }

    /// `COKES`. `OSIZE 15`, and takable — the one thing in the Tomb that is.
    let cokeBottles = Item {
        name("bunch of Coke bottles")
        adjectives("empty", "coke")
        synonyms("bottles", "bottle", "coke", "cokes", "bunch")
        description(Prose.tombCokeBottles)
        trait(.weight, 15)
    }

    /// `LISTS`. `OSIZE 70`, readable and burnable.
    let listings = Item {
        name("stack of listings")
        adjectives("line-printer", "fanfold")
        synonyms("listings", "listing", "stack", "output", "paper")
        description(Prose.tombListings)
        trait(.weight, 70)
        trait(.burnable, true)
    }

    /// Three rooms name a flight of steps — the landing at the head of them,
    /// the Stone Room at the foot, and the parapet — so three rooms answer for
    /// one. `DungeonHouse`'s Kitchen staircase set the precedent.
    private static func steps() -> Item {
        Item {
            name("stairs")
            adjectives("stone", "long")
            synonyms("stair", "stairs", "staircase", "steps", "flight")
            description(Prose.endgameStairs)
            scenery
        }
    }

    let stairsAtTheTop = steps()
    let stairsAtTheBottom = steps()
    let stairsToTheParapet = steps()

    // MARK: - The beam and the button

    /// `RBEAM`. Broken by anything left lying on the floor of the Small Room.
    let redBeam = Item {
        name("red beam of light")
        adjectives("red", "thin")
        synonyms("beam", "light", "ray")
        scenery
    }

    /// `RSWIT`. Opens the mirror for seven turns, but only with the beam
    /// broken; otherwise it pops straight back out.
    let redButton = Item {
        name("red button")
        adjectives("red", "large")
        synonyms("button", "switch")
        description(Prose.stoneRoomButton)
        scenery
    }

    // MARK: - The channel

    /// `CHANN`. The source carries it as one global on `CHANBIT`, which covers
    /// `INMIR`, `MRA`, `MRB`, `MRC` and `MRD` — and, notably, not `MRG`. Gnusto
    /// has no global objects, so it is five scenery items over exactly those
    /// five rooms.
    private static func channel() -> Item {
        Item {
            name("stone channel")
            adjectives("stone", "narrow")
            synonyms("channel", "groove", "slot", "track")
            description(Prose.stoneChannel)
            scenery
        }
    }

    let channelA = channel()
    let channelB = channel()
    let channelC = channel()
    let channelD = channel()
    let channelInside = channel()

    // MARK: - The Guardians

    /// `GUARD`. The source's `GUARDBIT` puts them in ten rooms. Four of those
    /// kill you on arrival, two more are narrow rooms whose one shared
    /// description names nothing, and `MRD` is a room you only ever pass
    /// through in the box — so **one** object, in the hallway room a player can
    /// stand in and look north from.
    ///
    /// The count is not fastidiousness: an object in a room whose description
    /// never prints is a noun the player can name and nothing can answer.
    let guardians = Item {
        name("Guardians of Zork")
        adjectives("enormous", "stone")
        synonyms("guardians", "guardian", "statues", "statue", "figures")
        description(Prose.guardians)
        properName
        scenery
    }

    // MARK: - The box, from outside

    /// The box as it looks from the hallway, which is a different thing from
    /// the room that is the inside of it. One per room it can be seen from,
    /// because scope in this engine is per-room and the hallway's own
    /// description names it.
    ///
    /// **Nine, not eleven.** The Guardians' own hallway room gets none — its
    /// `onEnter` kills you before any description prints — and neither does
    /// `MRD`, which is only ever passed through inside the box. Worth saying
    /// rather than leaving to be noticed: both were once put down to issue
    /// #174's budget, and neither ever needed that excuse.
    private static func boxFromOutside() -> Item {
        Item {
            name("mirror box")
            adjectives("enormous", "rectangular", "mirrored")
            synonyms("box", "mirror", "mirrors")
            scenery
        }
    }

    let boxSeenFromA = boxFromOutside()
    let boxSeenFromB = boxFromOutside()
    let boxSeenFromC = boxFromOutside()
    let boxSeenFromAEast = boxFromOutside()
    let boxSeenFromAWest = boxFromOutside()
    let boxSeenFromBEast = boxFromOutside()
    let boxSeenFromBWest = boxFromOutside()
    let boxSeenFromCEast = boxFromOutside()
    let boxSeenFromCWest = boxFromOutside()

    /// The two rooms at the ends of the channel, which are not hallway rooms
    /// and see the box exactly as one. `angleOnTheBox` has always answered for
    /// both — `roomNorth(of:)` returns the Dungeon Entrance past the last berth
    /// and `roomSouth(of:)` the Small Room below the first — and only the item
    /// was missing, so the box was a thing the room could describe and the
    /// parser could not find. (#332)
    let boxSeenFromEntrance = boxFromOutside()
    let boxSeenFromSmallRoom = boxFromOutside()

    // MARK: - The box, from inside

    /// `OAKND`. Pushing it slides the box one room along the channel.
    let mahoganyEnd = Item {
        name("mahogany wall")
        adjectives("mahogany", "dark")
        synonyms("mahogany", "wall", "end")
        description(Prose.mahoganyEnd)
        scenery
    }

    /// `PINND`. Pushing it swings it open for five turns — and does it in the
    /// Guardians' sight, if the box is standing where they can see that end.
    let pineEnd = Item {
        name("pine wall")
        adjectives("pine", "pale")
        synonyms("pine", "wall", "end", "door")
        scenery
    }

    /// `MR1` and `MR2`. The first is the one the red button opens; both break,
    /// and breaking either loses the game.
    private static func mirrorPanel(_ ordinal: String) -> Item {
        Item {
            name("\(ordinal) mirror")
            adjectives(ordinal, "large")
            synonyms("mirror", "mirrors", "glass")
            scenery
        }
    }

    let mirrorOne = mirrorPanel("first")
    let mirrorTwo = mirrorPanel("second")

    /// `RDWAL`, `YLWAL`, `WHWAL`, `BLWAL`. Red and yellow turn the box
    /// clockwise, white and black counterclockwise.
    private static func panel(_ colour: String) -> Item {
        Item {
            name("\(colour) panel")
            adjectives(colour)
            synonyms("panel", "panels")
            scenery
        }
    }

    let redPanel = panel("red")
    let yellowPanel = panel("yellow")
    let whitePanel = panel("white")
    let blackPanel = panel("black")

    /// `LPOLE` and `SPOLE` in one. The source carries two objects for the two
    /// lengths of one pole; here `POLEUP` is the state and a `describe` rule
    /// reads it.
    let pole = Item {
        name("pole")
        adjectives("long", "short", "wooden")
        synonyms("pole", "rod", "shaft")
        scenery
    }

    /// `TBAR`. The handle the pole is raised and lowered by.
    let tBar = Item {
        name("crossbar")
        adjectives("iron", "t")
        synonyms("bar", "t-bar", "handle", "tbar", "crossbar")
        description(Prose.tBar)
        scenery
    }

    /// `WDBAR`. What holds the pine end shut.
    let woodenBar = Item {
        name("wooden bar")
        adjectives("wooden", "stout")
        synonyms("bar", "brace")
        description(Prose.woodenBar)
        scenery
    }

    /// `ARROW` and `ROSE` in one item, because they are one instrument: the
    /// arrow is the pointer and the rose is the dial it turns over. The five
    /// floor roses `ROSEBIT` carries in the hallway are not reproduced — see
    /// `FIDELITY.md`.
    let compassArrow = Item {
        name("compass arrow")
        adjectives("compass", "brass")
        synonyms("arrow", "rose", "compass", "dial", "needle")
        scenery
    }

    // MARK: - The doors

    /// `QDOOR`. The quiz is on the far side of it. Distinct from the Living
    /// Room's `WDOOR`, which is also a wooden door.
    let woodenDoor = Item {
        name("massive wooden door")
        adjectives("massive", "wooden", "oaken")
        synonyms("door", "doors")
        openable
        scenery
    }

    /// `CDOOR`. The ordinary door of whichever cell is in the slot.
    let cellDoor = Item {
        name("cell door")
        adjectives("cell", "barred")
        synonyms("door")
        description(Prose.cellDoor)
        openable
        scenery
    }

    /// `ODOOR`. Cell four's other door, and the only way into the Treasury.
    /// Hidden until cell four docks.
    let bronzeDoor = Item {
        name("bronze door")
        adjectives("bronze")
        synonyms("door")
        openable
        scenery
        hidden
    }

    /// `MDOOR` and `LDOOR` in one. Whichever cell rides out of the slot with
    /// you in it, the door you came through is locked behind you; the item
    /// follows the player into the cell that took them.
    let lockedCellDoor = Item {
        name("locked door")
        adjectives("locked", "iron")
        synonyms("door")
        description(Prose.lockedCellDoor)
        scenery
        // Never opens, so it is never an exit; still a door to knock on.
        door
    }

    /// The Parapet's own description names the pit it is a ledge over, and the
    /// pit is the whole reason the room reads as high up.
    let greatPit = Item {
        name("great pit")
        adjectives("great", "deep")
        synonyms("pit", "ledge", "drop", "shaft")
        description(Prose.parapetPit)
        scenery
    }

    /// The doorway each of the two corridors names, and the slot behind it.
    /// Two items rather than one because scope in this engine is per-room, and
    /// both corridors print the word.
    private static func slot() -> Item {
        Item {
            name("doorway")
            adjectives("cut", "stone")
            synonyms("doorway", "slot", "opening", "shaft")
            scenery
        }
    }

    let southSlot = slot()
    let northSlot = slot()

    // MARK: - The sundial

    /// `DIAL`. Eight numbers, one of which is the one with the bronze door.
    let sundial = Item {
        name("sundial")
        adjectives("stone", "sun")
        synonyms("dial", "sundial", "pointer")
        scenery
    }

    /// `NUMBERS`. The eight numerals around the dial's face, one object each.
    ///
    /// This engine hands a rule the *item* a noun resolved to and never the word
    /// the player typed, so a number the player can name has to be a thing that
    /// exists. Milestone 9 could not afford eight of them and the dial stepped
    /// instead, which cost the source's own `set dial to four`; issue #174 is
    /// fixed and they are back. Each answers its word and its digit, so `set dial
    /// to 4` works as well as `set dial to four`.
    ///
    /// - Parameter number: which numeral, from one to eight.
    /// - Returns: one numeral on the dial's face.
    private static func numeral(_ number: Int) -> Item {
        Item {
            // ``DungeonEndgame/numberWord(_:)`` is the one place the eight words
            // are spelled, so `read dial` and `set dial to …` cannot disagree.
            name(numberWord(number))
            synonyms("\(number)")
            description(Prose.sundialNumeral)
            scenery
        }
    }

    let numeralOne = numeral(1)
    let numeralTwo = numeral(2)
    let numeralThree = numeral(3)
    let numeralFour = numeral(4)
    let numeralFive = numeral(5)
    let numeralSix = numeral(6)
    let numeralSeven = numeral(7)
    let numeralEight = numeral(8)

    /// The numerals in dial order, so a resolved noun becomes a setting.
    var numerals: [Item] {
        [
            numeralOne, numeralTwo, numeralThree, numeralFour,
            numeralFive, numeralSix, numeralSeven, numeralEight,
        ]
    }

    /// `DBUTT`. Turns the carousel and brings the selected cell into the slot.
    let parapetButton = Item {
        name("large button")
        adjectives("large", "square")
        synonyms("button")
        description(Prose.parapetButton)
        scenery
    }

    /// One per corridor, because a scenery item stands in a room and the prison
    /// is four of them. The nouns are the ones the four descriptions print; the
    /// text is the same walls seen from anywhere in the square.
    private static func marbleWalls() -> Item {
        Item {
            name("marble walls")
            adjectives("polished")
            // "marble" twice over on purpose: the name makes it an adjective,
            // and the description calls the stuff itself marble, so it has to
            // be a noun too.
            synonyms("marble", "wall", "corridor", "hall")
            description(Prose.prisonMarble)
            plural
            scenery
        }
    }

    let southCorridorWalls = marbleWalls()
    let northCorridorWalls = marbleWalls()
    let eastCorridorWalls = marbleWalls()
    let westCorridorWalls = marbleWalls()

    // MARK: - The Treasury

    /// Not *treasure of the ages*, however much the room wants to call it that:
    /// a declared phrase is split exactly as player input is, so the article in
    /// the middle of it would put "the" into the item vocabulary and make the
    /// parser's own noise word untypeable. A fatal bootstrap diagnostic, and a
    /// good one.
    ///
    /// It answers for everything the room's first paragraph piles up, which is
    /// more nouns than it was since the description became the trilogy's.
    let hoard = Item {
        name("precious jewels")
        adjectives("vast", "heaped", "ancient", "rare")
        synonyms(
            "treasure", "treasures", "hoard", "gold", "jewel",
            "chests", "chest", "zorkmids", "paintings", "painting", "statuary",
            "curios", "wealth"
        )
        description(Prose.treasuryHoard)
        plural
        scenery
    }

    // The other two things the Treasury's description names. Nobody will ever
    // type them — the rule that wins the game is an `afterEachTurn`, so the room
    // describes itself and ends the story on the paragraph after — but a named
    // thing the parser does not know reads as a bug the one time somebody tries.

    let treasuryMap = Item {
        name("annotated map")
        adjectives("great")
        synonyms("empire")
        description(Prose.treasuryMap)
        scenery
    }

    let treasuryDesk = Item {
        name("desk")
        adjectives("far")
        synonyms("certificates", "certificate", "stock", "frobozzco")
        description(Prose.treasuryDesk)
        scenery
    }

    // MARK: - The Dungeon Master

    /// `MASTE`. He starts behind the wooden door and follows you from the
    /// Narrow Corridor onward, and he is the only actor in the game who takes
    /// an order and carries it out in a room you are not standing in.
    let dungeonMaster = Actor {
        name("dungeon master")
        adjectives("old", "robed")
        synonyms("master", "man", "dungeonmaster", "wizard", "staff")
        firstSight(Prose.dungeonMasterFirstSight)
        description(Prose.dungeonMaster)
        // He is the second actor in the game to take an order and the first to
        // carry one out somewhere the player cannot go. The whole prison turns
        // on it.
        takesOrders
    }

    // MARK: - State

    /// The box's bearing, berth, pole and glass, all in one struct: every read
    /// of a `@Global` decodes and every write encodes, so the box is touched
    /// once per rule body rather than field by field.
    @Global var box = MirrorBox()

    /// `END-GAME!-FLAG`. Set by the herald, and what makes the crypt door open.
    @Global var endgameBegun = false

    /// Whether the player has crossed into the endgame proper — the transition
    /// out of the dark crypt. Death is final from here on.
    @Global var pastTheCrypt = false

    /// Which of the three questions is being asked, which is also how many have
    /// been answered right — they only ever move together. `-1` is "not asking".
    @Global var quizAsked = -1

    /// How many wrong answers at this question. Five ends the examination, and
    /// a right answer puts it back to nothing.
    @Global var quizWrong = 0

    /// The three questions this run drew, in order. Empty until the first
    /// knock.
    @Global var quizPaper = QuizPaper()

    /// Whether a turn has passed since the question was last put. He asks again
    /// every second one, so one bit is the whole of his patience.
    @Global var quizWaitedATurn = false

    /// Whether the wooden door has been won.
    @Global var quizWon = false

    /// Which of the eight cells the sundial is pointing at, and which is
    /// currently docked in the slot. `0` is "none docked".
    @Global var dialSetting = 1
    @Global var dockedCell = 0

    /// Whether the Dungeon Master has been told to stay put.
    @Global var masterStaying = false

    /// The plugin the Dungeon Master's following daemon is built from. A
    /// `GamePlugin` owns no state and registers nothing, so a bundle may hold
    /// its own rather than reach for the host's — `Dungeon` has one too, for
    /// the thief.
    let actors = ActorBehaviors()

    /// How brightly the sword was glowing when it was last reported: 0 not at
    /// all, 1 faintly, 2 fiercely. A warning that repeats every turn stops
    /// being a warning, so the daemon speaks only when this changes.
    @Global var swordGlow = 0
}

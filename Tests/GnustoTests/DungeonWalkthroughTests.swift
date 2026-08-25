import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Dungeon

/// Milestone 8's acceptance test: one scripted playthrough of *Dungeon* from
/// West of House to **616 of 616**, which is the mainframe's `SCORE-MAX` — the
/// whole main dungeon, thirty-two treasures cased and every room value paid.
///
/// **Why it exists.** Each of milestone 8's pieces has its own transcript test,
/// and each proves its own points are payable. What none of them proves is that
/// the thirty-one they add are payable *in the same run as the other 585* —
/// which is the only claim that matters, because the endgame's entry gate
/// (`SCORE-BLESS`, `rooms.394:794`) tests the score and nothing else. This is
/// the test that makes the claim.
///
/// **The seed.** Seed 52, and it matters only until the thief falls in stage 2.
/// The route takes the egg and nothing else above ground, so he stays offstage
/// — drawing nothing from the seeded stream — until the Treasure Room summons
/// him. After his death the only randomness left is the Round Room's carousel,
/// which stage 9 gambles four times before it is spat out at the Engravings
/// Cave.
///
/// It was seed 2 until #237 gave the troll and the thief a strike-first
/// probability, which moved every draw in the game. 52 was found the way the
/// original was — by brute-force scan — and it is the *only* seed below 400 this
/// route wins on, which is a narrower margin than it sounds and is discussed at
/// stage 2.
///
/// **The shape of it.** Stages 1 to 14 are the 585-point route milestone 7
/// left, with three commands added: `send for brochure` on turn one, the
/// skeleton keys picked up in Maze-5 (a room the route already stood in), and a
/// walk to the mailbox on the way home in stage 3 for the brochure's stamp and
/// the welcome mat. Stage 15 is milestone 8's own, and it is an appendix rather
/// than an insertion on purpose: the palantir wing is two puzzles at opposite
/// corners of the map, neither of them on the way to anything else, and folding
/// them into the tuned middle of the route would only have picked a fight with
/// the carrying cap. By stage 15 everything else is cased and the hands are
/// empty.
///
/// **The rope is why the appendix works at all.** Stage 4 ties it to the Dome
/// Room's railing and never unties it, so the drop into the Torch Room stays
/// open for the rest of the game. Stage 15 walks back down it, does the wing,
/// leaves the Torch Room the one way there is, and collects the rope on the
/// way past — from the **rim**, on a five-move detour off the Deep Ravine,
/// because a knot at the railing is not something you can reach from the floor
/// below (#286). Then to the head of the coal chute, where it is tied to the
/// broken timber and dropped, because the grip clock is `100 / carried weight`
/// and the descent is four moves.
///
/// A copy of the same script, playable by hand, is
/// `.context/walkthrough/route-616.txt` (gitignored working state); this file
/// is the committed one.
struct DungeonWalkthroughTests {
    /// The pinned seed. See the type doc.
    static let seed: UInt64 = 52

    @Test func theWholeMainDungeonScoresSixHundredAndSixteen() async throws {
        let transcript = try await play(Dungeon(), Self.route, seed: Self.seed)

        // Every checkpoint the route stops to read its own score at, in order.
        // Between them, the four lines that are milestone 8's whole claim.
        expectInOrder(
            transcript,
            [
                "Your score is 81 of a possible 716",
                // Stage 3: the stamp is cased, and it is worth exactly one.
                "Your score is 111 of a possible 716",
                // Stage 15 — the palantir wing.
                "Tiny Room",
                "There is a faint noise from the far side of the door",
                "As the mat comes up, a rusty iron key slides off it",
                "Something turns over inside the door, and the lock gives.",
                "Dreary Room",
                "In the center of the table sits a blue crystal sphere.",
                "You are hanging on a rope",
                "Slide Ledge",
                "Sooty Room",
                "There is a beautiful red crystal sphere here.",
                "Your score is 616 of a possible 716",
            ])

        // And the grip never failed: the descent was walked, not sightseen.
        #expect(!transcript.contains("Your grip goes"))
    }

    /// Milestone 9's acceptance test, and the one #189 asked for: the same run
    /// carried through the endgame to **716 of 716**, which is `SCORE-MAX` plus
    /// `EG-SCORE-MAX` — everything the game can pay.
    ///
    /// It is ``route`` with an appendix and nothing else changed. The appendix
    /// is assembled from the four segments `DungeonEndgameTests` keeps, because
    /// each of them is separately a test's subject there and a route written out
    /// twice is a route that drifts: the fifteen turns the herald takes and the
    /// walk to the Tomb, the crypt, the mirror box, the examination, the prison.
    ///
    /// **Why the endgame is an appendix rather than an insertion** needs no
    /// argument here, unlike milestone 8's: `SCORE-BLESS` will not arm the
    /// herald below the full 616, so there is nowhere else it could go.
    @Test func theWholeGameThroughTheEndgameScoresSevenHundredAndSixteen() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonEndgameTests.pastTheCrypt
                + DungeonEndgameTests.throughTheBox
                + DungeonEndgameTests.theQuiz
                + DungeonEndgameTests.thePrison,
            seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "Your score is 616 of a possible 716",
                "You are one of the chosen of Zork",
                "Tomb of the Unknown Implementer",
                "The door must weigh a ton",
                "You have passed",
                "Top of Stairs",
                "The button clicks",
                "Inside Mirror",
                "The box slides smoothly",
                "Dungeon Entrance",
                "You may pass.",
                "Narrow Corridor",
                "Parapet",
                "the whole cell begins to move",
                "Treasury of Zork",
                "You are Master of the Dungeon.",
                "Your score is 716 of a possible 716",
            ])

        // Nothing in the endgame was survived by accident: no death, and so no
        // resurrection covering one up.
        #expect(!transcript.contains("*** You have died ***"))
    }

    /// The whole script, stage by stage. Comments are the route's own.
    static let route: [String] = [
        // Stage 1: the brochure ordered, the egg, the house, the cellar
        "send for brochure", "north", "north", "up", "take egg",
        "down", "east", "southwest", "open window", "west",
        "open sack", "take garlic", "west", "take lamp",
        "take sword", "turn on lamp", "open case", "push rug",
        "open trap door", "down",

        // Stage 2: the troll, the maze, the cyclops, the thief and the egg.
        //
        // The fights budget exactly the blows they need and no spares, which
        // costs this route a seed hunt it could otherwise have skipped. A swing
        // at something already dead is `cantSeeAnySuchThing`, a `freeReply` that
        // burns no turn and no draw, so spares looked free — and in stream terms
        // they are. They are not free in *transcript* terms: this route is what
        // `DungeonEndgameTests.intoTheEndgame` is built from, and three of the
        // tests riding it are `expectEveryNounAnswered` tests, which scan the
        // whole transcript for that very line. A spare swing there is
        // indistinguishable from a noun the game failed to answer, which is the
        // one thing those tests exist to catch. Measured over seeds 0–399: with
        // spares eight of them win, without them one does. The one is this one.
        "east", "attack troll with sword", "attack troll with sword",
        "south", "south", "east", "up", "take keys", "southwest",
        "east", "south", "northeast", "odysseus", "up",
        "give egg to thief", "down", "wait", "wait", "wait", "wait",
        "up", "attack thief with sword", "take chalice", "take egg",
        "take canary", "score",

        // Stage 3: home by the Strange Passage; the first four treasures
        // cased
        "down", "north", "east", "turn off lamp",
        "put chalice in case", "put egg in case", "east", "east",
        "north", "north", "wind canary", "take bauble", "west",
        "east", "west", "west", "put canary in case",
        "put bauble in case",

        // The post has been and gone. Out to the mailbox for the brochure's
        // stamp, and for the welcome mat, which the oak door in the Tiny
        // Room needs.
        "east", "east", "north", "west", "open mailbox", "take mat",
        "take stamp", "north", "east", "west", "west",
        "put stamp in case",

        // The mat and the keys wait here until stage 15 needs them; both are
        // dead weight until the oak door is in front of you.
        "drop mat", "drop skeleton keys", "score",

        // Stage 4: the ivory torch takes over the lamp's work
        "drop sword", "drop garlic", "turn on lamp", "east", "up",
        "take rope", "down", "west", "open trap door", "down",
        "east", "north", "down", "west", "east",
        "tie rope to railing", "down", "take torch", "turn off lamp",

        // The rope stays up at the railing, and there is nothing to put down:
        // tying it is what takes it out of your hands. This line used to be
        // `drop rope`, which only worked because the coil rode down here in a
        // pocket while the room described it hanging overhead (#286). The knot
        // is never undone here, so the Dome Room's drop stays open — which is
        // what lets stage 15 come back down for the room west of here.
        "score",

        // Stage 4b: the Loud Room, Flood Control Dam #3 and the reservoir
        "down", "east", "north", "down", "east", "east", "northeast",
        "echo", "take bar", "up", "east", "north", "take matchbook",
        "north", "push yellow button", "take wrench",
        "take screwdriver", "south", "south",
        "turn bolt with wrench", "drop wrench", "south", "northwest",
        "north", "take trunk", "north", "north", "up", "north",
        "rub mirror", "north", "north", "up", "score",

        // Stage 5: the exorcism at the gate of Hades, then home by the
        // granite wall
        "drop trunk", "drop bar", "take bell", "east", "take book",
        "take candles", "west", "west", "east", "south", "down",
        "ring bell", "take candles", "light match",
        "burn candles with match", "read book", "east", "west", "up",
        "north", "north", "up", "drop book", "drop candles",
        "take trunk", "take bar", "treasure", "down", "north",
        "east", "put bar in case", "put trunk in case", "score",

        // Stage 6: the coal mine — the bat, the gas room, the shaft and the
        // machine
        "take garlic", "west", "south", "up", "temple", "west",
        "east", "southwest", "rub mirror", "west", "west", "north",
        "northwest", "west", "take jade", "east", "south",
        "northeast", "put torch in basket", "turn on lamp", "north",
        "west", "down", "take bracelet", "up", "east", "northeast",
        "north", "northeast", "northwest", "down", "down",
        "northeast", "take coal", "south", "up", "up", "east",
        "east", "south", "put coal in basket",
        "put screwdriver in basket", "lower basket", "north",
        "northeast", "north", "northeast", "northwest", "down",
        "down", "south", "drop all", "southwest", "score",
        "take coal", "take screwdriver", "take torch", "east",
        "open machine", "put coal in machine", "close machine",
        "turn switch with screwdriver", "open machine",
        "take diamond", "northwest", "put all in basket",
        "northeast", "take lantern", "take jade", "take bracelet",
        "take garlic", "take matchbook", "north", "up", "up", "east",
        "east", "south", "raise basket", "take diamond",
        "take torch", "take screwdriver", "turn off lamp", "score",

        // Stage 7: out of the mine by the mirrors, the grail on the way,
        // four cased
        "west", "south", "east", "east", "rub mirror", "north",
        "north", "take grail", "up", "treasure", "down", "north",
        "east", "drop garlic", "drop screwdriver",
        "put jade in case", "put bracelet in case",
        "put diamond in case", "put grail in case", "score",

        // Stage 8: the Gallery's painting, the Bank of Zork, and the bag of
        // coins
        "drop lantern", "open trap door", "down", "south", "south",
        "take painting", "west", "northwest", "west", "south",
        "take portrait", "north", "walk through curtain",
        "walk through curtain", "walk through curtain", "take bills",
        "walk through east wall", "south", "north", "north", "east",
        "south", "south", "east", "up", "take bag", "southwest",
        "east", "south", "northeast", "north", "east",
        "put portrait in case", "put canvas in case",
        "put bills in case", "put bag in case", "score",

        // Stage 9: the carousel, the riddle, the well, the tea party and the
        // robot
        "east", "take bottle", "open bottle", "west",
        "open trap door", "down", "east", "north", "east",

        // The Round Room turns under you: four tries to be spat out at the
        // Engravings Cave, walking back to the carousel after each one.
        "north", "south", "north", "west", "north", "east", "north",
        "east", "north", "north", "west", "north",

        // The riddle, the Pearl Room, and up the well in the bucket
        "southeast", "answer well", "east", "take necklace", "east",
        "board bucket", "pour water in bucket", "get out", "east",

        // The Low Room, the robot and the three buttons
        "northwest", "robot, north", "north",
        "push triangular button", "robot, south", "south",
        "take sphere", "robot, lift cage", "north", "west",
        "northwest",

        // Four inches high, under the tea table, for the tin of spices
        "take eat-me cake", "take red cake", "take orange cake",
        "eat eat-me cake", "east", "throw red cake in pool",
        "take tin", "west", "eat orange cake",

        // Down the well again, and out by a Round Room that has stopped
        // turning
        "west", "board bucket", "empty bucket", "get out", "west",
        "west", "down", "north", "open box", "take violin", "east",
        "up", "treasure", "down", "north", "east",
        "put necklace in case", "put sphere in case",
        "put tin in case", "put violin in case", "score",

        // Stage 10: Atlantis for the trident, the Egyptian Room for the
        // coffin
        "drop eat-me cake", "drop orange cake", "drop bottle",
        "drop matchbook", "west", "south", "up", "temple", "west",
        "east", "southwest", "rub mirror", "east", "down",
        "take trident", "southeast", "south", "south", "west",
        "take wire", "north", "east", "take coffin", "up", "north",
        "east", "north", "north", "north", "up", "north",
        "rub mirror", "north", "north", "up", "treasure", "down",
        "north", "east", "drop wire", "put trident in case",
        "put coffin in case", "score",

        // Stage 11: the shovel, the pump, the Frigid River, the beach and
        // the rainbow
        "open trap door", "down", "east", "north", "down", "east",
        "east", "northeast", "east", "east", "take shovel",
        "northwest", "south", "up", "east", "south", "northwest",
        "north", "north", "take pump", "south", "south", "up",
        "east", "down", "inflate plastic with pump", "drop pump",
        "take stick", "put stick in boat", "board boat", "launch",
        "down", "down", "down", "take buoy", "west", "take stick",
        "get out", "open buoy", "take emerald", "drop buoy",
        "dig sand with shovel", "dig sand with shovel",
        "dig sand with shovel", "dig sand with shovel",
        "take statue", "drop shovel", "south", "south", "wave stick",
        "east", "east", "take pot", "drop stick", "southeast", "up",
        "up", "west", "west", "north", "east", "west", "west",
        "put emerald in case", "put statue in case",
        "put pot in case", "score",

        // Stage 12: the Royal Puzzle, and the gold card under the sandstone
        // block
        "west", "south", "up", "east", "down", "push south", "east",
        "southeast", "east", "push south", "take card", "north",
        "north", "north", "push east", "southwest", "southwest",
        "northwest", "northwest", "push east", "south", "southeast",
        "southeast", "push south", "east", "northeast", "north",
        "north", "push west", "northwest", "push south",
        "push south", "push south", "push east", "south", "south",
        "push west", "push north", "northeast", "push west",
        "push west", "southeast", "push west", "push west",
        "push north", "push north", "push north", "northwest", "up",
        "west", "down", "north", "east", "put card in case", "score",

        // Stage 13: the glacier, the Ruby Room and the volcano
        "take lantern", "take matchbook", "take wire",
        "take newspaper", "turn on lamp", "east", "up", "take brick",
        "down", "west", "open trap door", "down", "east", "north",
        "down", "west", "northwest", "up", "throw torch at glacier",
        "west", "take ruby", "west", "south", "board basket",
        "put newspaper in receptacle", "burn match",
        "burn newspaper with match", "look", "wait", "wait", "wait",
        "wait", "west", "tie braided wire to hook", "get out",
        "take coin", "south", "read purple book", "take stamp",
        "north", "board basket", "untie braided wire", "launch",
        "wait", "wait", "wait", "wait", "wait", "wait", "east",
        "tie braided wire to hook", "get out", "south",
        "put brick in hole", "put wire in brick", "burn match",
        "burn wire with match", "north", "wait", "south",
        "take crown", "north", "board basket", "untie braided wire",
        "launch", "close receptacle", "wait", "wait", "wait", "wait",
        "wait", "wait", "wait", "wait", "wait", "wait", "wait",
        "wait", "look", "score",

        // Stage 14: out of the volcano, the quenched torch off the bank, and
        // home
        "north", "west", "south", "north", "take torch", "east",
        "north", "north", "north", "up", "north", "rub mirror",
        "north", "north", "up", "treasure", "down", "north", "east",
        "put ruby in case", "put zorkmid in case",
        "put flathead stamp in case", "put crown in case",
        "put torch in case", "score",

        // Stage 15: the palantir wing — the Tiny Room, the Dreary Room, the
        // coal chute and the Sooty Room. Kept to the end on purpose. The
        // wing is two puzzles at opposite corners of the map and neither is
        // on the way to anything else, so folding it into the tuned middle
        // of this route would only have cost the carrying cap a fight it
        // does not need to have. Everything else is cased; the lamp is lit
        // and the hands are otherwise empty.
        "take mat", "take skeleton keys", "open trap door", "down",
        "east", "north", "down", "west", "east", "down",

        // The oak door. Open the near lid, slide the mat under the door, and
        // punch the key out of the far keyhole with the skeleton keys —
        // which will not turn the lock themselves. The mat is what the key
        // lands on.
        "west", "open lid", "put mat under door",
        "put skeleton keys in keyhole", "take mat", "take rusty key",
        "take skeleton keys", "unlock door with rusty key",
        "open door", "north", "take blue sphere", "south",
        "drop mat", "drop skeleton keys", "drop rusty key", "east",

        // Out of the Torch Room the only way there is, and round to the coal
        // mine for the broken timber. The reservoir has been drained since
        // stage 4b.
        //
        // The five-move detour off the Deep Ravine is where the rope is
        // collected. It cannot be picked up in the Torch Room: the knot is at
        // the railing twenty feet overhead, which is what the room's own
        // paragraph and its blocked `up` have always said (#286). So the wing
        // is walked first and the rope taken afterwards, from the rim — which
        // unties it and shuts the drop behind the last visit that needed it.
        "down", "east", "north", "down",
        "west", "east", "take rope", "east", "west",
        "east", "east", "northeast",
        "up", "east", "south", "northwest", "north", "north",
        "north", "up", "north", "west", "west", "north", "northeast",
        "north", "northeast", "north", "northeast", "northwest",
        "down", "down", "south", "take timber", "north", "up", "up",
        "east", "east", "south", "west", "south",

        // The head of the chute. Tie the rope to the timber on the ground,
        // put down everything the climb does not need — the grip clock is a
        // hundred divided by what you are carrying, and the descent is four
        // moves — and go. The coil goes down too: it holds whether or not
        // you are holding it, and its weight is a quarter of the clock.
        "drop timber", "tie rope to timber", "drop rope",
        "drop blue sphere", "down", "down", "down", "east", "south",
        "take red sphere", "north", "up", "up", "up",
        "take blue sphere",

        // Home by the mirrors and the granite wall.
        "east", "east", "rub mirror", "north", "north", "up",
        "treasure", "down", "north", "east",
        "put blue sphere in case", "put red sphere in case", "score",
        "score", "quit", "y",
    ]
}

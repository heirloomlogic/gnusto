/// Prose for the underground crossroads (``DungeonRoundRoom``): the East-West
/// Passage, the Round Room and its carousel, the North-South Passage, the Deep
/// Ravine, the Chasm, Deep Canyon, the Loud Room and the Damp Cave.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
extension Prose {
    // MARK: - East-West Passage

    /// Verbatim. `PASS1` is in the comparison's `identical` bucket, and the
    /// room is the same room: a narrow east-west corridor with a stair at its
    /// north end. Only the destination at the foot of the stair differs.
    static let eastWestPassage = """
        This is a narrow east-west passageway. There is a narrow stairway
        leading down at the north end of the room.
        """

    static let eastWestStairway = """
        A narrow stair going down at the north end of the passage, cut rather
        than built, and steep with it.
        """

    // MARK: - The Round Room

    /// Adapted. Zork I's line — "a circular stone room with passages in all
    /// directions. Several of them have unfortunately been blocked by
    /// cave-ins" — describes a junction with three ways out. The mainframe's
    /// has eight, none of them blocked, and a machine under the floor turning
    /// all of them. The voice is the trilogy's; the facts are the source's.
    static let roundRoom = """
        This is a circular stone room with passages leading off in eight
        directions. Somewhere beneath the floor, machinery whirs.
        """

    /// The same room once the triangular button in the Machine Room has
    /// stopped the machinery. Milestone 5 built that button, and a room that
    /// went on whirring afterwards would be telling the player their own
    /// solution had not worked.
    static let roundRoomStilled = """
        This is a circular stone room with passages leading off in eight
        directions. Beneath the floor, the machinery that turned it has
        stopped.
        """

    /// Written fresh. The mainframe prints a second line while the carousel
    /// turns, and this is that beat in this game's own words.
    static let roundRoomCompass = """
        Your compass needle swings from one passage to the next and will not
        settle on any of them.
        """

    /// The eight passages, in two states. This room's entire description is
    /// about them and the word went unanswered; and a constant here would be
    /// the defect the room was already repaired for once, since which of the
    /// eight goes where is exactly what the machine underfoot is changing.
    /// (#233)
    static let roundRoomPassages = """
        Eight mouths of stone, evenly spaced around the wall, and no way to tell
        one from another while the floor is turning under them.
        """

    static let roundRoomPassagesStopped = """
        Eight mouths of stone, evenly spaced around the wall, and standing still
        at last long enough to be counted.
        """

    static let roundRoomMachinery = """
        Whatever is turning under the floor is bedded too deep to see and too
        steady to argue with. It sounds enormous, and it sounds patient.
        """

    static let roundRoomMachineryStopped = """
        Whatever was turning under the floor is bedded too deep to see, and it
        is not turning now.
        """

    /// Written fresh. Where the mainframe tells you plainly that directions
    /// cannot be told apart in here, this says the same thing in the trilogy's
    /// register.
    static let roundRoomNoBearings = """
        You set off confidently, and the room turns under you as you go. Which
        passage you actually took is anybody's guess.
        """

    // MARK: - North-South Passage

    /// Verbatim. `PASS5` is `identical`, and the fork northeast is the same
    /// fork — it simply reaches the Loud Room here rather than Deep Canyon.
    static let nsPassage = """
        This is a high north-south passage, which forks to the northeast.
        """

    static let passageFork = """
        The passage splits here, and the northeast branch carries a noise the
        other one does not.
        """

    // MARK: - Deep Ravine

    /// Written fresh — mainframe-only room. Zork I has no counterpart: the
    /// crossing where the east-west crawl meets the ravine, with stone steps
    /// south and a staircase falling away to the reservoir.
    static let deepRavine = """
        This is a deep ravine, crossed here by a crawlway running east and
        west. Stone steps climb out of it to the south, and a steep stair
        drops away into the dark below.
        """

    static let ravine = """
        The ravine falls away below the crossing, and the staircase cut into
        its side goes down further than the light reaches.
        """

    // MARK: - Chasm

    /// Adapted. The trilogy's Chasm has the path "follow it" and a crack
    /// opening into a passage, because Zork I gave the room four ways out. The
    /// mainframe's has two: south and east. The chasm itself is unchanged.
    static let chasmRoom = """
        A chasm runs southwest to northeast and the path follows it. You are
        on the south side of the chasm, where the path leaves south and east.
        """

    static let chasmScenery = """
        The chasm runs off in both directions, and the bottom of it is a
        rumour.
        """

    /// Distinct from ``chasmDownRefusal``, which is West of Chasm's answer two
    /// regions away: this chasm is a different chasm and refuses differently.
    static let chasmRoomDownRefusal = "Are you out of your mind?"

    // MARK: - Deep Canyon

    /// Adapted. Zork I's Deep Canyon leads "east, northwest and southwest" with
    /// a stairway down to the Loud Room. The mainframe's has three passages and
    /// no stair: east to the dam, northwest down to the reservoir, and south to
    /// the Round Room. The water below is the reservoir, not the Loud Room.
    static let deepCanyon = """
        You are on the south edge of a deep canyon. Passages lead off to the
        east, northwest and south. Somewhere below, a great deal of water is
        moving.
        """

    static let canyonScenery = """
        The canyon drops away northward, and somewhere down it water is moving
        — a great deal of water, by the sound.
        """

    // MARK: - Loud Room

    /// Adapted. The first two sentences are the trilogy's, unchanged. The
    /// third is this game's own, because the mainframe's Loud Room is loud
    /// from the first moment rather than only while the sluice gates run — its
    /// room routine never consults the gates at all.
    static let loudRoom = """
        This is a large room with a ceiling which cannot be detected from
        the ground. There is a narrow passage from east to west and a stone
        stairway leading upward. The noise in here is past bearing; it is
        difficult to hear yourself think.
        """

    static let loudRoomCeiling = """
        You cannot find the ceiling at all. Whatever is up there is what keeps
        throwing your own voice back down at you.
        """

    /// The room's read-loop: the walls fling the last word of your command
    /// back at you.
    static func loudRoomEcho(_ word: String) -> String {
        "The acoustics of the room cause your words to echo: \u{201C}\(word)... \(word)... \(word)...\u{201D}"
    }

    static let loudRoomAcousticsFixed = """
        The acoustics of the room change subtly.
        """

    // MARK: - The platinum bar

    static let platinumBarFirstSight = "On the ground is a large platinum bar."

    static let platinumBar = """
        A bar of solid platinum, the length of your forearm and heavier than it
        has any business being.
        """

    /// The bar is sacred while the room roars — the original's `SACREDBIT`.
    static let platinumBarTooLoud = """
        The room's ear-splitting roar shakes the bar from your grip; you
        cannot get hold of it while the acoustics rage.
        """

    // MARK: - Damp Cave

    /// Adapted. The trilogy's Damp Cave exits west and east and narrows to the
    /// south. The mainframe's exits south and east — east onto the top of the
    /// dam — and narrows to the west. Same cave, mirrored.
    static let dampCave = """
        This cave has exits to the south and east, and narrows to a crack
        toward the west. The earth is particularly damp here.
        """

    static let dampEarth = """
        The earth underfoot is soaked through, and there is water somewhere
        close on the other side of the rock.
        """

    static let dampCaveTooNarrow = "It is too narrow for most insects."

    // MARK: - What the carousel was hiding

    /// Verbatim — `IRBOX` is one of the comparison's `identical` entries.
    static let steelBoxFirstSight = "There is a dented steel box here."

    static let steelBox = """
        A steel box, badly dented down one side, of the sort that gets shipped
        and not carried.
        """

    /// Verbatim — `STRAD` is `identical` too, and the joke in it is the
    /// source's.
    static let violinFirstSight = "There is a Stradivarius here."

    static let violin = """
        A violin in a case lined with felt, and the label glued inside it says
        exactly what you were hoping it would say.
        """
}

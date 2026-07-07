/// Placeholder prose for the cellar region (``ZorkCellar``): East of Chasm,
/// the Gallery and its painting, the Studio and its chimney, the Troll Room,
/// and the two villains who work the region — the troll and the reduced
/// thief. See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Cellar region

    static let eastOfChasm = """
        You stand at the east edge of a chasm whose floor, if it has one,
        is lost in the dark below. A passage climbs back north toward
        the cellar, and another leads east.
        """

    static let chasm = """
        The chasm's far wall is barely visible. Nothing thrown in has
        ever been heard to land.
        """

    static let gallery = """
        This room was once a gallery: picture hooks and pale rectangles
        mark the walls where art used to hang. Daylight filters in from
        somewhere high above. Openings lead west and north.
        """

    static let paintingFirstSight = """
        One painting still hangs here, overlooked or abandoned — clearly
        the work of a master.
        """

    static let painting = """
        A landscape in oils, luminous even under its coat of dust. It
        must be worth a fortune.
        """

    static let studio = """
        This cramped room was an artist's studio, its floor and walls
        stained with old paint. A dark, sooty chimney climbs up one
        wall; the only other way out is a doorway south.
        """

    static let chimney = """
        The chimney is narrow, but the soot-blackened brick offers
        plenty of holds. It looks climbable — upward, at least.
        """

    // MARK: - The Troll Room
    //
    // Original prose only, as ever: the troll's name and his room's name
    // are fair game; Infocom's sentences are not.

    static let trollRoom = """
        A low, foul-smelling chamber of rough stone. Passages lead east
        and west, and the way south climbs back toward the cellar. Deep
        gouges in the walls were not made by anything friendly.
        """

    static let troll = """
        A mountain of gristle and bad temper, keeping his axe between
        you and everywhere you might want to go.
        """

    static let trollPresence = """
        A troll stands square in the middle of the room, axe up, daring
        you to try a passage.
        """

    static let trollBlocksTheWay = """
        The troll plants himself in your path, axe raised. Nobody is
        going that way while he stands.
        """

    static let trollMiss1 = "Your blade whistles past the troll's ear; he doesn't blink."
    static let trollMiss2 = "The troll turns your swing aside with the flat of his axe."
    static let trollWound1 = "You open a gash along the troll's arm. He notices."
    static let trollWound2 = "Your blade bites the troll's shoulder; he bellows."
    static let trollKnockout = """
        The pommel catches the troll square on the skull, and he sits
        down hard, eyes crossing.
        """
    static let trollDeath = """
        Your final stroke drops the troll where he stands. The body
        sinks into the shadows of the floor and is gone.
        """

    static let trollSwipeMiss = "The troll's axe hisses over your head."
    static let trollSwipeWound = "The troll's axe grazes you, and it is not a light graze."
    static let trollKillsYou = """
        The axe comes around one last time, and the argument is settled
        the troll's way.
        """

    // MARK: - The thief
    //
    // Reduced this phase: he roams the cellar region, bars the trap door
    // from below, and picks pockets. His maze, treasure room, stiletto,
    // and egg-opening services are later phases — see `FIDELITY.md`.

    static let thief = """
        A lean figure in patched leather, hands never quite still. His
        eyes have already priced everything you carry.
        """

    static let thiefPresence = """
        A shadowy figure leans against the wall here, idly rolling
        something small and probably yours across his knuckles.
        """

    static let thiefArrives = "A shadowy figure slips into the room."
    static let thiefLeaves = "The shadowy figure melts away into the dark."

    static func thiefSteals(_ name: String) -> String {
        "A feather-light touch at your pack — and the \(name) is gone."
    }

    static let trapDoorBarred = """
        You push, but the trap door doesn't give. Someone above has
        made very sure of the bolt.
        """

    static let thiefMiss1 = "The thief sways aside; your blade finds only air."
    static let thiefMiss2 = "Your swing tangles in the thief's cloak and comes back empty."
    static let thiefWound1 = "You nick the thief's arm; his smile thins."
    static let thiefWound2 = "Your blade draws a red line across the thief's ribs."
    static let thiefKnockout = """
        The flat of your blade cracks against the thief's temple, and
        he folds up with unexpected grace.
        """
    static let thiefDeath = """
        The thief drops without a sound, and the shadows he favored
        take him for good.
        """

    static let thiefLootScatters = """
        His satchel bursts as he falls, scattering his takings at your
        feet.
        """
}

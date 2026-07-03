/// Every description string in the game, gathered as named constants.
///
/// **Placeholder prose only.** Every line here is original text written for
/// this slice — it conveys the same facts a description needs to (what's
/// here, which exits lead where, what's worth touching) without reusing or
/// lightly rewording Infocom's copyrighted room and item text. Room and item
/// *names* are the iconic proper nouns ("West of House", "brass lantern"),
/// which are fine; the prose describing them is not. A later pass can drop
/// in verbatim text by editing exactly one constant per entity — see
/// `FIDELITY.md` at the repo root.
enum Prose {
    // MARK: - AboveGround: house exterior

    static let westOfHouse = """
        You stand on the west lawn of a white house, its front door boarded
        over and unwelcoming. A mailbox stands by the path. The lawn
        continues north and south, and a forest begins to the west.
        """

    static let northOfHouse = """
        You are at the north edge of the house's lawn, a bare stretch of
        wall with no doors or windows on this side. The lawn runs west and
        east around the house, and a worn path leads off into the trees to
        the north.
        """

    static let southOfHouse = """
        You are at the south edge of the house's lawn. Like the north
        side, this wall is blank. The lawn continues west and east around
        the house.
        """

    static let behindHouse = """
        You are in the small yard behind the house. A narrow window looks
        into the house here, its lower sash sitting unevenly in the frame.
        The yard opens north and south along the house, and a forest lies
        to the east.
        """

    static let whiteHouse = """
        The house is a plain two-story clapboard building, its paint
        peeling and its front door boarded shut. It looks as though nobody
        has used the front entrance in years.
        """

    static let frontDoor = """
        A heavy oak door, planked over from the inside. It hasn't opened
        in a long time.
        """

    static let frontDoorRefusal = "The door is boarded shut and won't budge."

    static let mailbox = "A small mailbox, its flag long since rusted in place."

    static let mailboxEmbellishment = "A leaflet sits inside, waiting to be read."

    static let leaflet = """
        A single typed page, the ink faded but legible: a welcome to
        visitors and a warning that treasure and danger both lie
        underground.
        """

    // MARK: - AboveGround: forest & clearings

    static let forestWest = """
        You are among close-set pines west of the house. The trees crowd
        in on every side; the lawn is visible back to the east, and a
        path winds north.
        """

    static let forestEast = """
        You are in a stretch of forest east of the house, the trees here
        a little sparser. The yard behind the house is west, a clearing
        opens north, and the ground slopes down toward a canyon to the
        east.
        """

    static let forestNortheast = """
        The forest continues here, a tangle of low branches and old
        leaves underfoot. Paths lead back south and west through the
        trees.
        """

    static let forestPath = """
        A trail winds between the trees here, running south toward the
        house and continuing north to a clearing. A large tree beside the
        path looks climbable.
        """

    static let tree = """
        A tall, gnarled tree with branches low enough to reach. Something
        pale is tucked into a nest high up among the leaves.
        """

    static let upATree = """
        You are perched in the branches of the large tree, well above the
        forest floor. A nest here holds something. The ground is a climb
        back down.
        """

    static let nest = "A crude nest wedged into the fork of the branches."

    static let egg = """
        A jewel-encrusted egg, its enamel shell inlaid with tiny gems.
        It looks both delicate and valuable.
        """

    static let clearingGrating = """
        You are in a small clearing in the forest. Half-buried in a pile
        of dead leaves in one corner, something metal glints. The forest
        path leads south, and the clearing continues east.
        """

    static let leaves = """
        A deep pile of dead leaves, heaped in the corner of the clearing.
        """

    static let leavesMoveEmbellishment = "Underneath the leaves, a metal grating is revealed."

    static let leavesAlreadyMoved = "The leaves have already been pushed aside."

    static let grating = """
        A sturdy iron grating, set into the ground and fastened with a
        heavy lock. Cool air drifts up from whatever lies beneath it.
        """

    static let clearingEast = """
        This clearing sits east of the grating clearing, ringed by trees.
        The forest continues west and south, and the trees thin out to
        the east.
        """

    // MARK: - AboveGround: canyon

    static let canyonView = """
        You stand at the lip of a steep canyon, the forest at your back.
        A narrow ledge switchbacks down the canyon wall below you.
        """

    static let rockyLedge = """
        You are on a rocky ledge partway down the canyon wall, with
        room enough to stand. The ledge continues down toward the canyon
        floor.
        """

    static let canyonBottom = """
        You stand on the floor of the canyon, steep walls rising on both
        sides. A brightly colored mist hangs in the air to the north,
        where a faint rainbow arcs over the ground.
        """

    static let endOfRainbow = """
        You are at the foot of a shimmering rainbow that seems to end
        squarely in the canyon floor here. The colors ripple faintly, as
        though the rainbow itself were somehow solid.
        """

    // MARK: - House: interior

    static let kitchen = """
        You are in the house's kitchen, plain cabinets lining one wall. A
        window looks out to the east, and a dark stairway leads up. A
        doorway to the west opens into another room.
        """

    static let kitchenWindow = """
        A window, its lower sash sitting unevenly and slightly ajar in the
        frame — enough of a gap to squeeze through.
        """

    static let sack = "A brown paper sack, rolled shut at the top."

    static let garlic = "A single clove of garlic, papery and pungent."

    static let lunch = "A hot meal, wrapped and still faintly warm."

    static let bottle = """
        A clear glass bottle, corked, with something sloshing inside it.
        """

    static let water = "A quantity of ordinary water."

    static let livingRoom = """
        You are in the living room. A thick oriental rug covers much of
        the floor, and a heavy trophy case stands against one wall. A
        doorway leads east back to the kitchen, and a stairway climbs to
        an attic.
        """

    static let lanternOff = """
        A sturdy brass lantern, its glass chimney clean. It is switched
        off.
        """

    static let lanternOn = """
        A sturdy brass lantern, burning with a steady white light.
        """

    static let lanternDim = """
        The flame inside the lantern shrinks and takes on an orange cast.
        It won't burn much longer.
        """

    static let lanternDies = "The brass lantern flickers and goes out."

    static let lanternSpent = """
        The lantern is burned out; no amount of switch-flicking will
        bring it back.
        """

    static let sword = """
        An elvish sword, its blade etched with fine, faded runes.
        """

    static let rug = "A thick, dusty oriental rug, heavy enough to take some effort to move."

    static let rugMoveEmbellishment = "Dragging the rug aside reveals a trap door beneath it."

    static let rugAlreadyMoved = "The rug has already been dragged aside."

    static let trapDoor = "A stout wooden trap door, set into the floorboards."

    static let trapDoorSlam = "The trap door swings shut, and you hear a bolt slide home above you."

    static let trophyCaseEmpty = "A glass-fronted trophy case, empty for now."

    static func trophyCaseHolding(_ contents: String) -> String {
        "A glass-fronted trophy case, holding \(contents)."
    }

    static let attic = """
        You are in a cramped attic under the sloped roof. A coil of rope
        lies in one corner, and a nasty-looking knife rests nearby. A
        stairway leads back down.
        """

    static let rope = "A long coil of sturdy rope."

    static let knife = "A nasty-looking knife, its edge notched but still sharp."

    static let cellar = """
        You are in a low, dirt-floored cellar. A passage leads off to the
        north, choked with fallen rubble a short way in, and a crawlway
        opens to the south. The trap door you came through is set into
        the ceiling above.
        """

    static let cellarNorthBlocked = """
        The passage north is blocked by fallen rubble a few steps in.
        """

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

    // MARK: - The grue
    //
    // Original prose only: the famous "likely to be eaten by a grue"
    // sentence is Infocom's and is deliberately not reproduced. The name
    // "grue" itself is fair game under the ledger's names-vs-prose line.

    static let grueWarning = """
        The darkness here is total. Something with slow, wet breathing
        has noticed you.
        """

    static let grueDeath = """
        Claws find you long before your eyes could ever adjust. You are
        devoured by a grue.
        """
}

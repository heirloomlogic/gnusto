/// Placeholder prose for the house interior (``ZorkHouse``): kitchen, living
/// room, attic, and the cellar the trap door drops into, plus the lantern's
/// fuel-state lines. See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
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
        north, and a crawlway opens to the south. The trap door you came
        through is set into the ceiling above.
        """
}

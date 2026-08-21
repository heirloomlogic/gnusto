import Gnusto

extension Intent {
    /// The mainframe spells `CROSS` as a pseudo-direction in Volcano View's
    /// exit table, where its only answer is a refusal. In this engine it is a
    /// verb, and it lives with the one room that has anything to say to it.
    #verb("cross", ["cross"], ["cross", .directObject])
}

/// The volcano — ten rooms, and the only part of the map you reach by flying.
///
/// The shape of it: the Ruby Room opens **west** on the Lava Room (a seam
/// milestone 3 left), the Lava Room opens south on the floor of a dormant
/// volcano, and the only way up the shaft from there is a wicker basket under a
/// cloth bag. Four levels of open air stand above the floor — `VAIR1` to
/// `VAIR4` — and two ledges hang off the shaft wall: the Narrow Ledge at the
/// second level, with the Library behind it, and the Wide Ledge at the fourth,
/// with the Dusty Room behind that. A third ledge, Volcano View, is on the far
/// wall and is reached on foot, east out of the Egyptian Room; nothing can be
/// flown to it and nothing can be crossed to it.
///
/// **The whole quarter is dark but the Dusty Room.** `dung.355`'s `ROOM` macro
/// defaults a room's flags to `RLANDBIT` alone, and `SAFE` is the only room here
/// that adds `RLIGHTBIT` — so the shaft with daylight visibly coming down it is
/// pitch black to stand in, exactly as the mainframe has it. The four air rooms
/// go further and carry no `RLANDBIT` at all: they are `RAIRBIT` rooms, which is
/// why stepping out of the basket in one of them is refused rather than
/// permitted and then punished.
///
/// **The balloon is the #133 spike, built.** Nothing here needed an engine
/// change: the hull is `enterable`, the receptacle is a `container` inside it,
/// the fire is the `.burn` stub promoted, the drift is a fuse that re-arms
/// itself every three turns, the fuel is a second fuse of `weight × 20` turns,
/// and the mooring is the `.tie` stub, whose `tie <thing> to <thing>` row
/// already parses an indirect object. The one rule the spike found by playing
/// rather than by reading is here too: the disembark gate is on `world`, because
/// bare `get out` carries no direct object and an item rule never sees it.
///
/// **Rise and fall are not symmetrical, and the asymmetry is the puzzle.** The
/// balloon climbs only while the receptacle is **open** and something is burning
/// in it; close the lid over a live fire and it comes down gently and lands
/// intact; let the fire go out and it comes down anyway and does not survive the
/// arrival. A balloon left untied on a ledge always leaves the ledge, which is
/// the stranding milestone 6 was warned about — and the gnome is the source's
/// own answer to it.
///
/// Seams host-wired in ``Dungeon``, because each names another bundle: the Ruby
/// Room's west door and the Egyptian Room's south one; the burner, which needs
/// the dam's matchbook to light; the gnome's bargain, which has to recognise the
/// Attic's brick; and the whole of the brick-and-wire explosion, whose two
/// halves start in ``DungeonHouse`` and ``DungeonDam``. See `FIDELITY.md`.
struct DungeonVolcano: GameContent {
    // MARK: - The floor

    let volcanoBottom = Location {
        name("Volcano Bottom")
        description(Prose.volcanoBottom)
        dark
    }

    let lavaRoom = Location {
        name("Lava Room")
        description(Prose.lavaRoom)
        dark
    }

    // MARK: - The shaft

    /// The four levels of open air. Each is `RAIRBIT` in the source and so
    /// carries no land bit: you can only ever be in one of these inside the
    /// balloon.
    private static func openAir(_ roomName: String, _ text: String) -> Location {
        Location {
            name(roomName)
            description(text)
            dark
        }
    }

    let volcanoCore = openAir("Volcano Core", Prose.volcanoCore)
    let volcanoNearNarrowLedge = openAir(
        "Volcano Near Small Ledge", Prose.volcanoNearNarrowLedge)
    let volcanoNearViewingLedge = openAir(
        "Volcano Near Viewing Ledge", Prose.volcanoNearViewingLedge)
    let volcanoNearWideLedge = openAir(
        "Volcano Near Wide Ledge", Prose.volcanoNearWideLedge)

    // MARK: - The ledges

    /// Always described, and with no static description, for the reason
    /// ``wideLedge`` is: the gnome's fee opens a second way off this ledge, and
    /// a brief re-entry would print a bare room name over a doorway that was
    /// not there before. See ``ledgeRules``.
    let narrowLedge = Location {
        name("Narrow Ledge")
        alwaysDescribed
        dark
    }

    let library = Location {
        name("Library")
        description(Prose.library)
        dark
    }

    let volcanoView = Location {
        name("Volcano View")
        description(Prose.volcanoView)
        dark
    }

    /// Always described: what it says about the way south changes when the
    /// Dusty Room comes down, and a brief re-entry would print a bare room name
    /// over a doorway that is no longer there.
    let wideLedge = Location {
        name("Wide Ledge")
        alwaysDescribed
        dark
    }

    /// The one lit room in the quarter — the source's own `RLIGHTBIT` — and
    /// always described, because the box's front changes.
    let dustyRoom = Location {
        name("Dusty Room")
        alwaysDescribed
    }

    // MARK: - The balloon

    /// `BALLO`. An open-topped basket you climb into and ride, and the only
    /// thing in the game that goes up. Its listing line and its description are
    /// rules rather than traits, because both report the state of the bag, the
    /// fire and the wire.
    let balloon = Item {
        name("wicker basket")
        adjectives("wicker", "large", "heavy")
        synonyms("balloon", "basket")
        enterable
        container
        capacity(100)
        trait(.weight, 70)
    }

    /// `CBAG`. Part of the basket, and not removable from it.
    let clothBag = Item {
        name("cloth bag")
        adjectives("cloth", "enormous")
        synonyms("bag", "envelope")
        description(Prose.clothBag)
        scenery
    }

    /// `RECEP`. The fire goes in here, and whether its lid is open is what
    /// decides which way the balloon is going.
    let receptacle = Item {
        name("metal receptacle")
        adjectives("metal", "shallow")
        synonyms("receptacle", "pan", "lid")
        description(Prose.receptacle)
        container
        openable
        startsOpen
        capacity(6)
        scenery
    }

    /// `BROPE`. Spliced to the basket at one end; the other end is what makes a
    /// ledge safe to stand on.
    let braidedWire = Item {
        name("braided wire")
        adjectives("braided")
        synonyms("wire", "rope", "cable")
        description(Prose.braidedWire)
        scenery
    }

    /// `BLABE`. Drops into the basket the first time the bag fills.
    ///
    /// The one of this region's four listing lines that is a rule rather than a
    /// trait, because the basket is the one holder here that can stop existing:
    /// ``wreckTheBalloon()`` tips the cargo onto the volcano floor, and a label
    /// in the ash is not a label in a basket. Its sibling the tan label carries
    /// the same rule for the same reason.
    let blueLabel = Item {
        name("blue label")
        adjectives("blue", "small")
        synonyms("label", "instructions", "warranty")
        description(Prose.blueLabel)
        trait(.weight, 1)
        trait(.burnable, true)
    }

    /// `DBALL`. What is left after the rim, or after a landing with a cold bag.
    let brokenBalloon = Item {
        name("broken balloon")
        adjectives("broken", "torn")
        synonyms("balloon", "basket", "wreck", "pieces")
        firstSight(Prose.brokenBalloonInPlace)
        description(Prose.brokenBalloon)
        trait(.weight, 40)
    }

    // MARK: - The hooks

    /// Not `scenery`, and not a `firstSight` either: the source swaps the
    /// hook's listing line for another one while the wire is over it, and a
    /// player on a ledge needs that line every time they look, not only until
    /// they have handled the thing. A `presence { }` rule carries it — and a
    /// hook is never touched, because tying a wire to one touches the wire.
    private static func ledgeHook() -> Item {
        Item {
            name("hook")
            adjectives("small", "iron")
            synonyms("hook")
            description(Prose.hook)
        }
    }

    /// `HOOK1` and `HOOK2`. One per ledge, and the source declares two objects
    /// with one shared listing line rather than a global, because which hook is
    /// holding the balloon is a thing the game has to remember.
    let narrowLedgeHook = ledgeHook()
    let wideLedgeHook = ledgeHook()

    // MARK: - Treasures

    /// `COIN`. Ten to find and **twelve** to case — one of the few treasures in
    /// the game worth more in the trophy case than in the hand.
    let zorkmid = Item {
        name("priceless zorkmid")
        adjectives("gold", "priceless", "engraved")
        synonyms("zorkmid", "coin", "gold")
        firstSight(Prose.zorkmidInPlace)
        description(Prose.zorkmid)
        trait(.weight, 10)
        trait(.takeValue, 10)
        trait(.depositValue, 12)
    }

    /// `CROWN`. Fifteen and ten, behind a steel door and a stick of clay.
    ///
    /// A static listing line rather than a `presence { }` rule: the box is
    /// `scenery` and imbedded in the wall, the thief's prowl stops at the
    /// volcano floor, and the only way the crown leaves the box is a hand — so
    /// there is no frame in which it lies loose and untouched, and a second
    /// line for one would be a constant nothing reads.
    let crown = Item {
        name("gaudy crown")
        adjectives("gaudy", "excessive")
        synonyms("crown", "diadem")
        firstSight(Prose.crownInBox)
        description(Prose.crown)
        wearable
        trait(.weight, 10)
        trait(.takeValue, 15)
        trait(.depositValue, 10)
    }

    /// `STAMP`. Four and ten, pressed inside a book nobody can read.
    ///
    /// Named *stamp* rather than *Flathead stamp*, with the Flathead in the
    /// adjectives: a capitalised display name warns at bootstrap unless it is
    /// `properName`, and a stamp is not a person. Milestone 5's Stradivarius
    /// went the same way.
    let stamp = Item {
        name("stamp")
        adjectives("flathead")
        synonyms("stamp")
        firstSight(Prose.stampInBook)
        description(Prose.stamp)
        trait(.weight, 1)
        trait(.takeValue, 4)
        trait(.depositValue, 10)
        trait(.burnable, true)
    }

    // MARK: - The Library

    private static func libraryBook(_ colour: String, _ listing: String) -> Item {
        Item {
            name("\(colour) book")
            adjectives(colour)
            // `pages` because two of this region's lines print the word — the
            // stamp rests "loose among its pages" and the purple book's fall
            // apart at a place somebody kept. In the factory rather than on the
            // purple book alone: `book` is already four ways ambiguous in this
            // room, and a fifth word for the same four objects changes nothing.
            synonyms("book", "books", "cover", "pages", "page")
            firstSight(listing)
            description(Prose.bookExamined(colour))
            container
            openable
            capacity(2)
            trait(.weight, 10)
            trait(.burnable, true)
        }
    }

    let blueBook = libraryBook("blue", Prose.blueBookInPlace)
    let greenBook = libraryBook("green", Prose.greenBookInPlace)
    let whiteBook = libraryBook("white", Prose.whiteBookInPlace)
    let purpleBook = libraryBook("purple", Prose.purpleBookInPlace)

    // MARK: - The Dusty Room

    /// `SAFE`. Set into the wall, and the only thing in the game a bomb opens.
    /// `openable` and closed, so the crown does not list through the door: the
    /// two rules that answer `open` and `close` refuse both, and the blast sets
    /// `isOpen` itself.
    let rustyBox = Item {
        name("rusty box")
        adjectives("rusty", "steel", "old")
        synonyms("box", "safe")
        description(Prose.rustyBox)
        container
        openable
        capacity(15)
        scenery
    }

    /// `SSLOT`. Somebody chipped it out of the front of the box and gave up.
    /// The brick fits it and nothing else in the game does.
    let oblongHole = Item {
        name("oblong hole")
        adjectives("oblong", "chipped")
        synonyms("hole", "slot")
        description(Prose.oblongHole)
        container
        startsOpen
        capacity(10)
        scenery
    }

    /// `CARD`. The Frobozz Magic Cave Company's opinion of what you are about
    /// to do in here.
    let card = Item {
        name("card")
        adjectives("plain")
        synonyms("card", "note", "writing")
        firstSight(Prose.cardInBox)
        description(Prose.card)
        trait(.weight, 1)
        trait(.burnable, true)
    }

    // MARK: - The gnome

    /// `GNOME`. He walks out of the rock ten turns after the balloon leaves a
    /// ledge without you, and he sells the only other way down.
    let gnome = Actor {
        name("Volcano Gnome")
        adjectives("volcano", "nervous")
        synonyms("gnome")
        firstSight(Prose.gnomeInPlace)
        description(Prose.gnome)
        properName
    }

    // MARK: - Scenery

    /// Takes its nouns as a builder result, the way ``DungeonRiver``'s three
    /// scenery factories do.
    private static func shaftScenery(_ text: String, _ nouns: ItemTrait) -> Item {
        Item {
            name("volcano")
            adjectives("dormant", "old")
            nouns
            description(text)
            scenery
        }
    }

    /// The far half of the pair, and the shape of the whole quarter: **every
    /// level of the shaft gets two scenery items, the rock close enough to
    /// touch and the view of everything the paragraph points at that is not.**
    /// One factory handing five rooms one description and eight nouns each made
    /// the wrong answer cheap — `x rim` two hundred feet under the rim answered
    /// "close enough to touch", and `x floor` on the floor answered with the
    /// sky. (#233)
    private static func distanceScenery(_ text: String, _ nouns: ItemTrait) -> Item {
        Item {
            name("view")
            adjectives("distant", "far")
            nouns
            description(text)
            scenery
        }
    }

    let coneAtBottom = shaftScenery(
        Prose.volcanoCone,
        synonyms("volcano", "cone", "light", "daylight", "shaft"))
    let volcanoBottomAsh = Item {
        name("ash")
        adjectives("grey", "gray", "deep")
        synonyms("ash", "floor", "ground", "bottom", "walls", "wall", "exit")
        description(Prose.volcanoBottomAsh)
        scenery
    }

    /// The rock beside the basket, which is the same rock and the same sentence
    /// at the three levels that have one. No noun parameter: what a hand can
    /// touch from a basket is the shaft wall and nothing else, at every height.
    /// `VAIR3` reads it too — its near item used to wear
    /// ``Prose/volcanoRimFromBelow``, which is a line about the rim overhead.
    private static func basketRock() -> Item {
        shaftScenery(
            Prose.volcanoWallsFromTheAir,
            synonyms("volcano", "rock", "walls", "wall", "side", "air"))
    }

    let wallsAtCore = basketRock()
    let viewFromCore = distanceScenery(
        Prose.shaftFromCore,
        synonyms("view", "top", "rim", "bottom", "floor", "cone", "light"))

    let wallsAtNarrowLedgeAir = basketRock()
    let viewFromNarrowLedgeAir = distanceScenery(
        Prose.shaftFromNarrowLedgeAir,
        synonyms("view", "rim", "top", "floor", "bottom", "ledge", "shelf"))

    let wallsAtViewingLedgeAir = basketRock()
    let viewFromViewingLedgeAir = distanceScenery(
        Prose.shaftFromViewingLedgeAir,
        synonyms("view", "rim", "top", "floor", "bottom", "ledge", "shelf"))

    // `VAIR4` is where the split inverts. At a rim fifteen feet across the rim
    // and the sky are the near things, and the ledge is the one across the gap.
    let rimAtWideLedgeAir = shaftScenery(
        Prose.volcanoRimFromBelow,
        synonyms("volcano", "rim", "top", "sky", "mouth", "rock", "walls", "wall"))
    let viewFromWideLedgeAir = distanceScenery(
        Prose.shaftFromWideLedgeAir,
        synonyms("view", "ledge", "place", "shelf", "floor", "bottom"))

    let lavaFlow = Item {
        name("old lava flow")
        adjectives("old", "lava")
        synonyms("flow", "lava", "walls", "wall", "rock", "exits", "exit")
        description(Prose.lavaFlow)
        scenery
    }

    let narrowLedgeRock = Item {
        name("narrow ledge")
        adjectives("narrow")
        synonyms("ledge", "rock", "shelf", "volcano", "exit")
        description(Prose.narrowLedgeRock)
        scenery
    }
    let narrowLedgeView = distanceScenery(
        Prose.narrowLedgeDistance,
        synonyms("view", "floor", "bottom", "rim", "top", "shaft"))

    let libraryShelves = Item {
        name("gnawed shelves")
        adjectives("gnawed", "royal")
        synonyms("shelves", "shelf", "library", "splinters", "pieces", "gnomes", "exit")
        description(Prose.libraryShelves)
        scenery
        plural
    }

    let volcanoViewDistance = distanceScenery(
        Prose.volcanoViewDistance,
        synonyms("view", "ledges", "shelves", "rim", "top", "bottom", "floor", "volcano"))
    /// The ledge the player is standing on, which the room's paragraph calls
    /// "this ledge" and which nothing here answered for. No `ledges` — the pair
    /// across the shaft keeps the plural.
    let volcanoViewLedge = Item {
        name("ledge")
        adjectives("stone")
        synonyms("ledge", "rock", "shelf", "wall", "walls", "exit")
        description(Prose.volcanoViewLedge)
        scenery
    }

    let wideLedgeRock = Item {
        name("wide ledge")
        adjectives("wide", "broad")
        synonyms("ledge", "rock", "shelf", "apron", "volcano")
        description(Prose.wideLedgeRock)
        scenery
    }
    let wideLedgeView = distanceScenery(
        Prose.wideLedgeDistance,
        synonyms("view", "rim", "top", "drop", "bottom", "floor", "shaft"))

    /// The small door south, which used to be a clause inside the description
    /// of the rock underfoot — so it went on being a doorway after the blast
    /// filled it with rubble. Its own item, and its own `describe { }`: the
    /// room's paragraph has always branched on this and the examine channel
    /// never did. `south`/`southern` tell it from the gnome's west door in the
    /// one frame where both stand on this ledge.
    let wideLedgeDoorway = Item {
        name("small door")
        adjectives("small", "low", "south", "southern")
        synonyms("door", "doorway", "opening", "rubble")
        scenery
        door
    }

    let dustyRoomDust = Item {
        name("dust")
        adjectives("thick")
        synonyms("dust", "floor", "walls", "wall", "room", "exit")
        description(Prose.dustyRoomDust)
        scenery
    }

    /// The chimney the gnome's fee opens. Offstage until it exists, and then in
    /// whichever ledge he was paid on.
    ///
    /// It keeps `door` and `doorway` even though ``wideLedgeDoorway`` also
    /// carries them: ``Prose/gnomePaid(_:)`` is trilogy-verbatim and says "a
    /// door appears on the west end of the ledge", so that is the word the
    /// player has just been handed. Paid on the Wide Ledge there really are two
    /// doors, and asking which is the true answer — it costs no turn, and
    /// `west`/`south` resolve it. (#233)
    let gnomeChimney = Item {
        name("narrow chimney")
        adjectives("narrow", "sloping", "west", "western")
        synonyms("chimney", "door", "doorway")
        description(Prose.gnomeChimney)
        scenery
    }

    // MARK: - State

    /// Whether the cloth bag is full of hot air. The mainframe's `BINF-FLAG`,
    /// which also names the thing that is burning; here the thing is whatever
    /// the receptacle holds, so only the flag is stored.
    @Global var bagInflated = false

    /// Whether the braided wire is over a hook. The mainframe's `BTIE-FLAG`,
    /// which stores *which* hook; here the ledge the balloon is standing on
    /// says which, so only the flag is stored.
    @Global var balloonTied = false

    /// Whether the label has ever dropped out of the bag.
    @Global var labelDropped = false

    /// Whether the gnome has started counting. The mainframe arms his five-turn
    /// watch the first time you address him and not before, which is why
    /// ignoring a gnome is the safe thing to do with one.
    @Global var gnomeIsWatching = false

    /// Whether he has been offered the brick and left for good. The mainframe
    /// disables both of his clocks when that happens, and nothing re-enables
    /// them.
    @Global var gnomeDismissed = false

    /// Whether the Dusty Room has come down on itself.
    @Global var dustyRoomWrecked = false

    /// And whether the ledge it stood on followed it.
    @Global var wideLedgeWrecked = false

    // MARK: - Derived state

    /// What is burning in the receptacle, if anything is.
    var burningFuel: Item? { bagInflated ? receptacle.contents.first : nil }

    /// Whether the gnome's chimney has been bought — the mainframe's
    /// `GNOME-DOOR`, which is one-way and which the chimney itself records: he
    /// puts it in the ledge he was paid on, and nothing takes it away again.
    var gnomeDoorOpen: Bool {
        gnomeChimney.isIn(narrowLedge) || gnomeChimney.isIn(wideLedge)
    }

    /// The four levels of open air with the floor beneath them, bottom first.
    /// The balloon's altitude is not a stored number: it is which of these
    /// rooms the balloon is in.
    var shaft: [Location] {
        [
            volcanoBottom, volcanoCore, volcanoNearNarrowLedge,
            volcanoNearViewingLedge, volcanoNearWideLedge,
        ]
    }

    /// Each ledge against the level of air it hangs in and the bearing between
    /// them. `LAUNC` reads it one way, `LAND` the other and the steering gate a
    /// third, so the pairing is written once.
    var ledgeLandings: [(ledge: Location, air: Location, toward: Direction)] {
        [
            (narrowLedge, volcanoNearNarrowLedge, .west),
            (wideLedge, volcanoNearWideLedge, .east),
        ]
    }

    /// Whether a room is one of the four the balloon is the only way to be in.
    /// A chain of identity tests rather than a search of ``shaft``, because
    /// every `go` in the game asks this.
    func isOpenAir(_ room: Location) -> Bool {
        room == volcanoCore || room == volcanoNearNarrowLedge
            || room == volcanoNearViewingLedge || room == volcanoNearWideLedge
    }

    /// Whether a room has a view of the shaft. The source announces the
    /// balloon's comings and goings from any ledge and from the floor — every
    /// room in the volcano with a sky over it, Volcano View included, since
    /// watching the shaft is the only thing that room is for.
    func watchesTheShaft(_ room: Location) -> Bool {
        room == volcanoBottom || room == narrowLedge || room == wideLedge
            || room == volcanoView
    }

    /// Where the balloon is, if it still exists. `nil` once the rim or a cold
    /// landing has finished with it — which is why nothing here stores a
    /// "wrecked" flag.
    var balloonPlace: Location? {
        balloon.location
    }

    var verbs: [SyntaxRule] { [.cross] }

    var actions: [IntentAction] {
        action(.cross) { try reply(Prose.crossNothingHere) }
    }

    // MARK: - Map

    var map: WorldMap {
        floorMap
        shaftMap
        ledgeMap
        volcanoEntities
    }

    /// The floor of the volcano and the room above it. The Lava Room's west
    /// door is the Ruby Room, a ``DungeonTemple`` room — host-wired.
    @MapBuilder private var floorMap: WorldMap {
        volcanoBottom.north(lavaRoom)
        lavaRoom.south(volcanoBottom)
    }

    /// The shaft. Two of the four levels reach a ledge and two reach nothing at
    /// all, which is why `VAIR1` and `VAIR3` have no exits in the atlas.
    @MapBuilder private var shaftMap: WorldMap {
        volcanoNearNarrowLedge.west(narrowLedge)
        volcanoNearWideLedge.east(
            wideLedge, when: { !wideLedgeWrecked }, otherwise: Prose.ledgeIsGone)
    }

    /// The three ledges and the two rooms behind them. Both gnome doors are one
    /// way: the chimney goes down to the floor and does not come back.
    @MapBuilder private var ledgeMap: WorldMap {
        narrowLedge.down(blocked: Prose.ledgeNoJumping)
        narrowLedge.south(library)
        narrowLedge.west(
            volcanoBottom, when: { gnomeDoorOpen }, otherwise: Prose.gnomeDoorShut)
        library.north(narrowLedge)
        library.out(narrowLedge)

        // Volcano View's east door is the Egyptian Room, a ``DungeonTemple``
        // room — host-wired. `CROSS` is a verb here rather than an exit.
        volcanoView.down(blocked: Prose.volcanoViewNoJumping)

        wideLedge.down(blocked: Prose.wideLedgeNoJumping)
        wideLedge.south(
            dustyRoom, when: { !dustyRoomWrecked }, otherwise: Prose.debrisBlocksTheWay)
        wideLedge.west(
            volcanoBottom, when: { gnomeDoorOpen }, otherwise: Prose.gnomeDoorShut)
        dustyRoom.north(
            wideLedge, when: { !wideLedgeWrecked }, otherwise: Prose.ledgeIsGone)
    }

    @MapBuilder private var volcanoEntities: WorldMap {
        balloon.starts(in: volcanoBottom)
        clothBag.starts(inside: balloon)
        receptacle.starts(inside: balloon)
        braidedWire.starts(inside: balloon)

        narrowLedgeHook.starts(in: narrowLedge)
        wideLedgeHook.starts(in: wideLedge)
        zorkmid.starts(in: narrowLedge)

        blueBook.starts(in: library)
        greenBook.starts(in: library)
        whiteBook.starts(in: library)
        purpleBook.starts(in: library)
        stamp.starts(inside: purpleBook)

        rustyBox.starts(in: dustyRoom)
        oblongHole.starts(in: dustyRoom)
        // Order here buys nothing: `ContainmentIndex` sorts a container's
        // contents by id, so the box always lists the card before the crown
        // whichever way round these two lines go. Their listing lines are
        // written for that order.
        crown.starts(inside: rustyBox)
        card.starts(inside: rustyBox)

        coneAtBottom.starts(in: volcanoBottom)
        volcanoBottomAsh.starts(in: volcanoBottom)
        lavaFlow.starts(in: lavaRoom)
        wallsAtCore.starts(in: volcanoCore)
        viewFromCore.starts(in: volcanoCore)
        wallsAtNarrowLedgeAir.starts(in: volcanoNearNarrowLedge)
        viewFromNarrowLedgeAir.starts(in: volcanoNearNarrowLedge)
        wallsAtViewingLedgeAir.starts(in: volcanoNearViewingLedge)
        viewFromViewingLedgeAir.starts(in: volcanoNearViewingLedge)
        rimAtWideLedgeAir.starts(in: volcanoNearWideLedge)
        viewFromWideLedgeAir.starts(in: volcanoNearWideLedge)
        narrowLedgeRock.starts(in: narrowLedge)
        narrowLedgeView.starts(in: narrowLedge)
        libraryShelves.starts(in: library)
        volcanoViewDistance.starts(in: volcanoView)
        volcanoViewLedge.starts(in: volcanoView)
        wideLedgeRock.starts(in: wideLedge)
        wideLedgeView.starts(in: wideLedge)
        wideLedgeDoorway.starts(in: wideLedge)
        dustyRoomDust.starts(in: dustyRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        balloonRules
        balloonPartRules
        ledgeRules
        libraryRules
        dustyRoomRules
        gnomeRules
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        balloonTimers
        volcanoTimers
    }

    @TimerBuilder private var balloonTimers: [TimedEvent] {
        // The mainframe's `BINT`: one level every three turns, re-armed by its
        // own body exactly as `CLOCK-INT ,BINT 3` re-arms at the head of both
        // of the source's routines.
        fuse("balloonDrifts", after: 3) { try drift() }

        // And its `BURNUP`: the fire lasts twenty turns per unit of the fuel's
        // weight, which is the source's `<* <OSIZE …> 20>`.
        fuse("burnerBurnsOut", after: 20) {
            guard let fuel = burningFuel else { return }
            if player.location == balloonPlace { say(Prose.fuelBurnsOut(fuel.name)) }
            fuel.vanish()
            bagInflated = false
        }
    }

    @TimerBuilder private var volcanoTimers: [TimedEvent] {
        // `VLGIN`. Ten turns after the balloon drifts off a ledge unmanned, and
        // then once a turn until the player is somewhere he can be met.
        fuse("gnomeArrives", after: 10) {
            // He has nothing left to sell once the chimney is open, and nothing
            // to say at all once he has been handed the brick.
            guard !gnomeDismissed, !gnomeDoorOpen else { return }
            let here = player.location
            guard ledgeLandings.contains(where: { $0.ledge == here }) else {
                startFuse("gnomeArrives", after: 1)
                return
            }
            gnome.move(to: here)
            say(Prose.gnomeArrives)
        }

        // `GNOIN`. Five turns from the moment you first speak to him.
        fuse("gnomeLeaves", after: 5) {
            guard gnome.isIn(player.location) else {
                gnome.vanish()
                return
            }
            say(Prose.gnomeLeaves)
            gnome.vanish()
            gnomeIsWatching = false
        }

        // `SAFIN`, five turns after the blast, and `LEDIN`, eight after that.
        fuse("dustyRoomFalls", after: 5) { try dustyRoomComesDown() }
        fuse("wideLedgeFalls", after: 8) { try wideLedgeComesDown() }
    }
}

// MARK: - Rules

extension DungeonVolcano {
    @RuleBuilder fileprivate var balloonRules: Rules {
        // Both of the basket's descriptions report the bag, the fire and the
        // wire, so both are rules. Neither may also be a static trait.
        balloon.presence {
            Prose.balloonInPlace(inflated: burningFuel?.name, tied: balloonTied)
        }
        balloon.describe {
            Prose.balloonExamined(inflated: burningFuel?.name, tied: balloonTied)
        }
        balloon.before(.take, .push, .pull) { try refuse(Prose.balloonTooHeavy) }

        // A balloon is not steered. Inside the shaft the only headings that
        // mean anything are the two that reach a ledge; on the ground and on a
        // ledge the basket goes wherever its passenger walks, which is the
        // source's own reading and how you carry it into the Library.
        world.before(.go) {
            guard player.vehicle == balloon else { return }
            try require(!balloonTied, else: Prose.tiedToTheLedge)
            // Whatever happens next, the drift clock starts again from here:
            // arriving on a ledge has to buy a full three turns, or the basket
            // is gone before its passenger can reach the hook.
            startFuse("balloonDrifts")
            let here = player.location
            guard isOpenAir(here) else { return }
            let ledgeward = ledgeLandings.first { $0.air == here }?.toward
            try require(command.direction == ledgeward, else: Prose.cantSteerTheBalloon)
        }

        // On `world` rather than on the basket: bare `get out` carries no
        // direct object, so an item rule never sees it.
        world.before(.disembark) {
            guard player.vehicle == balloon, isOpenAir(player.location) else { return }
            try refuse(Prose.disembarkWouldBeFatal)
        }

        // And you may not pick the fire up out of the pan.
        world.before(.take) {
            guard bagInflated, let target = command.directObject, target == burningFuel
            else { return }
            try refuse(Prose.wontHoldBurning(target.name))
        }
    }

    @RuleBuilder fileprivate var balloonPartRules: Rules {
        for part in [clothBag, receptacle, braidedWire] {
            part.before(.take, .pull) {
                let extra = part == braidedWire ? Prose.wireMightBeTied : ""
                try reply(Prose.balloonPartIsFixed(part.name) + extra)
            }
        }

        clothBag.before(.open) { try reply(Prose.clothBagWontOpen) }
        clothBag.before(.lookIn) { try reply(Prose.clothBagIsEmpty) }

        // One fire at a time. The engine's own capacity check keeps anything
        // heavier than the source's `OCAPAC 6` out of the pan.
        receptacle.before(.putIn) {
            try require(receptacle.contents.isEmpty, else: Prose.receptacleOccupied)
        }

        // The `.tie` stub already parses `tie wire to hook`, so mooring costs
        // one rule and no new grammar.
        braidedWire.before(.tie) {
            let hooks = [narrowLedgeHook, wideLedgeHook]
            if let named = command.indirectObject {
                try require(
                    hooks.contains(named) && named.isReachable, else: Prose.wireNeedsAHook)
            } else {
                try require(hooks.contains(where: \.isReachable), else: Prose.wireNeedsAHook)
            }
            balloonTied = true
            stopFuse("balloonDrifts")
            try reply(Prose.balloonFastened)
        }

        braidedWire.before(.untie) {
            try require(balloonTied, else: Prose.wireNotTied)
            balloonTied = false
            startFuse("balloonDrifts")
            try reply(Prose.wireFallsOff)
        }

        // The label reads one way in the basket and another in the ash the rim
        // leaves it in. See the declaration for why this one is a rule and the
        // region's other three listing lines are traits.
        blueLabel.presence {
            balloon.holds(blueLabel) ? Prose.blueLabelInBasket : Prose.blueLabelOnGround
        }
    }

    @RuleBuilder fileprivate var ledgeRules: Rules {
        // The gnome's chimney is `scenery`, so the room listing never mentions
        // it: the room's own paragraph is the only place a second way off this
        // ledge can be reported, and it counted one exit however many there
        // were.
        narrowLedge.describe {
            gnomeDoorOpen
                ? "\(Prose.narrowLedge) \(Prose.narrowLedgeChimneyOpen)"
                : Prose.narrowLedge
        }

        wideLedge.describe {
            let south = dustyRoomWrecked ? Prose.wideLedgeRubble : Prose.wideLedgeDoor
            return "\(Prose.wideLedge) \(south)"
        }

        // The examine channel, saying what the room's paragraph directly above
        // has always said. The rock underfoot used to carry this clause and
        // could not branch on it.
        wideLedgeDoorway.describe {
            dustyRoomWrecked ? Prose.wideLedgeDoorBlocked : Prose.wideLedgeDoorExamined
        }

        dustyRoom.describe {
            let box = rustyBox.isOpen ? Prose.dustyRoomBoxOpen : Prose.dustyRoomBoxShut
            return "\(Prose.dustyRoom)\n\n\(box)"
        }

        for hook in [narrowLedgeHook, wideLedgeHook] {
            hook.before(.take, .pull, .push) { try reply(Prose.hookIsFixed) }
            hook.presence {
                balloonTied && balloon.isIn(player.location)
                    ? Prose.hookHoldsTheBalloon : Prose.hookInPlace
            }
        }

        volcanoView.before(.cross) { try reply(Prose.volcanoViewNoCrossing) }

        zorkmid.before(.read) { try reply(Prose.zorkmidEngraved) }
    }

    @RuleBuilder fileprivate var libraryRules: Rules {
        for book in [blueBook, greenBook, whiteBook] {
            book.before(.read) { try reply(Prose.bookIsUnreadable) }
        }

        // The purple one is unreadable too, but reading it is what shakes the
        // stamp out of it — the source's `PURPLE-BOOK-FCN`, which performs an
        // `open` on the book's behalf.
        purpleBook.before(.read) {
            guard !purpleBook.isOpen, purpleBook.holds(stamp) else {
                try reply(Prose.bookIsUnreadable)
            }
            purpleBook.isOpen = true
            say(Prose.bookIsUnreadable)
            try reply(Prose.purpleBookOpens)
        }

        stamp.before(.read) { try reply(Prose.stamp) }
    }

    @RuleBuilder fileprivate var dustyRoomRules: Rules {
        rustyBox.before(.take, .pull, .push) { try reply(Prose.safeIsEmbedded) }
        rustyBox.before(.open) {
            try reply(rustyBox.isOpen ? Prose.safeHasNoDoor : Prose.safeWillNotOpen)
        }
        rustyBox.before(.close) {
            try reply(rustyBox.isOpen ? Prose.safeHasNoDoor : Prose.safeIsNotOpen)
        }
        card.before(.read) { try reply(Prose.cardText) }
        blueLabel.before(.read) { try reply(Prose.blueLabelText) }
    }

    @RuleBuilder fileprivate var gnomeRules: Rules {
        // Anything said or done to him that is not payment starts his watch.
        // The mainframe arms `GNOIN` here and nowhere else, which is what makes
        // leaving a gnome alone the safe thing to do with one.
        gnome.before(.attack, .take, .push, .touch, .greet, .kiss, .listen) {
            guard !gnomeIsWatching else { try reply(Prose.gnomeIsNervous) }
            gnomeIsWatching = true
            startFuse("gnomeLeaves")
            try reply(Prose.gnomeIsNervous)
        }
        // `give`/`throw` is dispatched by the host, because the one offer he
        // refuses by name is the Attic's brick and that is a ``DungeonHouse``
        // item. Both answers to it are below.
    }

    /// What he does with anything but the brick: a treasure buys the chimney,
    /// and everything else he crushes.
    ///
    /// - Parameter offered: what was handed or thrown to him.
    /// - Throws: always — every branch answers.
    func offerTheGnome(_ offered: Item) throws -> Never {
        let named = offered.name
        let worth = offered[default: .takeValue] + offered[default: .depositValue]
        offered.vanish()
        guard worth > 0 else { try reply(Prose.gnomeCrunches(named)) }
        gnome.replace(with: gnomeChimney)
        stopFuse("gnomeLeaves")
        try reply(Prose.gnomePaid(named))
    }

    /// And what he does with the brick, which is leave, permanently, taking
    /// both of his clocks with him.
    ///
    /// - Parameter charge: the brick, which he hands straight back.
    /// - Throws: always.
    func gnomeRefusesTheCharge(_ charge: Item) throws -> Never {
        gnome.replace(with: charge)
        gnomeDismissed = true
        stopFuse("gnomeArrives")
        stopFuse("gnomeLeaves")
        try reply(Prose.gnomeRefusesTheBrick)
    }
}

// MARK: - The flight

extension DungeonVolcano {
    /// Light whatever is sitting in the pan. Called by the host, because the
    /// only flame in the game that will do it is the dam's matchbook.
    func lightTheBurner(_ fuel: Item) throws -> Never {
        try require(fuel != burningFuel, else: Prose.alreadyBurning)
        try require(fuel[default: .burnable], else: Prose.wontBurn(fuel.definiteName))
        try require(
            player.heldFlame(named: command.indirectObject) != nil,
            else: Prose.nothingToBurnWith)
        say(Prose.fuelCatches(fuel.name))
        startFuse("burnerBurnsOut", after: fuel[default: .weight] * 20)
        guard !bagInflated else { try handled() }
        bagInflated = true
        startFuse("balloonDrifts")
        guard !labelDropped else { try reply(Prose.bagInflates) }
        labelDropped = true
        blueLabel.move(inside: balloon)
        try reply(Prose.bagInflates)
    }

    /// `LAUNC`, which the source spells as a pseudo-direction out of either
    /// ledge. Host-called, because `launch` is a word the boat answers too.
    func launchBalloon() throws -> Never {
        try require(!balloonTied, else: Prose.launchTied)
        guard let place = balloonPlace,
            let landing = ledgeLandings.first(where: { $0.ledge == place })
        else { try reply(Prose.launchNowhereFromHere) }
        say(Prose.balloonLeavesTheLedge)
        try moveBalloon(to: landing.air)
    }

    /// `LAND`, the same table read the other way.
    func landBalloon() throws -> Never {
        guard let place = balloonPlace,
            let landing = ledgeLandings.first(where: { $0.air == place })
        else { try reply(Prose.landNoLedge) }
        try require(landing.ledge != wideLedge || !wideLedgeWrecked, else: Prose.ledgeIsGone)
        try moveBalloon(to: landing.ledge)
    }

    /// The move both of those make, with the drift clock wound back so that
    /// arriving somewhere buys a full interval.
    private func moveBalloon(to room: Location) throws -> Never {
        balloon.move(to: room)
        startFuse("balloonDrifts")
        describeSurroundings()
        try handled()
    }

    /// One tick of `BINT`. Rise while the pan is open and alight, sink
    /// otherwise, and always leave a ledge you are not tied to.
    fileprivate func drift() throws {
        guard let place = balloonPlace, !balloonTied else { return }
        startFuse("balloonDrifts")
        let shaft = shaft
        let aboard = player.vehicle == balloon
        let watched = aboard || watchesTheShaft(player.location)

        if let landing = ledgeLandings.first(where: { $0.ledge == place }) {
            balloon.move(to: landing.air)
            if !aboard { startFuse("gnomeArrives") }
            announce(
                aboard: aboard, watched: watched,
                pilot: Prose.balloonLeavesTheLedge,
                onlooker: Prose.balloonWatchedFloatingAway)
            return
        }

        guard let level = shaft.firstIndex(of: place) else { return }
        if receptacle.isOpen, bagInflated {
            try rise(shaft, from: level, aboard: aboard, watched: watched)
        } else {
            sink(shaft, from: level, aboard: aboard, watched: watched)
        }
    }

    /// One line for the pilot and another for anybody watching from the floor
    /// or a ledge, and a fresh look for the pilot because the room has changed
    /// under them. Every leg of the flight says its two lines through here.
    private func announce(aboard: Bool, watched: Bool, pilot: String, onlooker: String) {
        guard aboard else {
            if watched { say(onlooker) }
            return
        }
        say(pilot)
        describeSurroundings()
    }

    private func rise(_ shaft: [Location], from level: Int, aboard: Bool, watched: Bool) throws {
        guard level + 1 < shaft.count else {
            // The rim is fifteen feet across, and the bag is a great deal
            // wider. The mainframe's ending, not the trilogy's: Zork II flies
            // the balloon out of the volcano and kills you in the mountains.
            let seenFromTheFloor = player.location == volcanoBottom
            wreckTheBalloon()
            guard aboard else {
                say(seenFromTheFloor ? Prose.balloonExplodesWatched : Prose.balloonExplodesHeard)
                return
            }
            try die(Prose.balloonHitsTheRim)
        }
        balloon.move(to: shaft[level + 1])
        announce(
            aboard: aboard, watched: watched,
            pilot: level == 0 ? Prose.balloonRises : Prose.balloonAscends,
            onlooker: level == 0
                ? Prose.balloonWatchedLiftingOff : Prose.balloonWatchedClimbing)
    }

    private func sink(_ shaft: [Location], from level: Int, aboard: Bool, watched: Bool) {
        // Level zero is the floor: a basket standing on the ground with a cold
        // pan does nothing at all until somebody lights it again.
        guard level > 0 else { return }
        balloon.move(to: shaft[level - 1])
        guard level == 1 else {
            announce(
                aboard: aboard, watched: watched,
                pilot: Prose.balloonDescends, onlooker: Prose.balloonWatchedSinking)
            return
        }
        // Arriving at the floor. A bag still full of hot air sets the basket
        // down; a cold one arrives at the speed the shaft gave it.
        guard !bagInflated else {
            announce(
                aboard: aboard, watched: watched,
                pilot: Prose.balloonHasLanded, onlooker: Prose.balloonWatchedLanding)
            return
        }
        if aboard { player.location = volcanoBottom }
        wreckTheBalloon()
        announce(
            aboard: aboard, watched: watched,
            pilot: Prose.balloonDidNotSurvive, onlooker: Prose.balloonExplodesWatched)
    }

    /// Take the basket out of the world and leave the wreck on the floor. The
    /// player stops being a passenger the moment the hull is gone, because
    /// `Visibility.boardedVehicle` asks where the vehicle is.
    private func wreckTheBalloon() {
        stopFuse("balloonDrifts")
        stopFuse("burnerBurnsOut")
        bagInflated = false
        balloonTied = false
        for cargo in balloon.contents where cargo.isTakable {
            cargo.move(to: volcanoBottom)
        }
        balloon.vanish()
        brokenBalloon.move(to: volcanoBottom)
    }
}

// MARK: - The blast

extension DungeonVolcano {
    /// What the charge does when the wire in it reaches the end. Host-called
    /// and handed the brick, because the brick is a ``DungeonHouse`` item and
    /// cannot be named from here — but where it is standing is this bundle's
    /// question, so it is asked here.
    ///
    /// - Parameter charge: the brick, which does not survive the call.
    /// - Throws: `TurnInterrupt.died` when the blast was in the player's room.
    func detonate(_ charge: Item) throws {
        let besideThePlayer = charge.isReachable
        let inTheDustyRoom =
            charge.isIn(dustyRoom) || oblongHole.holds(charge) || rustyBox.holds(charge)
        if oblongHole.holds(charge) {
            rustyBox.isOpen = true
            oblongHole.vanish()
        }
        charge.vanish()
        // The source gives an aftermath to exactly one room, and the fuse that
        // brings the Wide Ledge down after it hangs off that one too.
        if inTheDustyRoom { startFuse("dustyRoomFalls") }
        guard !besideThePlayer else { try die(Prose.brickBoom) }
        say(Prose.explosionNearby)
    }

    fileprivate func dustyRoomComesDown() throws {
        let caught = player.location == dustyRoom
        dustyRoomWrecked = true
        startFuse("wideLedgeFalls")
        guard !caught else { try die(Prose.roomCollapsesOnYou) }
        say(Prose.ominousRumbling)
    }

    fileprivate func wideLedgeComesDown() throws {
        wideLedgeWrecked = true
        guard player.location == wideLedge else {
            say(Prose.ledgeCollapsesElsewhere)
            return
        }
        guard player.vehicle == balloon else {
            try die(Prose.ledgeCollapsesUnderYou)
        }
        guard balloonTied else {
            say(Prose.ledgeCollapsesNoLanding)
            return
        }
        wreckTheBalloon()
        try die(Prose.ledgeCollapsesTiedOn)
    }
}

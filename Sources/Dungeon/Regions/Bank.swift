import Gnusto

extension Intent {
    /// Go through something that is not a door — a wall, or a curtain of light.
    /// The Bank is the only building in the game where it works, so the verb
    /// lives with it.
    #verb(
        "walkThrough",
        ["walk", "through", .directObject],
        ["go", "through", .directObject],
        ["step", "through", .directObject])
}

/// The Bank of Zork: nine rooms west of the Gallery, and the one building in
/// the game whose floor plan is a lie.
///
/// **The Bank did not reach Zork I at all**, and Zork II's version is a
/// different building in a different game. `BKEXE` and `BKVAU` are `identical`
/// entries in the comparison document, `BKENT` is `minor` and `BKBOX`, `BKVE`
/// and `BKVW` are `substantial`; the rest is written fresh. See
/// `Prose+Bank.swift`.
///
/// ## What the puzzle is
///
/// The Safety Depository has a curtain of light where its north wall should be.
/// Walking into it puts you in one of four rooms — and **which one depends on
/// the direction you last walked into the Depository by**, which is state the
/// game never shows you. That is the source's `SCOL-ROOMS` table, read as the
/// mainframe's exit tables leave it:
///
/// | you came in heading | the curtain leads to |
/// |---|---|
/// | west, from the West Teller's Room | the West Viewing Room |
/// | east, from the East Teller's Room | the East Viewing Room |
/// | north, from the Chairman's Office | the Small Room |
/// | south, back out of the curtain itself | the **Vault** |
///
/// Two of those four rooms have no declared exits whatsoever (`BKTWI` and
/// `BKVAU` are both `NULEXIT` in the source), so the way out of them is through
/// a wall. `SCOL-WALLS` pairs four (room, wall) combinations with a room each —
/// the west Viewing Room's east wall reaches the east Viewing Room, the Small
/// Room's south wall reaches the Vault, and both of those run backwards too.
/// **Every other wall drops you at the Bank Entrance**, which is `SCOLEXIT`'s
/// destination and the only way to leave the building carrying anything, since
/// the Depository's own doorways ring the alarm on bank property.
///
/// So the solution is: in by a teller's room, south to the Chairman's Office
/// for the portrait, north into the Depository — *heading north* — through the
/// curtain into the Small Room, through its south wall into the Vault, take the
/// bills, and out through any other wall.
///
/// ## What the atlas leaves open, and what fills it
///
/// The atlas records `BKBOX`'s east and west exits as conditional on `FROBOZZ`.
/// That flag is never set anywhere in `dung.355`; it is the source's idiom for
/// *this exit is decided by a routine*, and the routines here — `BKLEAVEW`,
/// `BKLEAVEE`, `SCOLGO`, `BKBOX-ROOM` — are in files the extraction does not
/// carry. What is in the source, and is used above, is the shape of the two
/// tables and the text of the alarm. The rest is reconstruction, and the PR
/// that landed this milestone says so.
///
/// The seam the host wires is the Gallery's west door in — a ``DungeonCellar``
/// room.
struct DungeonBank: GameContent {
    // MARK: - Rooms

    /// `BKENT`. Northwest and northeast to the tellers, south to the Gallery.
    let bankEntrance = Location {
        name("Bank Entrance")
        description(Prose.bankEntrance)
        dark
    }

    /// `BKTW`. Its description is generated in the source; written fresh here.
    let westTellersRoom = Location {
        name("West Teller's Room")
        description(Prose.tellerRoom("west"))
        dark
    }

    /// `BKTE`.
    let eastTellersRoom = Location {
        name("East Teller's Room")
        description(Prose.tellerRoom("east"))
        dark
    }

    /// `BKVW`. Named "Viewing Room" exactly like its twin, and being unable to
    /// tell them apart is half the puzzle.
    let westViewingRoom = Location {
        name("Viewing Room")
        alwaysDescribed
        dark
    }

    /// `BKVE`. The twin.
    let eastViewingRoom = Location {
        name("Viewing Room")
        alwaysDescribed
        dark
    }

    /// `BKBOX`. Lit in the source (`RLIGHTBIT`), which is the curtain's doing.
    let safetyDepository = Location {
        name("Safety Depository")
        description(Prose.safetyDepository)
    }

    /// `BKEXE`.
    let chairmansOffice = Location {
        name("Chairman's Office")
        description(Prose.chairmansOffice)
        dark
    }

    /// `BKTWI`. No exits at all.
    let smallRoom = Location {
        name("Small Room")
        alwaysDescribed
        dark
    }

    /// `BKVAU`. No exits at all, and the bills are in it.
    let vault = Location {
        name("Vault")
        alwaysDescribed
        dark
    }

    // MARK: - State

    /// Which of the four inner rooms the curtain of light currently opens on —
    /// the source's `SCOL-ROOM`, whose initial value is the West Viewing Room.
    /// Set by the direction you last walked into the Depository by, and by
    /// nothing else.
    @Global var curtainLeadsTo = BankInnerRoom.westViewing

    // MARK: - Items

    let bankSigns = Item {
        name("signs")
        adjectives("painted")
        synonyms("sign", "arrows", "arrow", "furniture")
        description(Prose.bankSigns)
        scenery
        plural
    }

    let westTellerCounter = Self.tellerCounter()
    let eastTellerCounter = Self.tellerCounter()

    private static func tellerCounter() -> Item {
        Item {
            name("stone counter")
            adjectives("stone", "brass")
            synonyms("counter", "grille", "slot", "station")
            description(Prose.tellerCounter)
            scenery
        }
    }

    let westViewingSign = Self.viewingSign()
    let eastViewingSign = Self.viewingSign()

    private static func viewingSign() -> Item {
        Item {
            name("sign")
            adjectives("printed")
            synonyms("notice", "sign", "writing")
            description(Prose.viewingRoomSign)
            scenery
        }
    }

    /// `VAULT`. The stone cube in the middle of the Depository, and the only
    /// thing in the room that says what is behind the curtain.
    let stoneCube = Item {
        name("large stone cube")
        adjectives("large", "stone", "grey")
        synonyms("cube", "lettering", "letters", "block")
        description(Prose.stoneCube)
        scenery
    }

    /// `SCOL`. Carries *wall* in its vocabulary as well as its own name,
    /// because the atlas puts `WALL-NBIT` on `BKBOX` too and the room's own
    /// description calls the curtain a wall. It does **not** carry *north*:
    /// the four inner rooms have a northern wall of their own, and the curtain
    /// follows the player into them.
    let curtain = Item {
        name("shimmering curtain of light")
        adjectives("shimmering")
        synonyms("curtain", "light", "wall")
        description(Prose.curtainOfLight)
        scenery
    }

    let officeWreckage = Item {
        name("wreckage")
        adjectives("vandalized", "broken")
        synonyms("desk", "chair", "drawers", "paint", "furniture", "wall")
        description(Prose.chairmansOfficeWreckage)
        scenery
    }

    /// `BILLS`. Ten to find and fifteen to case — the largest single treasure
    /// this milestone adds.
    let bills = Item {
        name("stack of zorkmid bills")
        adjectives("neat", "zorkmid", "stacked")
        synonyms("bills", "bill", "stack", "pile", "money")
        firstSight(Prose.billsFirstSight)
        description(Prose.bills)
        trait(.weight, 10)
        trait(.takeValue, 10)
        trait(.depositValue, 15)
    }

    /// `PORTR`. Ten and five, and it hangs on the wall until it doesn't.
    let portrait = Item {
        name("portrait of J. Pierpont Flathead")
        adjectives("flathead", "painted")
        synonyms("portrait", "painting", "art", "picture")
        firstSight(Prose.portraitFirstSight)
        description(Prose.portrait)
        trait(.weight, 25)
        trait(.takeValue, 10)
        trait(.depositValue, 5)
    }

    // MARK: - The walls

    /// `WEAST`, `WSOUT`, `WWEST`, `WNORT` — four `GOBJECT` globals over two
    /// bits (`WALL-ESWBIT` and `WALL-NBIT`), carried into the four inner rooms.
    /// This engine has no globals, so each of the four rooms declares its own
    /// four walls: sixteen items where the source has four. The factory keeps
    /// it to a line each, and the PR that landed this milestone files it as
    /// further evidence for the feature the atlas's Globals section describes.
    private static func bankWall(_ face: String) -> Item {
        Item {
            name("\(face)ern wall")
            adjectives(face, "\(face)ern")
            synonyms("wall", "walls")
            description(Prose.bankWall(face))
            scenery
        }
    }

    let westViewingNorthWall = Self.bankWall("north")
    let westViewingSouthWall = Self.bankWall("south")
    let westViewingEastWall = Self.bankWall("east")
    let westViewingWestWall = Self.bankWall("west")

    let eastViewingNorthWall = Self.bankWall("north")
    let eastViewingSouthWall = Self.bankWall("south")
    let eastViewingEastWall = Self.bankWall("east")
    let eastViewingWestWall = Self.bankWall("west")

    let smallRoomNorthWall = Self.bankWall("north")
    let smallRoomSouthWall = Self.bankWall("south")
    let smallRoomEastWall = Self.bankWall("east")
    let smallRoomWestWall = Self.bankWall("west")

    let vaultNorthWall = Self.bankWall("north")
    let vaultSouthWall = Self.bankWall("south")
    let vaultEastWall = Self.bankWall("east")
    let vaultWestWall = Self.bankWall("west")

    // MARK: - Verbs

    var verbs: [SyntaxRule] { [.walkThrough] }

    /// The word answers everywhere, because it is in the game's vocabulary
    /// everywhere — and what it says everywhere is region-neutral. The Bank's
    /// own walls answer it in ``rules``; a default that talked about *walls*
    /// would be this region telling the whole game what a rainbow is.
    var actions: [IntentAction] {
        action(.walkThrough) { try reply(Prose.nothingToWalkThrough) }
    }

    // MARK: - Map

    var map: WorldMap {
        // The entrance hall. South is the Gallery, a ``DungeonCellar`` room —
        // host-wired.
        bankEntrance.northwest(westTellersRoom)
        bankEntrance.northeast(eastTellersRoom)

        // The teller's rooms. North into a viewing room is one-way in the
        // source, and stays one-way here: a viewing room's only door is south.
        westTellersRoom.north(westViewingRoom)
        westTellersRoom.south(bankEntrance)
        westTellersRoom.west(safetyDepository)

        eastTellersRoom.north(eastViewingRoom)
        eastTellersRoom.south(bankEntrance)
        eastTellersRoom.east(safetyDepository)

        westViewingRoom.south(bankEntrance)
        eastViewingRoom.south(bankEntrance)

        // The Depository. North is the curtain, which is not a compass exit at
        // all — the source declares it `#NEXIT` and answers `walk through
        // curtain` instead, so the refusal here is the room's own.
        safetyDepository.north(blocked: Prose.curtainOfLight)
        safetyDepository.south(chairmansOffice)
        safetyDepository.west(
            westTellersRoom, when: { !carryingBankProperty }, otherwise: Prose.bankAlarm)
        safetyDepository.east(
            eastTellersRoom, when: { !carryingBankProperty }, otherwise: Prose.bankAlarm)

        chairmansOffice.north(safetyDepository)

        // `BKTWI` and `BKVAU` declare no exits at all. Neither do they here.

        bankSigns.starts(in: bankEntrance)
        westTellerCounter.starts(in: westTellersRoom)
        eastTellerCounter.starts(in: eastTellersRoom)
        westViewingSign.starts(in: westViewingRoom)
        eastViewingSign.starts(in: eastViewingRoom)

        stoneCube.starts(in: safetyDepository)
        curtain.starts(in: safetyDepository)

        officeWreckage.starts(in: chairmansOffice)
        portrait.starts(in: chairmansOffice)
        bills.starts(in: vault)

        for (room, walls) in wallsByRoom {
            for wall in walls { wall.starts(in: room) }
        }
    }

    /// The four walls each inner room carries, in north, south, east, west
    /// order — the order ``wallLeadsTo(from:through:)`` reads them in.
    /// The four rooms the curtain reaches, which are also the four with walls
    /// worth walking through.
    private var innerRooms: [Location] { [westViewingRoom, eastViewingRoom, smallRoom, vault] }

    private var wallsByRoom: [(Location, [Item])] {
        [
            (
                westViewingRoom,
                [
                    westViewingNorthWall, westViewingSouthWall, westViewingEastWall,
                    westViewingWestWall,
                ]
            ),
            (
                eastViewingRoom,
                [
                    eastViewingNorthWall, eastViewingSouthWall, eastViewingEastWall,
                    eastViewingWestWall,
                ]
            ),
            (
                smallRoom,
                [smallRoomNorthWall, smallRoomSouthWall, smallRoomEastWall, smallRoomWestWall]
            ),
            (vault, [vaultNorthWall, vaultSouthWall, vaultEastWall, vaultWestWall]),
        ]
    }

    /// The source's `SCOL-WALLS`: the four (room, wall) pairs that reach
    /// somewhere other than the street. Everything not in here reaches the
    /// Bank Entrance.
    private var scolWalls: [(wall: Item, to: Location)] {
        [
            (westViewingEastWall, eastViewingRoom),
            (eastViewingWestWall, westViewingRoom),
            (smallRoomSouthWall, vault),
            (vaultNorthWall, smallRoom),
        ]
    }

    /// Whether the player is carrying something that belongs to the bank. The
    /// alarm on the Depository's two doorways reads this and nothing else.
    var carryingBankProperty: Bool { bills.isHeld || portrait.isHeld }

    // MARK: - Rules

    var rules: Rules {
        // The hidden state, set where nobody would think to look for it: the
        // bearing you were travelling on when you walked in.
        for (from, heading, answer) in [
            (westTellersRoom, Direction.west, BankInnerRoom.westViewing),
            (eastTellersRoom, .east, .eastViewing),
            (chairmansOffice, .north, .small),
        ] {
            from.before(.go) {
                guard command.direction == heading else { return }
                curtainLeadsTo = answer
            }
        }

        // The lettering the Depository's description promises. `examine` gives
        // you the cube; `read` gives you what is cut into it.
        stoneCube.before(.read) { try reply(Prose.stoneCubeLettering) }

        // The curtain, which is the source's `SCOL-ACTIVE`: it does not stay in
        // the Depository. Walk into it and you arrive in whichever room the
        // last bearing chose, and the curtain arrives with you — so it is the
        // way back as well, and going back through it is a walk into the
        // Depository *heading south*, which is the one bearing no doorway can
        // give you and the only one that opens the Vault.
        curtain.before(.walkThrough, .board, .touch) {
            if player.location == safetyDepository {
                let inner = room(for: curtainLeadsTo)
                curtain.move(to: inner)
                say(Prose.curtainCarriesYou)
                player.location = inner
            } else {
                curtain.move(to: safetyDepository)
                curtainLeadsTo = .vault
                say(Prose.curtainCarriesYou)
                player.location = safetyDepository
            }
            describeSurroundings()
            try reply("")
        }

        // The four inner rooms say whether the curtain is standing in them,
        // because it is their only door and a brief re-entry would hide it.
        for room in innerRooms {
            room.describe { innerRoomDescription(room) }
        }

        // And the walls. `SCOL-WALLS` names four of the sixteen; the other
        // twelve are the way out of the building. The pairing table is read
        // once here rather than rebuilt inside each of the sixteen closures.
        let pairs = scolWalls
        for (_, walls) in wallsByRoom {
            for wall in walls {
                wall.before(.walkThrough) { try walkThrough(wall, pairedBy: pairs) }
            }
        }
    }

    /// An inner room's description, plus the curtain if the curtain is here.
    private func innerRoomDescription(_ room: Location) -> String {
        let base =
            if room == smallRoom {
                Prose.smallRoom
            } else if room == vault {
                Prose.vault
            } else {
                Prose.viewingRoom
            }
        guard curtain.isIn(room) else { return base }
        return "\(base)\n\n\(Prose.curtainHangsHere)"
    }

    /// Which room a wall gives onto: the paired room if `SCOL-WALLS` names the
    /// pair, and the Bank Entrance otherwise. The second half is what lets
    /// anybody leave the Vault at all, and it is the only way out of the
    /// building with the takings.
    private func walkThrough(
        _ wall: Item, pairedBy pairs: [(wall: Item, to: Location)]
    )
        throws -> Never
    {
        let destination = pairs.first { $0.wall == wall }?.to ?? bankEntrance
        say(Prose.wallGivesWay)
        player.location = destination
        describeSurroundings()
        try reply("")
    }

    /// The room a ``BankInnerRoom`` names.
    private func room(for inner: BankInnerRoom) -> Location {
        switch inner {
        case .westViewing: westViewingRoom
        case .eastViewing: eastViewingRoom
        case .small: smallRoom
        case .vault: vault
        }
    }
}

/// The four rooms the Bank's curtain of light can open on — the source's
/// `SCOL-ROOMS`, which is a table of four directions against four rooms.
///
/// A named value rather than a `Location`, because a `@Global` holds saved
/// state and a room is not that; the mapping back is
/// ``DungeonBank/room(for:)``.
enum BankInnerRoom: String, Codable, Sendable, GlobalValue {
    case westViewing, eastViewing, small, vault

    /// Stored as its own raw string rather than through the default JSON box,
    /// which would encode and decode on every read and write of a global the
    /// Bank touches on every move. `GnustoClock`'s `TimeOfDay` is the same
    /// four lines for the same reason.
    public var stateValue: StateValue { .string(rawValue) }

    /// - Parameter stateValue: the saved value to read back.
    public init?(stateValue: StateValue) {
        guard case .string(let raw) = stateValue else { return nil }
        self.init(rawValue: raw)
    }
}

import Gnusto

/// Which Viewing Room the player last walked through. This is the Bank of
/// Zork's hidden state: nothing in the Safety Depository shows it, and it is
/// the only thing that decides where the curtain of light puts you.
enum ViewingSide: String, Codable, Sendable, GlobalValue {
    case west, east
}

/// A miniature Bank of Zork, the fixture behind the Dungeon spike (#132).
///
/// The mainframe's Bank has walls that are not Euclidean: the *same* move from
/// the *same* room lands you somewhere different depending on state you were
/// never shown. Both destinations — `BKTWI` Small Room and `BKVAU` Vault —
/// have zero declared exits in the atlas; the curtain is their only door.
///
/// Room names are the atlas's own (`docs/games/dungeon-atlas.md`), including
/// the two Viewing Rooms that deliberately share a display name — being unable
/// to tell them apart is the puzzle.
///
/// The fixture carries both routes into the vaults, side by side, because the
/// difference between them is the spike's finding:
///
/// - **North** is a dynamic exit. It runs through the engine's `enter()`, so
///   the destination's `onEnter` rules fire.
/// - **`walk through curtain`** is the hand-rolled teleport idiom Zork 1's
///   mirror rooms use (`player.location =` / `describeSurroundings()`). It
///   reaches the same room and silently skips its `onEnter` rules.
struct BankOfZorkGame: Game {
    let title = "The Bank of Zork"
    let intro = "The Bank of Zork regrets that its floor plan is proprietary."

    // MARK: - Geography

    let bankEntrance = Location {
        name("Bank Entrance")
        description(
            "This is the west end of a large lobby. Doorways lead west and east."
        )
    }

    /// `BKVW`. Named "Viewing Room" exactly like its twin — see the type doc.
    let viewingRoomWest = Location {
        name("Viewing Room")
        description("The walls here are lined with dull silver. A passage leads north.")
    }

    /// `BKVE`. The twin.
    let viewingRoomEast = Location {
        name("Viewing Room")
        description("The walls here are lined with dull gold. A passage leads north.")
    }

    let depository = Location {
        name("Safety Depository")
        description(
            """
            This is a large rectangular room. A shimmering curtain of light \
            hangs across the north wall, and a passage leads south.
            """
        )
    }

    /// `BKTWI`. No declared exits.
    let smallRoom = Location {
        name("Small Room")
        description("This is a small, bare room with a shimmering wall to the south.")
    }

    /// `BKVAU`. No declared exits either — the room the issue calls out.
    let vault = Location {
        name("Vault")
        description("This is the Bank Vault. A shimmering wall stands to the south.")
    }

    // MARK: - Things

    /// `SCOL`. Scenery, because the Depository's description names it and every
    /// noun a room prints has to answer.
    let curtain = Item {
        name("shimmering curtain of light")
        adjectives("shimmering")
        synonyms("curtain", "light")
        description("A wall of pure white light, silent and cold.")
        scenery
    }

    /// The two dead ends need a wall each: an item is in one room at a time,
    /// so the way out of two exitless rooms cannot be one declaration. They
    /// share `leaveThroughWall()` below rather than a declaration.
    let vaultWall = Item {
        name("shimmering wall")
        adjectives("shimmering")
        synonyms("wall")
        description("The south wall shimmers like heat over stone.")
        scenery
    }

    let smallRoomWall = Item {
        name("shimmering wall")
        adjectives("shimmering")
        synonyms("wall")
        description("The south wall shimmers like heat over stone.")
        scenery
    }

    // MARK: - The hidden state

    @Global var lastViewingRoom = ViewingSide.west

    // MARK: - Map

    var map: WorldMap {
        bankEntrance.west(viewingRoomWest)
        bankEntrance.east(viewingRoomEast)

        viewingRoomWest.east(bankEntrance)
        viewingRoomWest.north(depository)

        viewingRoomEast.west(bankEntrance)
        viewingRoomEast.north(depository)

        depository.south(bankEntrance)

        // The whole spike, in one line: one direction, two destinations,
        // chosen in the live turn frame from state the player never sees.
        depository.north { lastViewingRoom == .west ? smallRoom : vault }

        player.starts(in: bankEntrance)
        curtain.starts(in: depository)
        vaultWall.starts(in: vault)
        smallRoomWall.starts(in: smallRoom)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("walk", "through", .directObject, intent: Self.walkThrough)
    }

    static let walkThrough = Intent("walkThrough")

    // MARK: - Rules

    var rules: Rules {
        // The hidden state, set where the player would never think to look.
        viewingRoomWest.onEnter { lastViewingRoom = .west }
        viewingRoomEast.onEnter { lastViewingRoom = .east }

        // Probes: these fire only when the destination is reached through a
        // real exit, which is exactly what the two routes below are compared on.
        smallRoom.onEnter { say("[onEnter] Dust lifts off the floor.") }
        vault.onEnter { say("[onEnter] The air in here is very still.") }

        // Route B — the hand-rolled teleport, the idiom shipped at
        // `Sources/Zork1/Regions/Mirror.swift:184`. Same destination as the
        // north exit, reached without the engine's `enter()`.
        curtain.before(Self.walkThrough) {
            say("You step into the light, and the light steps into you.")
            player.location = lastViewingRoom == .west ? smallRoom : vault
            describeSurroundings()
            try handled()
        }

        // The way back out of two rooms that have no exits at all.
        vaultWall.before(Self.walkThrough) { try leaveThroughWall() }
        smallRoomWall.before(Self.walkThrough) { try leaveThroughWall() }
    }

    /// Puts the player back in the Depository from a room with no declared
    /// exits. Shared by both walls so the two dead ends can't drift apart.
    func leaveThroughWall() throws -> Never {
        say("The wall gives like water, and closes behind you.")
        player.location = depository
        describeSurroundings()
        try handled()
    }
}

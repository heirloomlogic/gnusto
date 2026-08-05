import GnustoTestSupport
import Testing

@testable import Gnusto

/// The Dungeon spike for the Bank of Zork (#132): can one move from one room
/// reach two destinations, chosen from hidden state, and is the arriving room
/// narrated properly?
///
/// FOLLOW's side of the same exit kind is pinned in `FollowTests`, against the
/// fixture that already contrasts the other four kinds; the duplicate-direction
/// diagnostic is in `BootstrapTests`.
struct NonEuclideanTests {
    // MARK: - The headline

    @Test func oneDirectionReachesTwoDestinations() async throws {
        // West Viewing Room, then north: the Small Room. Back out, east
        // Viewing Room, then north: the Vault. Same room, same move — the
        // spellings differ only so `turnOutput` can tell the turns apart.
        let transcript = try await play(
            BankOfZorkGame(),
            [
                "west",  // Viewing Room (west)
                "go north",  // Safety Depository
                "north",  // -> Small Room
                "walk through wall",  // back to the Depository
                "south",  // Bank Entrance
                "east",  // Viewing Room (east)
                "run north",  // Safety Depository
                "walk north",  // -> Vault
            ]
        )
        // Both arrivals are narrated in full — name, description, and the
        // destination's own onEnter line. Nothing assumes the room had
        // anything to do with the direction.
        let westward = turnOutput(of: "north", in: transcript)
        let eastward = turnOutput(of: "walk north", in: transcript)
        #expect(westward.contains("Small Room"))
        #expect(westward.contains("This is a small, bare room"))
        #expect(westward.contains("[onEnter] Dust lifts off the floor."))
        #expect(!westward.contains("Vault"))

        #expect(eastward.contains("Vault"))
        #expect(eastward.contains("This is the Bank Vault."))
        #expect(eastward.contains("[onEnter] The air in here is very still."))
        #expect(!eastward.contains("Small Room"))
    }

    // MARK: - A room with no ordinary door

    @Test func theVaultHasNoDeclaredExits() async throws {
        let transcript = try await play(
            BankOfZorkGame(),
            ["east", "north", "north", "south", "west", "up"]
        )
        #expect(turnOutput(of: "south", in: transcript).contains("You can't go that way."))
        #expect(turnOutput(of: "west", in: transcript).contains("You can't go that way."))
        #expect(turnOutput(of: "up", in: transcript).contains("You can't go that way."))
    }

    @Test func theShimmeringWallIsTheOnlyWayOutOfTheVault() async throws {
        let transcript = try await play(
            BankOfZorkGame(),
            ["east", "north", "north", "walk through wall", "look"]
        )
        expectInOrder(
            transcript,
            [
                "> walk through wall",
                "The wall gives like water",
                "Safety Depository",
            ]
        )
    }

    // MARK: - The curtain answers as a noun

    @Test func theCurtainTheRoomDescribesIsExaminable() async throws {
        // The Depository's description names the curtain, so the parser has to
        // know it — "You can't see any such thing" here would be a bug.
        let transcript = try await play(
            BankOfZorkGame(), ["west", "north", "examine curtain"])
        let looked = turnOutput(of: "examine curtain", in: transcript)
        #expect(looked.contains("A wall of pure white light"))
        #expect(!looked.contains("can't see any such thing"))
    }

    // MARK: - What the two routes do differently

    /// Characterization, not endorsement. `player.location =` is a bare
    /// teleport — it sets the location and nothing else — so the destination's
    /// `onEnter` rules never run, where the north exit's do. `locationOnEnter`
    /// is dispatched from exactly one place, `DefaultActions.enter()`. Every
    /// hand-rolled teleport in the repo has this hole; this test is here so
    /// that closing it has to be a decision somebody makes on purpose.
    @Test func aHandRolledTeleportSkipsTheDestinationsOnEnterRules() async throws {
        let transcript = try await play(
            BankOfZorkGame(), ["east", "north", "walk through curtain"])
        let arrival = turnOutput(of: "walk through curtain", in: transcript)
        expectInOrder(arrival, ["You step into the light", "Vault", "This is the Bank Vault."])
        #expect(!arrival.contains("[onEnter]"))
    }

    // MARK: - Vehicles

    @Test func aBoardedVehicleRidesAlongThroughADynamicExit() async throws {
        // Every other passable exit carries the boarded vehicle into the
        // destination room; a dynamic one has to as well, or `player.vehicle`
        // silently empties mid-journey. The dock's east channel comes out in
        // the boathouse until the tide goes out.
        let transcript = try await play(
            HarborGame(), ["enter boat", "east", "get out", "look"])
        let arrival = turnOutput(of: "east", in: transcript)
        #expect(arrival.contains("Boathouse, in the red boat"))
        #expect(!arrival.contains("There is a red boat here."))
        // Ashore again, the boat is in the room it carried the player to.
        #expect(turnOutput(of: "look", in: transcript).contains("There is a red boat here."))
    }

    @Test func theSameChannelComesOutSomewhereElseOnceTheTideIsOut() async throws {
        // The dark cave, reached through the same exit — and described as the
        // engine describes any unlit arrival, not mistaken for the boathouse.
        let transcript = try await play(HarborGame(), ["ebb", "east"])
        let arrival = turnOutput(of: "east", in: transcript)
        #expect(!arrival.contains("Boathouse"))
        #expect(arrival.contains("pitch black"))
    }
}

import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// End-to-end playthroughs of the Phase 10.11 thief endgame: the egg's two ways
/// open (your clumsy hands wreck the canary; the thief's careful hands don't),
/// the give-to-thief service, and the defended lair (the Treasure Room's +25
/// award, the guarded silver chalice, and the thief who fights to the death
/// there). The thief roams the whole underground, so every route is seed-pinned;
/// the seeds are final (the Phase 10.14 walkthrough closed the roadmap's planned
/// one-time re-pin).
struct Zork1ThiefTests {
    @Test func forcingTheEggOpenRuinsTheCanary() async throws {
        // Opening the jewel-encrusted egg by hand is fatal to the delicate
        // clockwork bird inside: the intact canary is swapped for a mangled
        // ruin, and the shell's 5 points for the find are all it's now worth.
        // No thief involved, so no seed pin is needed for the mechanic — seed 1
        // just keeps the run reproducible.
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg", "open egg",
                "look in egg", "examine canary", "score",
            ],
            seed: 1)
        expectInOrder(
            transcript,
            [
                "clumsiness of your attempt",  // ruined on force
                "reveals a broken clockwork canary.",  // the built-in open shows the ruin
                "In the jewel-encrusted egg is a broken clockwork canary.",
                "recently had a bad experience",  // the broken canary's own description
                "Your score is 5 of a possible 350",  // the shell scored 5; the canary, nothing
            ])
    }

    @Test func theThiefTakesTheEggYouOffer() async throws {
        // Hand the thief the egg where you meet him in the Gallery and he
        // pockets it with a knowing smile — the setup for his off-screen
        // egg-opening service (where, unlike your clumsy hands, he keeps the
        // canary intact). The egg leaves your possession with him. Seed 5 keeps
        // the thief loitering in the Gallery when you arrive with the egg.
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg", "down",
                "south", "west", "south",
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east",  // East of Chasm → Gallery, where the thief starts
                "give egg to thief", "examine egg", "inventory",
            ],
            seed: 5)
        expectInOrder(
            transcript,
            [
                "unexpected generosity",
                "stops to admire its beauty.",  // he takes it (the service is armed)
                "You can't see any such thing.",  // examine egg — it's gone with him
                "You are carrying:",
                "a brass lantern",  // …and only the lantern; the egg is his now
            ])
        // The egg really did leave your hands — the inventory names only the
        // lantern.
        let carried = turnOutput(of: "inventory", in: transcript)
        #expect(!carried.contains("egg"))
    }

    @Test func theThiefDefendsHisLair() async throws {
        // The Treasure Room is the thief's, and he defends it. Reaching it pays
        // 25; entering summons him home; the silver chalice can't be lifted
        // while he lives; and his stiletto finds you before you can force the
        // issue — death, then Zork's resurrection to the forest. Seed 39 (the
        // prelude's three-blow troll kill lands on this seed): kitchen 10 +
        // cellar 25 + Treasure Room 25 − the 10-point death toll = 50.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west",
                "take lunch", "take bottle", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north",
                "attack troll", "attack troll", "attack troll",
                "west",  // Maze-1
                "west", "west", "up",  // Maze-4 → Maze-3 → Maze-5
                "southwest", "east", "south", "southeast",  // → Cyclops Room
                "odysseus",  // rout the cyclops, opening the stair up
                "up",  // Treasure Room
                "take chalice",  // guarded — and his killing blow lands this turn
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Treasure Room",
                "silver chalice, intricately engraved",  // the hoard's prize
                "suspicious-looking individual",  // the thief, summoned to defend it
                "stabbed in the back first",  // the take is refused
                "you probably deserve another",  // his stiletto kills you; resurrection
                "Forest",  // you wake in the woods
                "Your score is 50 of a possible 350",  // +25 lair visit, −10 death toll
            ])
    }
}

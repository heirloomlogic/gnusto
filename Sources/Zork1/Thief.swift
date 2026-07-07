import Gnusto
import GnustoMeleeCombat

/// The thief — Zork's roving antagonist, promoted this phase from the reduced
/// Phase-8 cutpurse into the full endgame villain. He roams the whole
/// underground, lifts any treasure you carry, ferries his takings back to his
/// lair (the Treasure Room), and defends that lair to the death with his
/// stiletto — but stays evasive everywhere else. Give him the jewel-encrusted
/// egg and he'll open it for you where you can't; kill him and his whole hoard,
/// the stiletto included, spills at your feet, and the trap door he bolted from
/// below swings free.
///
/// This bundle owns only the thief's *entities and state*: the actor, his
/// weapon, and the `thiefDefeated` flag. Every behaviour he has reaches across
/// bundles — the blades that fell him (``ZorkHouse``), the treasures he covets
/// (every region), his lair (``ZorkMaze``), the trap door he bars
/// (``ZorkHouse``) — so, following the codebase rule that cross-bundle seams
/// belong to the host, all of his roaming, stealing, stashing, lair defence,
/// egg service, and death are wired in ``Zork1``. See `FIDELITY.md`.
struct ZorkThief: GameContent {
    // MARK: - The thief

    let thief = Actor {
        name("thief")
        adjectives("shadowy")
        synonyms("figure")
        description(Prose.thief)
        firstSight(Prose.thiefPresence)
    }

    /// Set the moment he falls (his `onDefeat`, wired in ``Zork1``). Clears the
    /// trap-door bar and gates the silver chalice: while he lives the Treasure
    /// Room is his, and its hoard stays out of reach.
    @Global var thiefDefeated = false

    // MARK: - Items

    /// The thief's vicious little blade — his own weapon, and, like the sword,
    /// the nasty knife, the rusty knife, the axe, and the sceptre, sharp enough
    /// to hole the inflatable boat. Rides in his hand until he drops it dead;
    /// the original's SIZE 10.
    let stiletto = Item {
        name("stiletto")
        adjectives("vicious")
        synonyms("blade", "knife")
        description(Prose.stiletto)
        trait(.weight, 10)
        trait(.weapon, true)
        trait(.sharp, true)  // holes the river boat — see ZorkRiver
    }

    // MARK: - Map

    var map: WorldMap {
        stiletto.starts(heldBy: thief)
        // The thief begins in the Gallery, one of the rooms in his roam set, and
        // teleport-wanders the underground from there (the roam daemon is
        // host-wired in ``Zork1``, spanning every region he prowls).
    }
}

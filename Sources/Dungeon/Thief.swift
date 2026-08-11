import Gnusto
import GnustoActors
import GnustoMeleeCombat

/// The thief — `THIEF` in the source, and the one inhabitant of the dungeon
/// who belongs to no region because he walks through all of them. He prowls the
/// underground, lifts treasure out of your hands, ferries it back to the
/// Treasure Room at the top of the maze, and defends that hoard to the death.
///
/// He is also the only pair of careful hands in the game. The jewel-encrusted
/// egg has a mechanism too fine for yours: force it and the clockwork canary
/// inside comes out ruined, worth nothing and good for nothing. Hand it to the
/// thief and he opens it cleanly — which is the whole route to the canary's
/// six-and-two and to the brass bauble the songbird drops for it. Milestone 1
/// declared those ten points and said plainly that they were unwalkable until
/// he landed. This is where he lands.
///
/// This bundle owns his *entities and state* only: the actor, his blade, and
/// his two flags. Every behaviour he has crosses bundles — the weapons that
/// fell him are ``DungeonHouse``'s, the treasures he covets are every region's,
/// his lair is ``DungeonMaze``'s, the egg is ``DungeonAboveGround``'s and the
/// bird inside it is ``DungeonHouse``'s — so all of it is wired on ``Dungeon``,
/// which is the codebase rule for a seam. It is in `Dungeon+Thief.swift`
/// rather than in `Dungeon.swift` itself: that file is nine hundred lines
/// already, and a seam this size announcing itself by name is easier to find
/// and cheaper to rebase than three hundred lines buried in the host.
///
/// ### Where he differs from `Sources/Zork1/`'s thief
///
/// - **He does not free the trap door.** In Zork I the bar is his doing and his
///   death lifts it. In the mainframe the trap door bars itself for good and
///   the chimney is the way home — milestone 1's finding, and the reason his
///   `onDefeat` here is shorter than Zork I's by one line.
/// - **His stiletto is not sharp.** This game carries no `.sharp` trait at all:
///   the broken sharp stick is the only thing in it that holes the boat, which
///   is milestone 4's finding. Zork I's stiletto is one of five blades that do.
/// - **He starts nowhere.** The atlas records `THIEF`'s start as *by code*, not
///   in a room; Zork I stands him in the Gallery from turn one. Here the code is
///   a rule: the first treasure lifted off the dungeon floor puts him into play,
///   in the Treasure Room, standing over what he has already taken.
/// - **His lair pays.** `TREAS` carries a room value of 25 and the chalice in it
///   is worth 10 and 10; Zork I gives the room nothing and the chalice half.
///   The 35 points milestone 4 declared for walking in are what he is guarding.
///
/// See `FIDELITY.md` and `docs/games/dungeon.md`.
struct DungeonThief: GameContent {
    // MARK: - The thief

    /// The vocabulary is the two lines he prints. `bag` is a synonym and
    /// `large` an adjective because his presence line says "holding a large
    /// bag", and every noun a room description prints has to answer; `suspicious`
    /// and `looking` are written apart because that is how the tokenizer splits
    /// the hyphen on both sides.
    ///
    /// In the Treasure Room `bag` collides with the discarded bags on the floor,
    /// and the parser's own question is the right answer to that: the room
    /// really does contain two things a player could mean by it.
    let thief = Actor {
        name("thief")
        adjectives("shadowy", "suspicious", "looking", "seedy", "large")
        synonyms("robber", "figure", "individual", "man", "bandit", "bag")
        description(Prose.thief)
        firstSight(Prose.thiefPresence)
    }

    /// Set the moment he falls. Read by every rule that has to know whether the
    /// dungeon still has a thief in it — the summons, the gift, the egg fuse.
    @Global var thiefDefeated = false

    /// Set while he is turning a gift over in his hands, and read by the
    /// aggression daemon's gate: a man appraising a jewel-encrusted egg is not
    /// also stabbing you.
    ///
    /// The line he answers a gift with says he "stops to admire its beauty",
    /// and until this flag existed he said it and stabbed you in the same turn.
    /// Found by playing. Two turns, cleared by the `thief.admires` fuse.
    @Global var thiefAdmiring = false

    // MARK: - Items

    /// His blade. `STILL` in the source, which gives it a size of 10 and no
    /// value at all — he is not carrying a treasure, he is carrying a knife.
    /// Deliberately **not** sharp: only the broken sharp stick holes the boat
    /// in this game.
    let stiletto = Item {
        name("stiletto")
        adjectives("vicious", "deadly")
        synonyms("stiletto", "blade", "knife")
        description(Prose.stiletto)
        trait(.weight, 10)
        trait(.weapon, true)
        trait(.weaponStrength, 1)  // a clumsy thing in anyone's hand but his
    }

    // MARK: - Rules

    /// The one thing he does that is not theft or a knife. Everything else
    /// about him — his roaming, his stealing, his fight — is
    /// ``Dungeon/thiefRules``, because the melee plugin and the treasures are
    /// the host's; this needs nothing outside the bundle.
    ///
    /// `reply` because the engine's `.greet` default is a `say`, so a rule that
    /// only said would print both lines. Two states, which is the source's own
    /// count; a dead thief has `vanish()`ed and never reaches a rule.
    @RuleBuilder var rules: Rules {
        thief.before(.greet) {
            try reply(thief.isUnconscious ? Prose.thiefGreetedOnTheFloor : Prose.thiefGreeted)
        }
    }

    // MARK: - Map

    var map: WorldMap {
        stiletto.starts(heldBy: thief)
        // The thief himself is placed by code, which is what the atlas records
        // for him. ``Dungeon/thiefRules`` puts him in the Treasure Room the
        // first time a treasure comes off the dungeon floor.
    }
}

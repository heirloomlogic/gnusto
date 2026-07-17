import Gnusto

/// Logic-only NPC behaviors: roaming, theft, canned reactions. The plugin
/// owns no entities and no state — position *is* the actor's placement —
/// so the host declares its actors and splices these factories into its
/// own `timers` and `rules` blocks:
///
/// ```swift
/// let actors = ActorBehaviors()
///
/// var timers: [TimedEvent] {
///     actors.roams(thief, daemonName: "thief.roam",
///                  rooms: [cellar, gallery, studio])
///     actors.steals(thief, daemonName: "thief.steal",
///                   candidates: [painting],
///                   announcement: { "A shadow relieves you of the \($0)." })
/// }
/// ```
///
/// Every random decision draws from the game's seeded stream, and draws
/// happen **only after** a factory's guards pass — a daemon whose actor is
/// out of position (or whose player has nothing worth taking) consumes no
/// randomness, so transcripts that never meet the actor stay stable no
/// matter what he does elsewhere.
public struct ActorBehaviors: GamePlugin {
    /// Creates the plugin.
    public init() {}

    /// A daemon that, with `chancePerTurn`, moves `actor` to a random
    /// *other* room in `rooms` — a teleport within the set, with no
    /// exit-graph awareness (a wall between two rooms in the set won't
    /// stop him). Arrival/departure lines print only when the player's
    /// room is lit and is the room being entered or left: in the dark, or
    /// a room away, movement is silent. The daemon idles (no RNG drawn)
    /// while the actor is outside `rooms` — including after `vanish()` —
    /// but the host should still `stopDaemon(_:)` on the actor's death.
    ///
    /// - Parameters:
    ///   - actor: the NPC to teleport.
    ///   - daemonName: the daemon's global timer name.
    ///   - rooms: the set of rooms the actor teleports within.
    ///   - percent: per-turn chance of a move, while in the set.
    ///   - arrival: line printed when the player watches the actor arrive.
    ///   - departure: line printed when the player watches the actor leave.
    /// - Returns: the roaming daemon, for the host's `timers` block.
    public func roams(
        _ actor: Actor,
        daemonName: String,
        rooms: [Location],
        chancePerTurn percent: Int = 50,
        arrival: String? = nil,
        departure: String? = nil
    ) -> TimedEvent {
        daemon(daemonName, autostart: true) {
            // Guards before any draw, so absent actors burn no randomness.
            guard let here = actor.location, rooms.contains(here) else { return }
            guard chance(percent) else { return }
            let elsewhere = rooms.filter { $0 != here }
            guard !elsewhere.isEmpty else { return }
            let destination = elsewhere[random(0...elsewhere.count - 1)]

            let playerRoom = player.location
            let playerSees = playerRoom.isLit
            if let departure, playerSees, playerRoom == here {
                say(departure)
            }
            actor.move(to: destination)
            if let arrival, playerSees, playerRoom == destination {
                say(arrival)
            }
        }
    }

    /// A daemon that, when `actor` shares the player's room, rolls
    /// `chancePerTurn` and moves one random *reachable* item from `candidates`
    /// into the actor's inventory, announcing it with the stolen item's name.
    /// Like the original's thief, the actor lifts a candidate from wherever it
    /// lies in the shared room: held by the player, on the floor, or inside an
    /// open container listed in `containers` that is itself here (or held) —
    /// the trophy case among them. Only another actor's hands are beyond reach.
    /// The theft is announced only when the player's room is lit: in the dark
    /// you find out when you check your pockets.
    ///
    /// - Parameters:
    ///   - actor: the thieving NPC.
    ///   - daemonName: the daemon's global timer name.
    ///   - candidates: the items eligible to be stolen.
    ///   - containers: open, co-located containers the actor may rifle (e.g.
    ///     the trophy case). A candidate inside one is fair game when the
    ///     container is open and shares the room (or is held).
    ///   - percent: per-turn chance of a theft, while sharing the room.
    ///   - announcement: builds the theft line from the stolen item's name.
    /// - Returns: the theft daemon, for the host's `timers` block.
    public func steals(
        _ actor: Actor,
        daemonName: String,
        candidates: [Item],
        containers: [Item] = [],
        chancePerTurn percent: Int = 30,
        announcement: @escaping @Sendable (String) -> String
    ) -> TimedEvent {
        daemon(daemonName, autostart: true) {
            // Guards before any draw, so absent actors burn no randomness.
            guard let here = actor.location, player.location == here else { return }
            // Open containers the actor can reach into: co-located (or held)
            // and not shut.
            let openHere = containers.filter { ($0.isIn(here) || $0.isHeld) && $0.isOpen }
            // Reachable candidates: held, on the floor here, or inside one of
            // those open containers.
            let reachable = candidates.filter { loot in
                loot.isHeld || loot.isIn(here) || openHere.contains { $0.holds(loot) }
            }
            guard !reachable.isEmpty else { return }
            guard chance(percent) else { return }
            let loot = reachable[random(0...reachable.count - 1)]
            let name = loot.name
            loot.move(heldBy: actor)
            if player.location.isLit {
                say(announcement(name))
            }
        }
    }

    /// A canned reply when any of the named intents target the actor —
    /// "talk to troll", "give sword to troll", whatever the host's verbs
    /// emit. One line, before-phase, ends the turn.
    ///
    /// - Parameters:
    ///   - actor: the actor the intents target.
    ///   - intents: the intents that trigger the reply.
    ///   - text: the canned reply.
    /// - Returns: the before-phase rules, for the host's `rules` block.
    @RuleBuilder
    public func reaction(
        of actor: Actor,
        to intents: [Intent],
        reply text: String
    ) -> Rules {
        for intent in intents {
            actor.before(intent) {
                try reply(text)
            }
        }
    }
}

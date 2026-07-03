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
    /// `chancePerTurn` and moves one random *held* item from `candidates`
    /// into the actor's inventory, announcing it with the stolen item's
    /// name. Candidates are host-chosen and only count while the player
    /// holds them — the floor, a trophy case, another actor's hands are
    /// all out of reach. The theft is announced only when the player's
    /// room is lit: in the dark you find out when you check your pockets.
    public func steals(
        _ actor: Actor,
        daemonName: String,
        candidates: [Item],
        chancePerTurn percent: Int = 30,
        announcement: @escaping @Sendable (String) -> String
    ) -> TimedEvent {
        daemon(daemonName, autostart: true) {
            // Guards before any draw.
            guard let here = actor.location, player.location == here else { return }
            let held = candidates.filter(\.isHeld)
            guard !held.isEmpty else { return }
            guard chance(percent) else { return }
            let loot = held[random(0...held.count - 1)]
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

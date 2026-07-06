import Gnusto

extension TraitKey<Bool> {
    /// The item can be swung at a villain.
    public static let weapon = Self("weapon", default: false)
}

extension Intent {
    /// The one intent every combat verb emits: attack/kill/hit/fight
    /// bare-handed or `with` a weapon, plus stab/strike (weapon required).
    #verb(
        "attack",
        ["attack", .directObject],
        ["attack", .directObject, "with", .indirectObject],
        ["kill", .directObject],
        ["kill", .directObject, "with", .indirectObject],
        ["hit", .directObject],
        ["hit", .directObject, "with", .indirectObject],
        ["fight", .directObject],
        ["stab", .directObject, "with", .indirectObject],
        ["strike", .directObject, "with", .indirectObject])
}

/// Zork-style-lite melee: attack verbs, a weapon trait, per-villain health,
/// a seeded outcome table (miss / wound / knockout / kill), and an
/// aggression daemon so villains hit back. Deterministic under a pinned
/// seed — every roll draws from the game's saved random stream.
///
/// Add it to the game's `content` block (the verbs and the futile stage-4
/// default come along automatically), mark the weapons, then register each
/// villain and, if he fights back, splice his aggression daemon:
///
/// ```swift
/// let melee = MeleeCombat()
/// let sword = Item { name("elvish sword"); trait(.weapon, true) }
///
/// var content: GameContents { melee }
/// var rules: Rules {
///     melee.villain(troll, key: "troll", strength: 2,
///                   weapons: [sword],
///                   prose: trollProse,
///                   onDefeat: { trollDefeated = true })
/// }
/// var timers: [TimedEvent] {
///     melee.aggression(of: troll, key: "troll", daemonName: "melee.troll",
///                      prose: trollAggression)
/// }
/// ```
///
/// The classic exchange emerges from the turn pipeline: your swing
/// resolves in the command stages, his answer lands with the end-of-turn
/// timers. One deliberate simplification, ledgered per game: player wounds
/// don't heal, and a defeated villain stays defeated.
public struct MeleeCombat: GameContent {
    /// The system's own voice — refusals that belong to the mechanics, not
    /// to any one villain. Override lines at init to re-skin.
    public struct CombatText: Sendable {
        /// Attacking something no villain rule claimed.
        public var attackFutile = "Violence isn't the answer to this one."
        /// Attacking bare-handed with no registered weapon in hand.
        public var noWeapon = "Bare hands won't do it. You need a weapon."
        /// Naming a weapon that isn't one ("attack troll with feather").
        public var notAWeapon: @Sendable (_ name: String) -> String = {
            "The \($0) is no weapon."
        }
        /// Naming a real weapon the player isn't holding.
        public var weaponNotHeld: @Sendable (_ name: String) -> String = {
            "You aren't holding the \($0)."
        }

        /// Creates the default combat text; override any line after construction.
        public init() {}
    }

    /// A villain's lines. Host-supplied per villain — these are inherently
    /// specific, so there are no stock defaults. `miss`/`wound` rotate via
    /// the seeded stream.
    public struct VillainProse: Sendable {
        /// Lines rotated when the player's blow misses.
        public var miss: [String]
        /// Lines rotated when the player's blow wounds.
        public var wound: [String]
        /// Printed when a blow knocks the villain unconscious.
        public var knockout: String
        /// Printed when the villain is killed.
        public var death: String

        /// Creates a villain's prose. All lines are required — villains carry no stock defaults.
        ///
        /// - Parameters:
        ///   - miss: lines rotated when the player's blow misses.
        ///   - wound: lines rotated when the player's blow wounds.
        ///   - knockout: printed when a blow knocks the villain unconscious.
        ///   - death: printed when the villain is killed.
        public init(miss: [String], wound: [String], knockout: String, death: String) {
            self.miss = miss
            self.wound = wound
            self.knockout = knockout
            self.death = death
        }
    }

    /// A villain's counter-attack lines.
    public struct AggressionProse: Sendable {
        /// Lines rotated when the villain's counter-attack misses.
        public var miss: [String]
        /// Lines rotated when the villain's counter-attack wounds.
        public var wound: [String]
        /// Handed to `die(_:)` when the last hit lands.
        public var playerDeath: String

        /// Creates a villain's counter-attack prose.
        ///
        /// - Parameters:
        ///   - miss: lines rotated when the villain's counter-attack misses.
        ///   - wound: lines rotated when the villain's counter-attack wounds.
        ///   - playerDeath: handed to `die(_:)` when the last hit lands.
        public init(miss: [String], wound: [String], playerDeath: String) {
            self.miss = miss
            self.wound = wound
            self.playerDeath = playerDeath
        }
    }

    /// The plugin-owned combat ledger: villain health and stun counters
    /// keyed by registration key, plus the player's own hits. Health seeds
    /// lazily from each villain's declared strength.
    struct Ledger: Codable, Sendable, GlobalValue {
        var health: [String: Int] = [:]
        var stunned: [String: Int] = [:]
        var playerHealth: Int?
    }

    @Global var ledger = Ledger()

    let text: CombatText

    /// Creates the plugin with the given combat text.
    ///
    /// - Parameter text: the system-voice combat lines shared across villains.
    public init(text: CombatText = CombatText()) {
        self.text = text
    }

    /// The attack syntax: attack/kill/hit/fight bare-handed or `with` a weapon,
    /// plus stab/strike, which always name a weapon.
    public var verbs: [SyntaxRule] {
        .attack
    }

    /// The stage-4 default for a target no villain rule claimed.
    public var actions: [IntentAction] {
        action(.attack) {
            try reply(text.attackFutile)
        }
    }

    /// Registers a villain: attacks against `actor` resolve a weapon, roll
    /// the outcome table, and track his health under `key`. At zero health
    /// the death line prints, `onDefeat` runs (unbar the door, drop the
    /// loot — this is the host's composition point, before the body
    /// vanishes), and the actor is removed from play.
    ///
    /// The fixed table, one roll per swing: miss ≤ 30, wound ≤ 70,
    /// knockout ≤ 85, kill above. A stunned villain doesn't roll — the
    /// next blow lands clean.
    ///
    /// - Parameters:
    ///   - actor: the villain being attacked and tracked.
    ///   - key: ledger key storing this villain's health and stun.
    ///   - strength: starting health — clean hits needed to kill.
    ///   - weapons: items that count as weapons against this villain.
    ///   - prose: per-outcome combat lines (miss, wound, knockout, death).
    ///   - onDefeat: host hook run at death, before the actor vanishes.
    /// - Returns: the `before(.attack)` rules driving the villain's combat.
    @RuleBuilder
    public func villain(
        _ actor: Actor,
        key: String,
        strength: Int,
        weapons: [Item],
        prose: VillainProse,
        onDefeat: @escaping @Sendable () -> Void = {}
    ) -> Rules {
        actor.before(.attack) {
            // Resolve the weapon: the named one must be real and in hand;
            // otherwise any held registered weapon serves.
            if let named = command.indirectObject {
                guard weapons.contains(named) else {
                    try refuse(text.notAWeapon(named.name))
                }
                guard named.isHeld else {
                    try refuse(text.weaponNotHeld(named.name))
                }
            } else if !weapons.contains(where: \.isHeld) {
                try refuse(text.noWeapon)
            }

            var health = ledger.health[key] ?? strength
            if ledger.stunned[key, default: 0] > 0 {
                // Finishing the unconscious: no roll, the blow lands clean.
                ledger.stunned[key] = nil
                health = 0
            } else {
                let roll = random(1...100)
                switch roll {
                case ...30:
                    try reply(oneOf(prose.miss))
                case ...70:
                    health -= 1
                    if health > 0 {
                        ledger.health[key] = health
                        try reply(oneOf(prose.wound))
                    }
                case ...85:
                    ledger.health[key] = health
                    ledger.stunned[key] = 2
                    try reply(prose.knockout)
                default:
                    health = 0
                }
            }

            ledger.health[key] = 0
            say(prose.death)
            onDefeat()
            actor.vanish()
            try reply("")
        }
    }

    /// The villain's own turn: while he is alive, conscious, and in the
    /// player's room, each end-of-turn tick rolls once — miss ≤ 50, wound
    /// ≤ 85, an outright kill above. `playerStrength` hits end the player;
    /// wounds don't heal this phase. A stunned villain spends his turn
    /// coming to instead (no roll).
    ///
    /// `while:` is an extra gate evaluated *first*, before the alive/conscious/
    /// same-room guards and before any draw — so a villain whose combat is
    /// scoped (the thief only fights in his lair) burns no randomness on the
    /// turns his gate is closed, keeping every seeded draw sequence intact.
    ///
    /// - Parameters:
    ///   - actor: the villain who fights back each turn.
    ///   - key: ledger key sharing this villain's health and stun with `villain`.
    ///   - daemonName: global timer name for the counter-attack daemon.
    ///   - playerStrength: hits the player survives before a wound turns fatal.
    ///   - gate: extra gate checked first — a false gate is a quiet, draw-free turn.
    ///   - prose: per-outcome counter-attack lines (miss, wound, playerDeath).
    /// - Returns: the daemon rolling the villain's counter-attack each turn.
    public func aggression(
        of actor: Actor,
        key: String,
        daemonName: String,
        playerStrength: Int = 2,
        while gate: @escaping @Sendable () -> Bool = { true },
        prose: AggressionProse
    ) -> TimedEvent {
        daemon(daemonName, autostart: true) {
            // The host's gate first: a false gate is a quiet turn, no draw.
            guard gate() else { return }
            // Guards before any draw, so quiet turns burn no randomness.
            guard ledger.health[key] ?? 1 > 0 else { return }
            if ledger.stunned[key, default: 0] > 0 {
                let remaining = ledger.stunned[key, default: 0] - 1
                ledger.stunned[key] = remaining == 0 ? nil : remaining
                return
            }
            guard let here = actor.location, player.location == here else { return }

            let roll = random(1...100)
            switch roll {
            case ...50:
                say(oneOf(prose.miss))
            case ...85:
                let health = (ledger.playerHealth ?? playerStrength) - 1
                if health <= 0 {
                    try die(prose.playerDeath)
                }
                ledger.playerHealth = health
                say(oneOf(prose.wound))
            default:
                try die(prose.playerDeath)
            }
        }
    }
}

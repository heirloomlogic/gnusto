import Gnusto

extension TraitKey<Bool> {
    /// The item can be swung at a villain.
    public static let weapon = Self("weapon", default: false)
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
    /// The one intent every combat verb emits.
    public static let attack = Intent("attack")

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

        public init() {}
    }

    /// A villain's lines. Host-supplied per villain — these are inherently
    /// specific, so there are no stock defaults. `miss`/`wound` rotate via
    /// the seeded stream.
    public struct VillainProse: Sendable {
        public var miss: [String]
        public var wound: [String]
        public var knockout: String
        public var death: String

        public init(miss: [String], wound: [String], knockout: String, death: String) {
            self.miss = miss
            self.wound = wound
            self.knockout = knockout
            self.death = death
        }
    }

    /// A villain's counter-attack lines.
    public struct AggressionProse: Sendable {
        public var miss: [String]
        public var wound: [String]
        /// Handed to `die(_:)` when the last hit lands.
        public var playerDeath: String

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

    public init(text: CombatText = CombatText()) {
        self.text = text
    }

    public var verbs: [SyntaxRule] {
        SyntaxRule("attack", .directObject, intent: Self.attack)
        SyntaxRule("attack", .directObject, "with", .indirectObject, intent: Self.attack)
        SyntaxRule("kill", .directObject, intent: Self.attack)
        SyntaxRule("kill", .directObject, "with", .indirectObject, intent: Self.attack)
        SyntaxRule("hit", .directObject, intent: Self.attack)
        SyntaxRule("hit", .directObject, "with", .indirectObject, intent: Self.attack)
        SyntaxRule("fight", .directObject, intent: Self.attack)
        SyntaxRule("stab", .directObject, "with", .indirectObject, intent: Self.attack)
        SyntaxRule("strike", .directObject, "with", .indirectObject, intent: Self.attack)
    }

    /// The stage-4 default for a target no villain rule claimed.
    public var actions: [IntentAction] {
        action(Self.attack) {
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
    @RuleBuilder
    public func villain(
        _ actor: Actor,
        key: String,
        strength: Int,
        weapons: [Item],
        prose: VillainProse,
        onDefeat: @escaping @Sendable () -> Void = {}
    ) -> Rules {
        actor.before(Self.attack) {
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
    public func aggression(
        of actor: Actor,
        key: String,
        daemonName: String,
        playerStrength: Int = 2,
        prose: AggressionProse
    ) -> TimedEvent {
        daemon(daemonName, autostart: true) {
            // Guards before any draw, so quiet turns burn no randomness.
            guard ledger.health[key] ?? 1 > 0 else { return }
            if ledger.stunned[key, default: 0] > 0 {
                ledger.stunned[key]! -= 1
                if ledger.stunned[key] == 0 { ledger.stunned[key] = nil }
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

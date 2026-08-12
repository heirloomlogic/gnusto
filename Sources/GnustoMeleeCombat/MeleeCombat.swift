import Gnusto

extension TraitKey<Bool> {
    /// The item can be swung at a villain.
    public static let weapon = Self("weapon", default: false)
}

extension TraitKey<Int> {
    /// How keen a weapon is in melee — the original's per-weapon distinction.
    /// A higher value misses less and kills more; the outcome table reads it
    /// to slide the cutpoints. Defaults to `2`, the baseline table, so a plain
    /// `.weapon` with no keenness declared fights exactly as before.
    public static let weaponStrength = Self("weaponStrength", default: 2)
}

/// Zork-style-lite melee: the engine's attack verbs promoted to real behavior,
/// a weapon trait, per-villain health, a seeded outcome table (miss / wound /
/// knockout / kill), and an aggression daemon so villains hit back.
/// Deterministic under a pinned seed — every roll draws from the game's saved
/// random stream.
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
            "\(GameText.sentenceCase($0)) is no weapon."
        }
        /// Naming a real weapon the player isn't holding.
        public var weaponNotHeld: @Sendable (_ name: String) -> String = {
            "You aren't holding \($0)."
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

    /// The plugin-owned combat ledger: villain health, stun counters and who is
    /// currently in a fight, keyed by registration key, plus the player's own
    /// hits. Health seeds lazily from each villain's declared strength.
    ///
    /// `stunned` is the countdown, and a villain has an entry in it for exactly
    /// as long as he is unconscious — counting down to zero and resting there
    /// for the last of those turns. ``Actor/isUnconscious`` is the same fact
    /// where other plugins can see it; ``stun(_:key:turnsLeft:)`` writes both.
    ///
    /// `engaged` is the source's `FIGHTBIT`: a villain is in it from the blow
    /// that starts the fight — the player's, or his own — until the two of them
    /// are no longer standing in one room. It is the whole of the difference
    /// between a villain who blocks and a villain who kills you for reading the
    /// room; see
    /// ``aggression(of:key:daemonName:strikesFirst:playerStrength:while:prose:)``.
    struct Ledger: Codable, Sendable, GlobalValue {
        var health: [String: Int] = [:]
        var stunned: [String: Int] = [:]
        var engaged: Set<String> = []
        var playerHealth: Int?

        init() {}

        /// A stale save has to degrade rather than trap, the way
        /// `RoyalPuzzleGrid` does: `Global`'s getter `fatalError`s when a stored
        /// value fails to decode instead of falling back to the declared
        /// default, and save validation only checks that a `.data` case is a
        /// `.data` case — it cannot tell one payload from another. Swift's
        /// synthesized decoder ignores a property's default and demands every
        /// key, so a save written before `engaged` existed would otherwise crash
        /// the game on the first turn a villain's daemon ticked. Every field
        /// decodes leniently and keeps its default instead: a restored fight
        /// starts unengaged, which is one strike-first roll's worth of mercy and
        /// nothing worse.
        init(from decoder: any Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            health = (try? box.decode([String: Int].self, forKey: .health)) ?? [:]
            stunned = (try? box.decode([String: Int].self, forKey: .stunned)) ?? [:]
            engaged = (try? box.decode(Set<String>.self, forKey: .engaged)) ?? []
            playerHealth = (try? box.decodeIfPresent(Int.self, forKey: .playerHealth)) ?? nil
        }
    }

    @Global var ledger = Ledger()

    let text: CombatText

    /// Creates the plugin with the given combat text.
    ///
    /// - Parameter text: the system-voice combat lines shared across villains.
    public init(text: CombatText = CombatText()) {
        self.text = text
    }

    /// Everything that reaches `.attack`, claimed as melee's: the engine's rows,
    /// spliced by listing the intent, and the two it adds. attack/kill/hit/fight
    /// are core vocabulary, bare-handed or `with` a weapon; stab and strike are
    /// melee's own, and always name the weapon.
    ///
    /// The spliced rows are the standard table's, so the merged table is the
    /// same either way — what listing `.attack` changes is arbitration: melee
    /// re-asserts those shapes, last-wins, over an earlier bundle that reclaimed
    /// one of them for something else.
    public var verbs: [SyntaxRule] {
        .attack
        SyntaxRule("stab", .directObject, "with", .indirectObject, intent: .attack)
        SyntaxRule("strike", .directObject, "with", .indirectObject, intent: .attack)
    }

    /// The stage-4 default for a target no villain rule claimed.
    public var actions: [IntentAction] {
        action(.attack) {
            try reply(text.attackFutile)
        }
    }

    /// Writes both halves of "he is out cold" at once: the ledger's countdown,
    /// which is this plugin's, and ``Actor/isUnconscious``, which is the
    /// engine's and is how `GnustoActors` — a plugin that cannot see this
    /// ledger — knows to stop him roaming and picking pockets. Going through
    /// one funnel is what keeps the two from drifting.
    ///
    /// - Parameters:
    ///   - actor: the villain going down or getting up.
    ///   - key: his ledger key.
    ///   - turnsLeft: turns still to spend on the floor, or `nil` for back on
    ///     his feet. Zero is a real value: it is the last of those turns.
    func stun(_ actor: Actor, key: String, turnsLeft: Int?) {
        ledger.stunned[key] = turnsLeft
        actor.isUnconscious = turnsLeft != nil
    }

    /// The per-weapon outcome cutpoints out of 100 for one swing: miss ≤ first,
    /// wound ≤ second, knockout ≤ third, kill above. A keener weapon (higher
    /// `.weaponStrength`) misses less and kills more — the original's per-weapon
    /// tables in miniature. Strength 2 is the baseline 30/70/85 table, so an
    /// ordinary weapon fights exactly as the old fixed table did.
    static func outcomeCutpoints(weaponStrength: Int) -> (Int, Int, Int) {
        switch weaponStrength {
        case ...1: return (40, 76, 90)  // a clumsy blade — the thief's stiletto
        case 2: return (30, 70, 85)  // the baseline — the nasty knife, the troll's axe
        default: return (22, 64, 82)  // a keen blade — the elvish sword
        }
    }

    /// Whether an unengaged villain picks this turn to start something — the
    /// source's `F-FIRST?` branch, as a probability out of a hundred.
    ///
    /// A hundred and nought are not questions, so neither draws: a villain who
    /// always starts one and a villain who never does both leave the random
    /// stream exactly where they found it, and their standing in the room
    /// shifts nothing downstream of them. That is the opposite call from
    /// ``oneOf(_:)``, which draws even for a single option — deliberately, and
    /// the two do not want reconciling. `oneOf`'s option count is a list an
    /// author edits, and the stream must not notice the edit; this is a
    /// constant of the villain, declared once at his call site.
    ///
    /// - Parameter percent: the odds he starts a fight, out of a hundred.
    /// - Returns: whether he starts one this turn.
    static func startsAFight(chance percent: Int) -> Bool {
        if percent >= 100 { return true }
        if percent <= 0 { return false }
        return chance(percent)
    }

    /// Registers a villain: attacks against `actor` resolve a weapon, roll
    /// the outcome table, and track his health under `key`. At zero health
    /// the death line prints, `onDefeat` runs (unbar the door, drop the
    /// loot — this is the host's composition point, before the body
    /// vanishes), and the actor is removed from play.
    ///
    /// One roll per swing against a per-weapon table (see
    /// `outcomeCutpoints(weaponStrength:)`). A stunned villain doesn't roll —
    /// the next blow lands clean.
    ///
    /// A knockout also sets ``Actor/isUnconscious`` — see ``stun(_:key:turnsLeft:)``.
    /// It is cleared again by the villain's own
    /// ``aggression(of:key:daemonName:strikesFirst:playerStrength:while:prose:)`` daemon, so
    /// a villain registered here without one stays down for good once knocked
    /// out, exactly as his stun counter already did.
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
            // otherwise the player's keenest held weapon serves.
            let weaponUsed: Item
            if let named = command.indirectObject {
                guard weapons.contains(named) else {
                    try refuse(text.notAWeapon(named.definiteName))
                }
                guard named.isHeld else {
                    try refuse(text.weaponNotHeld(named.definiteName))
                }
                weaponUsed = named
            } else if let best = weapons.filter(\.isHeld)
                .max(by: { $0[default: .weaponStrength] < $1[default: .weaponStrength] })
            {
                weaponUsed = best
            } else {
                try refuse(text.noWeapon)
            }

            // `FIGHTBIT`, set where the source sets it. `HERO-BLOW`
            // (`1actions.zil:3484`) does it on the way in, before the blow is
            // resolved and before it knows whether the blow lands — so a swing
            // that misses engages him just as thoroughly as one that draws
            // blood. But it is `V-ATTACK` (`gverbs.zil:176`) that decides
            // whether `HERO-BLOW` is reached at all, and its three refusals —
            // bare hands, a weapon you aren't holding, a thing that isn't a
            // weapon — all return short of it. Those are the three above, so a
            // refused swing is not a provocation here either.
            ledger.engaged.insert(key)

            var health = ledger.health[key] ?? strength
            if ledger.stunned[key, default: 0] > 0 {
                // Finishing the unconscious: no roll, the blow lands clean.
                stun(actor, key: key, turnsLeft: nil)
                health = 0
            } else {
                // The original's per-weapon table: a keener weapon slides the
                // cutpoints toward the killing end (less miss, more kill). The
                // baseline (strength 2) is the historic 30/70/85 table, so an
                // ordinary weapon fights exactly as before.
                let (missMax, woundMax, knockoutMax) = Self.outcomeCutpoints(
                    weaponStrength: weaponUsed[default: .weaponStrength])
                let roll = random(1...100)
                switch roll {
                case ...missMax:
                    try reply(oneOf(prose.miss))
                case ...woundMax:
                    health -= 1
                    if health > 0 {
                        ledger.health[key] = health
                        try reply(oneOf(prose.wound))
                    }
                case ...knockoutMax:
                    ledger.health[key] = health
                    stun(actor, key: key, turnsLeft: 2)
                    try reply(prose.knockout)
                default:
                    health = 0
                }
            }

            ledger.health[key] = 0
            say(prose.death)
            onDefeat()
            actor.vanish()
            try handled()
        }
    }

    /// The villain's own turn: while he is alive, conscious, in the player's
    /// room, and *in a fight*, each end-of-turn tick rolls once — miss ≤ 50,
    /// wound ≤ 85, an outright kill above. `playerStrength` hits end the
    /// player; wounds don't heal this phase. A stunned villain spends his turn
    /// coming to instead (no roll).
    ///
    /// *In a fight* is the source's `FIGHTBIT`. `I-FIGHT` (`1actions.zil:3810`)
    /// has a villain strike only once the player has engaged him or once his own
    /// `F-FIRST?` branch says he starts one, and `strikesFirst` is that branch,
    /// out of a hundred: the troll's is 33 (`1actions.zil:702`), the thief's 20
    /// (`:2064`), and the cyclops, who has no such branch at all, is 0. A fight
    /// either of them starts persists — both branches set `FIGHTBIT` — and he
    /// strikes in the turn he starts it rather than telegraphing it. `I-FIGHT`
    /// clears the bit on the villain the player is no longer standing with, so
    /// walking out ends a fight and walking back in asks the question again.
    /// Neither 0 nor 100 draws; see ``startsAFight(chance:)``.
    ///
    /// `while:` is an extra gate evaluated before the same-room guard and
    /// before any draw — so a villain whose combat is scoped (the thief only
    /// fights in his lair) burns no randomness on the turns his gate is
    /// closed, keeping every seeded draw sequence intact. It does *not* gate
    /// coming round, which happens first: a man knocked out where his gate is
    /// shut still wakes up. Nor does it gate *disengaging*, which is the room's
    /// business rather than the host's — the source agrees, skipping the
    /// engrossed thief's turn without clearing his `FIGHTBIT` — so a man
    /// admiring a gift you handed him is still in the fight when he looks up.
    /// Gates are assumed pure: they are asked once per turn and their answer is
    /// not otherwise observed.
    ///
    /// - Parameters:
    ///   - actor: the villain who fights back each turn.
    ///   - key: ledger key sharing this villain's health, stun and engagement
    ///     with `villain`.
    ///   - daemonName: global timer name for the counter-attack daemon.
    ///   - strikesFirst: the odds out of a hundred that he starts a fight on a
    ///     turn the player hasn't. 100 fights on sight; 0 never starts one and
    ///     only ever answers a blow.
    ///   - playerStrength: hits the player survives before a wound turns fatal.
    ///   - gate: extra gate checked first — a false gate is a quiet, draw-free turn.
    ///   - prose: per-outcome counter-attack lines (miss, wound, playerDeath).
    /// - Returns: the daemon rolling the villain's counter-attack each turn.
    public func aggression(
        of actor: Actor,
        key: String,
        daemonName: String,
        strikesFirst: Int = 100,
        playerStrength: Int = 2,
        while gate: @escaping @Sendable () -> Bool = { true },
        prose: AggressionProse
    ) -> TimedEvent {
        daemon(daemonName, autostart: true) {
            // One snapshot for both guards below: `ledger` is a `@Global`, and
            // every read of one decodes the whole struct.
            let ledgered = ledger
            // Guards before any draw, so quiet turns burn no randomness.
            guard ledgered.health[key] ?? 1 > 0 else { return }

            // Both of these are read off the snapshot before anything below
            // writes, so neither can go stale under a later reordering: the
            // guards further down ask these locals and never the live ledger.
            let together = actor.location == player.location
            let wasEngaged = ledgered.engaged.contains(key)

            // Where `FIGHTBIT` is cleared. Ahead of the host's gate because
            // leaving is the room's business and a gate that shuts for two turns
            // while he admires a gift must not read as a truce; ahead of the
            // stun block because a man the player has walked away from is out of
            // the fight whether he is on his feet or not. Written only on the
            // transition, so a quiet turn re-encodes nothing.
            if !together, wasEngaged {
                ledger.engaged.remove(key)
            }
            // Coming round happens ahead of the host's gate, because it is not
            // an aggressive act: a villain knocked out somewhere his gate is
            // shut — the thief anywhere but his own lair — would otherwise
            // never wake at all. It draws no randomness, so nothing seeded
            // moves by being here.
            if let stunTurns = ledgered.stunned[key] {
                guard stunTurns == 0 else {
                    // Still out. He spends the turn coming to.
                    stun(actor, key: key, turnsLeft: stunTurns - 1)
                    return
                }
                // Zero is the last of the turns he spends down — the counter
                // rests there rather than clearing, so that "unconscious"
                // lasts exactly as long as the turns he skips. Without it he
                // woke halfway through the last one and picked a pocket on the
                // way up, which is this bug again, one daemon over.
                stun(actor, key: key, turnsLeft: nil)
            }
            // The host's gate: a false gate is a quiet turn, no draw.
            guard gate() else { return }
            guard together else { return }

            // The source's `<OR <FSET? .O ,FIGHTBIT> <APPLY … ,F-FIRST?>>`, and
            // its short circuit is the point: an engaged villain asks nothing
            // and draws nothing, so a fight already in progress reads the stream
            // exactly as it did before this parameter existed. Only the
            // unengaged roll — and only here, behind the gate and behind the
            // same-room guard, so a villain alone in his lair burns no
            // randomness on the hundreds of turns nobody is standing in it.
            if !wasEngaged {
                guard Self.startsAFight(chance: strikesFirst) else { return }
                // He strikes in the turn he starts it: `F-FIRST?` sets
                // `FIGHTBIT` and `I-FIGHT` falls straight through to the blow.
                ledger.engaged.insert(key)
            }

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

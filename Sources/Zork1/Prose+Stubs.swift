import Gnusto
import GnustoMeleeCombat

/// The stub floor: what this game answers for the 47 verbs the parser knows and
/// no mechanic here is behind.
///
/// **This game reproduces; it does not adapt.** `FIDELITY.md`'s preamble splits
/// the ledger at exactly this line — everything from *Task 8* to *The kitchen
/// window* is Zork 1, which takes its source's words as written, where
/// `Sources/Dungeon/` writes its own in the Infocom register. So the floor next
/// door in ``Sources/Dungeon/Prose+Stubs.swift`` is the wrong answer here however
/// much it looks like the right one, and the job is not a translation of it but
/// a second reading of `gverbs.zil`. (#242)
///
/// Three things follow from the verbatim rule, and none of them is taste:
///
/// - **The narrator keeps its first person.** "I'd sooner kiss a pig."
///   (`V-KISS`), "I don't think that the X would agree with you." (`V-EAT`),
///   "I've known strange people…" (`V-ATTACK`). Dungeon turned these into the
///   second person because an adaptation may; this game may not, and
///   ``Prose/drinkWater`` has kept the source's "I" since Task 8.
/// - **Where the source has no such verb, the line is an invention and says
///   so.** Twelve of the engine's stubs — `sing`, `buy`, `sell`, `think`,
///   `point`, `kneel`, `lie`, `sit`, `sleep`, `taste`, `dive`, `empty` — appear
///   nowhere in `gsyntax.zil`, so there is nothing to reproduce. Those lines are
///   written to the register and are recorded in `FIDELITY.md` as inventions, in
///   their own bullet group, so the ledger never implies the source said
///   something it didn't.
/// - **Where the source's line cannot be rendered, the departure is recorded.**
///   `V-SKIP` draws one of four (`WHEEEEE`, `gverbs.zil:1272`) and `HACK-HACK`
///   one of three (`HO-HUM`, `:2031`); a `GameText` line has no turn frame and
///   so no access to the seeded stream, and the only ways to reach it — a rule
///   or an `action(…)` row — are the mechanism this floor exists to stop using.
///   Each takes one entry and the draw is noted.
///
/// Installed as `text.stubs` in ``Zork1``, not as `action(…)` rows. The rows
/// were how this game re-skinned its first thirteen, and `DefaultActions.run`
/// returns from an action override *before* `requireReach`, so each one had
/// quietly given up the engine's reach guard, the object's rendered name, its
/// number agreement, and the `yourself`/`somebodyElse` guards. Assigning the
/// line keeps all four; it is also what the play-test harness's survey measures,
/// so the rows were invisible to a round on this game.
///
/// Every reproduced line is `gverbs.zil`'s as written, under the MIT grant
/// `THIRD_PARTY_NOTICES` records — the same licence every other
/// `Sources/Zork1/` constant already sits under. Citations are to the
/// `historicalsource-zork1` checkout `bin/atlas/build_atlas.py` reads.
extension Prose {
    /// `V-ATTACK`'s first branch (`gverbs.zil:178`).
    ///
    /// Named rather than inlined because it has two homes: the stub floor sets
    /// it so the game owns `.attack` whatever claims the verb, and
    /// ``combatText`` sets it where a player can actually reach it. The callers
    /// choose the article between them — ``combatText`` hands it the indefinite
    /// name, as the source's `A ,PRSO` does.
    static let attackFutile = GameText.Line<GameText.Noun>.naming {
        "I've known strange people, but fighting \($0)?"
    }

    /// ``GnustoMeleeCombat``'s four system-voice refusals, in Zork I's own.
    ///
    /// The plugin claims `.attack` for the whole game and shipped these as plain
    /// modern lines, so `attackFutile` — the most reachable stock line in the
    /// game, what anyone who swings at the scenery reads — was a narrator this
    /// game has never used. All four are `V-ATTACK`'s own branches
    /// (`gverbs.zil:176-193`). (#242)
    static var combatText: MeleeCombat.CombatText {
        var text = MeleeCombat.CombatText()
        text.attackFutile = attackFutile
        // `V-ATTACK:182`, which names its target; #242 widened `noWeapon` so it
        // could.
        text.noWeapon = .naming { "Trying to attack \($0) with your bare hands is suicidal." }
        // `V-ATTACK:188` is "Trying to attack the X with a Y is suicidal." — the
        // plugin hands this line the *weapon* only, so the target becomes "it".
        text.notAWeapon = .naming { "Trying to attack it with \($0) is suicidal." }
        // `V-ATTACK:185`.
        text.weaponNotHeld = .naming { "You aren't even holding \($0)." }
        return text
    }

    /// Every engine stub verb, in Zork I's words where Zork I has any.
    static var stubFloor: GameText.StubReplies {
        var stubs = GameText.StubReplies()

        // MARK: People

        // Invented: the source has no general self-deferral, because no ZIL
        // routine ever had to render the player's name.
        stubs.yourself = "Do that to something else!"
        // `V-SQUEEZE`'s actor branch (`gverbs.zil:1289`) — the source's answer
        // to laying hands on somebody, and the floor under every stub that has
        // to reach its object.
        stubs.somebodyElse = .naming {
            "\($0.sentenceCased) \($0.verb("does", "do")) not understand this."
        }

        // MARK: Violence and force

        // Set for completeness rather than for reading: ``GnustoMeleeCombat``
        // claims `.attack` for the whole game, so what a player who swings at
        // the scenery meets is ``Prose/combatText``'s `attackFutile`. If the
        // plugin ever stops claiming the verb, the floor is already the game's.
        stubs.attack = Prose.attackFutile
        // `V-MUNG` (`gverbs.zil:943`), which `break`, `smash` and `destroy` all
        // route to (`gsyntax.zil:163`).
        stubs.smash = "Nice try."
        // `V-BURN`'s last branch (`gverbs.zil:274`).
        stubs.burn = .naming { "You can't burn \($0)." }
        // `V-CUT`'s last branch (`gverbs.zil:400`). The four dots are the
        // source's.
        stubs.cut = .naming { "Strange concept, cutting \($0)...." }
        // `V-DIG` (`gverbs.zil:416`) answers for the *instrument*, defaulting it
        // to `HANDS` when the player names none. The engine's `dig` is handed no
        // instrument, so the hands are written in. The one place digging is the
        // puzzle is the sand, and `sand.before(.dig)` in ``ZorkRiver`` claims it
        // long before this.
        stubs.dig = "Digging with your hands is silly."
        // `pull` routes to `V-MOVE` in the source (`gsyntax.zil:368`), whose
        // immovable branch is `gverbs.zil:918`.
        stubs.pull = .naming { "You can't move \($0.phrase)." }
        // `V-TURN` (`gverbs.zil:1506`).
        stubs.turn = "This has no effect."
        // `V-SQUEEZE`'s other branch (`gverbs.zil:1291`).
        stubs.squeeze = "How singularly useless."
        // `V-SHAKE`'s un-takeable branch (`gverbs.zil:1217`).
        stubs.shake = "You can't take it; thus, you can't shake it!"
        // `V-KNOCK`'s door branch (`gverbs.zil:767`). The other branch names the
        // thing knocked on and this line cannot, but a stub floor is what
        // answers after every door in the game has had its say.
        stubs.knock = "Nobody's home."
        // Invented: Zork I's `THROW AT` requires an actor (`gsyntax.zil:486`),
        // and `V-THROW` drops the object rather than refusing, so there is no
        // general refusal to reproduce.
        stubs.throwAt = "You'd only have to pick it up again."

        // MARK: Senses

        // `touch`, `feel` and `rub` are one verb in the source
        // (`SYNONYM RUB TOUCH FEEL PAT PET`, `gsyntax.zil:419`), and `V-RUB`
        // (`gverbs.zil:1165`) hands `HACK-HACK` the stem "Fiddling with the ",
        // which finishes with one of `HO-HUM`'s three (`:2031`). This takes the
        // third; the draw is recorded.
        stubs.touch = .naming(orBare: "Touching it accomplishes nothing in particular.") {
            "Fiddling with \($0) has no effect."
        }
        // `V-SMELL` (`gverbs.zil:1279`), whose whole joke is that it names the
        // thing. #242 widened this line so it could. Zork I has no objectless
        // `smell`, so the bare form is this game's own sentence, kept from the
        // line that stood here before.
        stubs.smell = .naming(orBare: "You smell nothing you could put a name to.") {
            "It smells like \($0)."
        }
        // `V-LISTEN` (`gverbs.zil:853`). Same shape, same widening; the source's
        // `LISTEN` also always takes an object (`gsyntax.zil:291`).
        stubs.listen = .naming(orBare: "You hear nothing you didn't hear before.") {
            "\($0.sentenceCased) makes no sound."
        }
        // Invented: no `TASTE` or `LICK` anywhere in `gsyntax.zil`.
        stubs.taste = "I wouldn't put that in my mouth."

        // MARK: Body

        // `V-EAT`'s last branch (`gverbs.zil:515`).
        stubs.eat = .naming { "I don't think that \($0.phrase) would agree with you." }
        // `V-EAT`'s no-water branch (`gverbs.zil:504`). The bottle's own rules in
        // ``ZorkHouse`` claim `drink` wherever there is water to drink.
        stubs.drink = .init(Prose.nothingToDrink)
        // Invented: no `SLEEP` in `gsyntax.zil`.
        stubs.sleep = "This is no place for a nap!"
        // `V-ALARM`'s non-actor branch (`gverbs.zil:168`), which `wake` routes to
        // (`gsyntax.zil:527`). Bare `wake` and `wake up` parse too, so the line
        // has to be true with and without something named.
        stubs.wake = .naming(orBare: "Nothing here is asleep.") {
            "\($0.sentenceCased) isn't sleeping."
        }

        // MARK: Social

        // `V-KISS` (`gverbs.zil:763`).
        stubs.kiss = "I'd sooner kiss a pig."
        // `V-GIVE`'s actor branch (`gverbs.zil:717`). The engine names the
        // recipient, which the `action(…)` row that stood here could not — so
        // this stops being false in front of the cyclops, who wants a great deal.
        stubs.give = { _, recipient in
            "\(recipient.sentenceCased) \(recipient.verb("refuses", "refuse")) it politely."
        }
        // `V-YELL` (`gverbs.zil:1616`).
        stubs.yell = "Aaaarrrrgggghhhh!"
        // `V-WAVE` (`gverbs.zil:1595`) hands `HACK-HACK` the stem "Waving the ",
        // finished by one of `HO-HUM`'s three; this takes the third, as `touch`
        // does. Zork I has no objectless `WAVE`, so that half is invented.
        stubs.wave = .naming(orBare: "Waving your hands about has no effect.") {
            "Waving \($0) has no effect."
        }
        // Invented: no `POINT` in `gsyntax.zil`.
        stubs.point = "Nobody is looking."

        // MARK: Motion

        // `V-CLIMB-ON` (`gverbs.zil:298`). The bare `climb` is this game's own
        // sentence, kept from the line that stood here before; the source's
        // objectless climb walks an exit instead of answering.
        stubs.climb = .naming(orBare: "There's nothing here worth climbing. Try up or down.") {
            "You can't climb onto \($0)."
        }
        // `V-LEAP` sends an objectless jump to `V-SKIP` (`gverbs.zil:820`), which
        // draws one of four (`WHEEEEE`, `:1272`). This is the entry the table is
        // named for; the draw is recorded.
        stubs.jump = "Wheeeeeeeeee!!!!!"
        // `V-SWIM`'s last branch (`gverbs.zil:1345`).
        stubs.swim = "Go jump in a lake!"
        // Invented: no `DIVE` in `gsyntax.zil`. Kept off the subject of the room,
        // since this line prints in all of them.
        stubs.dive = "That would take more water than you have."
        // `V-STAND`'s standing branch (`gverbs.zil:1309`).
        stubs.stand = "You are already standing, I think."
        // Invented: no `SIT` in `gsyntax.zil`.
        stubs.sit = "You didn't come all this way to sit down!"
        // Invented: no `LIE` in `gsyntax.zil`.
        stubs.lie = "You'd only get up again filthy."
        // Invented: no `KNEEL` in `gsyntax.zil`.
        stubs.kneel = "Nobody is impressed."

        // MARK: Liquids and containers

        // `V-FILL`'s no-source branch (`gverbs.zil:673`). The bottle's rules in
        // ``ZorkHouse`` claim `fill` wherever there is water.
        stubs.fill = "There's nothing to fill it with."
        // `V-POUR-ON`'s last branch (`gverbs.zil:1044`).
        stubs.pour = "You can't pour that."
        // Invented: no `EMPTY` in `gsyntax.zil`.
        stubs.empty = .naming { "You'd have to put something in \($0) first." }
        // `V-TIE`'s general branch (`gverbs.zil:1469`). The rope in the dome
        // claims `tie` where tying is the puzzle.
        stubs.tie = .naming { "You can't tie \($0) to that." }
        // `V-UNTIE` (`gverbs.zil:1512`).
        stubs.untie = "This cannot be tied, so it cannot be untied!"

        // MARK: Ritual and flavor

        // `V-PRAY`'s non-temple branch (`gverbs.zil:1054`). The altar claims
        // `pray` where praying moves you.
        stubs.pray = "If you pray enough, your prayers may be answered."
        // Invented: no `SING` in `gsyntax.zil`.
        stubs.sing = "Your voice is not among your assets!"
        // `V-CURSES`'s objectless branch (`gverbs.zil:382`), and the only line in
        // this floor a player is likely to go looking for on purpose.
        stubs.curse = "Such language in a high-class establishment like this!"
        // `V-ADVENT` (`gverbs.zil:154`), which both `xyzzy` and `plugh` route to
        // (`gsyntax.zil:352`) — as they do on the engine's single intent.
        stubs.xyzzy = Prose.verbMagicWordInert
        // `V-COUNT`'s general branch (`gverbs.zil:369`).
        stubs.count = "You have lost your mind."
        // Invented: no `THINK` in `gsyntax.zil`.
        stubs.think = "That would be a first!"
        // `V-WISH` (`gverbs.zil:1613`).
        stubs.wish = "With luck, your wish will come true."

        // MARK: Commerce

        // Invented: no `BUY` in `gsyntax.zil`.
        stubs.buy = "This is a dungeon, not a bazaar!"
        // Invented: no `SELL` in `gsyntax.zil`.
        stubs.sell = "And who, exactly, would buy it?"

        // MARK: Fixtures

        // `V-BLAST` (`gverbs.zil:199`), which `BLOW UP` routes to
        // (`gsyntax.zil:107`).
        stubs.blow = "You can't blast anything by using words."

        return stubs
    }
}

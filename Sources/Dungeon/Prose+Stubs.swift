import Gnusto
import GnustoMeleeCombat

/// The stub floor: what the game answers for the ~47 verbs the parser knows and
/// no mechanic in this dungeon is behind.
///
/// The play-test round (#233, box 12) found the game answering seventeen of them
/// in its own voice and the rest in the engine's, so a plain modern narrator
/// took over on the turn after an Infocom-voiced re-skin. Two things in this
/// repository decide how far to go, and neither is a matter of taste:
///
/// - `docs/games/dungeon.md`'s mechanics contract — *"The voice is Infocom's …
///   it does not read as a modern pastiche."* A stock stub is exactly a modern
///   pastiche.
/// - Rule 10 — *"A game-wide default is a sentence printed in all 196 rooms, so
///   it may not be a claim about any one of them."* Several stock lines are
///   claims about the surroundings, and are flatly false somewhere in this map:
///   `listen` asserts quiet in the **Loud Room**, `sit` and `buy` and `curse`
///   all report on a room they cannot see.
///
/// So every line here is a claim about **the thing named** or about **the
/// player**, never about the room. Where a room genuinely answers differently it
/// takes the verb back with a rule of its own, which is the pair `smell` already
/// has in ``DungeonCoalMine``.
///
/// Installed as `text.stubs` in ``Dungeon``, not as `action(…)` rows. The rows
/// were how this game re-skinned its first seventeen, and `DefaultActions.run`
/// returns from an action override *before* `requireReach`, so each one had
/// quietly given up the engine's reach guard, its object naming, its number
/// agreement, and the `yourself`/`somebodyElse` guards. Assigning the line keeps
/// all of it; it is also what the play-test harness's own survey measures, so
/// the rows were invisible to the round that filed the box.
///
/// Lines marked *Trilogy verbatim* are the original's own answer, taken as-is
/// under the rule `FIDELITY.md` states for `identical`/`minor` lines — the same
/// licence ``Prose/drinkWater`` already sits under.
extension Prose {
    /// `V-ATTACK`'s first branch (`gverbs.zil:176`). Trilogy verbatim.
    ///
    /// The narrator is appraising *the player* — it is you who is strange for
    /// swinging at a rubber raft — so the first person is the line, not a
    /// house style to be converted away from. Second person turns the joke
    /// inside out: "You have known strange people" makes the player a
    /// connoisseur of strangers rather than the specimen, and points the
    /// remark at nobody. The narrator already says "I" elsewhere in this game
    /// — `stubs.stand`'s "You are already standing, I think.", the volcano's
    /// "I wouldn't jump from here." — and those are verbatim too.
    ///
    /// Takes the object's name because the source does (`A ,PRSO`): "fighting
    /// that?" is the same sentence with the joke's subject deleted. The two
    /// callers choose the article between them — ``combatText`` hands it the
    /// indefinite name, as `A` does, and the stub floor gets whatever
    /// `StubVerb.named` hands every stub.
    ///
    /// Named rather than inlined because it is the one line in this file with
    /// two homes: the stub floor sets it so the game owns `.attack` whatever
    /// claims the verb, and ``combatText`` sets it where a player can actually
    /// reach it.
    static let attackFutile = GameText.Line<GameText.Noun>.naming {
        "I've known strange people, but fighting \($0)?"
    }

    /// ``GnustoMeleeCombat``'s four system-voice refusals, in this game's.
    ///
    /// The plugin claims `.attack` for the whole game and ships these as plain
    /// modern lines, so every swing at something that is not a villain was
    /// answered by a narrator the rest of the game had stopped using — box 12
    /// at the one verb the box did not look at. All four are `V-ATTACK`'s own
    /// branches (`gverbs.zil:176-190`). (#233)
    static var combatText: MeleeCombat.CombatText {
        var text = MeleeCombat.CombatText()
        text.attackFutile = attackFutile
        text.noWeapon = "Trying that with your bare hands would be suicidal."
        text.notAWeapon = .naming { "Attacking anything with \($0) would be suicidal." }
        text.weaponNotHeld = .naming { "You aren't even holding \($0)." }
        return text
    }

    static var stubFloor: GameText.StubReplies {
        var stubs = GameText.StubReplies()

        // MARK: People

        stubs.yourself = "Leave yourself out of it."
        // `V-SQUEEZE`'s actor branch (`gverbs.zil:1287`) — the source's answer
        // to laying hands on somebody, and the floor under every stub that has
        // to reach its object.
        stubs.somebodyElse = .naming {
            "\($0.sentenceCased) \($0.verb("does", "do")) not understand this."
        }

        // MARK: Violence and force

        // Set for completeness rather than for reading: ``GnustoMeleeCombat``
        // claims `.attack` for the whole game, so what a player who swings at
        // the scenery meets is ``Prose/combatText``'s `attackFutile` below,
        // which says this in the frame it is reachable in. If the plugin ever
        // stops claiming the verb, the floor is already the game's.
        stubs.attack = Prose.attackFutile
        stubs.smash = .naming {
            "\($0.sentenceCased) \($0.verb("is", "are")) made of sterner stuff."
        }
        stubs.burn = .naming { "You have nothing to set \($0) alight with." }
        stubs.cut = .naming { "You have nothing that would cut \($0)." }
        // `V-DIG` (`gverbs.zil:405`) answers for the tool, not the ground. The
        // one place in the game where digging is the puzzle is the sand, and
        // `sand.before(.dig)` in ``DungeonRiver`` claims it long before this.
        stubs.dig = "Digging with your bare hands is silly."
        stubs.pull = .naming {
            "\($0.sentenceCased) \($0.verb("doesn't", "don't")) give an inch."
        }
        // `V-TURN` (`gverbs.zil:1505`) is "This has no effect." — kept, with the
        // thing named, so the reply does not read as a failed `turn on`.
        stubs.turn = .naming { "Turning \($0) has no effect." }
        // `V-SQUEEZE`'s other branch: "How singularly useless."
        stubs.squeeze = .naming { "Squeezing \($0) is singularly useless." }
        stubs.shake = .naming { "You shake \($0). Nothing comes loose." }
        // `V-KNOCK` (`gverbs.zil:766`) branches on `DOORBIT` and this floor
        // carries the half a line can word: the one about anything that is not
        // a door. The door half is a game-wide rule in ``Dungeon``, because
        // doorness is a fact about the map. Adapted rather than reproduced —
        // the source asks "Why knock on a X?", which is a question, and this
        // game's narrator does not ask the player questions it will not answer.
        // Lived in the endgame's prose file while it was that bundle's
        // `action(…)` row — it was always game-wide, and this is where the
        // game-wide floor lives now.
        // The line has to be true of a mailbox, a doorway and a welcome mat
        // alike — this branch is everything that is *not* a door — so it says
        // nothing about an inside, which a mat has not got.
        stubs.knock = .naming(orBare: Prose.verbKnockDoor) {
            "You knock on \($0). \($0.verb("It is", "They are")) not something that answers."
        }
        // "the dungeon" rather than "here": the source's own word for the whole
        // place (`V-SWIM`, `gverbs.zil:1324`), and the only way a line printed
        // in 196 rooms can name a place at all.
        stubs.throwAt = "Throwing things about the dungeon achieves nothing."

        // MARK: Senses

        stubs.touch = .init(Prose.verbTouch)
        stubs.smell = .init(Prose.verbSmell)
        // Was "You hear nothing out of the ordinary." — a claim about the room,
        // printed in the Loud Room, whose whole puzzle is that it is too loud to
        // hear in. `loudRoom.before(.listen)` in ``DungeonRoundRoom`` answers
        // there; this is what is left over, and it reports on the listener.
        stubs.listen = "You listen, and learn nothing you did not already know."
        stubs.taste = "You would regret it."

        // MARK: Body

        stubs.eat = .naming {
            "\($0.sentenceCased) \($0.verb("is", "are")) not something you could eat."
        }
        stubs.drink = .init(Prose.cantDrinkThat)
        stubs.sleep = "You have not come all this way to sleep."
        // Bare `wake` and `wake up` parse too, so the line has to be true with
        // and without something named.
        stubs.wake = "There is no one asleep to be woken."

        // MARK: Social

        // `V-KISS` (`gverbs.zil:762`), second person.
        stubs.kiss = "You would sooner kiss a pig."
        // Was "There is nobody here who wants it." — false while standing in
        // front of the troll, who wants a great deal. The engine's template
        // names the recipient and an `action(…)` row could not.
        stubs.give = .naming {
            let who = $0.recipient
            return "\(who.sentenceCased) \(who.verb("has", "have")) no use for \($0.gift)."
        }
        // `V-YELL` (`gverbs.zil:1616`). Trilogy verbatim.
        stubs.yell = "Aaaarrrrgggghhhh!"
        stubs.wave = .init(Prose.verbWave)
        stubs.point = "You point. The gesture is wasted."

        // MARK: Motion

        stubs.climb = "That is not something you could climb."
        // `V-SKIP` picks one of four (`WHEEEEE`, `gverbs.zil:1272`); this is the
        // one the table is named for. Trilogy verbatim.
        stubs.jump = "Wheeeeeeeeee!!!!!"
        stubs.swim = .init(Prose.noSwimming)
        stubs.dive = .init(Prose.noDiving)
        // `V-STAND` (`gverbs.zil:1305`). Trilogy verbatim.
        stubs.stand = "You are already standing, I think."
        stubs.sit = "That is not something you could sit on."
        stubs.lie = "Lying down would gain you nothing."
        stubs.kneel = "You kneel briefly, and get up again."

        // MARK: Liquids and containers

        // These two ignore the name the engine offers them, where the rest of
        // the floor takes it. #236 wrote them and `drink` as a family that reads
        // alike, and naming the object in two of the three would break the set
        // for no gain.
        //
        // The other half of that reasoning is gone: this used to add that "the
        // `String` these are handed carries no number to agree with", which was
        // true and was the second widening #245 closed. All three are handed a
        // `GameText.Noun` now, so a line here that wants agreement can simply
        // ask for it.
        stubs.fill = .init(Prose.cantFillThat)
        stubs.pour = .init(Prose.cantPourThat)
        stubs.empty = .naming { "\($0.sentenceCased) has nothing in it to empty." }
        stubs.tie = .naming { "You cannot tie \($0) to anything." }
        stubs.untie = .naming {
            "\($0.sentenceCased) \($0.verb("is", "are")) not tied to anything."
        }

        // MARK: Ritual and flavor

        stubs.pray = .init(Prose.verbPray)
        stubs.sing = "The dungeon is unmoved by your singing."
        // `V-CURSES` (`gverbs.zil:382`). Trilogy verbatim, and the only line in
        // this floor the player is likely to go looking for on purpose.
        stubs.curse = "Such language in a high-class establishment like this!"
        stubs.xyzzy = .init(Prose.verbMagicWordInert)
        // The mainframe's count is a hint toward the grating under the leaves,
        // but the number cannot be confirmed from
        // `docs/games/dungeon-prose-comparison.md` and inventing one is worse
        // than not answering — so this stays a shrug, in this game's voice. (#233)
        stubs.count = "You lose count somewhere in the middle."
        stubs.think = "You think. It is not obviously helping."
        // `V-WISH` (`gverbs.zil:1610`). Trilogy verbatim.
        stubs.wish = "With luck, your wish will come true."

        // MARK: Commerce

        stubs.buy = "That is not for sale."
        stubs.sell = "That is not something you could sell."

        // MARK: Fixtures

        stubs.blow = .naming { "Blowing on \($0) achieves nothing." }

        return stubs
    }
}

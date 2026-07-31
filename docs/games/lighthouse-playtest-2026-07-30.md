# Lighthouse — playtest round, 2026-07-30

Commit `4aae966` · seed `0` · `fix: none` · charters: tourist, clock-watcher, vandal,
solver, idiot, re-reader (interrogator skipped — Lighthouse has no `talk` capability)

Oracle tiers: **T0 kernel, T2 `LighthouseTranscriptTests`, T3 source.** No T1 — this
round ran with `docPath: null`, because it *is* the round that drafted
`docs/games/lighthouse.md`. Testers had the type doc comment's seven-idiom list as
the nearest thing to a contract and nothing else, which is exactly the blindness
[#87](https://github.com/heirloomlogic/gnusto/issues/87) was filed about.

Budget: 40 turns planned per charter. The round's own turn count does not survive
contact with the transcripts; see [Coverage](#coverage).

29 findings confirmed, 13 refuted, 0 routed, 0 fixed (`fix: none`).

## The round

One class dominates and it is the class a transcript test structurally cannot
catch: **prose that was true when it was written, printed in a frame that has moved
underneath it.** Lighthouse has a roaming actor and a portable light, so almost
everything about it moves, and almost none of its prose branches. All of it predates
this branch; provenance is in the [ledger](lighthouse-playtest-ledger.md).

- **The keeper's departure line says she "limps away up the stairs" while leaving
  the Lamp Room.** *Frame:* Lamp Room, turn 11, lamp lit and carried, on the turn
  the roam daemon moves her down. *Cause:* `actors.roams` prints `departure` in the
  room being left, and the circuit is two rooms one above the other, so one fixed
  string is spoken from both ends. The room's own description says "Stairs spiral
  back down", and `up` from it answers "You can't go that way." The paired arrival
  line is wrong in the Base for the mirrored reason.
- **The shelf goes on announcing a key that is in the player's pocket.** *Frame:*
  Base, any look after `take key`. *Cause:* `firstSight` on the shelf, which prints
  until the *shelf* is touched — and nothing in the game touches it. On the first
  visit the same line also duplicates the engine's own surface listing, so the key
  is announced twice in five lines.
- **The keeper's briefing doesn't know where she is or what the player has.**
  *Frame:* Lamp Room, key in inventory, chest already open. *Cause:* an unbranched
  `reply`. "Turns from the window", "the shelf yonder" and the claim that the key is
  on it are all false at once.
- **Both lamp fuses narrate a flame nobody can see.** *Frame:* Base, lamp lit and
  dropped in the Storeroom behind a shut door. *Cause:* neither `say` guards on the
  player being able to see the lamp; the fuse fires relative to the lighting event,
  by which time the lamp may be two rooms away.
- **The beacon sends the player to fetch oil they are standing on.** *Frame:* Lamp
  Room, oil can dropped on the floor. *Cause:* the guard is `oilCan.isHeld` and the
  message is written for the can being in the storeroom; the one case they disagree
  on is the one a player reaches by putting things down to work.
- **Two dozen nouns the prose prints are outside the vocabulary.** *Frame:* every
  room, including the first one a player sees. *Cause:* no scenery items behind the
  copy. `lighthouse`, `storeroom` and `oil` are known as adjectives only, so they
  fail differently — "You can't see any such thing" rather than "I don't know the
  word", which reads as a scope bug rather than a vocabulary gap.
- **Three stock stub lines contradict the game.** `pour can` / `empty can` assert
  the win item is empty on the turn after `x can` calls it "heavy with lamp oil";
  `burn lamp` denies a capability `light lamp` grants one turn later; `swim` and
  `dive` deny the sea, on the jetty, while the daemon narrates it rising. *Cause:*
  the game re-skins no stock text and the stub layer runs no state check.
- **`talk to <anything but the keeper>` prints a parse-failure message and spends
  the turn.** *Frame:* the Jetty, where three of them kill you. *Cause:* a declared
  custom intent with no handler for that noun falls through to
  `frame.say(text.didntUnderstand)` — `say`, not `refuse`, so the turn commits and
  every daemon runs. This one is the engine's, not the game's.

## Fixed

None. This round ran `fix: "none"` by design — it was drafting the design doc, and
the harness clamps `fix` to `none` when `docPath` is null anyway, which is the
constraint #87 exists to lift.

## Filed, not fixed

All 29, deduplicating to eight classes across seven issues.

| Issue | Class |
|---|---|
| [#91](https://github.com/heirloomlogic/gnusto/issues/91) | Prose untrue of the frame it printed in — five sites, plus the takeable chest |
| [#92](https://github.com/heirloomlogic/gnusto/issues/92) | Unanswerable nouns (K8) |
| [#93](https://github.com/heirloomlogic/gnusto/issues/93) | Stock stub lines that contradict the game |
| [#94](https://github.com/heirloomlogic/gnusto/issues/94) | The beacon's `isHeld` guard vs. its own message |
| [#95](https://github.com/heirloomlogic/gnusto/issues/95) | `beacon.isLit`'s unreachable `describe` branch — a design call |
| [#96](https://github.com/heirloomlogic/gnusto/issues/96) | Engine: a parse-failure message that costs a turn |
| [#97](https://github.com/heirloomlogic/gnusto/issues/97) | Harness: label collisions destroy the audit trail |

Why not fixed here: [#87](https://github.com/heirloomlogic/gnusto/issues/87)'s
deliverable is the design docs, and a fix round riding along would have buried them
under a rewrite of the game. The fix rounds — with `docPath` set and `fix: "game"`
permitted, which is #87's second acceptance criterion — move to a follow-up PR now
that the doc exists to license them.

## Routed elsewhere

Nothing. `routedIssues` was derived fresh from the open enhancement issues and
passed [#88](https://github.com/heirloomlogic/gnusto/issues/88) (definite article on
a proper name) and [#85](https://github.com/heirloomlogic/gnusto/issues/85) (stub
verb reachability). Lighthouse has no proper-named actors, and no finding in this
round turned on stub reachability, so neither bucket caught anything. Both were
checked against by hand in four separate refutations.

## Refuted

13 refutations covering 8 distinct claims — five were the same claim filed by a
second or third charter and refuted again from scratch, which is duplicated work the
dedupe key did not catch.

| Charter | Claim | Refutation |
|---|---|---|
| tourist | The Jetty's description names no exit while the other three rooms all name theirs | Accurate, but no sentence is false of its frame. Omission is not assertion. |
| tourist, vandal, idiot | `x keeper` answers the stock "You see nothing special" for the game's only NPC | `ActorTests.anUndescribedActorIsNothingSpecial` asserts exactly this for an actor with no `description`. Designed, tested engine behaviour. |
| clock-watcher | The keeper "stands by the window" in two windowless rooms | Refuted on the Lamp Room, whose walls are glass "open to the night on every side". **Note:** a different verifier *confirmed* the same substance for the Base. Recorded in the ledger as split, and carried into #91. |
| clock-watcher | Her "leg's no good for the stairs" one turn after she climbed them | Characterization. The limp and the climb were authored as one idea. |
| clock-watcher | "Climbs stiffly into the room" prints on a descent | Same site as the confirmed departure defect; folded into #91 rather than counted twice. |
| vandal | The game re-skins none of ~47 stub verbs, so it answers in the engine's voice | Register, not truth — except the three cases that *are* untrue, which were promoted out and are #93. |
| vandal, solver | The tagline promises a deadline the tide enforces nowhere but the jetty | **`licensed-by-doc`.** The type doc comment says "the rising `tide` that eventually floods the jetty" — jetty-scoping is the stated design — and the tagline prints at boot, on the jetty, at `tideStage` 0, when the tide *is* a live three-turn lethal deadline. |
| solver, idiot | The beacon's lit `describe` branch is unreachable dead prose | Refuted as "not false of any frame"; the underlying fact is accurate and was separately confirmed as `doc-drift`. Filed as the design call #95. |
| idiot | `search shelf` finds nothing while the key is listed on it | `.lookIn` reports the *inside*. The key is *on* the shelf. The preposition carries the claim. |

## Coverage

**The round's own numbers do not survive contact with the transcripts, and that is
the most important thing in this report.**

| Claimed | Ground truth on disk |
|---|---|
| 947 tester turns over ~90 replays | **266 engine turns over 31 surviving probe directories** |
| 11 unknown-word occurrences, 8 distinct | **92 occurrences, 27 distinct tokens**, 24 of them nouns the game prints |
| 4 of 4 rooms visited | 4 of 4 — the one number that checks out |

`bin/playtest-replay` writes to a flat `.context/playtest/<label>/` namespace and a
re-used label overwrites in place. Six charters and their verifiers ran concurrently
into it. Roughly two thirds of this round's evidence no longer exists, and the
surviving third is the *last* probe written under each name. Three refutations cite
`verify-1`, `verify-2` and `verify-3` for three different claims; what is at
`verify-1/` now is a four-command probe that replays none of them. Filed as
[#97](https://github.com/heirloomlogic/gnusto/issues/97), and it should be fixed
before any round runs with `fix: "game"` — a fixer citing an overwritten transcript
is exactly the "plausible wrong fix" failure `SKILL.md` warns about.

**Rooms** — 4 of 4. None never-visited. Lighthouse has no off-map geography.

**Charters** — six run, none silent. **interrogator not run**, and its absence is
not neutral: Lighthouse's whole conversation surface is the custom `talk` verb over
a two-branch `keeper.before(.talk)`, and *all six* charters that did run listed the
`keeperGreeted == true` branch as unreached. Six charters, and the second-talk
branch had zero coverage. The completeness critic reached it in 9 turns and found
the briefing reciting a puzzle the player has already solved — which is the
substance now in #91.

**State axes** — 12 identified by the survey; the grid below is what was actually
stood in.

| Axis | Cells | Probed |
|---|---|---|
| `tideStage` 0 / 1–2 / 3 / ≥4 on the Jetty | 4 | 1 (death from turn 1 only) |
| Lamp fuel: unlit / 1–5 / 6 flicker / 7–8 / 9 out / relit | 6 | 3 |
| Keeper room × player room (present / arriving / departing / absent) | 8 | 5 |
| `keeperGreeted` false / true | 2 | 1 |
| `beacon.isLit` false / true | 2 | 1 (the second appears unreachable — #95) |
| Door locked×closed / unlocked×closed / unlocked×open | 3 | 3 |
| Chest closed / open / emptied | 3 | 3 |
| `oilCan` in chest / held / dropped in room | 3 | 3 |
| Score 0 / 5 / 25 | 3 | 3 |

**Dropped** — none dropped for budget or non-reproducibility. Every confirmed
finding replayed cleanly at seed 0 before being filed. Two findings were promoted
*out* of the "register, not truth" bucket (the `pour`/`burn` cases) on the argument
that they assert state rather than tone.

**Not covered, and named so the next round can target it:** the Jetty's stage-3
describe branch ("no time left") was read only in source, never printed; re-entering
the Jetty at `tideStage ≥ 4` from the Base was claimed by the idiot and never
captured; `take chest` — the "heavy chest" the Storeroom says "fill[s] most of it"
is takeable and carryable out, while the room description goes on asserting it fills
the room. That last one is the same class as #91 and has been added to it.

**Completeness critic's verdict: `round-is-thin`.** Recorded rather than argued
with.

## Hygiene

This round and the Gramarye round of the same day share a branch, so they share one
set of numbers. This report owns them; the Gramarye report points here.

- `swift test` — 873 tests, 0 failures.
- Strict lint — clean.
- Test files: two tests added to `LighthouseTranscriptTests` (the dark Lamp Room, the
  beacon's fuel gate) and one seed pin added to `GramaryeTests`. No assertion removed,
  no needle weakened.
- **No game source changed by either round.**

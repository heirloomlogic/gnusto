# KindlyDeep — playtest round, 2026-08-02

Commit `0b78ad8` · seed `0` · `fix: "none"` · charters: tourist, clock-watcher, vandal,
solver, idiot, re-reader (interrogator **not run** — see Coverage)
Oracle tiers: **T0 kernel, T2 `KindlyDeepTests`, T3 source. No T1** — KindlyDeep has no
design doc, so there was no contract, no timeline and no stated solution to judge
against. The testers used the type's doc comment and `maxScore` 25 as a stand-in.
Budget: 360 turns planned; **~2,383 engine turns spent over 237 probes** (6.6× budget;
the testers' own self-report of 1,051 counts only their own probes and under-reports
even those by ~9%).

64 findings confirmed, 11 refuted, 0 routed, 0 fixed. Completeness critic:
`trustworthiness: sound`.

This is the game's first round. It is one commit old — `0b78ad8` is the only commit that
has ever touched `Sources/KindlyDeep/KindlyDeep.swift` — so every finding below is a
birth defect, not a regression, and none of it has been through a fix round.

## The round

**The game can be made permanently unwinnable in three turns, and its central promise —
the subtitle is "Two went down; two come up" — is not checked by the ending that
delivers it.** Under that, one class dominates: prose that asserts where Biscuit is,
or what state a thing is in, without ever asking. 64 findings deduplicate to 19 classes;
the top five account for 43 of them.

- **Dousing the cap-lamp and dropping it strands the only light source in the game.**
  *Frame:* any room, from turn 3, with no death, no warning and no hint anything was
  lost. *Cause:* `capLamp` (KindlyDeep.swift:217) is `lightSource` with no
  `before(.drop, .putIn, .putOn)` guard, while `striker` twenty lines later has exactly
  that guard ("Not down here. It goes on your belt and it stays on your belt"). Every
  location is `dark` and no second `lightSource` exists, so an unlit lamp on the floor
  of a pitch-black room is out of scope and cannot be taken back. The lamp's own doc
  comment — "Worn on the cap, so always to hand" — states an invariant the code never
  enforces. Compounding it, the re-skinned `text.pitchBlack` goes on telling the player
  the striker "is the only good idea available", forever, about a striker that can no
  longer light anything.
- **The winning ending narrates Biscuit inspecting the cage and riding up in the sling
  while he is stranded two rooms west at the Forks.** *Frame:* `ring bell` at the Shaft
  Bottom having reached it through the crawl, which Biscuit cannot use, with the
  air-door never opened; score 15/25 in 6 turns. *Cause:* the ending text is
  unconditional. The player abandoned the mule and the game congratulates them in detail
  for not doing so — the one beat the whole demo is built to land.
- **Ten sites assert Biscuit's presence or his body without checking his location.**
  *Frame:* wherever he has been parked at the Forks by the crawl beat. *Cause:* the
  follow daemon is stopped in `lowCrawl.onEnter` and nothing downstream re-reads
  `biscuit.isIn(…)`. `harness tack` narrates his shoulders setting and his hooves biting
  from two rooms away; `rest` has him standing watch over the sleeping player; both death
  fuses have him nosing the dying player's cheek and his hooves "coming near"; the
  corn-bin discovery gives him a reaction shot; `push beam` refuses because "hauling is a
  trade with a professional standing eight feet away"; and `text.pitchBlack` says
  "Somewhere near, hooves shift on stone" in every dark room including the Low Crawl —
  one paragraph after the crawl beat said his bray recedes "until the stone shuts it out
  altogether". Those two sentences print in the same turn's output.
- **The beam and the cage gate never re-read their own state after the haul.** *Frame:*
  the Shaft Bottom, on the turn after Biscuit grinds the beam off the gate "until it lies
  clear". *Cause:* `shaftBottom` is declared with a static `description(…)` and `beam`
  and `cageGate` with static `description(…)`s, none branching on the hauled flag. All
  three still put twelve feet of poplar across the gate; `x cage gate` still calls the
  gate "perfectly useless while twelve feet of poplar lies across it".
- **The Forks' paragraph never re-reads `airDoor.isOpen`.** *Frame:* the Forks, after
  opening the door from the shaft side and walking west through it. *Cause:* a static
  `description(…)` (KindlyDeep.swift:168–178) hard-codes "the fall has racked the frame
  and jammed it fast on this side". The door's *own* text already branches three ways —
  `airDoor.describe` has an `isOpen` branch that says it "stands wide on its hinges" —
  so the room paragraph is the only thing left insisting the route is shut, and the two
  contradict each other in adjacent turns. Per K2 the fix deletes the static trait rather
  than adding a second channel.
- **Biscuit is a proper name that is not declared `properName`,** so seven stock lines
  say "The Biscuit would take exception to that" and "The Biscuit nods, and says
  nothing". *Frame:* every session. *Cause:* the missing trait — and the bootstrap
  already emits the exact warning predicting it, on stderr, at every single launch.
- **~60 distinct nouns the prose prints are unknown to the parser, 286 occurrences.**
  *Frame:* every room. *Cause:* no vocabulary. `wall` (28), `entry` (21) — the word four
  of six room descriptions use for the passage the player is standing in — `frame` (19),
  `walls` (16), `brick` (16), `belt` (13), `rib` (12), `floor` (12). The intro and the
  pitch-black line name the belt, the dust, the dinner bucket and the hooves before the
  player has typed anything; none is a word the parser knows. The Low Crawl answers none
  of its own four nouns, including "crawl", which is the room's name.

## Fixed

Nothing. The round ran `fix: "none"`, and with no design doc the harness clamps prose
fixing off regardless — `docs/games/kindly-deep.md` does not exist, and the repo makes
the design doc the copy source of truth.

No source file was modified by this round. Test files: ±0 lines. No assertion removed.

## Filed, not fixed

All 64 findings, deduplicating to **19 classes**. Filed as the round's one issue (see the
ledger preamble for the number), which carries **20 boxes**: the nineteen classes below
plus the dead-content finding the completeness critic turned up and no charter filed
(The Old Works — see Coverage). That twentieth box did not go through the adversarial
verify gate; I confirmed it by hand instead, against the source and a four-route probe.

| Reason | Count | What it means here |
|---|---|---|
| `out-of-mode` | 61 | `fix: "none"` — the setting reached no owner class. |
| `needs-human` | 3 | The verifier confirmed it and declined to let a fixer near the design. |
| `harness` | 0 | — |
| `unclassified` | 0 | — |

The three `needs-human` classes and why the verifier stopped:

| Class | Severity | Why it needs a person |
|---|---|---|
| The Forks' air-door paragraph | major | The same paragraph's crawl clause is a *second* thing the room never re-reads: once the door is open the crawl is no longer the only way east. Rewriting one clause without the other trades one false sentence for another. |
| "The rails is not food." (Engine) | minor | `GameText.stubs.eat` hard-codes a singular copula. Either the engine grows a plural flag on the item or the game drops its plural `name` — and the game's noun is the natural English one. Every `named` stub with a copula has the same hazard; `smash rails` reads "The rails is sturdier than that." |
| All three swallows print one line | minor | `takeASwallow()` branches only on Biscuit's presence, so the swallow that empties the canteen still says he stopped "while there is still something to stop for". The last swallow is the beat the thirst clock is built around; what it should say is a design call. |

## Refuted

11 of 75. The verifier is doing real work — it rejected two findings against the exit
prose, two register complaints, and one repeat-behavior claim.

| Charter | Claim | Refutation |
|---|---|---|
| tourist | The Low Crawl says "The crawl runs east and west" but the Shaft Bottom never names the hole the player crawled out of | Every fact in the finding is true and none of it is false *of the frame it printed in*. "The crawl runs east and west" printed in the Low Crawl, where east and west both work. An exit that is absent and was never named instantiates neither exit class. |
| tourist | The Forks gives "East" to the jammed air-door while `east` is the route into the crawl; the west exit is never named | Replayed; the room's own sentence names the crawl in the next clause. An unnamed working exit is not an exit-prose mismatch. |
| idiot | With the air-door open, `east` at the Forks still puts the player in the crawl | Same site. The door is a `shaftBottom.west(forks, via: airDoor)` one-way declaration; the Forks never claimed `east` was the door. (The Forks paragraph *is* a confirmed defect — as a state lie, not an exit lie.) |
| vandal, idiot | KindlyDeep re-skins none of `GameText.stubs`, so ~47 verbs answer in the engine's voice | Refuted as filed twice over, then confirmed once in the narrower form that survives: the defect is the *individual* stub lines that make a false claim about the room, not the aggregate register. |
| solver | `ask`/`tell`/`show` are unknown words in a game with an actor at your elbow | Not a defect of this game: the engine does not back those intents, and KindlyDeep declares its own `talk to`. |
| clock-watcher | The blocked north exit still says the roof "has been down an hour" after a full rest | The line is Biscuit's characterization, not a clock claim; `rest` advances no stated hour. |
| clock-watcher | `take beam` says hauling is "a trade with a professional standing eight feet away" with Biscuit two rooms west | Refuted on the verb — but the *same sentence* under `push beam` was confirmed. One filed, one rejected, same string; the `take` path was not reached in the cited frame. |
| re-reader | The "Biscuit cannot follow" beat is silently dropped on the second trip into the crawl | Replayed: he is at the Forks, the beat is a one-shot by design, and the follow daemon reaches the Shaft Bottom only via the opened air-door. |
| solver | The default `.talk` reply says the words go "into the dark" with the lamp lit | The reply is the *unaddressed* `talk`, not `talk to biscuit`; the frame was misread. |
| idiot | `x me` answers with the engine's stock `selfDescription` | Preference, not a defect — and with no design doc the verifier will not infer intent from outside. |

## Coverage

### Rooms — 6 of **7**

Never entered, in **0 of 237 probes**: **The Old Works**.

The per-charter survey reported "6 of 6, never visited: none", which is the flattering
denominator: it was reached by deleting the room nobody could get into. All five play
charters and the survey independently listed it as "I believe but cannot prove it is
unreachable"; the critic spent three more routes on it and I spent a fourth. All refused.

The reason is structural, and stating it flatly is the point so round 2 does not spend
turns on it: `forks.exit(.north, to: oldWorks, when: { !biscuit.isIn(forks) })`
(KindlyDeep.swift:1058–1067) is evaluated in the live turn; the follow daemon relocates
Biscuit into the player's room in the *same* turn as the move; the only `stopDaemon` site
is `lowCrawl.onEnter`, which parks him **at the Forks**. There is no turn in which the
player stands at the Forks and Biscuit does not. **The Old Works is dead content** — it
declares `name` and `dark` and *no description at all*, so its paragraph would print
empty — and both `oldWorks.onEnter`'s gas death and the `to: oldWorks` branch are
unreachable code. No charter filed it; it is in the issue as a code-owner box.

### The state cross-product — 7 rooms × 8 axes = 56 cells, 31 ticked

✓ probed · ~ sampled thinly · ✗ never · — structurally impossible

| | lit | dark | Biscuit with you | Biscuit absent | stub verbs (of 47) | nouns typed | thirst death | fatigue death |
|---|---|---|---|---|---|---|---|---|
| The Fresh Fall | ✓ 237 | ✓ 237 | ✓ | — | ✓ 47 | ✓ 53 | ✓ | ✗ |
| The Stable | ✓ 51 | ✓ 1 | ✓ | — | ~ 14 | ✓ 38 | ✗ | ✗ |
| The Shelter Hole | ✓ 43 | ✓ 13 | ✓ | — | ✗ 4 | ~ 21 | ✗ | ✗ |
| The Forks | ✓ 129 | ✓ 5 | ✓ | — | ~ 9 | ~ 16 | ✓ | ✗ |
| The Low Crawl | ✓ 104 | ✓ 10 | — | ✓ | ✗ 7 | ✗ 9 | ✗ | ✗ |
| The Shaft Bottom | ✓ 85 | ✓ 5 | ✓ 39 | ✓ 46 | ~ 13 | ✓ 32 | ✓ | ✓ |
| The Old Works | ✗ | ✗ | ✗ | ✗ | ✗ 0 | ✗ 0 | ✗ | ✗ |

**The stub-verb row is this round's biggest illusion of coverage.** All 47 stub intents
were typed at least once, so "we swept the stubs" is technically true — and 47 of them
landed in **one room**, the Fresh Fall, across two sweep probes. The Shelter Hole saw 4;
the Low Crawl saw 7. Register is room-independent; *truth* is not, which is exactly why
`smell` reading "You smell nothing out of the ordinary" is a defect in the Stable and at
the Forks and nowhere else.

Two corrections in the charters' favour: three of them reported dark cells as unprobed
that verifiers had in fact walked, and the thirst death did fire at the Forks — a cell
every charter listed as uncovered. Testers cannot see what verifiers covered, and no
artifact tells them. That is a harness gap, not a tester failure.

### Timers

| Timer | Exercised | Where |
|---|---|---|
| `biscuit.follow` | ✓ heavily | all six reachable rooms, both daemon states |
| `thirst` (12/20/28) | ✓ | ladder read in full |
| `dehydration` (death, 36) | ✓ 6 probes | Fresh Fall, the Forks, Shaft Bottom. Never: Stable, Shelter Hole, Low Crawl |
| `fatigue` (16/26/36) | ✓ | ladder read in full |
| `collapse` (death, 44) | ✓ 3 probes | **Shaft Bottom only** — 5 of 6 rooms uncovered |

Nothing was wholly unexercised, so the timer line is honest. The room dimension under it
is not: `collapse` prints "sits you down against the rib" and `dehydration` prints
"hooves on stone, coming near" — both are location claims, judged in 3 of the 12
room-cells that exist.

### Charters

**No charter found nothing.** All six that ran filed findings and all but the solver had
at least one refuted. None is a silent no-op.

**The interrogator was not run, and on this game that is not an interchangeable
omission.** KindlyDeep is a *companion* demo: it puts an actor at the player's elbow for
the entire running time, declares its own `talk` verb, wires two `actors.reaction`
replies, and hangs a scored beat and a survival-clock interaction off `give`. That
surface is the interrogator's whole charter, and it is exactly the surface that came back
zero across 237 probes — the successful `give canteen to biscuit` share printed in **no
transcript in the round**, and the "forelock" noun the pet reply prints was never typed
at the parser. Four charters listed the water-sharing beat in `cellsSkipped`, each
assuming another had it. None did, because the charter that owned it was not run.

One caveat on trust, recorded because next round should act on it: the clock-watcher's
self-report says "nothing here rests on a restored save", while 5 of its 16 probes begin
with `restore`, including two of the three deaths it observed. The claim is about its
cited reproducers rather than its probes, and that distinction is not checkable from the
artifacts. Its reproducers deserve spot-checking rather than trust.

### Findings dropped

0 dropped for budget, 0 dropped as non-reproducible. Every one of the 75 was replayed by
its verifier before a verdict. I independently re-ran four of the highest-severity
claims against the shipped binary — the lamp-drop trap, the beam-after-haul trio, the
winning ending with Biscuit stranded, and "The Biscuit" — and all four reproduce
verbatim at seed 0.

### Next round's targets

Carried from the completeness critic, in its priority order:

1. The canteen quadrant crossed with the thirst ladder — `give canteen to biscuit`, then
   run to the 12/20/28 warnings without drinking. The share spends a swallow and by
   design does *not* reset thirst; nobody has read that sequence.
2. `collapse` in the five rooms it has never fired in.
3. `dehydration` in the Low Crawl specifically, with Biscuit parked at the Forks.
4. Stub verbs outside the Fresh Fall — priority the Shelter Hole (4 of 47) and the Low
   Crawl (7 of 47). Target the ones whose stock line makes a claim about the room.
5. The noun surface at the Forks (16 typed) and the Low Crawl (9) against the Fresh
   Fall's 53. Twenty critic turns there produced five words absent from this round's
   60-word census plus three printed nouns that parse but are out of scope.
6. Run the interrogator.

## Hygiene

- `swift test` — **1,060 tests in 84 suites, 0 failures**, 0.85s.
- Strict lint — clean, exit 0. (`.swift-format` is gitignored and generated by
  `.build/checkouts/Persnicket/bin/ci-lint-setup`; it must be generated before the
  command in `CLAUDE.md` will run in a fresh checkout.)
- Test files +0 / −0 lines. **No assertion removed, no needle weakened** — this round
  modified no source and no test.

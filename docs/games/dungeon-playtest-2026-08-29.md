# Dungeon — playtest round, 2026-08-29

Commit `daee513` · seed `52` · roundId `2026-08-29` · `packagePath .` · charters: explorer ×3,
timekeeper ×3, solver, wrong-footer. **`interrogator` did not run — no seat.** Oracle tiers:
T0 kernel, T1 `docs/games/dungeon.md`, T2 `DungeonWalkthroughTests`, T3 source, T4 ledger — all
five. Budget: **60 turns per charter over 8 seats**, 480 in all. 17 agents, 1,713,132 subagent
tokens, 682 tool calls, ~61 minutes wall clock. **No `fix` stage**: `.claude/workflows/playtest.js`
takes no `fix` argument any more, and the round changed no code.

Twenty-nine findings were filed; three merged into a class already seen, so **26 reached
verification. 12 confirmed** (9 unanimous, 3 `needs-human`), **14 refuted**, 0 routed, 0 dropped. `ownerClass`: 11 `game`, 1 `engine`. Two verification batches, two raters on
every finding, `bothRaters` 26, **agreement 23 of 26 = 88.5%**. All three disagreements resolved
to `needs-human`.

Four regions were declared in `docs/games/dungeon-playtest-focus.md` and chunked over three blind
seats: explorer-1 and timekeeper-1 took **R1+R2**, explorer-2 and timekeeper-2 took **R3**,
explorer-3 and timekeeper-3 took **R4**. `routedIssues` was empty: no open issue owned a class
this round found.

**The `ledgerKeys` argument was wrong, in the exact way the ledger's own preamble warns
against, and it did no damage because every key in it was inert.** 55 keys were passed. Sorted
against the ledger's own verdict column: **39 `fixed`, 3 `confirmed`, 13 `refuted`.** The rule
is that only rejections go in, because `ledgerKeys` feeds `seen` and a matching finding is
dropped unverified and unreported — so passing a `fixed` key instructs the harness to swallow a
regression in silence. What saves the round is that **all 55 are the ledger's display-truncated
2026-08-11 rows, every one ending in `…`**, and `normalize()` strips every character that is not
`[a-z0-9 ]`, so no produced key can ever equal one. None of the 55 could match anything. The
whole set worked as prompt deterrence and as nothing else — and the 31 full-form `decl::`
refuted keys from 2026-08-18, 2026-08-24 and 2026-08-25, which were the entire working dedupe
set, were passed as none of it.

**The completeness critic rates this round `round-is-thin`, and it is right.** The published
`rooms.worked` figure is 22 of 195; the honest count is **17 of 195 — 8.7% — whose prose a
charter actually read**. 758 `turn=cost` lines went unattributed, and they are this round's own
slot machinery. One of the eight seats produced no evidence about the game at all, through an
operator's error rather than its own. Read *Coverage* before treating twelve confirmed findings
as a thorough pass.

## Why this round exists

This is the round **#333** was filed to make possible. #333 was itself the residue of the
2026-08-25 round: three items on that round's ranked list were round-*preparation* work that no
code change could do, and they became the acceptance criteria below. All four were met.

| #333 wanted | This round shipped |
|---|---|
| a save with the thief **alive** | `z-1` (`route[0:29]`) and `z-2` (`route[0:35]`), both cut before `route[41]` `attack thief with sword`. R4 was seated on explorer-3 and timekeeper-3 |
| the four zeroed regions in `focus`, one seat each | Maze 23, Coal Mine 20, Mirror 10, Palantir 7 — all four in the focus text, each with a seat; the dispatch log proves it |
| `damLeak`, `slideGrip`, `thief.opensEgg` in the `firedTimers` census | fired **41**, **6** and **7** times |
| each slot named with its route index | nine slots, nine indices, below |

### The slots

Cut by `bin/playtest-slots Dungeon` into label `Dungeon-r1-slots`, then restored one at a time
under `Dungeon-r1-slots-check` and each landing read off the footer and the inventory rather
than assumed.

| Slot | Cut at | Landed in | moves | score | Holding / state |
|---|---|---|---:|---:|---|
| `z-1` | `route[0:29]` | Maze | 31 | 40 | jewel-encrusted egg, skeleton keys, garlic, brass lantern, elvish sword |
| `z-2` | `route[0:35]` | Treasure Room | 37 | 65 | thief alive and listed, leaning on the wall with his bag and stiletto |
| `d-1` | `route[0:113]` | Maintenance Room | 112 | 142 | gates shut, four buttons, tools still in place |
| `m-1` | `route[0:123]` | Reservoir | 122 | 142 | drained to mud, trunk of jewels half buried and untaken |
| `m-2` | `route[0:128]` | Mirror Room | 127 | 157 | the untouched half of the matched pair |
| `c-1` | `route[0:184]` | Shaft Room | 181 | 210 | hoist at the head of the shaft |
| `c-2` | `route[0:224]` | Machine Room | 220 | 225 | coal and screwdriver in hand, machine unrun |
| `p-1` | `route[0:659]` | Tiny Room | 646 | 586 | skeleton keys and welcome mat in hand, oak door shut |
| `p-2` | `route[0:719]` | Slide Room | 706 | 596 | rope tied off at the head of the slide, blue crystal sphere in hand |

**The slice indices are the artifact.** `.context/` is gitignored and one line regenerates the
lot: `bin/playtest-slots Dungeon`.

### One claim in the focus file was wrong, and it is worth correcting here

The blind text told timekeeper-1 that R1 *"owns a clock that has never fired in any artifact of
any round"* and told timekeeper-2 the same of R3's daemon. Both sentences came from the
2026-08-25 round's census, which was scoped to that round's own artifacts. Checked against the
tree: **`damLeak` fired 28×, `thief.opensEgg` 7× and `slideGrip` 3× in the 2026-08-24 round**
(`docs/games/dungeon-playtest-2026-08-24.md`, *Timers*), and that round has a section per each.
The true statement is narrower and still worth having: all three fired again here, under seats
assigned to them, at 41, 7 and 6 — and `slideGrip` was read three ways (loaded, light, and
empty-handed) rather than merely tripped.

## The round

The class is the one the harness exists to find: a sentence untrue of the frame it printed in.
By the verifier's own categories: **five `prose-untrue-of-frame`, three `prose-untrue-of-state`,
two `unanswerable-noun`, one `presence-line-location-blind`, one `contract-violation`.**
**Three arrived in, or were left behind by, an earlier fix**, and those bullets say so.

- **`look through window` in the Dreary Room answers about a keyhole.** *Frame:* Dreary Room,
  moves=654, oak door unlocked and standing open, lantern in hand; the room's paragraph prints
  "a door made of oak, and beside it a small barred window" and no keyhole at all. *Cause:*
  `DungeonPalantir.seeThroughWindow` (`Regions/Palantir.swift:648-658`) replies `Prose.keyholeDark`
  on its dark branch — a constant it shares with the keyhole's own `.lookThrough` rule at :589.
  The Dreary Room is permanently lit by its red glow, so the window's dark branch is reachable
  only from that side, and the only sentence it can print there was written for the other
  aperture.
- **The Slide Room advertises a small opening to the north, and `x opening` describes the
  downward chute.** *Frame:* Slide Room from `p-2`, moves=706, nothing touched. *Cause:*
  `opening` is a declared synonym of `metalSlide` (`Regions/Mirror.swift:230-236`), so the
  parser binds a northward hole to a thing that goes down. `north` from that room reaches the
  Mine Entrance, so the opening is real and separate. This predates the #332/#339 synonym sweep,
  which fixed the same class in the Dam and River regions and did not reach here.
- **The Mirror Room prints "the south wall" and answers about the ceiling.** *Frame:* `m-2`,
  moves=127-128, mirror untouched. *Cause:* both Mirror Room ceilings carry
  `synonyms("ceilings", "ceiling", "wall", "walls", "exits", "exit")`
  (`Regions/Mirror.swift:136-150`), so `x wall` and `x walls` print the ceiling's own sentence
  about itself, and `x south wall` — the exact adjective-plus-noun the room printed — is refused
  with "You can't see any such thing."
- **The broken egg scatters its mother-of-pearl "on the forest floor" while the egg is broken in
  the Maze.** *Frame:* a twisty little passage from `z-1`, moves=31-32, score 40, the egg forced
  open on the turn before. *Cause:* `Prose.brokenEgg` (`Regions/Prose+AboveGround.swift:390-397`)
  is one unbranched literal with the breaking-place baked in, and the player can carry the intact
  egg anywhere in the Empire before opening it.
- **`x useless lantern` answers with a room-listing sentence, and goes on answering with it while
  the lantern is in the player's hands.** *Frame:* the skeleton chamber of the Maze, reached from
  `z-1`; the lantern is taken at moves=35 and examined at moves=37. *Cause:*
  `Regions/Maze.swift:203-210` hands the same string to `firstSight` and `description`, so
  EXAMINE returns a listing line and that line asserts a floor position. `needs-human`: the prose
  file says the two channels share a line on purpose, "trilogy verbatim", and Zork1 carries the
  identical pair.
- **The thief's death puts a body on the floor and the world holds none.** *Frame:* Treasure
  Room from `z-2`, moves=38-40. "The thief takes a fatal blow and slumps to the floor dead… His
  stiletto clatters to the floor beside him." Then `x thief` and `x body` are both refused and
  the LOOK lists egg, chalice and stiletto and no corpse. *Cause:* `onDefeat`
  (`Dungeon+Thief.swift:213`) drops the hoard and lets `melee` take the actor off stage. Zork I
  covers this seam with its black-fog line, which disposes of the carcass in prose; Dungeon's
  adapted line was rewritten to "name what fell" and dropped the disposal. `needs-human`.
- **The grue's death line says the player "walked into" it, after four `wait`s, on a rope.**
  *Frame:* `slideStretch` from `p-2`, everything dropped first, `down` then four `wait`s; the
  four preceding footers read `room=Slide` and the killing turn's footer reads `room=Forest`
  because the death teleports before the footer prints. The room's own description is "You are
  hanging on a rope in a chute of sheet metal, wide enough to fall down and too smooth to stand
  in." *Cause:* `Prose.grueDeath` is one unbranched literal handed to `GnustoDangerousDark` as a
  single `death:` parameter (`Dungeon.swift:203`) and shared with Zork1's table. `needs-human`:
  the repair is a design trade between an engine plugin API change, a per-room override the
  plugin does not take, and rewording a chute description written fresh for this wing.
- **A match is struck and reported burning with the flood over the player's head.** *Frame:*
  Maintenance Room from `d-1`, blue button then seven `z`s, moves=118-119; the same turn's rung
  line reads "high in your lungs". *Cause:* `matchbook.before(.burn, .turnOn)`
  (`Regions/Dam.swift:760-773`) checks the match count and whether one is lit, and nothing else.
  **This is a repair that stopped one flame short:** #329 (`3a3b3e3`) added the ivory torch's
  underwater branch precisely so a flame's prose would know this frame, and the frame check it
  needs already exists as `DungeonDam.waterOverYourHead`.
- **`x thief` reports him upright with his blade aimed at you, one turn after he is battered
  unconscious.** *Frame:* Treasure Room, moves=38 knockout, moves=39 examine, moves=40 the room
  listing has him face down against the wall. *Cause:* the examine text is a static
  `description(Prose.thief)` (`Thief.swift:68`) while the presence and greet channels both branch
  on `isUnconscious` at :132 and :142-144. **The #329 comment on the presence rule says "two
  channels needing it"; there are three.**
- **`search mud` at the drained Reservoir denies a trunk the room has just listed, and denies it
  in the name of the room.** *Frame:* `m-1`, moves=120-121; the restore itself prints "Lying half
  buried in the mud is an old trunk, bulging with jewels." and the next command answers "You find
  nothing of interest in the reservoir." *Cause:* `GameText.nothingToSearch` is left at the engine
  default, and `mud` is a synonym of `DungeonDam.reservoirWater`, whose `name("reservoir")` is the
  room's own name (`Regions/Dam.swift:419-426`). `search trunk` two commands away has bespoke
  prose, so the room already knows how to answer this verb.
- **The Maintenance Room contradicts itself about the ransacking.** *Frame:* `d-1`, moves=111-112.
  `x chests` → "…whoever ransacked this room was thorough and in no hurry." `x wreckage` →
  "…swept into the corners by whoever was in the hurry." `x equipment` prints the same string, so
  the contradiction is reachable by two nouns. *Cause:* **the offending sentence arrived in a
  commit that describes itself as a fix.** `Prose.maintenanceWreckage` was added by
  `0a97dea` (#233/#239) to make `wreckage` and `equipment` answerable; its own doc comment
  discusses the chests without reading what they say. "The hurry" is a definite reference whose
  only antecedent in the room denies there was one.
- **The `[status]` footer reports `turn=cost` for RESTORE.** *Frame:* clean boot at West of House
  moves=0, `restore` reads `turn=free`, and the slot answer `p-1` reads
  `room=Tiny Room | moves=644 | turn=cost`. Restoring on from there into `z-1` reads `turn=free`.
  *Cause:* `PlaytestSession.perform` computes `let turnCost = result.status.moves > movesBefore`,
  so across a state swap the field is the sign of a difference between two unrelated counters.
  `.restore` is in `Intent.metaIntents` and `StatusFooter`'s own doc comment says the field is
  false for a meta verb. It matters this round in particular: nine slots are reached by `restore`,
  every blind seat is told a restore is one free turn, and the brief tells every tester to read
  the footer rather than compute it.

## Filed

One issue for the round, holding every confirmed class as a checklist row. 12 confirmed: 11
`major`, 1 `minor`. `ownerClass`: 11 `game`, 1 `engine`.

| Class | Severity | Owner | Site |
|---|---|---|---|
| `look through window` answers about the keyhole | major | `game` | `Sources/Dungeon/Regions/Palantir.swift:648-658`, `Prose+Palantir.swift::keyholeDark` |
| `opening` is a synonym of the downward slide | major | `game` | `Sources/Dungeon/Regions/Mirror.swift:230-236` |
| the Mirror Room's wall answers as its ceiling | major | `game` | `Sources/Dungeon/Regions/Mirror.swift:136-150` |
| the broken egg scatters on a forest floor underground | major | `game` | `Sources/Dungeon/Regions/Prose+AboveGround.swift:390-397` |
| the burned-out lantern examines as a listing line (`needs-human`) | major | `game` | `Sources/Dungeon/Regions/Maze.swift:203-210` |
| the thief's death leaves a body the world does not hold (`needs-human`) | major | `game` | `Sources/Dungeon/Prose+Thief.swift:104,:122`, `Dungeon+Thief.swift:213` |
| the grue death line asserts a walk (`needs-human`) | major | `game` | `Sources/Dungeon/Prose.swift:38`, `Dungeon.swift:203` |
| the matchbook has no underwater branch | major | `game` | `Sources/Dungeon/Regions/Dam.swift:760-773` |
| the thief's examine channel cannot see he is down | major | `game` | `Sources/Dungeon/Thief.swift:68` |
| `search mud` denies a listed trunk, in the room's name | major | `game` | `Sources/Dungeon/Dungeon.swift` `text` block; `Regions/Dam.swift:419-426` |
| the Maintenance Room contradicts itself about the hurry | major | `game` | `Sources/Dungeon/Regions/Prose+Dam.swift:212-225` |
| `turn=cost` for RESTORE | minor | `engine` | `Sources/Gnusto/Playtest/PlaytestSession.swift` |

Two notes on the owner column, both of which say who owns the site and decide nothing:

- **The RESTORE footer row is filed `engine` and its site is
  `Sources/Gnusto/Playtest/PlaytestSession.swift`**, which is the play-test harness living inside
  the engine target. The rule that computes `ownerClass` keys off the path, and every
  `Sources/Gnusto/` path is `engine`. A reader deciding what to fix should treat it as harness
  work.
- **`search mud` is filed `game` and its dedupe key names
  `Sources/Gnusto/Actions/GameText.swift::nothingToSearch`.** That is correct on both counts: the
  string is the engine's stock line, and the defect is that Dungeon's `text` block re-skins twenty
  keys and not this one.

One finding names an owner file that does not exist. The broken-egg row was filed against
`Sources/Dungeon/DungeonForest.swift`; the literal is at
`Sources/Dungeon/Regions/Prose+AboveGround.swift:390`. The verifier caught it and recorded the
correction in the finding's provenance.

## Refuted

Fourteen of twenty-six, a 54% refutation rate. Every one carries a dedupe key and a reasoned
argument, and eight of the fourteen were re-run by the verifier before being refused.

| # | Charter | Claim | Refutation |
|---|---|---|---|
| F-01 | explorer-1 | `pull mat` refuses with a stock immovability line while the mat is under the door | `stock-behavior-by-design` — `stubs.pull` (`Prose+Stubs.swift:109`) says the same of every noun in the game; the verifier reproduced it on the lantern and keys **in the player's hands**. The repo's own solution uses `take mat` |
| F-02 | explorer-1 | A mat pushed under the oak door is still listed by LOOK as lying loose on the floor | `stock-behavior-by-design` — the stock line says only "here", which is true; the state is carried on `x door`, and `Palantir.swift:139-140` declares that choice in as many words |
| F-03 | explorer-1 | Tiny Room prints "A passage leads east", `x passage` returns the bare-rock walls | `stock-behavior-by-design` — `passage` is a declared synonym of `tinyRoomWalls`; the reply describes the room truthfully and makes no false claim about the passage |
| F-04 | explorer-1 | START with the lid open says the machine is inert rather than that the lid is open | `licensed-by-doc` — `Sources/Zork1` names the identical string `machineLidOpen`; source policy 1 takes it verbatim. A refusal that is correct and merely terse is not a finding |
| F-05 | explorer-1 | The Machine Room describes one switch twice, in two voices with two measurements | `licensed-by-doc` — the room paragraph is policy-1 verbatim trilogy prose (the one adaptation is documented at `Prose+CoalMine.swift:325-327`); the switch's examine is policy-3 new writing because the source has none |
| F-06 | explorer-2 | The trunk answers `search` with bespoke prose and `open` with a stock refusal; the two disagree about a lid | `stock-behavior-by-design` — neither reply mentions a lid, and the trunk genuinely cannot be opened in this game, ever |
| F-07 | explorer-2 | `x mirror` shows a face; `look in mirror` finds nothing of interest | `stock-behavior-by-design` — `.lookIn` answers `nothingToSearch` for anything not a `container`, which CLAUDE.md states outright; the reflection is on the examine channel and prints there |
| F-08 | explorer-3 | The stiletto is still described as a live weapon after its owner is dead | `characterization` — "it is the thief's own" is provenance, and provenance survives its owner; "it is quick" is a property of the blade |
| F-09 | explorer-3 | The egg is examinable while hidden inside the thief's shut bag | `stock-behavior-by-design` — the gift rule does `move(heldBy: thief)` (`Dungeon+Thief.swift:181`); the egg is in the actor's hands and the bag contains nothing. The finding's model is wrong, so the fault it names does not exist |
| F-10 | timekeeper-1 | The huge diamond's listing says "here" in the only frame it can print — inside the machine | `licensed-by-doc` — `DIAMO` is in the comparison's identical bucket (`Prose+CoalMine.swift:371-375`) and Zork I lists it the same way; the diamond *is* in the Machine Room and the line says nothing more |
| F-11 | timekeeper-1 | Shaft Room still says the shaft descends "into darkness below" after a lit torch goes down it | `licensed-by-doc` — `TSHAF` verbatim (`Prose+CoalMine.swift:70-78`); the game does not model light travelling up a shaft, and "below" is what the shaft mouth looks like from this room |
| F-12 | timekeeper-3 | The thief comes round and stabs you inside the turn whose listing calls him face down | `stock-behavior-by-design` — both sentences are true when they print; he is down during the command stage and up when the aggression daemon runs. The fix requested is a new field on `MeleeCombat.AggressionProse` |
| F-13 | timekeeper-3 | Treasures in the living thief's hands answer with the bare reach refusal | `stock-behavior-by-design` — held by a living actor standing in the room is exactly `cantReach`'s case; the finding's own fault paragraph concedes "here but out of arm's length" |
| F-14 | wrong-footer | Button labels answer "They're greek to you." — a lowercase proper adjective and a plural for a singular noun | `licensed-by-doc` — the doc's "free to change" list makes a one-line joke's spelling the author's call, and the corpus already prints "an elvish sword of great antiquity" lowercase. On number: `labels` is a `plural` item, the room prints "labelled", and each button's examine says "with a label above it" |

**The refutation pattern is itself a finding about the harness.** Eight of fourteen are
`stock-behavior-by-design` and five are `licensed-by-doc`: thirteen of fourteen amount to "the
tester did not know the rules". The brief's threshold is doc-licensed refutations above two in
five, and 5/14 = 36% clears it. The larger bucket is the blind charters filing against
*documented engine behaviour* — `.lookIn`/`nothingToSearch`, `cantReach`, actor scope, the
stub-verb floor. That is the T0 kernel, not the design doc, and **four findings died on rules
written down in CLAUDE.md in plain language.** Withholding the kernel is buying nothing.

**explorer-1 filed eight and two survived.** One merged into a class it had already filed, five
were refuted, and all five refusals are in one wing (R1/`p-1`). That is the round's largest
filer at a 5-in-7 miss rate, and it is worth weighing when reading its two survivors. (The
critic wrote this as "8 filed, 3 survived"; the verified set says two, and the extra finding it
counted is the merge.)

### Rater-independence audit

Two of the three audited pairs read as separately reasoned; one is convergent. Nobody is
rubber-stamping. The script writes no rationale to disk, so the full text of one agreed pair is
reproduced here or it exists nowhere.

**The keyhole/window finding — both raters `confirmed-defect`. Separately reasoned.**

> **Rater 1, `attemptedRefutation`:** "For this line to be right, 'keyhole' would have to be a
> fair name for what the player just looked through, or the Dreary Room would have to have a
> keyhole its prose acknowledges. Neither holds. There IS a `keyholeDreary` item filed in this
> room, so the noun is answerable — but the player did not type it; they typed `window`, and
> `barredWindow`'s own `.lookThrough` rule is what fired. The second half of the tester's claim
> is the weak one and I discount it: the Tiny Room genuinely is dark (the lantern went north
> with the player, and Gnusto does not model light spilling through an open door), so the dark
> verdict itself is right. What is wrong is only the noun the sentence uses to report it — and
> that is enough, because a player asked about bars and was answered about a lock."

> **Rater 2, `attemptedRefutation`:** "For the line to be right, 'keyhole' would have to be the
> game's word for the thing the player looked through — i.e. the window and the keyhole would be
> one aperture with one shared dark line, the way the two mirrors are one passage. They are not:
> `barredWindow()` and `keyhole()` are separate factory declarations, both filed in both rooms,
> each with its own `.lookThrough` rule, and it is the window's rule that fired here. The other
> defence is that the sentence is factually true — no light does come through the Dreary Room's
> keyhole either, since `lidTiny` had just dropped — so nothing false was asserted. That defence
> fails on the oracle the round actually applies: the reply reports on an object the player did
> not name and the paragraph did not print, in a room whose only advertised aperture is a barred
> window a hand's breadth across."

Rater 1 argues from what the player typed and volunteers a concession against its own verdict.
Rater 2 argues from declaration topology and knocks down a different defence (that the sentence
is factually true). Different premises, different candidate defences.

**The Slide Room "small opening" finding — both `confirmed-defect`. Separately reasoned.**
Rater 1 cites a commit: `0dd0efe`, rule 14 — a synonym is right when the word names what the
thing *is* and wrong when it names something the thing is merely near. Rater 2 cites the map:
`slideRoom` north is host-wired to the Mine Entrance, so the room has a real north exit to
answer for. Neither piece of evidence appears in the other's write-up.

**The `pull mat` finding — both `refuted`. Convergent.** Both land on the same argument in
nearly the same closing sentence: this is the game-wide stub floor, and filing it against
`DungeonPalantir.swift` misroutes the fixer. They are not identical — rater 2 opens with a
genuine steelman ("a refusal that asserts immobility one turn before TAKE succeeds is not merely
terse — it is wrong") that rater 1 never offers, and rater 1 supplies corroborating evidence
rater 2 lacks (the line fires on objects already in the player's hands). Two people reaching a
forced conclusion, but it is the weakest of the three.

**Verdict: the raters reasoned separately.** 88.5% is the agreement of two people who mostly got
the same right answer, not of two stamps — and the three they split on all went to a human.

### The three disagreements, and how each split

| Finding | Rater 1 | Rater 2 | Resolved |
|---|---|---|---|
| the burned-out lantern examines as its own listing line | `confirmed-defect` | `refuted` — the prose file says the two channels share a line on purpose, "trilogy verbatim", and Zork1 carries the identical pair; "here" is room-granular and the player is in the room | `needs-human` |
| the thief's death leaves a body the world does not hold | `refuted` — nothing printed is false at the instant it prints, and removing a defeated villain is what this engine and both Zork games do | `confirmed-defect` — Zork I disposes of the carcass in prose with its black-fog line; Dungeon's adapted line dropped the disposal, and the contract makes an unanswerable printed noun non-negotiable | `needs-human` |
| the grue death line asserts a walk | `refuted` — this is the trilogy line unchanged (`Sources/Zork1/Prose.swift:20`), so source policy 1 governs it, not the adaptation rule the finding cites | `needs-human` — the false clause is real, but the repair is a design trade between an engine plugin API change, a per-room override the plugin does not take, and rewording the chute | `needs-human` |

## Coverage

This section is the completeness critic's, recounted off the artifacts. Three of the published
counts overstate what happened, and the transcripts win.

### Rooms — 27 entered, 22 published as worked, 17 honestly read

`total` 195, of which `ruleEntered` 22. `visited` 27, `neverVisited` 168 — 27 + 168 = 195, and
`offRoster` is empty, so the artifacts and the roster describe the same build. `worked` 22,
`neverWorked` 173. `sessionsFinished` 8, `sessionsUnfinished` 0: every session wrote a
`closing.json`, so no figure here is a floor for that reason.

**The `worked` counter credits the room a turn *resolved* in, not the room it was typed in.** A
death teleport therefore credits the destination, and the proof is the Forest:

- `DungeonAboveGround.forestDeep` is credited `worked` by solver, timekeeper-2 and timekeeper-3.
  **timekeeper-2 typed zero commands in the Forest.**
  `Dungeon-2026-08-29-r1-session-timekeeper-2/probe-001/branch-001.txt:106` and
  `branch-003.txt:78` both end at the `[status] room=Forest` line with no command after it; the
  command that earned the credit was `x torch`, typed in the flooded Maintenance Room on the turn
  that drowned them. timekeeper-3's is the same shape —
  `Dungeon-2026-08-29-r1-session-timekeeper-3/probe-001/branch-001.txt:98-109`, `z` typed in the
  Treasure Room, the thief kills them, the footer says Forest. solver's Forest credit is twelve
  `wait`s.
- **Nobody typed a content command in the Forest all round, and it is credited to three
  charters.**
- Pure-transit rooms are credited too: `Palantir.slideOne` and `slideTwo` (explorer-1, four
  commands, all travel), `Mirror.narrowCrawlway` (explorer-2, three, all travel),
  `CoalMine.shaftRoom` and `Mirror.slideRoom` for solver (two each, both travel).

**Honest count: 17 rooms of 195, 8.7%, had a charter read their prose.** Three more —
`slideOne`, `cyclopsRoom`, `forestDeep` — got clock-probe waits only. Seven were transit.

### The grid — charter × room

`X` the charter typed content commands there · `w` only let time pass, no prose read · `.`
transit or restore-landing only · `–` never reached.

| Room (id) | E1 | E2 | E3 | T1 | T2 | T3 | SO | WF |
|---|---|---|---|---|---|---|---|---|
| West of House (`AboveGround.westOfHouse`) | . | . | . | . | . | . | . | . |
| Forest (`AboveGround.forestDeep`) | – | – | – | . | – | w | w | – |
| Tiny Room (`Palantir.tinyRoom`) | **X** | – | – | – | – | – | **X** | – |
| Dreary Room (`Palantir.drearyRoom`) | **X** | – | – | – | – | – | – | – |
| Slide Room (`Mirror.slideRoom`) | **X** | – | – | **X** | – | – | . | – |
| Slide (`Palantir.slideOne`) | . | – | – | w | – | – | . | – |
| Slide (`Palantir.slideTwo`) | . | – | – | . | – | – | . | – |
| Slide (`Palantir.slideThree`) | – | – | – | . | – | – | – | – |
| Cellar (`House.cellar`) | **X** | – | – | **X** | – | – | . | – |
| Shaft Room (`CoalMine.shaftRoom`) | **X** | – | – | **X** | – | – | . | – |
| Machine Room (`CoalMine.machineRoom`) | **X** | – | – | **X** | – | – | **X** | – |
| Wooden Tunnel (`CoalMine.woodenTunnel`) | – | – | – | – | – | – | . | – |
| Smelly Room (`CoalMine.smellyRoom`) | – | – | – | – | – | – | . | – |
| Reservoir (`Dam.reservoir`) | – | **X** | – | – | – | – | – | **X** |
| Maintenance Room (`Dam.maintenanceRoom`) | – | – | – | – | **X** | – | **X** | **X** |
| Dam Lobby (`Dam.damLobby`) | – | – | – | – | **X** | – | – | – |
| Mirror Room (`Mirror.mirrorRoomNorth`) | – | **X** | – | – | – | – | – | – |
| Mirror Room (`Mirror.mirrorRoomSouth`) | – | **X** | – | – | – | – | – | – |
| Narrow Crawlway (`Mirror.narrowCrawlway`) | – | . | – | – | – | – | – | – |
| Grail Room (`Temple.grailRoom`) | – | **X** | – | – | – | – | – | – |
| Maze (`Maze.maze5`) | – | – | **X** | – | – | – | – | – |
| Maze (`Maze.maze6`) | – | – | **X** | – | – | – | – | – |
| Maze (`Maze.maze7`) | – | – | **X** | – | – | – | – | – |
| Maze (`Maze.maze14`) | – | – | . | – | – | – | – | – |
| Treasure Room (`Maze.treasureRoom`) | – | – | **X** | – | – | **X** | w | **X** |
| Cyclops Room (`Maze.cyclopsRoom`) | – | – | – | – | – | w | – | – |
| Small Square Room (`RoyalPuzzle.anteroom`) | – | – | **X** | – | – | – | – | – |

**168 of the 195 declared rooms have no row here at all.** Whole regions untouched: the Bank of
Zork (7), the Endgame (18), the volcano (11), the river (17), the Round Room quarter (8), the
Alice carousel (10), the coal mine proper (16 of 18). Twelve above-ground rooms — the first thing
any real player sees — were entered by nobody.

The maze rooms are the one place the grid cannot resolve. `maze5/6/7/14` all print the display
name "Maze", so explorer-3's 41 commands there cannot be split between them; the same holds for
the three `Slide` rooms and the two `Mirror Room`s. CLAUDE.md warns about exactly this, and it
bit the grid rather than the counter.

### Slot × charter

All nine slots were opened. Two were opened once.

| Slot | E1 | E2 | E3 | T1 | T2 | T3 | SO | WF |
|---|---|---|---|---|---|---|---|---|
| `p-1` | X | – | – | – | – | – | X | – |
| `p-2` | X | – | – | X | – | – | X | – |
| `c-1` | X | – | – | X | – | – | X | – |
| `c-2` | X | – | – | X | – | – | X | – |
| `m-1` | – | X | – | – | – | – | – | X |
| `m-2` | – | X | – | – | – | – | – | – |
| `d-1` | – | – | – | – | X | – | – | X |
| `z-1` | – | – | X | – | – | – | – | – |
| `z-2` | – | – | X | – | X | X | X | X |

### Turns — and the 758 the round could not name

| bucket | turns | probes |
|---|---:|---:|
| tester sessions | 342 | 8 |
| branches a `rewind` wrote out of a transcript | 89 | — |
| `.replays/` — the testers' | 143 | 61 |
| `bin/playtest-replay` under a play label | 805 | 1 |
| **testers, total** | **1,379** | |
| verifiers | 289 | 56 |
| the round's own errands (`harnessReplays`) | 0 | 2 |
| **attributed total** | **1,668** | |
| unattributed | 758 | |
| **`all`** | **2,426** | |

**The 758 unattributed turns are this round's own slot machinery.**
`.context/playtest/Dungeon-r1-slots/probe-001/transcript.txt` holds **704** `turn=cost` lines and
the eighteen probes under `Dungeon-r1-slots-check/` hold **54**. 704 + 54 = 758, exactly. That is
`bin/playtest-slots` cutting the nine saves and then restoring each one to read its landing. The
`harnessReplays` row reported 0 because it only sees labels the workflow itself wrote, and the
slots tool writes its own — which is deliberately not round-scoped, because slots outlive the
round that cuts them, so no round glob can reach it.

**This is a harness accounting gap the round exposed, and `fb40d30` closes it.**
`.claude/workflows/playtest.js` now carries a `slotsReplays` row and a `SLOTS_GLOB` built from
the `slots` argument, counted and named beside the four trees and deliberately **not** folded
into `total` — the slots label carries no `roundId`, because slots outlive the round that cuts
them, so summing them would charge a second round in this checkout for the first one's cutting.
They are subtracted from the residual instead. Run against this round's own numbers, that takes
`unattributed` from 758 to **0**. The dry run exempts the one round-agnostic glob from its
roundId rule and then checks the promise that exemption rests on: a second assertion fails if
`slots` is ever added to `total`.

**A second harness defect surfaced while writing this up, and `ledgerKeysFrom` is fixed in the
same branch.** The 55 keys above were not merely truncated — they were the wrong rows. The
verdict was read from a fixed column index, and five ledgers across this repo put it in three
different places, so on Dungeon the parser was reading the *category* column, matched `refuted`
nowhere, and fell back to a heuristic that admitted one whole table of abbreviated keys. It now
locates the verdict column from each table's own header, honours the older
`| Key | Charter | Refutation kind |` shape where the table itself is the verdict, and drops
abbreviated keys as inert. Dungeon's real dedupe set is **44 keys**, Fulminate's is 18.
Gramarye, The Kindly Deep and Lighthouse come back **0**: their ledgers have only ever stored
abbreviated keys, so those three games have never had a working dedupe set and this round is the
first thing to say so.

**The tester/verifier split is 1,379 : 289, about 4.8:1** — the right way round. But 805 of the
tester figure is solver's single full-walkthrough replay, which is a route file being typed
rather than composed play. **Composed tester play is about 574 against a 480 budget.** Every
charter overran its 60 turns and said so in its own `finish` note — explorer-1 ~115, explorer-3
~69, timekeeper-1 ~90, wrong-footer ~85, solver ~870 — and every charter still stood in three to
five rooms. The overrun is almost entirely reproducer verification, which is the right thing to
spend it on and is still not coverage.

### Timers — 13 of 34 fired, and 6 of the 13 are noise

`endgame.blessing`, `endgame.master`, `forestSongbird`, `grue`, `melee.troll` and `thief.fights`
all report exactly **415**: identical counts, because they are per-turn daemons whose bodies ran
on every turn of the round and mostly did nothing. Timers that produced a readable event:
`thief.roams` / `thief.steals` / `thief.stashes` 101 each, **`damLeak` 41**, **`thief.opensEgg`
7**, **`slideGrip` 6**, `matchBurnsOut` 1. **Seven timers with observable behaviour, one of which
fired once.**

Never fired in any session: `balloonDrifts`, `bellCools`, `brickBlast`, `brochureArrives`,
`burnerBurnsOut`, `cageGas`, `candlesBurn`, `dustyRoomFalls`, `endgame.crypt`, `endgame.herald`,
`endgame.mirror`, `endgame.pine`, `endgame.quiz`, `endgame.swordGlow`, `exorcismLapse`,
`gnomeArrives`, `gnomeLeaves`, `lanternDies`, `lanternDim`, `lanternLastGasp`, `wideLedgeFalls`.
`offRoster` is empty.

**The lantern clock has never fired.** That is the spine clock of Zork — dim at 200, last gasp at
300, dead at 350 (`Sources/Dungeon/Regions/House.swift:169-178`) — and no session in this round
burned a lamp long enough to see any of the three lines.

### Forks nobody took — six recorded, and at least one is false

`object:bag:open`, `object:egg:eat`, `object:egg:open`, `object:paper:burn`, `object:water:drink`,
`object:window:eat`.

**`object:egg:open` is wrong.** explorer-3's `closing.json` records it `"taken": false`, while
`Dungeon-2026-08-29-r1-session-explorer-3/probe-001/branch-001.txt:2` shows `> open egg` →
"The egg is now open, but the clumsiness of your attempt has seriously compromised its esthetic
appeal." explorer-3 says so themselves in their own note — the open was a policy breach they
rewound. **The fork tracker reads the canonical transcript only and does not see rewound
branches, even though the turn counter deliberately does.** Same tree, two policies. Of the other
five, `object:water:drink` is the best next-round target.

### Which charters found nothing, and why — three different silences

**Ran properly, found real defects.** explorer-1 (8 filed, 2 survived), explorer-2, explorer-3,
timekeeper-1, timekeeper-2, timekeeper-3. Each worked its assigned slots to a real depth and each
wrote down what it skipped. timekeeper-2's dam-leak work is the strongest single seat in the
round: four passes through the flood daemon — on-cell through all nine rungs to the drowning,
off-cell across the whole climb, a mid-climb re-entry, and the plugged branch — establishing that
the rung line prints in the Maintenance Room and nowhere else at any rung, that the
`alwaysDescribed` water paragraph tracks the rung on both branches and survives a re-entry, that
`x water` and `x leak` both branch on the plug, and that the drowning carries its own room test.
Both of its filed defects are cross-products of the flood with something the flood did not reach.

**Ran, found nothing in the game, and that is a real result.** `solver`. It filed exactly one
defect and it is in the harness, not the game. Its four questions all answered yes, and the
load-bearing one answered by play: **a live 822-command replay at seed 52 ended "You are Master
of the Dungeon." and "Your score is 716 of a possible 716, in 805 turns."**, with no
`*** You have died ***` anywhere in 6,149 lines and no unanswered noun — grep for "can't see any
such thing", "don't know the word" and "I don't understand" over the whole winning transcript
returns nothing. Eighteen score checkpoints all read "of a possible 716". Three gates held under
minus-one-step, three losses fired and each named what the player did, and the
`score + 10*deaths >= 616` hole is closed because each of the first two deaths subtracts exactly
ten. **That silence is evidence: the game is winnable at this commit.**

**Ran, found nothing, and it is because the charter never met its target. Do not count this
silence.** `wrong-footer`. Its whole STEP 1 — the generated article sweep, looking for a definite
article printed in front of a proper name — **was run against the thief, who is not
`properName`**. The cast's only `properName` actor is the Volcano Gnome, who is in none of the
nine slots and 200+ moves from the nearest. **That is an operator error in the focus file's
`wrong-footer` row, not a tester failure**: the sighted text sent the sweep at "this game's only
reachable actor" without asking whether he was the kind of actor the sweep tests. The tester
says so plainly and labels the rows UNCLOSED rather than passed. Its other passes ran in three
rooms; eleven of forty-seven stub verbs were typed; its one filed finding was refuted. This
charter produced no evidence about the game, and its own report is honest about that.

**Not run at all.** `interrogator` — no seat, no turns, no findings. The interrogator is the
charter that types the nouns a room description printed, which is precisely the class of defect
the critic found in the Forest in eight turns. Its absence is not a neutral gap; it is the direct
cause of at least one missed defect.

Published as one number these would be indistinguishable, and the round would read as eight seats
finding twelve defects instead of six seats finding twelve, one seat proving the game finishable,
one seat missing its target, and one seat that did not exist.

### Unknown words — 4 occurrences over 3 tokens

`,` ×2 (harness punctuation), `frotz` ×1 (the reserved control), `hurry` ×1. The `hurry` probe is
wrong-footer typing a word out of the wreckage line rather than a noun the room printed as an
object; the sentence that word came from is finding 11 above. No noun any charter saw printed was
refused — in the three rooms wrong-footer stood in.

### What the critic found in the gap

The critic spent eight turns walking west from the boot frame, a move no charter made, and found
a defect the round missed.
`.context/playtest/Dungeon-2026-08-29-critic/probe-001/transcript.txt`, moves=1-2:

```
> w
Forest

This is a forest, with trees standing close on every side. The light that reaches the ground is
green and dim, and one direction looks very much like another.

> x light
You can't see any such thing.

> x ground
You can't see any such thing.
```

Two nouns the room's own description prints, both unanswerable. `x direction` answers "I don't
know the word 'direction'", which is weaker and arguably not a physical object. This room is
`westOfHouse.west(forestDeep)`, **one move from the boot frame**
(`Sources/Dungeon/Regions/AboveGround.swift:693`), and it is where every death in the game
deposits the player (`Sources/Dungeon/Dungeon.swift:336,585`). Four charters were teleported into
it this round and none looked at anything. The critic swept North of House, Behind House and
South of House as well (`probe-002`, `probe-003`) and found nothing further — `path`, `windows`,
`trees`, `window`, `clearing` and `house` all answer. The Forest is the outlier, not the region.

### Findings dropped

**None dropped by the verifier.** All 26 findings reached a verdict, and every confirmed
reproducer carries `replayedCleanly: true`.

Two findings were **withheld by their own testers as unverifiable inside the budget**, and both
are carried into the next round's dedupe set by claim text rather than key, and neither is
counted as covered:

1. explorer-2 — the Grail Room prints "a small round chamber… A flight of stairs rises from one
   side" and both `x chamber` and `x flight` answer "You can't see any such thing." Seen in
   `Dungeon-2026-08-29-r1-session-explorer-2/probe-001` at moves=149; the trimmed replay took the
   wrong route (north from an untouched `m-2` is Steep Crawlway, not Narrow Crawlway, because the
   mirror transport had not fired) and never reached the room. The correct reproducer is
   `restore` / `m-2` / `touch mirror` / `north` / `north` / `x chamber` / `x flight`.
2. timekeeper-3 — "You suddenly notice that the golden clockwork canary vanished." printed at
   moves=51 in the Treasure Room while the thief who took it was standing in plain sight in a lit
   room. `ActorBehaviors.steals` suppresses the announcement when the room is dark, so the one
   frame the line prints in is the frame where "you suddenly notice … vanished" is least true.
   Could not be trimmed to a reproducer inside the budget: it needs the stash daemon to have
   unloaded, and the roam daemon keeps carrying him off first.

Beyond those, the round left large coverage queues open at `finish` — explorer-1 234 items at a
0.19 discharge rate, explorer-3 125 of 130, explorer-2 72 of 89, timekeeper-2 57. explorer-1's
noun-follow rate was 0.00 across 45 nouns its own examines printed.

## What the next round should take

The critic's ranked list, recorded here rather than filed, because a coverage plan is a plan and
not a defect.

1. **The Forest, `x light` and `x ground`** — confirmed unanswerable nouns printed by the room's
   own description, reproduced at
   `.context/playtest/Dungeon-2026-08-29-critic/probe-001/transcript.txt` moves=1-2. File it,
   then sweep the other four forest rooms and the twelve-room above-ground block, **which needs
   no slot at all**: it is walkable from turn 0 and was entered by nobody this round.
2. **`brochureArrives` × Kitchen** — never fired in any session, and the cheapest never-fired
   timer in the game: order the brochure, enter the Kitchen, wait three turns
   (`Regions/AboveGround.swift:673, 941`). Reachable from a cold start in under fifteen turns
   with no slot. Read `Prose.brochureKnock` in the Cellar too, where the source comment says the
   joke deliberately follows you underground.
3. **The lantern clock** — `lanternDim` (200), `lanternLastGasp` (300), `lanternDies` (350),
   `Regions/House.swift:169-178`. Zork's spine clock, never fired in any session of any round.
   Needs one scripted probe of ~360 waits in a lit underground room, not a live seat. Three lines
   nobody has ever read.
4. **Gas Room × a carried flame, from `c-1`** — named explicitly on timekeeper-1's charter and on
   explorer-1's abstain fork, and reached by neither; both wrote it up as their single largest
   miss. Also the far end of the hoist, **Lower Shaft**, where the arrival prose and the
   LIGHT-SHAFT award are unread by both charters who worked the hoist from the near end.
5. **Volcano Gnome × `greet` / `follow` / `gnome, hello`** — the cast's only `properName` actor
   and the actual target of the wrong-footer article sweep, which ran against the thief instead
   and closed nothing. In no slot and 200+ moves out, so **this needs a new slot cut before the
   round dispatches.** `gnomeArrives` / `gnomeLeaves` (`Volcano.swift:778-788`) are both on the
   never-fired list and would fall out of the same seat.
6. **`drink water` in the flooded Maintenance Room at the over-your-head rung, from `d-1`** — the
   one fork row the critic fully believes. timekeeper-2 named the deep-plug cell as deliberately
   unprobed and declined to infer about it: open tube, squeeze tube, push blue, seven waits, plug.
   It would leave the player breathing indefinitely in water that drowns them one rung later.
7. **Slide Room north (`small opening`) and east (`long passage`) from `p-2`** — explorer-1
   committed to the one-way drop and never opened either exit, so R1's east and north halves are
   exactly as unread as before the round. The north exit is also the subject of a confirmed
   finding here, so the fix and the coverage close together.
8. **Timer × room cross-product for the three collapsed display names** — `maze5/6/7/14`,
   `slideOne/Two/Three`, `mirrorRoomNorth/South`. The grid could not resolve which of
   explorer-3's 41 maze commands landed where, because all four rooms print "Maze". Either the
   session record logs the room id alongside the footer name, or the next round's maze seat
   checkpoints per cell.

## Hygiene

- Seed **52**, read from `DungeonWalkthroughTests.seed`. `roundId` `2026-08-29`, `packagePath .`,
  `turns` 60. `verifyEffort` not set, so the workflow's inherited default applied.
- Budget: 480 turns planned across 8 seats. Testers spent 1,379 counted off the footers, of which
  805 is one full-route replay; composed play is ~574. Verifiers spent 289. `bin/playtest-slots`
  spent a further 758 outside all of it.
- Charters not run: **`interrogator` — no seat.** It has now never run in five rounds.
- Sessions unfinished: **0.** All eight wrote a `closing.json`.
- The round changed no code. No test file touched, no assertion removed, no needle weakened.
- Preflight resolved the MCP tools on the first `ToolSearch` attempt, opened
  `Dungeon-2026-08-29-preflight/probe-001` at seed 52 and finished it without taking a turn;
  `finish` returned `roomsVisited: [DungeonAboveGround.westOfHouse]`, so the server was live at
  the current commit and not frozen at an older one.
- **Three operator errors, all checkable before dispatch and none checked.** The `ledgerKeys`
  argument carried 39 `fixed` and 3 `confirmed` keys, and the 31 working `refuted` keys were left
  out of it, which is inverted from the rule; the whole set was inert because every string in it was
  display-truncated, so nothing was suppressed and nothing was swallowed. Next round's args must
  be built from the `decl::` rows, filtered on `verdict == refuted`, not pasted out of the
  ledger's reading column.
- **Two further errors in the focus file, both the operator's.** The `wrong-footer` row sent the
  generated article sweep at an actor with no `properName`, which cost the round that seat's
  whole first step; and two blind region headers asserted that `slideGrip` and `damLeak` had
  never fired in any artifact of any round, when both fired in the 2026-08-24 round. Neither
  invalidates a finding; both are checkable before dispatch and neither was checked.
- **One harness accounting gap, exposed by this round and fixed on this branch.** The 758
  unattributed turns are `bin/playtest-slots`' own probes, under a label the workflow's glob
  cannot see. `playtest.js` now counts them in a named `slotsReplays` row.

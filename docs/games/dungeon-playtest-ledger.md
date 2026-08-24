# Dungeon — playtest ledger

Append-only. One row per dedupe key the harness has ever seen, with what became of it.

This is the loop's memory, and it exists for two reasons. Without it, a round rediscovers
everything a previous round already rejected, forever — the harness argues with itself
instead of converging. And with it, a key marked `fixed` that shows up again is not a new
finding, it is a **regression**, and it goes back at raised severity.

Pass `ledgerKeys` into the workflow with every key below whose verdict is `refuted`.

**Not the `fixed` ones, and the instruction to pass them was wrong.** `ledgerKeys` feeds
`seen`, and a finding whose key matches is **dropped** — merged away unverified and
unreported. So passing a `fixed` key instructs the harness to swallow in silence exactly
the thing the paragraph above says is the point of this file: a `fixed` row that comes
back is a regression at raised severity, and it cannot come back if the round is told to
throw it away. Withhold them, and say in the round report that you did.

The key is `<ownerFile>::<normalized offending text>`, with the frame deliberately
excluded — one untrue sentence seen in two frames is one defect, so keying on the frame
would dispatch two fixers at one branch. Keys are abbreviated here for reading; the full
ones are in the round reports.

**Correction, 2026-08-18: the full ones are not in the round reports.**
`docs/games/dungeon-playtest-2026-08-11.md` contains no key table — the string `::` does
not occur in it — so no full key from that round survives anywhere in this repo. Every
row below is display-truncated with `…`, and `normalize()` strips every character that is
not `[a-z0-9 ]` and can therefore never emit one. **None of the 2026-08-11 keys can match
anything a later round produces**, whatever its verdict. They are a reading record, not a
working dedup set. (Their one remaining use: up to 60 are pasted into the *sighted*
charters' prompts under "do not report these again", which is deterrence and works on
prose rather than on string equality.) Record full, untruncated keys from now on — the
shape the clusterer actually compares is `decl::<file>::<declaration>`, with the excerpt
form only as an `unlocated` fallback.

## 2026-08-11 — first round, `0080053` (`fix: none`, nothing applied)

Ran at **seed 2**, not the harness default 0. Seed 2 was then the seed
`DungeonWalkthroughTests` pinned its 716-point route to, and the route is the only way a
tester reaches the volcano, the Royal Puzzle or the Endgame inside a round's budget — the
far side of this game is two hundred correct commands from the front door. A prefix
replayed at another seed lands somewhere else, quietly.

> **The seed is 52 now, and has been since the day after this round.** `97b5032`
> (*"Villains block rather than swing (#237) (#238)"*, 2026-08-12) gave the troll and the
> thief a strike-first probability, which moved every draw in the game;
> `DungeonWalkthroughTests.seed` was re-pinned by brute-force scan and 52 is the only
> seed below 400 the route still wins on. **A later round pins 52**, not 2 — the
> sentence this note replaces would have sent one to a seed where its own route prefixes
> land somewhere else and the `solver` charter, whose brief takes its route from this
> very test, fails outright. Read the constant, never a number written down here.

Oracle tiers T0/T1/T2/T3 — all four, unlike KindlyDeep's first round: `docs/games/dungeon.md`
exists and carries the mechanics contract, which is what let the verifiers refute on "the
doc licenses this" rather than on "you cannot tell intent from outside".

**A `confirmed` row below is an open defect in the game as it ships, filed as #233; a
`fixed` row is one that has since been repaired, and by what is dated in
[Amendments](#amendments).** Nothing was fixed *in the round itself*; #190 required
`fix: "none"`, because the failure mode is a plausible wrong fix in a suite where
`DungeonTests.swift` alone is 3,974 lines of substring assertions lifted from the prose.
The issue carries fifteen boxes: the fourteen classes these rows deduplicate to, plus one
harness box that came from the completeness critic rather than from a charter and so has
no key here.

A `fixed` row that comes back in a later round is a **regression**, and goes back at
raised severity.

Every row is `preexisting` — the verifiers dated all 42 confirmed findings against `git
log -S` and not one arrived with a recent fix. No row here can be a regression, and the
next round's first job is to check that none of them has become one.

Three things deserve a flag.

**The `major` bulk is two mechanisms, not thirteen defects.** A static trait asserting a
fact that has a state behind it (the kitchen window, the Round Room's whirring in three
places, the pine wall, the Library's books, the slide rope, the Narrow Ledge) and a fuse
body that says its line without asking where the player is standing (the lantern's three
rungs, the struck match). Both repairs already exist in this codebase —
`Prose.roundRoomStilled` for the first, `DungeonTemple.burnCandleStage()` for the second.
Do not file the individual sites again as separate classes.

**Five of the thirteen `refuted` rows are one charter reading one region wrong.** The
vandal charter took the Dam region's flood as a prose defect; the room paragraphs there
are trilogy-verbatim and assert nothing the water contradicts, and "describes itself dry"
was inference from omission. That region is not clean by proof, it is clean by argument —
a later round is free to re-examine it, but it needs a line that is *false*, not a line
that is silent.

**The unanswerable-noun rows are duplicated across two charters by design.** Tourist and
idiot both found `field` and `path`; the keys differ because the excerpts differ, so both
survive here. They are one class in #233 and should be fixed as one.

| Key (abbreviated) | Verdict | Category |
|---|---|---|
| `Sources/Dungeon/Regions/Prose+House.swift::open window opened  west kitchen y…` | fixed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Prose+Mirror.swift::look round room this is a circula…` | fixed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/AboveGround.swift::up up a tree you are about 10 feet…` | fixed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/Prose+AboveGround.swift::down rocky ledge you are on …` | fixed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/AboveGround.swift::east behind house you are behind t…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::you are behind the white house a p…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/House.swift::x passage you cant see any such thing  w…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/House.swift::cellar you are in a dark and damp cellar…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/RoundRoom.swift::round room this is a circular stone …` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::west of house you are standing in …` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/Prose+AboveGround.swift::founded in antiquity by will…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::east clearing you are in a clearin…` | fixed | mechanic-contradicts-prose |
| `Sources/Dungeon/Dungeon.swift::north you set off confidently and the room tur…` | fixed | doc-drift |
| `Sources/Dungeon/Regions/House.swift::drop lamp dropped  east it is pitch blac…` | fixed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/Dam.swift::light match one of the matches starts to b…` | fixed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/CoalMine.swift::west smelly room this is a small nond…` | fixed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/CoalMine.swift::down gas room this is a small room wh…` | fixed | prose-untrue-of-frame |
| `Sources/Dungeon/Dungeon+Palantir.swift::take timber taken  i you are carrying…` | fixed | mechanic-contradicts-prose |
| `Sources/Dungeon/Systems.swift::dam  the sluice gates on the dam are closed be…` | fixed | mechanic-contradicts-prose |
| `Sources/Dungeon/Systems.swift::swim swimming would be a brief and unrewarding…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Prose.swift::greet troll the troll nods and says nothing the …` | fixed | stock-line-not-reskinned |
| `Sources/Dungeon/Regions/Dam.swift::stream view  a coil of thin shiny wire lie…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Prose+Systems.swift::swim swimming would be a brief and unrew…` | confirmed | register-mismatch |
| `Sources/Dungeon/Regions/Prose+Volcano.swift::look volcano near wide ledge in …` | fixed | exit-prose-mismatch |
| `Sources/Dungeon/Regions/Volcano.swift::wide ledge you are on a wide ledge hig…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/RoyalPuzzle.swift::this is a small square room and in…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/Volcano.swift::x rim a shelf of old rock wide enough …` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/RoyalPuzzle.swift::mm ss west mm   east  ss   x openi…` | fixed | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/Volcano.swift::give coin to gnome thank you very much…` | fixed | exit-prose-mismatch |
| `Sources/Dungeon/Regions/Prose+Volcano.swift::this must have been a large libr…` | fixed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Prose+House.swift::open window opened  x window the w…` | fixed | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/Prose+Bank.swift::vault this is the vault of the bank…` | fixed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/Bank.swift::this is a large rectangular room the east…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/Prose+Maze.swift::i you are carrying a jewelencrusted…` | fixed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/AboveGround.swift::behind house you are behind the wh…` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::you are standing in an open field …` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::north of house you are facing the …` | fixed | unanswerable-noun |
| `Sources/Dungeon/Regions/House.swift::open window opened  enter window you can…` | fixed | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/Endgame+MirrorBox.swift::push pine the pine wall swin…` | fixed | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/Prose+EndgameMechanics.swift::push pine the pine wall…` | fixed | prose-untrue-of-state |
| `Sources/Dungeon/Dungeon+Endgame.swift::drop sword dropped the blue light goes…` | fixed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Endgame+Master.swift::knock on door beside the temple…` | fixed | repeat-behavior |
| `Sources/Dungeon/Regions/RoundRoom.swift::east round room there is a dented st…` | refuted | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/AboveGround.swift::up a tree you are about 10 feet ab…` | refuted | prose-taste |
| `Sources/Dungeon/Regions/Dam.swift::look dam lobby this room appears to have b…` | refuted | exit-prose-mismatch |
| `Sources/Dungeon/Regions/Dam.swift::x doorways two doorways marked private sta…` | refuted | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Dam.swift::squeeze tube the viscous material oozes in…` | refuted | prose-untrue-of-state |
| `Sources/Dungeon/Prose.swift::take troll the troll would take exception to tha…` | refuted | stock-line-not-reskinned |
| `Sources/Gnusto/Actions/DefaultActions.swift::x troll you cant see any such th…` | refuted | contract-violation |
| `Sources/Dungeon/Regions/Dam.swift::there is a control panel here on which a l…` | refuted | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Prose+RoundRoom.swift::listen the acoustics of the ro…` | refuted | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/River.swift::there is a folded pile of plastic here w…` | refuted | prose-taste |
| `Sources/Dungeon/Regions/Bank.swift::most of the furniture has gone the way of…` | refuted | prose-untrue-of-frame |
| `Sources/Dungeon/Dungeon.swift::attack troll with sword the troll takes a fata…` | refuted | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Prose+Endgame.swift::north south corridor  the dungeo…` | refuted | prose-taste |

Counts: 3 confirmed, 13 refuted, 0 routed, 39 fixed, 0 dropped. 55 verifications
over 57 probes; every finding was replayed from a clean start by its own tester and again
by an adversarial verifier from a different charter. The round itself closed at 42
confirmed and 0 fixed; the thirty-nine that have moved since are dated in
[Amendments](#amendments).

## Amendments

**2026-08-11 — twelve rows marked `fixed` by #235 (`37cb782`).** Boxes 1, 3, 4 and 14 of
the issue: the four fuse bodies, the static examine texts with a state behind them, three
of the five examines that answered about the wrong place, and the stale carousel-seam
comments. Cover is `DungeonProseTests.swift` (nine tests, each negative assertion paired
with a positive control) plus additions to `DungeonTests` and `DungeonEndgameTests`.

**2026-08-11 — ten more rows marked `fixed` by the second pass.** Boxes 5, 6, 7, 8, 9 and
13, plus the Gas Room half of box 4.

| Class | Row | What was done |
|---|---|---|
| `repeat-behavior` | `Endgame+Master.swift::knock on door…` | The re-knock path clears `quizWaitedATurn`, so the daemon no longer puts the question a second time in the breath it was first put in. The right-answer path already did this and said why. |
| `prose-untrue-of-state` | `Dungeon+Endgame.swift::drop sword…` | The sword-glow daemon gates on `isVisible` rather than `isHeld`, so a turn that only changes your grip reports nothing, and a blade left behind goes quiet rather than announcing that its light went out. `x sword` gained the glow it never mentioned. |
| `exit-prose-mismatch` | `Prose+Volcano.swift::look volcano near wide ledge…` | `VAIR4`'s paragraph says east, where its own exit table has always put the ledge. The contradiction is the original's; the table wins, per the mechanics contract. |
| `stock-line-not-reskinned` | `Prose.swift::greet troll…` | The troll, the cyclops, the thief and the robot answer a greeting for themselves, in two states each where the source has two. Not a re-voiced `text.greets`: one line for four creatures is the same defect one register up. |
| `mechanic-contradicts-prose` | `Systems.swift::dam…` | The game-wide `drink`/`pour`/`fill` refusals became claims about the object named rather than about the room, and the water in each `.waterSource` room answers `drink` for itself. In the `action(…)` bodies and not a `world.before`, which would have pre-empted `bottle.before(.fill)`. |
| `prose-untrue-of-frame` | `CoalMine.swift::west smelly room…`, `::down gas room…` | Two `location.before(.smell)` rules at stage 2 for the two rooms named for what they smell of. `Prose.verbSmell`, which was the engine stub character for character and so re-voiced nothing, was re-voiced. The Gas Room's `x stairs` got a staircase item at each end, and `coalGas`/`foulOdor` lost the synonyms they had no business owning. |
| `mechanic-contradicts-prose` | `RoyalPuzzle.swift::…x openi…` | The ceiling opening `describe`s on the player's square, so "a long way above your head" is read only from the square it is over. The grid, the climb condition and the solution are untouched. |
| `mechanic-contradicts-prose` | `AboveGround.swift::east clearing…` | The Clearing's leaves: the listing sentence moved to `firstSight`, where the room prints it, and `x leaves` got an examine text of its own. `scenery` kept, so the pile is still unliftable. |
| `prose-untrue-of-state` | `Prose+Maze.swift::i you are carrying…` | The rusty knife stopped calling itself older than anything else you carry. A branch on the sword would have left it false while carrying the coffin, the trident or the egg. |

**Three rows in those boxes stand `confirmed` on purpose.**

- The two `swim` rows (`Systems.swift`, `Prose+Systems.swift`). Box 5's `.dive` half *was*
  repaired — it had no `action` row at all and answered on the engine's stub, a claim
  about the room — but the line these two keys name is `noSwimming`, and that line is
  unchanged. Flipping them would be claiming credit for a repair to a different sentence.
- `Volcano.swift::wide ledge you are on a wide ledge hig…`. Adjacent to the `VAIR4`
  bearing above and not the same finding; `wideLedge.describe` already branched before
  either pass, and nothing here tells which frame the tester meant.
- `Prose+House.swift::open window opened  west kitchen y…` — the *Kitchen's* "slightly
  ajar", not the window's examine text. #235 declined it with an argument rather than
  repairing it: the room paragraph is trilogy-verbatim and asserts nothing about entry.
  An argument is not a repair, so the row stands and a later round is free to test it.

**2026-08-24 — ten rows of the 2026-08-18 round marked `fixed` by #286's Class 3.** D3
and D5 together: `frigidRiverHere`, `whiteCliffsFromBelow`, `aragainFallsItself`,
`rainbowItself` and `distantView` were catch-alls answering under nouns that belonged to
the room's own exits and ground; `etchingsAbove` and `machineRoomWithButtons` were the
same defect underground; `beachDigs` and `cageGas` printed nouns nothing modelled at all.
`roundRoomCompass` is the one that could not be repaired with an item — the line named a
compass and a needle this game does not have anywhere, so the sentence went instead, and
the declaration is now `roundRoomTurning`. The key stays as the round recorded it.

**The Viewing Room's sign stands `confirmed` on purpose.** It is `needs-human` and the
open question is whether the rule reaches nouns a notice says are *absent*; declaring
items for "the bank officer" and "all customers" would be inventing world, which is not a
decision to take unsupervised.

**2026-08-12 — the remaining fourteen `unanswerable-noun` rows marked `fixed` by the
third pass.** Box 10 entire, and what was left of box 4: the volcano's catch-all synonym
lists. The two are one piece of work and this is the reason, stated once — trimming a
catch-all leaves the noun it used to answer with nothing to answer it, so a trim without
its new items is not a repair but the same defect from the other side.

| Class | Rows | What was done |
|---|---|---|
| `unanswerable-noun` | `AboveGround.swift` ×5, `Prose+AboveGround.swift` | `field` — the game's opening room — plus `path` in four rooms going four different places, `clearing` twice, `trees` and `forest` at the house sides, `pages` on the brochure. `forestStand()` and `pathScenery(_:_:)` are the two factories; five byte-identical `trees…` declarations became one of them. |
| `unanswerable-noun` | `House.swift` ×2 | The Kitchen's passage west; the Living Room's doorway east; the Cellar's passageway **and** its crawlway, as two items, because they are two holes in two walls. |
| `unanswerable-noun` | `RoundRoom.swift` | The eight passages the room's whole description is about — a `describe { }` on `carouselSpinning`, not a constant, because which one goes where is exactly what the machine underfoot is scrambling. The Troll Room's four take a constant: his ways out do not move, he does. |
| `unanswerable-noun` | `Dam.swift` | Stream View's bank, and `path` off `streamWater` — the room stands you *on a path beside* the stream and the stream was answering for the ground. Plus the Maintenance Room's equipment, wreckage and doorways. |
| `unanswerable-noun` | `Bank.swift` | The Safety Depository's `walls` and `doorways`. `curtain` keeps singular `wall`; the split is the finding. |
| `unanswerable-noun` | `RoyalPuzzle.swift` | The anteroom's sand, in the room's own two states. The game's `sand` is in the cell ten feet below, which is this issue's other class seen through a hole. |
| `unanswerable-noun` | `Volcano.swift::x rim …` | Eight scenery items, not the three the issue names — the issue names a construction and `shaftScenery(_:_:)` has that many instances. Every level of the shaft now carries two items, the rock within reach and the view of what is not. The Wide Ledge's small door became its own item with its own `describe { }`, which removed a state claim from the rock rather than adding one. |

Cover is thirteen new tests in `DungeonProseTests` (every negative paired with its
control), sixteen extended sweeps and three new ones — Volcano View, the Lower Shaft and
the volcano's own — plus a `Which do you mean` negative in the four collision-prone
sweeps, since `expectEveryNounAnswered` matches only unknown words and unseen things and
an ambiguity passes it silently.

**One row correction while in here.** The paragraph this replaces cited "rows 89, 91" for
the volcano synonym lists. Row 89 is `swim` and row 91 is Stream View's bank; the volcano
row is 96.

Still open and unticked after three passes, and six rows: the Kitchen's "slightly ajar"
(row 70, declined by #235 with an argument); the two `swim` rows (89, 92); the Wide
Ledge's *room paragraph* (row 94) — this pass repaired that ledge's **examine** channel,
and flipping 94 would repeat the `swim` mistake of claiming credit for a different
sentence; `enter window` (row 107); and the mirror box's model of an opening (row 108).
By box: 2, 11, 12 and 15, all `needs-human` or a hand edit to the harness.

**2026-08-12 — three rows marked `fixed` by the fourth pass.** Boxes 2 and 11, and with
them row 70, which the paragraph above lists as declined rather than repaired. All three
were `needs-human`, and in all three the source had already made the call.

| Class | Row | What was done |
|---|---|---|
| `mechanic-contradicts-prose` | `Endgame+MirrorBox.swift::push pine…` (108) | **The pine end shuts behind you as you step out of it**, which is `MIROUT`'s own line and the half this game did not have. The box's model of an opening is *unchanged* — `MIRIN` admits you through the mirror alone, and `BoxFace.admitsEntry` now says so once instead of two same-shaped predicates saying it twice — because the disagreement the round found was that missing line, not the asymmetry. What was left after it is a refusal that named the side actually in the way: `MIRIN`'s three answers in place of one denial about the whole box. Two things fell out: `leaveTheBox()` tested its openings with two `if`s rather than a choice, so an open pine end shadowed an open mirror; and the pine end's examine text was a static "There is no opening in it." while it stood open. |
| `mechanic-contradicts-prose` | `House.swift::…enter window you can…` (107) | **The cause was the engine's, not the game's.** `enter` reached `.board`, which knew about vehicles and not about doors, so the game's front entrance answered "You can't get into that." one turn after its own examine text promised a gap wide enough to climb through. `.board` is `V-THROUGH` now — a door on an exit of this room is a way through, under five spellings, refusing in the same words `go` refuses in. Two private `walkThrough` verbs went with it, one of them in a test fixture. |
| `prose-untrue-of-state` | `Prose+House.swift::…west kitchen y…` (70) | **The Kitchen's "slightly ajar", and Behind House's with it.** #235 declined this on the grounds that the paragraph is trilogy-verbatim and so asserts nothing. Both sources *branch* that paragraph's last word on the window's `OPENBIT`; the game had frozen the shut half. Verbatim is a claim about a line, and a branched line has two halves. `Sources/Zork1/` had both paragraphs frozen the same way and is repaired in the same commit. |

Cover is three new tests in `DungeonProseTests`, four in `DungeonEndgameTests` — one of
them a value test on the box's model of an opening, which nothing pinned before — two in `Zork1Tests` and
seven engine cases in `DoorTests`.

**Still open: two boxes and three rows.** Box 12, the stub-verb register, and box 15, the
harness room census; rows 89, 92 and 94, each for the reason given above.

**2026-08-12 — box 12 closed by the fifth pass, and no row moves.** The stub-verb
register: the game answered seventeen of the engine's ~47 stub verbs in its own voice and
thirty in the engine's, and the whole floor is now written, installed as `text.stubs`
rather than as `action(…)` rows. The six stock lines that take a person as their subject
went with it, and so did `GnustoMeleeCombat`'s four, which turned out to be the most
reachable stock lines left in the game.

**Row 92 does not flip, and that is the point worth recording.** It is the only
`register-mismatch` row in the table and it is the obvious candidate, but its key
normalizes to the `swim` sentence — the same sentence as row 89 — and this pass does not
change `noSwimming`. Flipping it would be the mistake this file has now warned about
twice: claiming credit for a repair to a different sentence. Box 12 is closed on the
issue's checklist, where it lives; it has no row of its own here, because it came from the
survey's `reskinnedStubs` field rather than from a charter reading a line in a frame.

| Class | Row(s) | What was done |
|---|---|---|
| `register-mismatch` | none — box 12 has no key | **The floor is written, all ~47 of it, and every line is a claim about the thing named or the player rather than about the room.** `listen` asserted quiet — false in the Loud Room; `sit`, `buy` and `curse` reported on surroundings they cannot see. The mechanism moved with the words: `DefaultActions.run` returns from an `action(…)` override *before* `requireReach`, so all seventeen re-skins had silently given up the engine's reach guard, the object's name, its number agreement and the `yourself`/`somebodyElse` guards. `text.stubs` keeps them, and is also what the harness's own survey measures — the rows were invisible to the round that filed this box. |
| `prose-untrue-of-state` | none — found by this pass | **The Loud Room went on saying "The noise in here is past bearing" after `echo` had settled it.** A static paragraph with a state behind it, which is box 3's mechanism at a site that pass did not reach. It surfaced from the other end: the new `listen` says the listener learns nothing, which contradicts a paragraph calling the din unbearable. The room describes itself with a rule now, as the carousel next door already did. |

Cover is six new tests in `DungeonProseTests`, one of them a sweep that compares every
line in ``GameText/StubReplies`` against the engine's and derives its own completeness
from `Mirror`, so a forty-eighth stub arriving with no Dungeon line fails rather than
passing quietly.

**2026-08-12 — box 15 closed, and #233 with it.** The harness room census. No row moves
and none could: the preamble already records that this box came from the completeness
critic rather than from a charter, so it has no key here.

The round's own number was 112 of 195 rooms against a real 155, because `roomsVisited` is
a tester self-report field that was reconciled against the survey roster and never against
the 184 transcripts. `playtest.js` now derives it, in the shape the word census established
in the same file: a hardcoded `grep` on Haiku, started early and awaited late so it costs
no wall clock, with **the self-report kept beside the count rather than replaced by it** —
`coverage.rooms` reports the union, both sides, and the gap between them.

Three things the repair had to get right, each of which would have made the new number
wrong in its own way. A tester's comment is echoed into the transcript verbatim, so
`> // walk to Studio` had to be dropped or it would score a visit to the one room the last
round singled out as never entered. The critic's own probes write transcripts too — that
is exactly what took the last figure from 155 to 156 — so its label is excluded rather
than raced against. And a room entered **dark** prints no heading at all, which is why the
merge is a union: the grep cannot see those and a tester can.

The roster matcher was fixed while in there. It fell back to a character-substring test,
so on a 195-room roster `Maze 1` resolved silently to `Maze 14` — unique, and wrong. It
compares word lists now, and a name that is still ambiguous is reported unrecognized
rather than guessed at.

**Still open: nothing on #233. Three rows stand.** Rows 89, 92 and 94, each for the reason
given above — all three name a sentence no pass has changed, and the ledger's rule is that
a row belongs to the sentence in its key rather than to the box it was filed under.

~~Pass every `fixed` and `refuted` key above as `ledgerKeys` on the next round.~~ **Struck
2026-08-18** — see the correction in the preamble. Passing a `fixed` key makes the round
*drop* a rematch of it unverified, which is precisely how a regression goes unseen; and
every key in this file is display-truncated, so none of them can match anything anyway.
Pass the thirteen `refuted` keys, for deterrence in the sighted prompts, and nothing else.

## 2026-08-14 — a hand-played session, not a harness round

**Not the harness.** A player walked the first eighteen turns with `swift run Dungeon` and
annotated the transcript inline, which is the method `docs/playtesting.md` teaches and the
one the automated round is a scaled copy of. The rows are keyed the same way and count the
same, but there is no round report beside them and no seed to re-pin: nothing here depends
on the dice.

Five rows, and four of them are one defect. **A sentence bound to the wrong description
channel** was box 8's class in the second pass — the Clearing's leaves, row 152 above —
and the same swap was sitting on the branch above it, twice, plus two nouns the prose says
out loud and the parser had never been told. All five are `preexisting`; `git log -S` puts
every one of them in the region's first commit.

| Class | Row | What was done |
|---|---|---|
| `mechanic-contradicts-prose` | `AboveGround.swift::up a tree beside you on the branch is a s…` | `NEST`'s `FDESC` moved to `firstSight`, where the room prints it, and `x nest` got an examine text of its own. Up a Tree had named no nest at all and then listed an egg "on the birds nest". `scenery` kept, as with the leaves. |
| `prose-untrue-of-frame` | `Prose+AboveGround.swift::x egg in the birds nest is a large egg en…` | `EGG`'s `FDESC` moved to `firstSight` too, so the long paragraph is the listing line the source makes it; the examine text is the same paragraph with its opening clause repaired, because it was telling a player holding the egg that it was still in the nest. |
| `unanswerable-noun` | `AboveGround.swift::x clasp i dont know the word clasp` | `clasp` is a synonym of the egg. The paragraph names one in both games and neither had a noun behind it. |
| `unanswerable-noun` | `AboveGround.swift::x lock you cant see any such thing` | `lock` is a synonym of the grating. Three sentences name a heavy lock — the examine text, its twin from below, and `gratingLockNotReachable` — and `x lock` answered with the line reserved for a noun that is not in scope. |
| `mechanic-contradicts-prose` | `Dungeon.swift::enter house you hit your head against the …` | `WHITE-HOUSE-F` answers `THROUGH` itself (`1actions.zil:117`): behind the house an open window walks you into the Kitchen and a shut one says so, and from any other side the house says there is no way in. `enter house` had fallen to `V-THROUGH`'s generic head-butt from every side, in front of a paragraph that had just pointed at the window.

All five carry the same fix in `Sources/Zork1/`, which had byte-identical copies of four of
them and, in the fifth, no `grate` or `grating` synonym at all. Cover is three tests in
`DungeonProseTests.swift` and two in `Zork1ProseTests.swift`, each negative assertion
paired with a positive control.

**Four engine defects came out of the same eighteen turns and are filed rather than fixed**
— `TAKE ALL` enumerating the visible set instead of the reachable-minus-carried one, the
pitch-black line and the grue daemon's warning both firing on the walk-in turn, `look
inside X` failing where `look in X` works, and no conjunction support at all. None is a
Dungeon defect and none has a key here.

Pass these five keys as `ledgerKeys` too. The list is twenty-two keys longer than it was.


## 2026-08-18 — second round, `bd5f79b` (`fix: none`, nothing applied)

Ran at **seed 52**, the seed `DungeonWalkthroughTests` pins its 716-point route to. Oracle
tiers T0–T4, all five. `verifyEffort` inherited, not turned down. 52 findings: 42 confirmed
(29 unanimous, 13 `needs-human`), 10 refuted, 0 routed. Round report:
`docs/games/dungeon-playtest-2026-08-18.md`.

**Every `confirmed` row below is an open defect in the game as it ships, filed as #286.**

**The 39 `fixed` keys above were withheld from `ledgerKeys`.** Only the 13 `refuted` ones
were passed, which is what the correction at the top of this file instructs. Nothing in
this round matched any of them, and nothing could have: they are all display-truncated with
`…`, which `normalize()` can never emit.

**These keys are full and untruncated**, in the `decl::<file>::<declaration>` shape the
clusterer actually compares — the first round in this file for which that is true.

Every row is `preexisting`; the verifiers dated all 42 confirmed findings against `git
log -S` and not one arrived with a recent fix. **No row here is a regression, and none of
the 39 `fixed` rows above came back.** The next round's first job is still to check that
none of them has.

Four things deserve a flag.

**The critic rated the round `round-is-thin`, and 42 findings do not contradict that.**
Three region prefixes pointed six of eight testers at three regions. Volcano is 0/10 rooms
worked, Palantir 0/5, Royal Puzzle 0/2, Dam 0/8, Coal Mine 1/13 — thirty-eight rooms the
committed route walks straight through and nobody addressed a word to. A region with no
rows below is **not** clean; it is unvisited.

**The thief was dead in every session by move 48, and that is a property of the prefixes,
not of the dice.** `route616.txt` line 42 is `attack thief with sword`, and all three region
prefixes are prefixes of that route. `shadowy figure` appears zero times in ~18,900 played
commands, so six of the thirty-five timers are dead code for the whole round. A prefix that
omits line 42 is the single highest-value change the next round can make.

**Two keys are coarser than the defect and will over-match.**
`decl::Sources/Gnusto/Actions/StubVerbs.swift::stubs` and
`decl::Sources/Gnusto/Actions/CoreVerbs.swift::cores` name whole declaration arrays, not
lines. Both are `confirmed`, so neither is passed as a `ledgerKey` and neither can suppress
anything today — but if either is ever marked `refuted`, narrow it first or it will swallow
every future finding on any stub or core verb.

**Thirteen rows are `needs-human`, and in three of them the verifier corrected the finder's
own diagnosis.** `Prose+EndgameMechanics.swift::masterArrives` (the capitalised lines are
the outlier, not the listing line), `CoreVerbs.swift::cores` (the prescribed fix makes Zork 1
warn at launch) and `AboveGround.swift::mailbox` (confirmed on object-property fidelity, not
on the prose contradiction the finder led with). Read the round report's per-site notes
before acting on any of the three; the claim alone points at the wrong line.

| Key (full) | Verdict | Category | Severity |
|---|---|---|---|
| `decl::Sources/Dungeon/Regions/Prose+House.swift::bottle` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::sphere` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::etchingsAbove` | fixed | unanswerable-noun | major |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::cageGas` | fixed | unanswerable-noun | minor |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::machineRoomWithButtons` | fixed | unanswerable-noun | minor |
| `decl::Sources/Dungeon/Regions/Prose+Dam.swift::reservoirWater` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::buoy` | confirmed | presence-line-location-blind | major |
| `decl::Sources/Dungeon/Regions/River.swift::barrel` | confirmed (needs-human) | mechanic-contradicts-prose | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::boatHissesFlat` | confirmed (needs-human) | gate-not-gating | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::beachDigs` | fixed | unanswerable-noun | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::frigidRiverHere` | fixed | prose-untrue-of-frame | major |
| `decl::Sources/Dungeon/Regions/Prose+AboveGround.swift::distantView` | fixed | prose-untrue-of-frame | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::whiteCliffsFromBelow` | fixed | prose-untrue-of-frame | minor |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::aragainFallsItself` | fixed | prose-untrue-of-frame | minor |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::rainbowItself` | fixed | prose-untrue-of-frame | minor |
| `decl::Sources/Dungeon/Regions/Prose+Temple.swift::torchNoRope` | confirmed | mechanic-contradicts-prose | major |
| `decl::Sources/Dungeon/Regions/Prose+Temple.swift::spirits` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+Temple.swift::candles` | confirmed (needs-human) | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+RoundRoom.swift::roundRoomCompass` | fixed | unanswerable-noun | major |
| `decl::Sources/Gnusto/Actions/StubVerbs.swift::stubs` | confirmed (needs-human) | prose-untrue-of-frame | major |
| `decl::Sources/Dungeon/Regions/Prose+Temple.swift::bellCools` | confirmed | prose-untrue-of-frame | minor |
| `decl::Sources/Dungeon/Regions/Prose+Temple.swift::blackBook` | confirmed (needs-human) | mechanic-contradicts-prose | minor |
| `decl::Sources/Dungeon/Prose+Stubs.swift::stubs.climb` | confirmed (needs-human) | stock-line-not-reskinned | minor |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::blueIcingWriting` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::poolLeak` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::robotSpringsTheCage` | confirmed | mechanic-contradicts-prose | major |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::robotIsOutOfEarshot` | confirmed (needs-human) | stock-line-not-reskinned | minor |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::geronimoNotInBarrel` | confirmed | prose-untrue-of-frame | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::barrelInside` | confirmed (needs-human) | prose-untrue-of-state | minor |
| `decl::Sources/Dungeon/Prose+Systems.swift::verbSmell` | confirmed (needs-human) | prose-untrue-of-frame | minor |
| `decl::Sources/Dungeon/Regions/Prose+Temple.swift::exorcismLapses` | confirmed | prose-untrue-of-frame | major |
| `decl::Sources/Dungeon/Regions/Prose+Temple.swift::bellRingRedHot` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+Endgame.swift::pineEndOpen` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+Endgame.swift::guardians` | confirmed (needs-human) | prose-untrue-of-frame | major |
| `decl::Sources/Dungeon/Regions/Prose+Endgame.swift::cryptTransition` | confirmed | prose-untrue-of-state | minor |
| `decl::Sources/Dungeon/Prose+Systems.swift::toll` | confirmed | register-mismatch | note |
| `decl::Sources/Dungeon/Regions/Prose+EndgameMechanics.swift::masterArrives` | confirmed (needs-human) | register-mismatch | note |
| `decl::Sources/Dungeon/Regions/Prose+AboveGround.swift::gratingFromBelow` | confirmed | prose-untrue-of-state | major |
| `decl::Sources/Dungeon/Regions/Prose+Cellar.swift::chimney` | confirmed | mechanic-contradicts-prose | major |
| `decl::Sources/Dungeon/Regions/Prose+Bank.swift::viewingRoom` | confirmed (needs-human) | unanswerable-noun | major |
| `decl::Sources/Dungeon/Regions/AboveGround.swift::mailbox` | confirmed | mechanic-contradicts-prose | minor |
| `decl::Sources/Gnusto/Actions/CoreVerbs.swift::cores` | confirmed (needs-human) | register-mismatch | minor |
| `decl::Sources/Dungeon/Regions/Prose+Alice.swift::bucketGoesNowhereElse` | refuted | mechanic-contradicts-prose | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::river2` | refuted | mechanic-contradicts-prose | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::digRevealsStatue` | refuted | prose-untrue-of-state | minor |
| `decl::Sources/Dungeon/Prose+Systems.swift::drinkWater` | refuted | stock-line-not-reskinned | minor |
| `decl::Sources/Dungeon/Regions/Prose+AboveGround.swift::clearing` | refuted | exit-prose-mismatch | minor |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::whiteCliffsNorth` | refuted | unwinnable | blocking |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::river5` | refuted | exit-prose-mismatch | major |
| `decl::Sources/Dungeon/Regions/Prose+River.swift::chasmDeadEnd` | refuted | exit-prose-mismatch | minor |
| `decl::Sources/Dungeon/Regions/Prose+Temple.swift::bellRedHot` | refuted | prose-untrue-of-state | minor |
| `decl::Sources/Dungeon/Prose+Stubs.swift::stubs.sit` | refuted | register-mismatch | minor |

Pass the ten `refuted` keys above as `ledgerKeys` next round, alongside the thirteen from
2026-08-11. **Not the forty-two `confirmed` ones**, and not the thirty-nine `fixed` ones
above them. The list is twenty-three keys long, and for the first time ten of them can
actually match.

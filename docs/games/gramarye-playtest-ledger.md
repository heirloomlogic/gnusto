# Gramarye — playtest ledger

Append-only. One row per dedupe key the harness has ever seen, with what became of it.

This is the loop's memory, and it exists for two reasons. Without it, a round
rediscovers everything a previous round already rejected, forever — the harness argues
with itself instead of converging. And with it, a key marked `fixed` that shows up again
is not a new finding, it is a **regression**, and it goes back at raised severity.

Pass `ledgerKeys` into the workflow with every key below whose verdict is `refuted` or
`fixed`.

The key is `<ownerFile>::<normalized offending text>`, with the frame deliberately
excluded — one untrue sentence seen in two frames is one defect, so keying on the frame
would dispatch two fixers at one branch. Keys are abbreviated here for reading; the
full ones are in the round reports.

## 2026-07-30 — first round, `4aae966` (`fix: none`, nothing applied)

Dispatched with `docPath: null`, but `docs/games/gramarye.md` was already in the working
tree and three verifiers found and used it. Three of the fifteen refutations below are
`licensed-by-doc` and could not have been made without it.

Every `confirmed` row is an **open defect in the game as it ships**, filed as #98–#103.
None was fixed in this round. Rows marked `needs-human` are ones the verifier confirmed
as real and explicitly declined to let an autonomous fixer repair, because the fix is a
design call with incompatible reasonable answers — #98 above all.

Completeness critic's trustworthiness verdict for this round: **`sound`**. Caveat on the
evidence all the same: the tourist's and the idiot's transcripts are largely overwritten
by concurrent label collisions (#97). The clock-watcher, solver and re-reader are fully
audited.

| Key (abbreviated) | Verdict | Category |
|---|---|---|
| `Gramarye.swift::close door closed east the warded door is closed north the granite wall is…` | confirmed (needs-human) | unwinnable |
| `Gramarye.swift::passwall you read the scroll and it crumbles to ash but the granite before…` | confirmed | prose-untrue-of-state |
| `Gramarye.swift::look a close candlewarm room walled in books the heavy door in the west…` | confirmed | unanswerable-noun |
| `Gramarye.swift::west a cold stone gallery the way east runs back to the study to the north…` | confirmed | unanswerable-noun |
| `Gramarye.swift::north a low vaulted cellar the air chalky with old magic x cellar i dont…` | confirmed | unanswerable-noun |
| `Gramarye.swift::firebolt golem fire leaps from your hand and bursts against the golem it…` | confirmed | mechanic-contradicts-prose |
| `Gramarye.swift::x desk i dont know the word desk x master i dont know the word master x…` | confirmed (needs-human) | unanswerable-noun |
| `Gramarye.swift::x spellbook the masters working book bound in cracked leather the pages…` | confirmed | unanswerable-noun |
| `Gramarye.swift::out you were left to mind the tower a tower cannot be minded from the road…` | confirmed | unanswerable-noun |
| `Gramarye.swift::west the long gallery a cold stone gallery the way east runs back to the…` | confirmed (needs-human) | unwinnable |
| `Gramarye.swift::close door closed x door a stout door held shut by the wardingmarks cut…` | confirmed (needs-human) | prose-untrue-of-state |
| `Gramarye.swift::the study a close candlewarm room walled in books the heavy door in the…` | confirmed | unanswerable-noun |
| `Gramarye.swift::x golem a hulking figure of raw clay planted between you and the amulets…` | confirmed | unanswerable-noun |
| `Gramarye.swift::close door closed z time passes behind you the warded door meets its frame…` | confirmed (needs-human) | prose-untrue-of-state |
| `Gramarye.swift::read book you go through the pages at speed looking for anything at all on…` | confirmed | prose-untrue-of-state |
| `Gramarye.swift::close door closed read book you leaf through the book out of a sense of…` | confirmed (needs-human) | prose-untrue-of-state |
| `Gramarye.swift::x niche the shadow has been persuaded to give up its secret a rolled…` | confirmed | prose-untrue-of-state |
| `Gramarye.swift::x books i dont know the word books x desk i dont know the word desk x…` | confirmed | unanswerable-noun |
| `Gramarye.swift::cast passwall you read the scroll and it crumbles to ash but the granite…` | confirmed | unwinnable |
| `Gramarye.swift::close wall closed cast firebolt at golem fire leaps from your hand and…` | confirmed | prose-untrue-of-state |
| `Gramarye.swift::close warded door closed z time passes behind you the warded door meets its…` | confirmed (needs-human) | prose-untrue-of-state |
| `Gramarye.swift::glow pale light seeps from your fingers and in the niche it finds a rolled…` | confirmed | mechanic-contradicts-prose |
| `Gramarye.swift::x masters spellbook i dont know the word master x desk i dont know the word…` | confirmed (needs-human) | unanswerable-noun |
| `Gramarye.swift::x desk i dont know the word desk` | confirmed | unanswerable-noun |
| `Gramarye.swift::firebolt me the firebolt washes over the yourself and leaves it untouched` | confirmed | stock-line-not-reskinned |
| `playtest-replay::tool doc a blank line or a line whose first nonspace characters are or is a…` | fixed | doc-drift |
| `Gramarye.swift::close door closed look the long gallery a cold stone gallery the way east…` | refuted | exit-prose-mismatch |
| `Gramarye.swift::north the undercroft a low vaulted cellar the air chalky with old magic a…` | refuted | exit-prose-mismatch |
| `Gramarye.swift::close door closed open door the wardingmarks hold the door fast no amount…` | refuted | mechanic-contradicts-prose |
| `Gramarye.swift::close window you cant close that and at the win…` | refuted | mechanic-contradicts-prose |
| `Gramarye.swift::xyzzy nothing happens sing your singing is better kept to yourself pray…` | refuted | register-mismatch |
| `Gramarye.swift::a cold stone gallery the way east runs back to the study to the north the…` | refuted | exit-prose-mismatch |
| `Gramarye.swift::x window the study window stands open to the morning a pleasant draught…` | refuted | mechanic-contradicts-prose |
| `Gramarye.swift::north the granite wall is closed x wall a wall of dressed granite seamless…` | refuted | exit-prose-mismatch |
| `Gramarye.swift::read book you search the book for anything on warded doors what your…` | refuted | repeat-behavior |
| `Gramarye.swift::down you were left to mind the tower a tower cannot be minded from the road…` | refuted | exit-prose-mismatch |
36 distinct keys from 45 findings. The dedupe key is the normalized excerpt, so one
defect quoted with a different surrounding line survives as a separate key — the
`close door` softlock was filed three times and the `doorSeals` "You touched nothing"
line three times more. Worth tightening before a round runs with `fix: "game"`.

## Amendments

**2026-07-31 — every `confirmed` row on the game itself marked `fixed`.** #98–#101
closed in one change. Pass all of these keys as `ledgerKeys` on the next round: a `fixed`
key that comes back is a regression, not a finding.

What the rows became, by class:

| Class | What was done | Cover |
|---|---|---|
| `unwinnable` — `close door`, `close wall` (3 keys, all `needs-human`) | The door refuses while the master's book is out of reach and otherwise closes and says the wards caught; `unbar` is repeatable, so a close with the book to hand is survivable. The granite refuses outright, because `passwall` is its only opener and the scroll is ash. The design call the verifier declined to make was made with the owner: refuse-when-it-would-strand for the door, refuse-always for the wall. | `theWardedDoorRefusesToShutOnTheBook`, `theDoorWillNotBeShutOnABookLeftInTheGallery`, `shuttingTheDoorWithTheBookInHandIsSurvivable`, `theMistCannotBeClosedBehindYou` |
| `prose-untrue-of-state` — the fuse's "You touched nothing" over a hand-closed door (3 keys) | The fuse stands down if the door is already shut. The only way that happens is the apprentice's own hand, and the slam cannot narrate over it. | `theFuseStandsDownIfTheApprenticeShutsTheDoorHimself` |
| `prose-untrue-of-state` — "Nothing is currently wrong" with the amulet sealed away | `doorSealed` is now written by both closers, the fuse and the rule, so the book's ladder is keyed on the event however the event happened. | `theFuseStandsDownIfTheApprenticeShutsTheDoorHimself` |
| `prose-untrue-of-state` — `open wall` after `passwall` | The `isOpen` guard the warded door always had, given to the granite. | `theOpenedGraniteStopsOfferingTheHint` |
| `prose-untrue-of-state` — `x niche` after the scroll is spent | Four states, not three. The ladder asks `niche.holds(scroll)` rather than `isHeld`, so a `vanish()`ed scroll no longer falls into the branch written for "revealed and not yet picked up". | `theNicheKeepsItsSecretUntilGlow` |
| `prose-untrue-of-state` — the ending's "the warded door unbound" | The inventory reads the door. The wall needs no branch: nothing can close it and the master is standing in the hole. | `theEndingNamesTheDoorItFinds`, `theMasterReturnsAndLaughsWhenTheAmuletIsTaken` |
| `prose-untrue-of-state` — the book's "a second time … this time it relents" | The back-reference is gone. The ladder is keyed on world state and `glow` can be cast without ever opening the book, so no rung may claim a history it cannot check. Written into the design doc as a third constraint on the ladder. | `theBookNeverClaimsAReadThatDidNotHappen` |
| `mechanic-contradicts-prose` — `glow` finds a parchment "in the niche" that is on the floor | The niche is a `container` and the scroll starts inside it, so the listing, `x niche` and `search niche` all agree. | `theNicheHoldsTheScrollAndSaysSo` |
| `mechanic-contradicts-prose` — the golem "slumps to rubble" and vanishes outright | The firebolt reveals a rubble item and the Undercroft grew the second state the other two rooms had, so the ending's "redistributed evenly across the floor" is on the page. That also closes the design doc's open question 3. | `theUndercroftShowsTheRubbleOnceTheGolemIsGone` |
| `mechanic-contradicts-prose` — `burn golem` on a `.combustible` target | `golem.before(.burn)` replies, pointing at the apprentice's own reserves without claiming he has read the book. | `burningTheGolemPointsAtTheFirebolt` |
| `stock-line-not-reskinned` — "the yourself" | The game's own string, not the engine's. `definiteName` respects `properName`; a self-cast gets its own line. | `fireboltAtYourselfDoesNotSayTheYourself` |
| `unanswerable-noun` (9 keys, ~40 nouns) | A new `Fixtures` bundle of scenery items, the warding marks and the rubble in the game itself, and synonyms on the things whose own descriptions name their parts. Two nouns were reworded out instead: the intro's `shoulder`, which is the player's and whose vocabulary is fixed, and the gallery's simile knife, which nothing in the tower is. | `theIntroAnswersToEveryNounItPrints`, `theStudyAnswersToItsOwnDescription`, `theSpellbookAnswersToItsOwnPages`, `theGalleryAnswersToItsOwnDescription`, `theUndercroftAnswersToItsOwnDescription` |

Two `refuted` rows changed anyway, and neither is a reversal. `x window` was refuted as
`mechanic-contradicts-prose`; the window is unchanged, but it now answers to `draught`,
`draft`, `breeze` and `air` as well, because those are words its own description prints.
And the Undercroft names its way back south, which it never did — that came out of the
missing second state, not out of the refutation, and the five `exit-prose-mismatch` rows
stand refuted.

So do the register rows (`xyzzy`, `sing`, `pray`). One more will simply not reproduce:
`close door` / *Closed.* was the opening of two refuted keys, and there is no stock
`Closed.` on either barrier any more.

**2026-07-31 — the blank-line row marked `fixed`.** Fixed in the harness, not in
Gramarye: no `Sources/Gramarye/` file is touched. `bin/playtest-replay` built its
effective command file with a plain `cat`, so a blank line reached `perform()` and
drew "I beg your pardon?" while the tool's own `--commands` doc claimed it never
reached the engine. It now filters blank lines where it assembles the file, and the
doc says which layer drops which line kind — the engine records and skips `//` and
`#`, the tool strips blanks. The same change closed a second defect the round did
not see: `cat` passed an unterminated last line through unterminated, so a command
file saved without a trailing newline fused its last command onto the `--save`
epilogue (`z` + `save` → `zsave`), losing the command and the save both. No
regression test — the change is in a bash script, and the suite has no shell
harness; the reproducer is in the issue. See
[#103](https://github.com/heirloomlogic/gnusto/issues/103).

## Provenance

Everything here is original to the game:

```
git log --oneline -- Sources/Gramarye/Gramarye.swift
  1d28588 Second game — a general spellcasting system + Gramarye demo (#67)
```

One commit, 2026-07-22. Nothing has touched the file since, so nothing in this round
was introduced by an earlier fix. `git log -S 'close door'` on the owner file returns
nothing, because the marquee defect is an **absence** — there is no `.close` rule to
blame — so the date is the file's own introduction.

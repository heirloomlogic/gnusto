# The round's issue

**One issue per round, per game.** Every class the round confirmed goes in it, as a
checklist. Not one issue per class, not a separate one for the engine's share.

The rule exists because the first two rounds didn't have it. 2026-07-30 filed
**thirteen issues in a day**, #91 through #103 — seven for Lighthouse, six for
Gramarye. Every one was a good issue, and two rounds still took a tracker with six open
that morning to nineteen. Two of Gramarye's six weren't even Gramarye's (`Engine:`
#102, `Play-test harness:` #103), so it wasn't multiplying along one axis either.

The report is the evidence of record; the issue is the tracker entry that points at it.
Anything a reader needs in order to *judge* a finding belongs in
`docs/games/<game>-playtest-<date>.md` (see `report-shape.md`). What belongs here is
enough for someone to pick up one class and fix it.

**Zero confirmed classes files nothing.** An empty round still commits its report; an
issue with no boxes in it is noise.

## Title

```
<Game>: play-test round <YYYY-MM-DD> — <N> defect classes
```

`Gramarye: play-test round 2026-07-30 — 6 defect classes`. Greps per game, and states
its size before anyone opens it.

It is also the round's **key**, the way the report's filename is: search it before
filing, and a second issue for one round collides instead of quietly appearing.

```sh
gh issue list --state all --search "<Game>: play-test round <YYYY-MM-DD>"
```

## Labels

`bug`. Add `question` when any class came back `needs-human` — the verifier confirmed
it and declined to let a fixer near it, which is a design call waiting on a person.

No play-test-specific label. The title prefix is the filter, and a label nobody
maintains is worse than none.

**Never allowlist `gh issue create`.** `.claude/settings.json` keeps it in
`permissions.ask` rather than merely absent from `allow`, because an explicit `ask` rule
outranks `allow` and survives both a "don't ask again" click and an automated allowlist
sweep. The prompt is a backstop, not the cap — the title search above is the cap.

## Body

**1. Provenance, first line.** Game, commit, seed, `fix` mode, date, the confirmed and
refuted counts, and a link to the committed report.

> Found by the automated play-test round on Gramarye — commit `4aae966`, seed `0`,
> `fix: "none"`, 2026-07-30. 30 findings confirmed, 15 refuted, 0 routed. Full
> evidence, coverage grid and refutations: `docs/games/gramarye-playtest-2026-07-30.md`.

**2. The headline.** One bolded sentence naming the worst class. The round report's
lead sentence already is this sentence; reuse it rather than writing a second one.

**3. The checklist**, one line per class, worst severity first:

```markdown
- [ ] **blocking** · Gramarye · Two commands make the game permanently unwinnable,
      silently — and the same gap causes three of the prose lies below (`needs-human`)
- [ ] **major** · Gramarye · ~40 nouns the prose prints that the parser doesn't know
- [ ] **major** · Engine · An apostrophe in an adjective is a word the tokenizer can
      never match
```

Severity, then owner, then the claim. Owner is the finding's `ownerClass` — the
workflow computes it from `ownerFile` in `.claude/workflows/playtest.js`, deliberately
in code rather than by asking an agent, and hands it back on the finding. Capitalize
whatever it answers. A `Harness` box is always filed and never fixed: no `fix` mode
edits the harness's own files, by rule. Mark `needs-human` where the verifier did.

Checkboxes, not bullets. They are how a round with six classes and three fixed ones
reads as half done instead of open.

**4. One `##` section per class**, in checklist order. Each carries:

- the offending text **verbatim** in a fenced block, `> command` and output together,
  with enough lines around it to place the frame;
- a paragraph naming the mechanism at fault — an unbranched fuse body, a barrier gated
  on `.open` with no rule on `.close` — with the offending declaration quoted where
  that's shorter than describing it;
- the shortest reproducer, as commands.

Where several sites share one branch, say so in a `## One root cause` section rather
than repeating the diagnosis three times.

**5. `## Acceptance`.** Bullets, not checkboxes — the checklist above is the only thing
with boxes. The recurring ones:

- each site branches on its frame, or stops claiming what it can't check;
- a transcript test per site;
- `docs/games/<game>.md` updated in the same commit where prose changed;
- **a PR may fix one box, several, or all of them. It references this issue and ticks
  what it fixed; it writes `Closes #N` only when no box is left unticked.**

## How it closes

A fix PR takes as many boxes as it can sensibly carry — one, several, or the whole
checklist — ticks them, and references the issue. `Closes #N` goes in only when the PR
leaves nothing unticked, because a PR that fixes four of six classes and closes the issue
closes the other two along with them.

**That last acceptance bullet is load-bearing and belongs in the issue body itself, not
only here.** The reflex it fights lives outside this repo — the `journeyman` skill is
user-global and tells every PR body it writes to carry `Closes #<n>` so merging
auto-closes the issue. A fixer reads the issue and its own skill, and neither mentions the
exception unless the issue does. This file is the one thing in the chain such a fixer
never opens.

## Worked example

Gramarye's 2026-07-30 round, as it should have been filed. It went out as six issues,
#98–#103.

````markdown
Title: Gramarye: play-test round 2026-07-30 — 6 defect classes
Labels: bug, question

Found by the automated play-test round on Gramarye — commit `4aae966`, seed `0`,
`fix: "none"`, 2026-07-30. 30 findings confirmed, 15 refuted, 0 routed, 0 fixed.
Completeness critic: `sound`. Full evidence, coverage grid and refutations:
`docs/games/gramarye-playtest-2026-07-30.md`.

**The headline is not a prose defect: Gramarye can be made permanently unwinnable in
two commands, with no death, no warning, and no hint that anything has been lost.**

- [ ] **blocking** · Gramarye · Two commands seal the game, and the same root cause —
      barriers gated on `.open` with no rule on `.close` — accounts for three of the
      prose lies below (`needs-human`)
- [ ] **major** · Gramarye · ~40 nouns the prose prints that the parser doesn't know,
      `warding-marks` and `hook` among them
- [ ] **major** · Gramarye · The niche never held the scroll, and advertises it after
      it's ash
- [ ] **major** · Gramarye · Four lines that don't know the state they're printing in
- [ ] **major** · Engine · An apostrophe in an adjective or synonym is a dead word the
      tokenizer can never match
- [ ] **note** · Harness · Blank lines in a command file reach the engine despite the
      docs saying they don't

## Two commands make the game permanently unwinnable

```
> west
The Long Gallery
A cold stone gallery. The way east runs back to the study.

> close door
Closed.
```

`wardedDoor` is plain `openable` with a `before(.open)` rule and no rule on `.close`,
so the stock close succeeds. Every spell, every direction and every force verb was
probed from the resulting state; `maxScore` 10 is unreachable. `close wall` after
passwall is the same gap on `graniteWall`, and worse — `passwall`'s effect is the only
writer that can reopen it, and the scroll is already ash.

Reproducer: `west`, `close door`.

`needs-human`: three incompatible repairs are reasonable and the verifier declined to
pick.

## ~40 unanswerable nouns

…

## One root cause

The unwinnable trap and three of the four state-blind lines are the same missing
`.close` branch. Fixing the barrier retires four boxes; the remaining prose lie is
independent.

## Acceptance

- Both barriers refuse or survive a hand-close, and the `doorSeals` fuse stops
  asserting "You touched nothing" about a door the player closed.
- Every noun the prose prints is in the vocabulary, or leaves the prose.
- A transcript test per site; `docs/games/gramarye.md` updated in the same commit — its
  Copy and Spellbook sections quote three of these verbatim.
- **A PR may fix one box, several, or all of them. It references this issue and ticks
  what it fixed; it writes `Closes #N` only when no box is left unticked.**
````

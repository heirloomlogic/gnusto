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

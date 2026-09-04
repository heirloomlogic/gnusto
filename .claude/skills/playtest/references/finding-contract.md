# What a dispatchable finding carries

A finding is a claim that someone else has to be able to check without replaying
your whole session. Six things make that possible, and a finding missing any of
the first five gets dropped at triage rather than verified.

| Field | Why it exists |
|---|---|
| `seed` | Without it the reproducer is not a reproducer. Always record it, even for a game you believe is seed-independent — "believed" is not "pinned". |
| `reproducer` | The **shortest** command list from a clean start. Replayed before reporting. This is what becomes the regression test, so it is the field a fixer uses most. |
| `startedFrom` | Only when the reproducer begins at a **deep start**: the name of the route you opened with. The list is short because it begins where the route stopped, and read from turn zero it means something else or nothing at all — so this is the field that makes it replayable. The verifier passes it to `bin/playtest-replay --start`, which plays the route ahead of the list and takes the seed off its manifest. |
| `savesFrom` | Only when the reproducer begins `restore`: the label holding the save it restores, which is normally the one you opened under. This is about a save **you** wrote mid-session; a deep start is a route and wants `startedFrom` instead. A state you can only reach through a save is still reachable, so a reproducer that restores is a legitimate reproducer — but it replays for nobody unless it says where the slot is. Filed without this, it reaches the verifier looking like one that starts clean, the replay answers *"Restore failed."*, and it is refuted as `not-reproducible` for a reason that is about the harness. That is exactly how four real defects were lost in the 2026-08-25 Dungeon round. |
| `excerpt` | The offending text quoted **verbatim**, plus enough surrounding lines to show the frame. A paraphrase cannot be verified and cannot be grepped for. |
| `frame` | Room, hour and the world state that matters — what has and hasn't happened yet. Take the room and the hour from the `[status]` line the turn printed, not from counting commands. The hour on that line is the hour that turn's own prose was written at — the same reading its `time` reply and its room descriptions took. (It stood one tick ahead of them between 2026-08-15 and the fix for #280, so a transcript recorded in that window needs the correction before you quote it.) |
| `fault` | Which prose or which rule is at fault, and why. Name the mechanism (a static `firstSight` on an actor, an unbranched fuse body), not just the symptom. |
| `transcriptPath` | The transcript path **the server returned to you**, copied verbatim. You do not choose it and you do not construct it: a probe directory is written once and never rewritten, so the path the tool handed back resolves to the session you judged for as long as the scratch survives. Cite the path, never a bare label — a label is a namespace holding many probes, and pointing at one is how the 2026-07-30 Lighthouse round ended up with three refutations citing one directory that held none of them. A `replay` returns one too, on the first line of its answer (`transcript=…`); if the frame you are reporting came from a replay rather than from your own session, that is the path to give, because it is the one that holds the turn you are quoting. |

Plus, for routing:

| Field | Values |
|---|---|
| `category` | `presence-line-location-blind`, `prose-untrue-of-frame`, `prose-untrue-of-state`, `unanswerable-noun`, `stock-line-not-reskinned`, `register-mismatch`, `exit-prose-mismatch`, `mechanic-contradicts-prose`, `repeat-behavior`, `unwinnable`, `gate-not-gating`, `doc-drift`, `contract-violation`, `crash-or-hang`, `prose-taste` |
| `severity` | `blocking` (the game cannot be finished), `major` (a line is false), `minor` (true but misleading), `note` (taste) |
| `ownerFile` | The file that would change. This is what decides prose-vs-engine, so guess it honestly rather than conveniently. Spell it the way the repository that owns it does — `Sources/Gnusto/Actions/GameText.swift` for an engine file, whatever your own package calls its own — and never as a path into a resolved dependency checkout. When the engine is a dependency it sits somewhere you cannot know and nobody's ledger could match; the round puts your spelling and that one in a single frame, and yours is the one it can always read. |
| `routedTo` | An issue number from the set your prompt named, or empty. Set it and the finding leaves the pipeline. **Only an issue your prompt listed belongs here** — never one you remember, because a closed issue turns its replies back into regressions, and that has already happened three times. |
| `alsoSeenIn` | Other frames where the same sentence was also false. One sentence wrong at two hours is **one** defect with two frames, not two defects. |

**A word the game printed and then refused is `unanswerable-noun`, and it is a finding.**
Not a line in your coverage note, not a row in the round's unknown-word tally — that count
is a symptom, it names no file and no room, and nothing downstream can act on it. File one
finding per noun, quoting the line that printed the word, with the command that was
refused as the reproducer. Six such nouns arrived as tally entries on 2026-08-25 and were
never filed; the rule is CLAUDE.md's and unqualified: *every noun a room description prints
must be answerable*.

## The two rules that keep the loop honest

**One sentence, one finding.** Dedup is keyed on the **declaration that printed the
line** — the round locates it from your excerpt — and deliberately ignores the frame.
The Delphine case is why: the same unbranched `presence` rule printed a false line in
a lit study at 6:02 and in a dark cellar at 6:26. That is one branch to fix, so it
must arrive as one finding with two frames; otherwise two fixers get dispatched to
one line. This is also why `excerpt` must be verbatim — a paraphrase cannot be traced
back to the declaration, and an untraceable finding falls back to being keyed on your
wording, where it dedups against nothing.

**Report what you saw, not what you infer.** If you believe a line is *probably*
false somewhere you did not stand, that belongs in your coverage note as an
unprobed cell, not in a finding. The verifier will refute an unvisited frame, and it
is right to.

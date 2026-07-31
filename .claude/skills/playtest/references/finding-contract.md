# What a dispatchable finding carries

A finding is a claim that someone else has to be able to check without replaying
your whole session. Six things make that possible, and a finding missing any of
the first five gets dropped at triage rather than verified.

| Field | Why it exists |
|---|---|
| `seed` | Without it the reproducer is not a reproducer. Always record it, even for a game you believe is seed-independent — "believed" is not "pinned". |
| `reproducer` | The **shortest** command list from a clean start. Replayed before reporting. This is what becomes the regression test, so it is the field a fixer uses most. |
| `excerpt` | The offending text quoted **verbatim**, plus enough surrounding lines to show the frame. A paraphrase cannot be verified and cannot be grepped for. |
| `frame` | Room, hour (**anchored** to a real reading in the transcript), and the world state that matters — what has and hasn't happened yet. |
| `fault` | Which prose or which rule is at fault, and why. Name the mechanism (a static `firstSight` on an actor, an unbranched fuse body), not just the symptom. |
| `transcriptPath` | The `[playtest] transcript=…` path of the clean replay, copied verbatim from the trailer. A probe directory is written once and never rewritten, so this resolves to the session you judged for as long as the scratch survives. Cite the path, never a bare label — a label is a namespace holding many probes, and pointing at one is how the 2026-07-30 Lighthouse round ended up with three refutations citing one directory that held none of them. |

Plus, for routing:

| Field | Values |
|---|---|
| `category` | `presence-line-location-blind`, `prose-untrue-of-frame`, `prose-untrue-of-state`, `unanswerable-noun`, `stock-line-not-reskinned`, `register-mismatch`, `exit-prose-mismatch`, `mechanic-contradicts-prose`, `repeat-behavior`, `unwinnable`, `gate-not-gating`, `doc-drift`, `contract-violation`, `crash-or-hang`, `prose-taste` |
| `severity` | `blocking` (the game cannot be finished), `major` (a line is false), `minor` (true but misleading), `note` (taste) |
| `ownerFile` | The file that would change. This is what decides prose-vs-engine, so guess it honestly rather than conveniently. |
| `routedTo` | `76`, or empty. Set it and the finding leaves the pipeline. Only issues that are still **open** belong here — a closed one turns its replies back into regressions. |
| `alsoSeenIn` | Other frames where the same sentence was also false. One sentence wrong at two hours is **one** defect with two frames, not two defects. |

## The two rules that keep the loop honest

**One sentence, one finding.** Dedup is keyed on the owning file and the offending
text, deliberately *ignoring* the frame. The Delphine case is why: the same
unbranched `presence` rule printed a false line in a lit study at 6:02 and in a dark
cellar at 6:26. That is one branch to fix, so it must arrive as one finding with two
frames — otherwise two fixers get dispatched to one line.

**Report what you saw, not what you infer.** If you believe a line is *probably*
false somewhere you did not stand, that belongs in your coverage note as an
unprobed cell, not in a finding. The verifier will refute an unvisited frame, and it
is right to.

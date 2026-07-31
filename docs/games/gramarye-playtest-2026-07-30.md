# Gramarye — playtest round, 2026-07-30

Commit `4aae966` · seed `0` · `fix: none` · charters: tourist, clock-watcher, vandal,
solver, idiot, re-reader (interrogator correctly skipped)

Oracle tiers: **T0 kernel, T1 design doc, T2 `GramaryeTests`, T3 source.** The round
was dispatched with `docPath: null`, but `docs/games/gramarye.md` was already in the
working tree and three verifiers found and used it — see [Refuted](#refuted).

Budget: 40 turns planned per charter. **807 commands typed, 564 engine turns charged,
across 62 surviving transcripts.**

30 findings confirmed, 15 refuted, 0 routed, 0 fixed (`fix: none`). Completeness
critic's verdict: **`sound`**.

## The round

The headline is not a prose defect. **Gramarye can be made permanently unwinnable in
two commands**, and the same root cause — barriers gated on `.open` and not on
`.close` — accounts for three of the four blocking findings and three of the prose
lies underneath them. Everything predates this branch; provenance is in the
[ledger](gramarye-playtest-ledger.md).

- **`west`, `close door` seals the apprentice in the Long Gallery on turn 2.**
  *Frame:* Long Gallery, `doorSealed` still false, spellbook and niche and scroll all
  in the Study. *Cause:* `wardedDoor` is plain `openable` with a `before(.open)` rule
  and no rule on `.close`, so the stock close succeeds and answers with a bare
  `Closed.` The verifier probed the terminal state rather than inferring it — every
  spell, every direction, every force verb — and `maxScore` 10 is unreachable. The
  design already treats this state as forbidden: the `doorSeals` fuse guards against
  reaching it by accident. Only the player-driven path is unguarded.
- **`close wall` after passwall seals the Undercroft for good.** *Cause:* the same
  gap on `graniteWall`, but worse, because `passwall`'s effect is the only writer that
  can reopen it and the scroll is already ash. The warded door at least has a
  repeatable reopen path.
- **The fuse insists you didn't do it.** Close the door by hand and `doorSeals` still
  fires, narrating the slam and asserting "You touched nothing" about a door the
  player closed. **The spellbook agrees:** its first rung keys on the `@Global
  doorSealed`, written only inside the fuse, so a hand-closed door leaves the book
  saying "Nothing is currently wrong" while the amulet is sealed away. **And the
  ending describes a world that isn't there:** `amulet.after(.take)` is unbranched and
  inventories "the warded door unbound, the wall dispersed" with either or both
  standing again.
- **The niche never held the scroll it describes.** *Cause:* `scroll.starts(in:
  study)` puts it on the floor and `niche` is `scenery` without `container`, so
  `search niche` answers "You find nothing of interest" on the same turn `x niche`
  says a parchment rests there, and `look` lists the scroll as a loose floor item.
  And once `passwall` burns it, the describe ladder's `!scroll.isHeld` branch catches
  the *spent* state and re-advertises a parchment that no longer exists anywhere in
  the world — the "What it kept, you carry now" branch is only reachable while it is
  held.
- **`push wall` still points at a scroll that is ash.** *Cause:* `graniteWall.before(.open)`
  is a single unbranched `reply`, where `wardedDoor.before(.open)` twenty lines above
  it opens with an `isOpen` guard. The asymmetry between the two barrier rules is the
  bug.
- **`burn golem` denies what the spellbook just taught,** with a full mana pool and
  `trait(.combustible, true)` on the target.
- **The spellbook narrates a read that never happened.** Cast `glow` without opening
  the book and the *first* read says "You put the question of doors to the book a
  second time, and this time it relents" — the ladder is keyed on world state, and
  rung 3's copy claims a read history it can't check.
- **About forty nouns the prose prints are outside the vocabulary,** including
  `warding-marks` — the noun the whole first puzzle is about, printed in six separate
  passages — and `hook`, where the amulet has hung since the intro, unknown in the one
  room that contains it. `desk` fails too, and the intro's last sentence is the game's
  one instruction to the player.
- **`x master's spellbook` — the exact phrase the intro prints — answers `I don't know
  the word "master"`.** *Cause:* `tokenize` splits on every non-alphanumeric, so the
  declared adjective `master's` enters the vocabulary as a string no token can equal.
  Two entities carry it. This one is the engine's.

## Fixed

None. `fix: "none"` by design — this round drafted `docs/games/gramarye.md`, and until
it existed the harness clamped `fix` to `none` regardless.

## Filed, not fixed

30 findings, deduplicating to six classes across six issues.

| Issue | Class | Severity |
|---|---|---|
| [#98](https://github.com/heirloomlogic/gnusto/issues/98) | Two commands make the game unwinnable, silently — plus the three prose lies the same gap causes | **blocking** |
| [#99](https://github.com/heirloomlogic/gnusto/issues/99) | ~40 unanswerable nouns, `warding-marks` and `hook` among them | major |
| [#100](https://github.com/heirloomlogic/gnusto/issues/100) | The niche never held the scroll, and advertises it after it's ash | major |
| [#101](https://github.com/heirloomlogic/gnusto/issues/101) | Four lines that don't know the state they're printing in | major |
| [#102](https://github.com/heirloomlogic/gnusto/issues/102) | Engine: an apostrophe in an adjective makes it a word the tokenizer can never match | major |
| [#103](https://github.com/heirloomlogic/gnusto/issues/103) | Harness: blank lines in a command file reach the engine | note |

Why not fixed here: #87's deliverable is the design docs. #98 in particular is
explicitly `needs-human` — the verifier declined to pick between three incompatible
repairs, and it was right to. The fix rounds move to a follow-up PR.

## Routed elsewhere

Nothing. `routedIssues` carried [#88](https://github.com/heirloomlogic/gnusto/issues/88)
and [#85](https://github.com/heirloomlogic/gnusto/issues/85), derived fresh from the
open enhancement issues. Gramarye has one actor with no proper name, and the vandal
put the whole actor-directed stock set at it — `take/search/kiss/eat/attack/smell
golem`, `golem, hello` — and every one interpolated correctly, so #88's class is a
verified negative here rather than an untested blank. No finding turned on stub
reachability. `firebolt me` printing "the yourself" is adjacent to #88 but is the
game's own string, so it went to #101 rather than being routed.

## Refuted

15 refutations, and three of them are the ones this issue was filed to make possible.

| Kind | Claim | Refutation |
|---|---|---|
| **licensed-by-doc** | The Gallery's description doesn't reflect the door being sealed behind you | The doc specifies the Gallery's two states as wall-standing and wall-dispersed; the door is not one of its axes. |
| **licensed-by-doc** | `glow` in the Undercroft says "nothing hidden here" while the hidden amulet is in the room | The contract makes the amulet's reveal `firebolt`'s job, not `glow`'s — one obstacle per spell, in chain order. |
| **licensed-by-doc** | The golem's description names "the amulet's hook" while neither noun is addressable | The hook's absence is real and is #99; the *reveal* gating is contract-required. |
| required-by-contract | The open-door refusal points a trapped player at a spellbook they can't reach | The refusal is correct for its frame; the trap is #98, and pointing at the book is the contract's clue design. |
| characterization | The ending blames the player for the window, but `close window` answers "You can't close that" | The joke is that he never could have. Deliberate, and the window is contract-pinned as scenery. |
| characterization ×2 | The warded door "stands open on the gallery" read *from* the gallery | True of its frame — the door does stand open, and which side you read it from doesn't falsify it. |
| characterization | `down` and `out` share one refusal about the road | One sentence for two exits out of a tower is not a false sentence. |
| stock-behavior-by-design ×4 | Gramarye re-skins none of ~48 stub verbs; "The granite wall is closed" is terse | Register, not truth. `text.closedContainer` is correct for a `via:` item that isn't open. |
| frame-not-anchored | "The granite has already been opened; once was sufficient" is unreachable | The tester's own transcript reaches it; the code analysis was right and the conclusion wasn't. |
| misquoted-prose | Each spellbook rung re-narrates its discovery verbatim on re-read | Real, but the finding misquoted the line it objected to. |
| none ×3 | The Undercroft names no exit; the door's examine text is Study-centric | Omission is not assertion. |

Three of these — the first three — are refutations that could not have been made
before this branch. Without `docs/games/gramarye.md` the verifier's only recourse was
"you cannot tell authorial intent from the outside, so a finding that amounts to a
preference is refuted", which is a weaker instrument that rejects good findings along
with bad ones.

## Coverage

**Rooms** — 3 of 3. 40 of 62 transcripts reached the Gallery, 25 reached the
Undercroft, **11 won**. No off-map geography.

**Charters** — six run, none silent. **interrogator correctly skipped:** `content` is
`magic` alone, there is no `GnustoConversation`, the one actor has no topics and no
proper name. That is a clean absence, not an untested blank.

**Room × warded-door state** — commands issued in each cell:

| Door state | Study | Long Gallery | Undercroft |
|---|---|---|---|
| open, dormant (turns 1–2) | ✓ 200 | ✓ **4** | n/a |
| sealed by the fuse | ✓ 249 | n/a — the fuse guards on the player being in the Study | n/a |
| closed by the player's hand | ✓ 6 | ✓ 20 | **— reachable, never occupied** |
| re-opened by `unbar` | ✓ 54 | ✓ 138 | ✓ 136 |

**The Gallery-before-the-seal cell is four commands deep across the entire round** —
and it is the frame every first-time player who walks west on turn 1 occupies, and
where #98 lives. It was found anyway, which is the round's best result.

**Room × granite-wall state:**

| Wall state | Study | Long Gallery | Undercroft |
|---|---|---|---|
| granite standing | ✓ 500 | ✓ 84 | n/a |
| mist archway | ✓ 9 | ✓ 63 | ✓ 134 |
| re-closed by hand | — | ✓ 15 | ✓ 2 |

**Spell × room** — casts attempted:

| | Study | Gallery | Undercroft |
|---|---|---|---|
| glow | ✓ 42 | ✓ 1 | ✓ 2 |
| unbar | ✓ 80 | ✓ 3 | — |
| firebolt | ✓ 1 | ✓ 1 | ✓ 16 |
| passwall | ✓ 11 | ✓ 41 | — |
| memorize | ✓ 41 | ✓ 2 | — |
| rest | ✓ 2 | — | ✓ 2 |
| **`SPELLS`** | **—** | **—** | **—** |

**`SPELLS` was never typed once in 807 commands**, in the game whose stated purpose is
to demonstrate four casting paradigms. The critic checked it rather than leaving the
blank: 12/12 → `firebolt` → **8/12** → `rest` → 12/12, every line true. That confirms
the specific prediction `docs/games/gramarye.md` makes in its Open Question 1, and the
blank is not hiding a defect.

`firebolt` was cast at exactly two targets all round — `golem` 17×, `me` once. No
non-combustible scenery target was ever hit.

**Timer** — `doorSeals` exercised in both of its two reachable cells: fires in the
Study (24 transcripts), re-arms silently in the Gallery. The Undercroft cell is
structurally impossible.

**Stub verbs** — 27 of 64 typed. Never typed: `blow break cut destroy dive drag drink
empty feel fight fill hand hit hug kill kneel lick lie plugh point pour rotate rub
scream sell shout sit slice smash sniff squeeze stand swear throw tie untie wake`.

**Meta surface — entirely blank.** Zero occurrences of `undo`, `again`/`g`, `restart`,
`save`, `restore`, `version`, `verbose`, `brief`, `spells` across all 62 transcripts.
`wait`/`z` (82×) and `score` are the only meta commands touched. Note `undo` is the
*only* escape from #98, and nobody typed it.

**Evidence hygiene.** The survey's roll-ups do not survive contact with the
transcripts: it reported 4 unknown-word occurrences over 4 distinct words; ground
truth is **139 occurrences over 40 distinct words**, `hook` alone 17 times. And the
idiot charter's transcripts are 17/18 overwritten. Same cause as the Lighthouse round
— [#97](https://github.com/heirloomlogic/gnusto/issues/97), a flat label namespace
that concurrent charters overwrite. The clock-watcher, solver and re-reader kept clean
per-run labels and are fully audited; the tourist and the idiot are not.

**Dropped** — none for budget or non-reproducibility.

## Hygiene

Shared with the Lighthouse round of the same day — same branch, one set of numbers.
See [`lighthouse-playtest-2026-07-30.md`](lighthouse-playtest-2026-07-30.md#hygiene).
No game source was changed by this round.

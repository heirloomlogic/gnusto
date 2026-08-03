# KindlyDeep — playtest ledger

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

## 2026-08-02 — first round, `0b78ad8` (`fix: none`, nothing applied)

Ran with `docPath: null`: `docs/games/kindly-deep.md` does not exist, so the testers had
no design doc, no mechanics contract and no stated solution, and the harness clamped
`fix` to `none` regardless of what was asked for. Oracle tiers T0/T2/T3 only.

**Every `confirmed` row below is an open defect in the game as it ships, filed as #126.**
None was fixed in this round. The issue carries twenty boxes: the nineteen classes these
rows deduplicate to, plus one dead-content finding (The Old Works) that came from the
completeness critic rather than from a charter and so has no key here.

The game was one commit old when this round ran — `0b78ad8` is the only commit that has
ever touched `Sources/KindlyDeep/KindlyDeep.swift` — so every row is a birth defect. No
row here can be a regression, and the next round's first job is to check that none of
them has become one.

Two rows deserve a flag. The sentence "hauling is a trade with a professional standing
eight feet away" appears twice with opposite verdicts: **confirmed** under `push beam`
and **refuted** under `take beam`, because the `take` path was not reached in the frame
its finding cited. It is one defect; the confirmed row is the one to fix. And the
aggregate register complaint — "the game re-skins none of `GameText.stubs`" — was
**refuted twice** and then **confirmed once** in the narrower form that survives, which
is the individual stub lines that make a false claim about the room. Do not re-file the
aggregate.

| Key (abbreviated) | Verdict | Category |
|---|---|---|
| `KindlyDeep.swift::west the forks the clip of hooves catches up with you biscuit take…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::harness biscuit you back him up to the beam and hitch on and biscu…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::harness biscuit  the beam grinds off the gate an inch at a time un…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::x cage gate the gate the cage lands behind sound enough and perfec…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::east you get down on your hands and knees at the edge of the fall …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::search biscuit the biscuit would have something to say about that …` | confirmed | stock-line-not-reskinned |
| `KindlyDeep.swift::the low crawl rock above rock below rock pressing in from both sid…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::the entry forks here at the mouth of the old works north the old h…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::the entry ends abruptly in a wall of fallen rock and splintered ti…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::a timbered shelter hole cut into the rib where a man steps in when…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::whitewashed walls worn brick underfoot and the deep sweet smell of…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::there is a flint striker on your belt where it always is  dark of …` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::the cage gate stands in its frame  with a twelvefoot beam lying sq…` | confirmed | unanswerable-noun |
| `CLAUDE.md::claudemd17  sourcescloakofdarkness lighthouse zork1 gramarye fulminate  d…` | confirmed | doc-drift |
| `KindlyDeep.swift::ring bell you take the pull and ring  one long stroke and the soun…` | confirmed | mechanic-contradicts-prose |
| `KindlyDeep.swift::harness tack you back him up to the beam and hitch on and biscuit …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::rest you pinch the lamp out first  nobody sleeps next to an open f…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::turn off lamp the caplamp is now off it is now pitch black  look d…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::the weakness arrives all at once the way the roof did your knees g…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::your body done waiting sits you down against the rib for a moment …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::search corn bin you get a hand under the loose board and lift and …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::harness tack  the beam grinds off the gate an inch at a time until…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::open airdoor the door is jammed from the far side but from here th…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::take biscuit the biscuit would take exception to that  biscuit hel…` | confirmed | stock-line-not-reskinned |
| `KindlyDeep.swift::smell you smell nothing out of the ordinary  smell old works you s…` | confirmed | prose-untrue-of-frame |
| `KindlyDeep.swift::push beam you get your back under one end and achieve at considera…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::west the stable whitewashed walls worn brick underfoot and the dee…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::turn off lamp the caplamp is now off it is now pitch black  drop l…` | confirmed | unwinnable |
| `KindlyDeep.swift::take biscuit the biscuit would take exception to that  search bisc…` | confirmed | stock-line-not-reskinned |
| `KindlyDeep.swift::eat biscuit the biscuit is a person and would rather you didnt` | confirmed | prose-untrue-of-frame |
| `KindlyDeep.swift::i you are carrying a caplamp and a flint striker  x lamp your capl…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::the forks the entry forks here at the mouth of the old works north…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::east you get down on your hands and knees at the edge of the fall …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::biscuit walks straight past his own stall  underneath where a man …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::dark of the sort found only underground complete unhurried and inc…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::the entry ends abruptly in a wall of fallen rock and splintered ti…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::x walls i dont know the word walls  x brick i dont know the word b…` | confirmed | unanswerable-noun |
| `Actions/GameText.swift::eat rails the rails is not food` | confirmed | stock-line-not-reskinned |
| `KindlyDeep.swift::turn off lamp the caplamp is now off it is now pitch black  drop l…` | confirmed | unwinnable |
| `KindlyDeep.swift::the cage comes down singing on its guides and the cager steps out …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::east you get down on your hands and knees at the edge of the fall …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::take biscuit the biscuit would take exception to that and on stder…` | confirmed | stock-line-not-reskinned |
| `KindlyDeep.swift::ring bell you take the pull and ring  one long stroke and the soun…` | confirmed | mechanic-contradicts-prose |
| `KindlyDeep.swift::look the forks the entry forks here at the mouth of the old works …` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::the shelter hole a timbered shelter hole cut into the rib where a …` | confirmed | prose-untrue-of-frame |
| `KindlyDeep.swift::take biscuit the biscuit would take exception to that playtest std…` | confirmed | stock-line-not-reskinned |
| `KindlyDeep.swift::the entry ends abruptly in a wall of fallen rock and splintered ti…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::pet me there is nothing here that would care to be petted` | confirmed | prose-untrue-of-frame |
| `KindlyDeep.swift::give lamp to me there is no one here to give it to but yourself an…` | confirmed | prose-untrue-of-frame |
| `KindlyDeep.swift::east the airdoor stands in its frame  and past it the shaft  but t…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::a timbered shelter hole cut into the rib where a man steps in when…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::biscuit the mine mule stands close by dusty to the knees watching …` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::sing your singing is better kept to yourself  dig you have nothing…` | confirmed | register-mismatch |
| `KindlyDeep.swift::look the shaft bottom and here it is the shaft bottom the one door…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::x beam twelve feet of poplar lately part of the roof now lying acr…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::rest you pinch the lamp out first  nobody sleeps next to an open f…` | confirmed | repeat-behavior |
| `KindlyDeep.swift::z time passes your eyelids have taken on weight twice now you have…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::z time passes your lips have split there is an ache setting up beh…` | confirmed | prose-untrue-of-state |
| `KindlyDeep.swift::take biscuit the biscuit would take exception to that` | confirmed | stock-line-not-reskinned |
| `KindlyDeep.swift::drink canteen you work the stopper out and drink counting the way …` | confirmed | repeat-behavior |
| `KindlyDeep.swift::a timbered shelter hole cut into the rib where a man steps in when…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::whitewashed walls worn brick underfoot and the deep sweet smell of…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::x walls i dont know the word walls  x wall i dont know the word wa…` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::x stopper i dont know the word stopper` | confirmed | unanswerable-noun |
| `KindlyDeep.swift::the low crawl rock above rock below  the crawl runs east and west …` | refuted | exit-prose-mismatch |
| `KindlyDeep.swift::the entry forks here at the mouth of the old works north the old h…` | refuted | exit-prose-mismatch |
| `KindlyDeep.swift::sing your singing is better kept to yourself  dig you have nothing…` | refuted | register-mismatch |
| `KindlyDeep.swift::sing your singing is better kept to yourself  buy rails nothing he…` | refuted | register-mismatch |
| `Actions/StubVerbs.swift::ask biscuit about water i dont know the word ask  tell bisc…` | refuted | unanswerable-noun |
| `KindlyDeep.swift::rest you pinch the lamp out first  and lie down in the straw and l…` | refuted | prose-untrue-of-state |
| `KindlyDeep.swift::take beam you get your back under one end and achieve at considera…` | refuted | prose-untrue-of-state |
| `KindlyDeep.swift::talk to lamp you say a few words into the dark the dark profession…` | refuted | prose-untrue-of-state |
| `KindlyDeep.swift::x me you look much as you always do  x myself you look much as you…` | refuted | register-mismatch |
| `KindlyDeep.swift::east the low crawl  east the shaft bottom biscuit walks in and sta…` | refuted | repeat-behavior |
| `KindlyDeep.swift::east the airdoor stands in its frame  and past it the shaft   x ai…` | refuted | exit-prose-mismatch |

## 2026-08-03 — #126 fixed, `e148364`..HEAD

Every `confirmed` row in the 2026-08-02 section above is now **fixed**. Rather than
restate sixty-odd abbreviated keys — which would give the loop two rows per defect to
argue with — this section is the verdict change, and it applies to all of them.

**So every one of those keys is now a tripwire.** A line from that round appearing in a
transcript again is a **regression**, not a new finding, and goes back at raised
severity. Pass the whole 2026-08-02 confirmed set into `ledgerKeys` alongside the
refuted ones.

The `refuted` rows are unchanged and stay refuted. In particular the two
`exit-prose-mismatch` rows about the air-door were right to be refuted: the door
swings one way by design, the player's route east is the crawl in every state, and the
prose was what needed fixing, not the map.

Three rows deserve a note on *how* they closed, because the shape of the fix is not
what the row's category suggests:

| Key (abbreviated) | Closed by |
|---|---|
| `Actions/GameText.swift::eat rails the rails is not food` | Not a re-skin. A `plural` trait in the engine, beside `properName`, and seven stub lines that take a `GameText.Noun` and conjugate for themselves. The game's noun stayed plural, which was its stated position. |
| `KindlyDeep.swift::sing your singing is better kept to yourself  dig you have nothing…` (confirmed) | A ten-line `text.stubs` block, deliberately narrow. The **refuted** rows with the same opening text are the aggregate complaint and stay refuted; do not re-file it. |
| `KindlyDeep.swift::ring bell you take the pull and ring…` (both rows) | A second ending rather than a guard. Abandonment is still permitted and now has its own four paragraphs; it forfeits exactly the two awards the mule earns. |

One finding closed that has no key here, because it came from the completeness critic
rather than a charter: **The Old Works is dead content.** It is reachable now — one map
line, `shaftBottom.down(lowCrawl)` — with a description of its own, and its gas death
fires. A future round can and should probe north from the Forks after coming up out of
the crawl from the east.

And one thing the round did not find, which the fix did: the Old Works' `onEnter` kills
on arrival, and `onEnter` runs *before* the room is auto-described, so the room's new
description would never have printed. It calls `describeSurroundings()` first. Worth
knowing, because it is a trap any lethal room in any game walks into.

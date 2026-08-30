# Lighthouse — playtest ledger

Append-only. One row per dedupe key the harness has ever seen, with what became of it.

This is the loop's memory, and it exists for two reasons. Without it, a round
rediscovers everything a previous round already rejected, forever — the harness argues
with itself instead of converging. And with it, a key marked `fixed` that shows up again
is not a new finding, it is a **regression**, and it goes back at raised severity.

Pass `ledgerKeys` into the workflow with every key below whose verdict is `refuted`,
and only those. A `fixed` key carries the opposite instruction: it is meant to come
back, at raised severity, so passing it suppresses the regression this file exists to
catch. `ledgerScan` in `bin/lib/playtest-focus.js` reads the verdict column and enforces
that.

The key is the declaration that emits the offending prose — `decl::<file>::<name>` —
with the frame deliberately excluded, because one untrue sentence seen in two frames is
one defect and keying on the frame would dispatch two fixers at one branch. A finding
the round cannot locate falls back to `<ownerFile>::<normalized excerpt>`.

**Never write a key abbreviated.** A round matches keys against `normalize()`, which
emits nothing but `[a-z0-9 ]`, so a stored key holding an ellipsis can never equal a
produced one. It is inert, and a file full of them looks exactly like a game nothing has
ever been refuted about. Every key below was once written that way; preflight's `ledger`
row now fails rather than quietly reporting zero.

## 2026-07-30 — first round, `4aae966` (`fix: none`, nothing applied)

Ran with `docPath: null`: this is the round that drafted `docs/games/lighthouse.md`,
so the testers had no design doc and the harness clamped `fix` to `none` regardless of
what was asked for. Every confirmed row below is an **open defect in the game as it
ships**, filed as #91–#97. None was fixed in this round.

Caveat on the evidence, recorded because it affects how much these rows can be trusted:
concurrent charters overwrote each other's transcripts (#97), so about two thirds of
the round's probe directories no longer hold the transcript they were cited for. Every
row marked `confirmed` was replayed cleanly by its verifier before filing; the rows'
*claims* are sound, their *cited paths* mostly are not.

Two rows deserve a flag. The keeper's "stands by the window" line was **confirmed by
one verifier and refuted by another** — the refutation holds for the Lamp Room (glass
walls, open to the night) and not for the Base (a round stone room). It is carried in
#91 as a partial. And the beacon's unreachable lit `describe` branch was refuted twice
as "not false of any frame" while being confirmed once as `doc-drift`; all three agree
on the fact, so it is filed as the design call #95 rather than as a defect.

| Key (abbreviated) | Verdict | Category |
|---|---|---|
| `Lighthouse.swift::up lamp room glass walls wrap the top of the tower open to the night on every…` | confirmed | exit-prose-mismatch |
| `Lighthouse.swift::base of the lighthouse the round stone room at the foot of the tower a shelf…` | confirmed | presence-line-location-blind |
| `Lighthouse.swift::take key taken look base of the lighthouse the round stone room at the foot…` | confirmed | prose-untrue-of-state |
| `Lighthouse.swift::a short stone jetty runs out from the foot of the lighthouse to the mooring…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::the round stone room at the foot of the tower a shelf is set into the wall…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::a cramped space that smells of tar and brine coils of rope and a heavy chest…` | confirmed | unanswerable-noun |
| `Tower.swift::lamp room glass walls wrap the top of the tower open to the night on every…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::the old keeper stands by the window favoring one leg x window i dont know the…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::turn on beacon the beacons reservoir is dry youll want the oil from the…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::x key a stubby brass key green at the teeth x teeth i dont know the word…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::talk to keeper the old keeper turns from the window storm doused the beacon…` | confirmed | prose-untrue-of-frame |
| `Lighthouse.swift::z time passes the oil lamps flame sinks to a sullen flicker i you are…` | confirmed | prose-untrue-of-frame |
| `Lighthouse.swift::look base of the lighthouse the round stone room at the foot of the tower a…` | confirmed | prose-untrue-of-state |
| `Lighthouse.swift::north the old keeper stands by the window favoring one leg x window i dont…` | confirmed | unanswerable-noun |
| `Tower.swift::x beacon the great brass beacon is cold and dark its oil reservoir bone dry…` | confirmed | doc-drift |
| `Lighthouse.swift::look lamp room glass walls wrap the top of the tower open to the night on…` | confirmed | mechanic-contradicts-prose |
| `Lighthouse.swift::x can a tin can heavy with lamp oil pour can theres nothing in the oil can to…` | confirmed | prose-untrue-of-state |
| `Lighthouse.swift::burn lamp you have no way to set fire to the oil lamp light lamp the oil lamp…` | confirmed | mechanic-contradicts-prose |
| `Lighthouse.swift::swim theres nothing here to swim in cold water sluices between the planks of…` | confirmed | prose-untrue-of-frame |
| `Lighthouse.swift::x boat i dont know the word boat x mooring i dont know the word mooring x sea…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::i you are carrying a brass key look base of the lighthouse the round stone…` | confirmed | prose-untrue-of-state |
| `Lighthouse.swift::jetty a short stone jetty runs out from the foot of the lighthouse to the…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::lamp room the old keeper stands by the window favoring one leg talk to keeper…` | confirmed | prose-untrue-of-state |
| `Lighthouse.swift::drop can dropped turn on beacon the beacons reservoir is dry youll want the…` | confirmed | mechanic-contradicts-prose |
| `Lighthouse.swift::talk to me i didnt understand that sentence cold water sluices between the…` | fixed | mechanic-contradicts-prose |
| `Lighthouse.swift::take brass key taken look base of the lighthouse the round stone room at the…` | confirmed | prose-untrue-of-state |
| `Lighthouse.swift::the old keeper stands by the window favoring one leg the keeper limps away up…` | confirmed | unanswerable-noun |
| ~~`Lighthouse.swift::the keeper climbs stiffly into the room x keeper you see nothing special…`~~ | refuted | unanswerable-noun |
| ~~`Lighthouse.swift::lamp room glass walls wrap the top of the tower open to the night on every…`~~ | refuted | presence-line-location-blind |
| ~~`Lighthouse.swift::x me you look much as you always do the keeper climbs stiffly into the room…`~~ | refuted | mechanic-contradicts-prose |
| ~~`Lighthouse.swift::z time passes the keeper climbs stiffly into the room score your score is 0…`~~ | refuted | prose-untrue-of-frame |
| `decl::Sources/Gnusto/Actions/GameText.swift::stubs.sing` | refuted | register-mismatch |
| ~~`Lighthouse.swift::relight the beacon before the tide comes in light her again before the tides…`~~ | refuted | mechanic-contradicts-prose |
| ~~`Lighthouse.swift::the old keeper stands by the window favoring one leg x keeper you see nothing…`~~ | refuted | stock-line-not-reskinned |
| `decl::Sources/Lighthouse/Lighthouse.swift::jetty` | refuted | mechanic-contradicts-prose |
| `decl::Sources/Lighthouse/Tower.swift::beacon` | refuted | mechanic-contradicts-prose |
| `decl::Sources/Gnusto/Actions/GameText.swift::nothingToSearch` | refuted | mechanic-contradicts-prose |
| `decl::Sources/Lighthouse/Tower.swift::beacon` | refuted | mechanic-contradicts-prose |
| ~~`Lighthouse.swift::x keeper you see nothing special about the lighthouse keeper attack keeper…`~~ | refuted | register-mismatch |
39 distinct keys from 42 findings — the dedupe key is the normalized excerpt, so the
same defect quoted with a different surrounding line survives as a separate key. Five
refutations in this round were the same claim re-argued from scratch for a second or
third charter. Worth tightening before a round runs with `fix: "game"`.

## Provenance

The marquee defect — the keeper's direction-blind departure line — arrived with the
game and has never been touched:

```
git log -S 'limps away up the stairs' --oneline -- Sources/Lighthouse/Lighthouse.swift
  64a79ee Add "The Lighthouse" — a feature-showcase example (#50) (#56)
```

Nothing in this round was introduced by an earlier fix. Lighthouse has never had a
playtest round before this one.

## Amendments

**2026-07-30 — `talk to me` marked `fixed`.** Fixed in the engine, not in Lighthouse.
An intent nothing answers now reaches stage 4's last resort as
`TurnInterrupt.unhandled`: it says "You can't do that." instead of claiming a parse
failure, and it costs no turn, so the three commands that drowned a tester on the jetty
no longer move the tide. Lighthouse's own source is unchanged — answering `.talk` with
a rule on the keeper and leaving every other noun to the fall-back was never the defect.
Regression cover: `LighthouseTranscriptTests.talkingToNobodyOnTheJettyCostsNoTurn`. See
[#96](https://github.com/heirloomlogic/gnusto/issues/96).

**2026-07-31 — every `confirmed` row above marked `fixed`.** The game was reconciled
with the rewritten `docs/games/lighthouse.md` and #91–#95 closed in one change. Pass
all of these keys as `ledgerKeys` on the next round: a `fixed` key that comes back is a
regression, not a finding.

What the rows became, by class:

| Class | What was done | Cover |
|---|---|---|
| `exit-prose-mismatch`, `presence-line-location-blind` — the keeper's stair lines | Both rewritten direction-neutral. `ActorBehaviors.roams` has one arrival and one departure line for the whole room set, so there was no per-room seam to use. | `theKeepersStairLinesNameNoDirection` |
| `prose-untrue-of-frame` — the briefing | Rewritten to name where the key and the oil *are* and never where she is standing or what the player already holds, so it needs no branch. | `keeperBriefsOnceThenReminds` |
| `prose-untrue-of-state` — the shelf | `firstSight` deleted. The engine's own surface listing is the announcement and it stops with the key. | `theShelfStopsAnnouncingTheKeyOnceItIsTaken` |
| `prose-untrue-of-frame` — both lamp fuses | Each `say` guarded on the lamp being held or in the player's room. The state change stays unconditional. | `theLampBurnsDownQuietlyWhenYouCannotSeeIt` |
| `prose-untrue-of-state` — the takeable chest | `chest.before(.take)` refuses. | `theChestWillNotBeCarriedOut` |
| `unanswerable-noun` (11 rows) | Eight scenery items in a new `Fixtures` bundle plus three in `Tower`, and synonyms on the existing items for the parts their own descriptions name. | `theJettyAnswersToItsOwnDescription`, `theBaseAndStoreroomAnswerToTheirOwnDescriptions`, `theLampRoomAnswersToItsOwnDescription`, `theKeeperAnswersToHerselfAndHerLeg` |
| `mechanic-contradicts-prose` — `pour`/`empty`, `burn` | Promoted per entity with `refuse`/`reply`. The other ~47 stubs still answer in the engine's voice; that is register, and it is carried as an open question in the design doc rather than fixed. | `pouringTheCanTheGameCallsFull`, `burnAndLightAgreeAboutTheLampAndTheBeacon` |
| `prose-untrue-of-frame` — `swim` on the jetty | `jetty.before(.swim, .dive)` refuses. | `theSeaIsThereWhenYouTryToSwimInIt` |
| `mechanic-contradicts-prose` — `drop can` then `turn on beacon` | The predicate stays `isHeld`; the refusal now names your hands rather than the storeroom. | `theFuelGateNamesYourHandsNotTheStoreroom` |
| `doc-drift` — the beacon's lit `describe` branch | `isLit` set before `end(won:)`. Not reachable by an examine — the game is over — but the branch and the doc comment are honest, and the save state is. | `theBeaconIsLitWhenTheGameEnds` |

Two of the round's `refuted` rows changed anyway, and neither is a reversal. `x keeper`
answered the engine's stock "nothing special" line, correctly and by design; the keeper
now has a description because #92 needed `leg` to answer and a stock line was a poor
place to send it. The tagline row was refuted as licensed-by-doc; the rewritten design
doc retired the tagline on its own terms.

The `refuted` rows on register (`sing`, `jump`, `attack keeper`) stand refuted, and the
design doc now says so in writing, so the next round can cite it rather than re-argue
it.

**2026-08-30 — the twelve `refuted` rows re-keyed on their declarations.** Every key in
the round above was written in the abbreviated display form, and an abbreviated key is
inert: a round matches against `normalize()`, which emits nothing but `[a-z0-9 ]`, so
none of these could ever equal a key a round produced. Lighthouse's dedupe set has been
empty since the day it was written. See
[#351](https://github.com/heirloomlogic/gnusto/issues/351).

The full excerpts are not recoverable — the round report quotes claims, not transcripts —
so the rows are re-keyed on the declaration that emits the line, the form the harness has
produced since declaration clustering landed. Five were re-keyed, onto four distinct
declarations, each checked against the current source and against a replay. Seven are
struck: a struck row keeps its reading record and hands the round nothing.

Every one of the seven is struck for the same reason, and it is the 2026-07-31 pass
rather than a gap in the archaeology. The keeper's stock "You see nothing special" cannot
print any more — #92 needed `leg` to answer, so she has a description of her own. Her
stair lines are direction-neutral, so "the keeper climbs stiffly into the room" is gone
and takes three rows with it. And the tagline that promised a tide deadline was retired
on the design doc's own terms. A row whose sentence no longer exists has nothing to key
on and nothing to suppress.

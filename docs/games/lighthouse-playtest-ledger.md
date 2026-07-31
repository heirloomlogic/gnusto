# Lighthouse — playtest ledger

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
| `Lighthouse.swift::talk to me i didnt understand that sentence cold water sluices between the…` | confirmed | mechanic-contradicts-prose |
| `Lighthouse.swift::take brass key taken look base of the lighthouse the round stone room at the…` | confirmed | prose-untrue-of-state |
| `Lighthouse.swift::the old keeper stands by the window favoring one leg the keeper limps away up…` | confirmed | unanswerable-noun |
| `Lighthouse.swift::the keeper climbs stiffly into the room x keeper you see nothing special…` | refuted | unanswerable-noun |
| `Lighthouse.swift::lamp room glass walls wrap the top of the tower open to the night on every…` | refuted | presence-line-location-blind |
| `Lighthouse.swift::x me you look much as you always do the keeper climbs stiffly into the room…` | refuted | mechanic-contradicts-prose |
| `Lighthouse.swift::z time passes the keeper climbs stiffly into the room score your score is 0…` | refuted | prose-untrue-of-frame |
| `Lighthouse.swift::sing your singing is better kept to yourself jump you jump on the spot…` | refuted | register-mismatch |
| `Lighthouse.swift::relight the beacon before the tide comes in light her again before the tides…` | refuted | mechanic-contradicts-prose |
| `Lighthouse.swift::the old keeper stands by the window favoring one leg x keeper you see nothing…` | refuted | stock-line-not-reskinned |
| `Lighthouse.swift::south jetty the sea closes over the jetty and over you you have died your…` | refuted | mechanic-contradicts-prose |
| `Tower.swift::source sourceslighthousetowerswift beacondescribe beaconislit the beacon…` | refuted | mechanic-contradicts-prose |
| `DefaultActions.swift::a brass key lies on the stone shelf on the stone shelf is a brass key the old…` | refuted | mechanic-contradicts-prose |
| `Tower.swift::turn on beacon you tip the last of the oil into the beacons reservoir and…` | refuted | mechanic-contradicts-prose |
| `Lighthouse.swift::x keeper you see nothing special about the lighthouse keeper attack keeper…` | refuted | register-mismatch |
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

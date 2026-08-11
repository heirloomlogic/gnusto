# Dungeon — playtest ledger

Append-only. One row per dedupe key the harness has ever seen, with what became of it.

This is the loop's memory, and it exists for two reasons. Without it, a round rediscovers
everything a previous round already rejected, forever — the harness argues with itself
instead of converging. And with it, a key marked `fixed` that shows up again is not a new
finding, it is a **regression**, and it goes back at raised severity.

Pass `ledgerKeys` into the workflow with every key below whose verdict is `refuted` or
`fixed`.

The key is `<ownerFile>::<normalized offending text>`, with the frame deliberately
excluded — one untrue sentence seen in two frames is one defect, so keying on the frame
would dispatch two fixers at one branch. Keys are abbreviated here for reading; the full
ones are in the round reports.

## 2026-08-11 — first round, `0080053` (`fix: none`, nothing applied)

Ran at **seed 2**, not the harness default 0. Seed 2 is the seed
`DungeonWalkthroughTests` pins its 716-point route to, and the route is the only way a
tester reaches the volcano, the Royal Puzzle or the Endgame inside a round's budget — the
far side of this game is two hundred correct commands from the front door. A prefix
replayed at another seed lands somewhere else, quietly. Any round that wants the deep
regions has to pin 2 as well, or re-derive its own route.

Oracle tiers T0/T1/T2/T3 — all four, unlike KindlyDeep's first round: `docs/games/dungeon.md`
exists and carries the mechanics contract, which is what let the verifiers refute on "the
doc licenses this" rather than on "you cannot tell intent from outside".

**Every `confirmed` row below is an open defect in the game as it ships, filed as #233.**
None was fixed in this round; #190 required `fix: "none"`, because the failure mode is a
plausible wrong fix in a suite where `DungeonTests.swift` alone is 3,974 lines of
substring assertions lifted from the prose. The issue carries fifteen boxes: the fourteen
classes these rows deduplicate to, plus one harness box that came from the completeness
critic rather than from a charter and so has no key here.

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
| `Sources/Dungeon/Regions/Prose+House.swift::open window opened  west kitchen y…` | confirmed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Prose+Mirror.swift::look round room this is a circula…` | confirmed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/AboveGround.swift::up up a tree you are about 10 feet…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/Prose+AboveGround.swift::down rocky ledge you are on …` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/AboveGround.swift::east behind house you are behind t…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::you are behind the white house a p…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/House.swift::x passage you cant see any such thing  w…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/House.swift::cellar you are in a dark and damp cellar…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/RoundRoom.swift::round room this is a circular stone …` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::west of house you are standing in …` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/Prose+AboveGround.swift::founded in antiquity by will…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::east clearing you are in a clearin…` | confirmed | mechanic-contradicts-prose |
| `Sources/Dungeon/Dungeon.swift::north you set off confidently and the room tur…` | confirmed | doc-drift |
| `Sources/Dungeon/Regions/House.swift::drop lamp dropped  east it is pitch blac…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/Dam.swift::light match one of the matches starts to b…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/CoalMine.swift::west smelly room this is a small nond…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/CoalMine.swift::down gas room this is a small room wh…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Dungeon+Palantir.swift::take timber taken  i you are carrying…` | confirmed | mechanic-contradicts-prose |
| `Sources/Dungeon/Systems.swift::dam  the sluice gates on the dam are closed be…` | confirmed | mechanic-contradicts-prose |
| `Sources/Dungeon/Systems.swift::swim swimming would be a brief and unrewarding…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Prose.swift::greet troll the troll nods and says nothing the …` | confirmed | stock-line-not-reskinned |
| `Sources/Dungeon/Regions/Dam.swift::stream view  a coil of thin shiny wire lie…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Prose+Systems.swift::swim swimming would be a brief and unrew…` | confirmed | register-mismatch |
| `Sources/Dungeon/Regions/Prose+Volcano.swift::look volcano near wide ledge in …` | confirmed | exit-prose-mismatch |
| `Sources/Dungeon/Regions/Volcano.swift::wide ledge you are on a wide ledge hig…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/RoyalPuzzle.swift::this is a small square room and in…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/Volcano.swift::x rim a shelf of old rock wide enough …` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/RoyalPuzzle.swift::mm ss west mm   east  ss   x openi…` | confirmed | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/Volcano.swift::give coin to gnome thank you very much…` | confirmed | exit-prose-mismatch |
| `Sources/Dungeon/Regions/Prose+Volcano.swift::this must have been a large libr…` | confirmed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Prose+House.swift::open window opened  x window the w…` | confirmed | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/Prose+Bank.swift::vault this is the vault of the bank…` | confirmed | prose-untrue-of-frame |
| `Sources/Dungeon/Regions/Bank.swift::this is a large rectangular room the east…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/Prose+Maze.swift::i you are carrying a jewelencrusted…` | confirmed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/AboveGround.swift::behind house you are behind the wh…` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::you are standing in an open field …` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/AboveGround.swift::north of house you are facing the …` | confirmed | unanswerable-noun |
| `Sources/Dungeon/Regions/House.swift::open window opened  enter window you can…` | confirmed | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/Endgame+MirrorBox.swift::push pine the pine wall swin…` | confirmed | mechanic-contradicts-prose |
| `Sources/Dungeon/Regions/Prose+EndgameMechanics.swift::push pine the pine wall…` | confirmed | prose-untrue-of-state |
| `Sources/Dungeon/Dungeon+Endgame.swift::drop sword dropped the blue light goes…` | confirmed | prose-untrue-of-state |
| `Sources/Dungeon/Regions/Endgame+Master.swift::knock on door beside the temple…` | confirmed | repeat-behavior |
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

Counts: 42 confirmed, 13 refuted, 0 routed, 0 fixed, 0 dropped. 55 verifications
over 57 probes; every finding was replayed from a clean start by its own tester and again
by an adversarial verifier from a different charter.

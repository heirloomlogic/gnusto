# Dungeon — playtest round, 2026-08-18

Commit `bd5f79b` · seed `52` · charters: explorer ×3, timekeeper ×3, solver, wrong-footer
(interrogator filtered itself out — no `GnustoConversation`). Oracle tiers: T0 kernel, T1
`docs/games/dungeon.md`, T2 `DungeonWalkthroughTests`, T3 source (MDL/ZIL), T4 ledger — all
five. `verifyEffort` inherited, not turned down. Budget: 200 turns per charter planned;
**~18,884 counted off the artifacts** (3,393 in session transcripts, 703 in rewound
branches, 7,142 in MCP verifier replays, 7,646 in CLI replay probes the collator cannot
see — see Coverage). 52 findings, **42 confirmed** (29 unanimous, 13 `needs-human`), 10
refuted, 0 routed.

**The 39 `fixed` keys from the 2026-08-11 round were withheld from `ledgerKeys`**, and only
the 13 `refuted` ones were passed. A `fixed` key feeds `seen` and would have made the
harness drop a regression in silence. Nothing in this round matched any of the 13 — they
are all display-truncated with `…`, which `normalize()` can never emit, so their only live
effect was deterrence in the sighted prompts.

**The completeness critic rates this round `round-is-thin`, and it is right.** Read the
Coverage section before treating 42 confirmed findings as a thorough pass. Three region
prefixes pointed six of eight testers at three regions; five regions came back all-blank or
near-blank, and the game's principal NPC was dead in every session by move 48.

## The round

Every one of the 42 is `preexisting`; the verifiers dated each against `git log -S` and not
one arrived with a recent fix. No row is a regression.

### A static `description` that never learns the state changed — 10 sites

This is `docs/games/dungeon.md`'s rule 1, and it is the round's largest class. A trait is a
constant; the state behind it moves; the two channels then disagree inside one frame.

- **The glass bottle says it is "stoppered" while it is open.** *Frame:* Kitchen, moves 8,
  one turn after `open bottle` printed "reveals a quantity of water". *Cause:*
  `description(Prose.bottle)` at `House.swift:132` with no `isOpen` branch. The well puzzle
  requires the bottle opened, so the false state is the normal one for most of the game.
- **The white crystal sphere describes itself "resting on a low pedestal" while you hold
  it inside the steel cage.** *Frame:* Cage, moves 334, on the turn after the take that
  springs the trap. *Cause:* flat `description(Prose.sphere)` at `Alice.swift:369`. The
  event that falsifies the sentence is the only event that lets a player read it.
- **`x water` in the drained Reservoir claims a billion and a half cubic feet of it "between
  you and the north shore".** *Frame:* Reservoir, moves 54, gates open, the room's own
  heading calling it "a large mud pile"; the player walks north across the bed next turn.
  *Cause:* `reservoirWater` at `Dam.swift:382` is flat, while the two neighbouring rooms'
  water items already carry the state-aware line. The branch exists one room over.
- **`x buoy` answers with the room-listing sentence "There is a red buoy here" while the buoy
  is in your hands.** *Frame:* Frigid River, moves 73, afloat. *Cause:* `River.swift:194`
  passes one constant, `Prose.buoy`, to **both** `firstSight(…)` and `description(…)`. Per
  K1 that is the listing channel doing the examine channel's job, and the word "here" is
  location-blind by construction.
- **`x spirits` still calls them a present, gloating crowd after the exorcism drove them
  through the walls.** *Frame:* Entrance to Hades, moves 151, one turn after `read book`.
  *Cause:* flat `description(Prose.spirits)` at `Temple.swift:419`, while the room's own
  describe rule at `:566` does branch on `spiritsBanished`. Two channels, one fact,
  disagreeing in the same frame.
- **The Entrance to Hades goes on printing "evil spirits, who jeer at your attempts to pass"
  one turn after the game said they stopped jeering.** *Frame:* Entrance to Hades, moves
  139, `exorcismStage == 1`. *Cause:* the room's describe branches on `spiritsBanished`
  alone, so the whole six-turn ceremony prints the untouched paragraph. It also makes
  "resume their hideous jeering" in the lapse line describe a stop that never appeared.
- **The candles' examine text is identical lit and out, and nothing anywhere says they are
  alight when found.** *Frame:* Altar, moves 133 and 136. *Cause:* `startsLit` with a static
  `description(Prose.candles)` and no `firstSight` (`Temple.swift:324`). The mainframe's
  `CANDL` carries `ODESCO "On the two ends of the altar are burning candles."` and Dungeon
  dropped it, so the only evidence of a flame is a refusal. (`needs-human`.)
- **`x leak` still has the leak dripping "and never quite stopping" after the pool went up in
  steam.** *Frame:* Pool Room, moves 357, on the turn after the room said the steam took the
  leak with it. *Cause:* the room is a branched `describe { }` (`Alice.swift:612`); the leak
  under it is a static `description` (`Alice.swift:263`). The #233 sweep reached the room and
  not the scenery item inside it.
- **`x grating` says it is "fastened … with a heavy lock" after it has been unlocked and
  opened — from below and from above alike.** *Frame:* Grating Room, moves 35, and the
  Clearing, whose own listing says "There is an open grating". *Cause:*
  `grating.describe` (`Dungeon.swift:812`) branches on **which side you stand on** and
  nothing else; both constants assert the lock. The room describers three lines above in the
  same file do read `isOpen`/`isLocked`.
- **Inside the mirror box, `out` says every wall is shut on the turn after the pine wall
  swung open.** *Frame:* Inside Mirror, moves 775, berth 1, bearing northwest. *Cause:*
  `leaveTheBox()` (`Endgame+Box.swift:192`) reuses `Prose.boxNoWayOut` for two different
  facts — no opening at all, and an opening that faces a corner. `Prose.beyond(_:)` already
  exists for the second and `push pine` used it one turn earlier.

### `shrunk` outlives death, and seals the Alice wing — 1 site

- **After dying shrunk and being resurrected at full size above ground, the game still
  narrates the player as four inches high.** *Frame:* Behind House, moves 338, broad
  daylight, standing on the grass; `read blue cake` prints "Now that you are the size of a
  mouse…". *Cause:* `DungeonAlice.shrunk` (`Alice.swift:113`) is cleared only by
  `orangeCake.before(.eat)`, which requires the Posts Room; `Dungeon.onDeath()`
  (`Dungeon.swift:296`) scatters the inventory and relocates the player and never touches
  the flag. The knock-on is worse than the sentence: `eatMeCake.before(.eat)` guards on
  `!shrunk`, so the cake can never be eaten again and the shrunken world — with the tin of
  rare spices in it — is closed for the rest of the game.

### One scenery item owns every noun the room prints — 7 sites

A room declares a single wide-synonym scenery blob, so an examine of any printed noun
answers about something else. Four separate declarations, one habit.

- **`x cave` at Rocky Shore answers with the Frigid River's description** — for a cave mouth
  the room names and `northwest` really enters. *Frame:* Rocky Shore, moves 65; `northwest`
  reaches Small Cave on the next turn. *Cause:* `riverAtRockyShore` (`River.swift:360`) owns
  `cave`, `mouth` and `entrance`, and is the room's only scenery.
- **`x path` at White Cliffs Beach answers that the cliffs cannot be climbed** — about the
  room's one working exit. *Frame:* White Cliffs Beach (north), moves 59. *Cause:*
  `cliffsAtNorthBeach` (`River.swift:363`) claims `path` and `beach`.
- **`x path` at Aragain Falls answers with the 450-foot waterfall.** *Frame:* Aragain Falls,
  moves 69; `north` is the real exit. *Cause:* `fallsAtFalls` (`River.swift:382`) claims
  `path` and `end` — the two words the room uses for its only way out.
- **`x beach` at End of Rainbow describes a rainbow** — the ground under the player's feet.
  *Frame:* End of Rainbow, moves 10. *Cause:* `rainbowAtEndOfRainbow` (`River.swift:376`)
  claims `beach`, `cliffs` and `falls`.
- **`x forest` at Canyon View says it is "too far off to make out more than the shape"** —
  the player walked out of it one turn earlier and it is an ordinary exit west and south.
  *Frame:* Canyon View, moves 6, six moves into a clean game. *Cause:* one
  `distantViewAtTop` item (`AboveGround.swift:541`) answers `forest`, `rainbow`, `dam`,
  `cliffs` and `river` with one paragraph.
- **`x crack` at Top of Well answers with the well's ring of etchings.** *Frame:* Top of
  Well, moves 328. *Cause:* `etchingsAbove` (`Alice.swift:162`) carries `crack` and `floor`
  as synonyms. A ring of letters carved round a shaft is not a crack across the floor.
- **`x machinery` in the Machine Room asks which of the three buttons you meant.** *Frame:*
  Machine Room, moves 330, first visit. *Cause:* `controls`/`machinery`/`bank` hang on all
  three buttons (`Alice.swift:331`/`339`/`347`) and no machinery item exists. The machinery
  is explicitly *behind* the buttons, so none of the three offered objects is the answer.

### A mechanic that contradicts its own prose — 6 sites

- **PUSH BARREL says "You can't move that", and entering it and walking north relocates it
  off the lip of Aragain Falls permanently.** *Frame:* Aragain Falls → Shore, moves 84–87.
  *Cause:* the barrel is `enterable` and the only immovability rule is `before(.take)`;
  nothing guards `.go`. The MDL has that guard — `BARREL` (`act2.mud:214`) answers
  `<VERB? "WALK">` with "You cannot move the barrel." — and the sibling bucket in
  `DungeonAlice` already carries it. (`needs-human`: the two raters split on whether
  `FIDELITY.md:1929`'s "the barrel is a vehicle" forecloses the fix.)
- **The boat's label says to keep broken sticks out of the boat, and a stick riding *inside*
  it is harmless down all five river stretches.** *Frame:* Dam Base → Shore, moves 53–62.
  *Cause:* the only puncture check is `magicBoat.before(.board)` reading `sharpStick.isHeld`
  (`River.swift:650`). The label states the rule as a property of the boat's contents, which
  is the one case nothing checks. (`needs-human`: `RBOAT-FUNCTION` (`act2.mud:243`) also
  guards only BOARD, so this is Zork I's variant versus the mainframe's.)
- **The rope tied to the Dome Room railing can be carried down and dropped, so the Torch Room
  prints it hanging and coiled at once, and UP refuses "You cannot reach the rope" while that
  rope lies at the player's feet.** *Frame:* Torch Room, moves 98. *Cause:* tying sets
  `ropeTiedToRailing` (`Dungeon.swift:510`) without moving or fixing the item, and the Torch
  Room's extra paragraph keys off that global. Line 99 of the committed winning route is
  `drop rope`, so the doubled state sits on the golden path at seed 52.
- **`robot, take sphere` narrates "the sphere is still in its hand" and leaves the sphere on
  the floor.** *Frame:* Dingy Closet, moves 391; the next `look` lists the sphere and `take
  sphere` answers "Taken." *Cause:* `sphere.before(.take)` (`Alice.swift:744`) ends in `try
  reply(…)`, which is `throws -> Never`, so the take is abandoned and nothing is transferred.
  The paragraph's last clause asserts a transfer the rule prevented one statement earlier.
- **The Studio chimney's examine says it "looks climbable", UP climbs it, and `climb chimney`
  answers "That is not something you could climb."** *Frame:* Studio, moves 14–16, three
  consecutive turns. *Cause:* the chimney (`Cellar.swift:167`) has no `.climb` rule, so CLIMB
  falls to the flat stub. CLIMB is not a dead verb here — the great tree, the Royal Puzzle
  ladder, the Palantir window and the mouse hole all answer it.
- **`take all` on turn one walks off with the small mailbox.** *Frame:* West of House, move
  1. *Cause:* `AboveGround.mailbox` declares `container` and `openable` and omits `scenery`;
  `MAILB` (`dung.355:5083`) has no `TAKEBIT`, and `Sources/Zork1/AboveGround.swift:77`
  declares the identical item *with* `scenery`. The consequence is a portable openable
  container from turn one, and the brochure fuse posts into wherever it was last set down.

### Nouns the prose prints that the parser denies — 4 sites

- **`x gas` in the Cage answers "You can't see any such thing."** *Frame:* Cage, moves 332,
  one turn after "A colorless gas begins to enter the cage through a vent in the floor."
  `x vent` is worse — 'I don't know the word "vent".' *Cause:* both nouns exist only inside
  the fuse body (`Prose+Alice.swift:477`). This is the reserved out-of-scope denial, aimed at
  the thing the game has just said is killing the player.
- **Digging at Sandy Beach prints "hole" twice and the parser then denies the word.** *Frame:*
  Sandy Beach, moves 79. *Cause:* the dig progression names a hole no item backs; `x sand`
  works, so the room does carry scenery.
- **The Round Room says "Your compass needle swings from one passage to the next" and the
  player has no compass.** *Frame:* Round Room, moves 132; the inventory is matchbook,
  screwdriver, trunk, lantern, bar, torch. *Cause:* Dungeon's own written-fresh line
  (`Prose+RoundRoom.swift:47`) asserts a possession that exists nowhere in the game and names
  two nouns nothing answers to.
- **The Viewing Room's sign prints "AN ADVANCED PROTECTIVE DEVICE", "THE BANK OFFICER" and
  "ALL CUSTOMERS", and none of the three is a word the parser knows.** *Frame:* West Viewing
  Room, moves 15; the sign is the whole of the room. *Cause:* the only declared scenery is
  the sign itself. (`needs-human`: one rater holds that the rule reaches nouns a room says
  are *present*, and a notice about absent people names none.)

### A fuse prints its line wherever the player walked to — 2 sites

The game's own rule, `docs/games/dungeon.md:1066`: "A fuse body that prints a line about an
object tests that the object is perceivable first." `burnCandleStage()` is the pattern; two
fuses in the same file never got it.

- **"The bell appears to have cooled down." prints two rooms and a staircase from the bell.**
  *Frame:* Narrow Crawlway, moves 160; the bell is on the floor at the Entrance to Hades.
  *Cause:* `fuse("bellCools", after: 20)` (`Temple.swift:701`) says its line with no
  perceivability test. "Appears to" is an observation verb.
- **The lapse fuse says the wraiths "resume their hideous jeering" three rooms and a
  staircase away from the wraiths.** *Frame:* Grail Room, moves 143. *Cause:*
  `fuse("exorcismLapse", after: 6)` (`Temple.swift:694`) — same shape, different
  declaration. The state change is right and must stay; only the `say` needs the guard.

### Two endgame lines untrue of the frame — 2 sites

- **The Guardians of Zork "stand in the hallway" the player is in, in a room whose own
  description ends "nothing else in it at all", and walking north into them is what kills
  you.** *Frame:* hallwayC, moves 776–778; `north` at moves 780 prints "*** You have died
  ***". *Cause:* a static `description` on an item the map deliberately places one room short
  of the Guardians' real position, written as though they are beside you. The mainframe never
  prints `GUARDSTR` bare — `act4.231:175` prefixes "Somewhat to the north". Dungeon dropped
  the distance marker in the only room the line can ever print in. (`needs-human`: the
  placement is a documented decision at `Endgame.swift:320` and the fix is a three-way fork.)
- **The crypt transition promises "one word will return you to it, and you have that word
  now"; there is no such word and no way back.** *Frame:* Top of Stairs, moves 761–763.
  *Cause:* `Prose.cryptTransition`'s own doc comment concedes it "names nothing typeable,
  because inventing a word the parser does not answer would be a defect" — and the result is
  the other half of that defect. `temple` and `treasure` both answer "Nothing happens."

### Stock lines in frames the game has its own words for — 4 sites

- **`climb rope` in the Torch Room answers "That is not something you could climb."**
  *Frame:* Torch Room, moves 99, one turn after `up` said "You cannot reach the rope."
  *Cause:* the rope has no `.climb` answer. `ROPE-AWAY` (`act3.199:1287`) sets `CLIMBBIT` on
  the tied rope so the mainframe walks the exit. (`needs-human`: one rater notes the parser
  binds the *coil on the floor*, and the finder's proposed fix would make a carried coil
  answer "You cannot reach the rope" everywhere.)
- **An order naming an object, given to a robot out of earshot, prints the bare stock "You
  can't see any such thing." about a cage the same player examines on the next line.**
  *Frame:* Cage, moves 390, gas fuse running — the exact sentence the puzzle asks for.
  *Cause:* the earshot skin is a `world.before` rule (`Alice.swift:673`) that runs only after
  the command parses, and an order's objects resolve in the absent addressee's scope. The
  direction-only `robot, go south` does reach the game's written refusal. (`needs-human`:
  engine-side or game-side fix, and the owner file is arguable.)
- **`geronimo` at Aragain Falls answers "there is nothing here to leap from"** — in the one
  room in the game that is a 450-foot drop. *Frame:* Aragain Falls, moves 451, on foot.
  *Cause:* `before(.geronimo)` returns early unless the player is in the barrel, dropping to
  the region catch-all. `GERONIMO` (`act2.92:375`) answers off-barrel with "Wasn't he an
  Indian?" — a joke that makes no claim about the place; the rewrite swapped a location-free
  punchline for a location claim and put it where the claim is untrue.
- **`smell guano` answers "Nothing here smells of anything in particular."** *Frame:* Small
  Cave, moves 451, standing over the guano the room has just listed. *Cause:* `stubs.smell`
  is a flat room claim (`Prose+Stubs.swift:141`). The same block six lines down records the
  identical mistake being repaired for `listen`. (`needs-human`: the design doc's fifth pass
  explicitly left this line alone.)

### Two one-off frame contradictions — 2 sites

- **`read book` outside the exorcism reprints the physical description of a book advertised as
  "open at a page somebody has marked".** *Frame:* Altar, moves 132. *Cause:*
  `blackBook.before(.read)` returns early unless the player is at Hades at `exorcismStage ==
  2`, so `.read` falls through to the examine text. Both source families give this book a read
  text; Dungeon moved the commandment onto a separate wall item and left the book's own
  advertised page empty. (`needs-human`: one rater holds no sentence is false of its frame.)
- **Inside the barrel, `look` says you cannot see the falls at all, and the next two turns
  describe the falls and the rainbow in full.** *Frame:* Aragain Falls, moves 453–455, no
  state change between them. *Cause:* the describe branch governs only the room's own
  paragraph; the falls and rainbow scenery stay in scope from inside a vehicle standing in the
  room. (`needs-human`: narrowing scope silences the whole outdoor set; rewording decides how
  much of the joke survives.)

### Register — 2 sites

- **DIAGNOSE reports "You have been killed 2 times" where the one-death arm spells it out.**
  *Frame:* Forest, two grue deaths spent. *Cause:* `Prose.diagnoseDeaths` writes `"killed
  \(deaths) times"` for every arm but the first, and the third death is final — so the only
  two lines a player can read are "once" and "2 times". `melee.137:322` writes exactly two
  arms: "once." and "twice."
- **The dungeon master is spelled two ways in consecutive turns.** *Frame:* Narrow Corridor
  then South Corridor, moves 793–794. *Cause:* `Prose.dungeonMasterWaiting` writes "the
  dungeon master"; fourteen lines in `Prose+EndgameMechanics.swift` write "the Dungeon
  Master". **Both raters corrected the finder's diagnosis in the same direction**: the actor
  is `name("dungeon master")` with no `properName`, so every engine-rendered line says it
  lower case, and `dung.355:1446` is lower case too — the fourteen capitalised lines are the
  outlier, not the listing line. A fixer acting on the finding as filed would edit the wrong
  side. (`needs-human`.)

### Engine — 2 sites

- **`light candles with matchbook` answers "You can't see any such thing." with the matchbook
  in hand.** *Frame:* Altar, moves 136; the next INVENTORY lists it. *Cause:* `.turnOn` has
  only `["light", .directObject]` (`CoreVerbs.swift:209`) and no `light X with Y` row, so the
  residue is swallowed into the noun phrase and the whole phrase fails to resolve. `burn X
  with Y` does have the row and answers properly. `dung.mud:3961` declares the second form.
  (`needs-human`: one rater showed the behaviour is uniform across verbs with a cold-start
  control probe, so the question is whether an unmatched prepositional phrase should yield a
  parse error rather than `cantSeeAnySuchThing` — a general engine design call.)
- **Bare `hello` and `hi` answer "What do you want to hello?"** where bare `greet` reaches
  "There's nobody here to greet." *Frame:* West of House, turn zero. *Cause:* `.greet` has
  `["hello", .directObject]` and `["hi", .directObject]` but only a bare `["greet"]`
  (`CoreVerbs.swift:289`), so the unfilled slot falls to a template written for infinitives.
  **The finding's prescribed fix is wrong and the verifier says so**: adding bare rows to
  `coreTable` is what `CoreVerbs.swift:285` explicitly forbids, and would make Zork 1's
  `#verb("hello", …)` warn at launch. (`needs-human`.)

## Filed

42 findings, deduplicating to 12 classes. Filed as **#286**.

| Class | Severity | Owner | Sites |
|---|---|---|---|
| `shrunk` outlives death and seals the Alice wing | major | `game` | 1 |
| A static `description` that never learns the state changed | major | `game` | 10 |
| One scenery item owns every noun the room prints | major | `game` | 7 |
| A mechanic that contradicts its own prose | major | `game` | 6 |
| Nouns the prose prints that the parser denies | major | `game` | 4 |
| A fuse prints its line wherever the player walked to | major | `game` | 2 |
| Two endgame lines untrue of the frame | major | `game` | 2 |
| No `light X with Y` grammar row | major | `engine` | 1 |
| Stock lines in frames the game has its own words for | minor | `game` | 4 |
| Two one-off frame contradictions | minor | `game` | 2 |
| Bare `hello`/`hi` fall to an infinitive template | minor | `engine` | 1 |
| Register — the death toll and the dungeon master's name | note | `game` | 2 |

**13 of the 42 are `needs-human`** — the two raters split, or agreed the defect is real and
declined to let a fixer pick the repair. In three of them the verifier corrected the
*finder's* diagnosis (C37 the dungeon master, C42 the greeting rows, C41 the mailbox), so the
finding as written would send a fixer at the wrong line. Read the verifier note before acting
on any `needs-human` row.

## Refuted

Ten of fifty-two, 19%. Every one concedes the transcript reproduces; not one was refuted for
failing to replay. The refutations cite a file and a line, and the critic spot-checked four
citations against the tree and found all four real.

| # | Charter | Claim | Refutation | Kind |
|---|---|---|---|---|
| 1 | explorer-1 | `out` in the bucket is refused although `get out of bucket` works | Bare `out` is a *direction* (`WorldMap.swift:6`); `.disembark` is `exit`/`get out`. Without the refusal the well's only lift can be wheeled into the Round Room and the Alice wing shut for good (`Alice.swift:531`) | stock-behavior-by-design |
| 2 | explorer-2 | Eight WAITs afloat move the boat nowhere; the river only carries you on DOWN | `FIDELITY.md:1904`: "**There is no current.**" Zork I's eight-turn drift is the trilogy's invention, and the contract forbids adopting it | licensed-by-doc |
| 3 | explorer-2 | One turn after "surrounded by a wall of sand on all sides", LOOK prints an ordinary beach | The sand line is a spent dig-progress report, not a state claim. Omission, not falsehood; the tester's frame is also off by one turn | stock-behavior-by-design |
| 4 | explorer-2 | DRINK WATER afloat with no bottle returns the bottled-water quaff line | `River.swift:610` routes it there deliberately; `Dam.swift:573` carries the comment saying this *is* the repair for #233 | stock-behavior-by-design |
| 5 | explorer-2 | The Clearing's east and north exits lead back into the Clearing and reprint in full | `dungeon-atlas.md:398` records `CLEAR NORTH CLEAR` and `CLEAR EAST CLEAR`; the reprint is `alwaysDescribed` on purpose so the grating report is never suppressed | required-by-contract |
| 6 | timekeeper-2 | Puncturing the boat on a White Cliffs beach maroons the player permanently | `RBOAT-FUNCTION` bursts it unconditionally, `SWIMMER` never kills, neither beach has an inland exit. `dungeon.md:687`: "The stranding is kept, because the source keeps it" | required-by-contract |
| 7 | timekeeper-2 | River-5's description names a west landing but `west` is refused | `dung.355:2622` gives RIVR5 UP/DOWN/LAND and no west. "Where a description names its exits, the description yields to the table" | required-by-contract |
| 8 | timekeeper-2 | The Dead End north of Ancient Chasm can only be left southwest | `dung.355:2394`: DEAD5 has `<EXIT "SW" "CHAS3">`. The bend is the mainframe's | required-by-contract |
| 9 | timekeeper-3 | The red-hot bell lists as a plain "brass bell" for the twenty turns it cannot be touched | The finding concedes the line is "not false, only blind to the clock", and the prescribed fix cannot fire — `RoomDescriber.swift:112` gates presence on `!touched` and the bell has been carried and rung | stock-behavior-by-design |
| 10 | wrong-footer | The SIT refusal is a bare string in an object-carrying slot | Both premises wrong. `text.stubs.sit = "…"` is CLAUDE.md's own first example for the property, and `Prose+Stubs.swift:4` names `sit` among the lines rewritten *because* the engine default reports on a room it cannot see | licensed-by-doc |

**Auditing the refutations.** Every one concedes the transcript reproduces, which read
charitably says the testers were rigorous and read sceptically says the verifiers were
checking the contract rather than re-reading the frame. #3 is the only refutation that
corrects the tester's reading of their own transcript, and it does so as an aside.

**Doc-blindness tax: 6 of 10 refutations turn on a document the blind charters were
deliberately denied** — 60% of refusals, over the brief's "two in five" trigger, but **only 6
of 52 findings, 12%**, which is the denominator that matters. The brief does not need
tightening on this evidence, and three of the six (#6, #7, #8) are exactly the
topology-and-fidelity confusions a fresh reader *should* raise.

**Rater independence.** The `attemptedRefutation` fields exist nowhere in the artifacts, so
independence was judged off the files instead: of 52 paired verification probes, **44 have
different `commands.effective.txt`** — the two raters built their own reproducers rather than
re-running each other's. The eight byte-identical pairs are findings whose reproducer is a
named route file plus a short tail. That is the strongest evidence in the round that 77%
agreement was earned. It is also all the evidence there is: **the verifiers' rationales are
persisted nowhere**, which is a harness gap — this section is auditable only because the
refuted list was handed to the critic in its brief.

## Coverage

Everything below is counted off the files under `.context/playtest/`, not off what any
charter said.

### The thief was dead in every session

`routes/route616.txt` line 42 is `attack thief with sword`, and **all three region prefixes
are prefixes of that route**, so all three contain it. Seven of the eight sessions print "The
thief takes a fatal blow and slumps to the floor dead." at transcript **line 345**,
identically. The eighth (`wrong-footer`) never lifted an underground treasure, which is what
places him.

The string `shadowy figure` — both halves of `thief.roams`'s prose,
`Sources/Dungeon/Prose+Thief.swift:35-36` — appears **zero times in every artifact in the
tree**: 9 session transcripts, 25 branch files, 60 MCP replay probes, 39 CLI replay probes,
~18,900 played commands. Six of the thirty-five timers (`thief.roams`, `thief.steals`,
`thief.fights`, `thief.stashes`, `thief.opensEgg`, `thief.admires`) are dead code from move
~48 onward.

Two controls, both citable:

- `.context/playtest/Dungeon-critic/probe-001/transcript.txt` — cold start, the route's first
  20 commands to the lit Cellar (a prowl room), then 150 `z`. Zero arrivals.
- `.context/playtest/Dungeon-critic/probe-003/transcript.txt` — the full 329-line wing prefix
  (score 322), then 250 `z` in Engravings Cave, a lit prowl room. Zero arrivals. Line 261 is
  the kill.

`wrong-footer` reported the symptom ("across 245 turns he never walked into a room I was
standing in") and blamed the dice. It was not the dice. `thiefProwl` is 108 rooms; with a live
thief at 50%/turn the round's volume would have produced dozens of encounters.

### Rooms — entered is not worked

**The survey's "119 of 195" is wrong in both directions and cannot be repaired from the record
as written.** The roster keys on room *ID* and disambiguates collisions as `Forest
[forestNorth]`; the `closing.json` records carry only the bare display name the game prints.
The twelve names the survey flagged "off-roster" are exactly the collision families, so
**72 of the 76 rooms reported "never entered" are unverifiable** — all five Frigid River
stretches were stood in by two charters and all five are on the never-entered list. Only four
roster names were never printed at all: **Stream, Volcano View, Side Room, East Corridor**.

Ground truth from the transcripts: **134 distinct room names entered; 81 had a tester's own
command typed in them; 53 were pure transit.** Attribution is by aligning each transcript's
command stream against its route file as a subsequence.

Legend: **X** = the charter typed its own command standing there · **.** = the room only
flashed past inside a replayed prefix · **-** = never reached.

| Room | e1 | e2 | e3 | t1 | t2 | t3 | sol | wf |
|---|---|---|---|---|---|---|---|---|
| **AboveGround** (10/10 worked) | | | | | | | | |
| Behind House | . | X | . | . | . | . | X | X |
| Canyon Bottom | - | X | - | - | - | - | . | - |
| Canyon View | - | X | - | - | - | - | . | - |
| Clearing | . | X | X | . | . | . | X | X |
| Forest | X | X | X | X | X | . | X | X |
| North of House | . | . | . | . | . | . | . | X |
| Rocky Ledge | - | X | - | - | - | - | . | - |
| South of House | - | X | - | - | - | - | . | - |
| Up a Tree | . | . | . | . | . | . | . | X |
| West of House | . | . | . | . | . | . | . | X |
| **Alice** (9/9 worked) | | | | | | | | |
| Cage | X | . | - | X | . | - | . | - |
| Circular Room | X | . | - | X | . | - | . | - |
| Dingy Closet | X | . | - | X | . | - | . | - |
| Low Room | X | . | - | X | . | - | . | - |
| Machine Room | X | . | - | X | . | - | . | - |
| Pool Room | X | . | - | X | . | - | . | - |
| Posts Room | X | . | - | X | . | - | . | - |
| Tea Room | X | . | - | X | . | - | . | - |
| Top of Well | X | . | - | X | . | - | . | - |
| **Bank** (5/8 worked) | | | | | | | | |
| Bank Entrance | . | . | - | . | . | - | . | X |
| Chairman's Office | . | . | - | . | . | - | . | - |
| East Teller's Room | - | - | - | - | - | - | - | X |
| Safety Depository | . | . | - | . | . | - | . | - |
| Small Room | . | . | - | . | . | - | X | - |
| Vault | . | . | - | . | . | - | . | - |
| Viewing Room | - | - | - | - | - | - | - | X |
| West Teller's Room | . | . | - | . | . | - | . | X |
| **Cellar** (4/5 worked) | | | | | | | | |
| Gallery | . | . | - | . | . | - | . | X |
| North-South Crawlway | . | . | . | . | . | . | . | - |
| Studio | - | - | - | - | - | - | - | X |
| The Troll Room | . | . | . | . | . | . | . | X |
| West of Chasm | . | . | - | . | . | - | . | X |
| **CoalMine** (1/13 worked) | | | | | | | | |
| Bat Room | . | . | - | . | . | - | . | - |
| Coal Mine | . | . | - | . | . | - | . | - |
| Dead End | . | . | - | . | X | - | . | X |
| Gas Room | . | . | - | . | . | - | . | - |
| Ladder Bottom | . | . | - | . | . | - | . | - |
| Ladder Top | . | . | - | . | . | - | . | - |
| Lower Shaft | . | . | - | . | . | - | . | - |
| Mine Entrance | . | . | - | . | . | - | . | - |
| Shaft Room | . | . | - | . | . | - | . | - |
| Smelly Room | . | . | - | . | . | - | . | - |
| Squeaky Room | . | . | - | . | . | - | . | - |
| Timber Room | . | . | - | . | . | - | . | - |
| Wooden Tunnel | . | . | - | . | . | - | . | - |
| **Dam** (0/8 worked) | | | | | | | | |
| Dam | . | . | . | . | . | . | . | - |
| Dam Base | - | . | - | - | . | - | . | - |
| Dam Lobby | . | . | . | . | . | . | . | - |
| Maintenance Room | . | . | . | . | . | . | . | - |
| Reservoir | . | . | . | . | . | . | . | - |
| Reservoir North | . | . | . | . | . | . | . | - |
| Reservoir South | . | . | . | . | . | . | . | - |
| Stream View | - | . | - | - | . | - | . | - |
| **Endgame** (14/15 worked) | | | | | | | | |
| Crypt | - | - | - | - | - | - | X | - |
| Dungeon Entrance | - | - | - | - | - | - | X | - |
| Hallway | - | - | - | - | - | - | X | - |
| Inside Mirror | - | - | - | - | - | - | X | - |
| Narrow Corridor | - | - | - | - | - | - | X | - |
| Narrow Room | - | - | - | - | - | - | X | - |
| North Corridor | - | - | - | - | - | - | X | - |
| Parapet | - | - | - | - | - | - | X | - |
| Prison Cell | - | - | - | - | - | - | X | - |
| South Corridor | - | - | - | - | - | - | X | - |
| Stone Room | - | - | - | - | - | - | X | - |
| Tomb of the Unknown Implementer | - | - | X | - | - | - | X | - |
| Top of Stairs | - | - | - | - | - | - | X | - |
| Treasury of Zork | - | - | - | - | - | - | . | - |
| West Corridor | - | - | - | - | - | - | X | - |
| **House** (4/4 worked) | | | | | | | | |
| Attic | . | . | . | . | . | . | . | X |
| Cellar | . | . | . | . | . | . | X | X |
| Kitchen | . | . | . | . | . | . | X | X |
| Living Room | . | . | . | . | . | . | X | X |
| **Maze** (5/5 worked) | | | | | | | | |
| Cyclops Room | . | . | . | . | . | . | X | X |
| Grating Room | - | - | - | - | - | - | - | X |
| Maze | . | . | . | . | . | . | . | X |
| Strange Passage | . | . | . | . | . | . | X | X |
| Treasure Room | . | . | . | . | . | . | X | - |
| **Mirror** (6/8 worked) | | | | | | | | |
| Atlantis Room | . | . | . | . | . | . | . | - |
| Cave | . | . | X | . | . | X | X | - |
| Cold Passage | . | . | X | . | . | - | . | X |
| Mirror Room | . | . | X | . | . | . | . | X |
| Narrow Crawlway | . | . | X | . | . | X | X | - |
| Slide Room | . | . | - | . | . | - | . | - |
| Steep Crawlway | - | - | X | - | - | - | - | X |
| Winding Passage | - | - | X | - | - | - | - | - |
| **Palantir** (0/5 worked) | | | | | | | | |
| Dreary Room | - | - | - | - | - | - | . | - |
| Slide | - | - | - | - | - | - | . | - |
| Slide Ledge | - | - | - | - | - | - | . | - |
| Sooty Room | - | - | - | - | - | - | . | - |
| Tiny Room | - | - | - | - | - | - | . | - |
| **Riddle** (2/2 worked) | | | | | | | | |
| Pearl Room | X | . | - | X | . | - | . | - |
| Riddle Room | X | . | - | X | . | - | . | - |
| **River** (10/10 worked) | | | | | | | | |
| Ancient Chasm | - | . | - | - | X | - | . | - |
| Aragain Falls | - | X | - | - | X | - | . | - |
| End of Rainbow | - | X | - | - | X | - | . | - |
| Frigid River | - | X | - | - | X | - | . | - |
| Rainbow Room | - | - | - | - | X | - | . | - |
| Rocky Shore | - | X | - | - | X | - | - | - |
| Sandy Beach | - | X | - | - | X | - | . | - |
| Shore | - | X | - | - | X | - | . | - |
| Small Cave | - | X | - | - | X | - | . | - |
| White Cliffs Beach | - | X | - | - | X | - | - | - |
| **RoundRoom** (4/8 worked) | | | | | | | | |
| Chasm | . | . | . | . | . | . | . | - |
| Damp Cave | . | . | . | . | . | . | . | - |
| Deep Canyon | . | . | . | . | . | . | . | X |
| Deep Ravine | . | . | . | . | . | . | . | - |
| East-West Passage | . | . | . | . | . | . | . | X |
| Loud Room | . | . | . | . | . | . | . | - |
| North-South Passage | . | . | . | . | . | . | . | X |
| Round Room | X | . | X | X | . | - | . | X |
| **RoyalPuzzle** (0/2 worked) | | | | | | | | |
| Room in a Puzzle | - | - | - | - | - | - | . | - |
| Small Square Room | - | - | - | - | - | - | . | - |
| **Temple** (7/12 worked) | | | | | | | | |
| Altar | . | . | X | . | . | X | . | - |
| Dome Room | . | . | . | . | . | . | . | - |
| Egyptian Room | - | . | - | - | . | - | . | - |
| Engravings Cave | X | . | X | X | . | - | . | - |
| Entrance to Hades | . | . | X | . | . | X | X | - |
| Glacier Room | - | . | - | - | . | - | . | - |
| Grail Room | . | . | X | . | . | X | X | - |
| Land of the Living Dead | . | . | X | . | . | . | X | - |
| Rocky Crawl | . | . | . | . | . | . | . | - |
| Ruby Room | - | - | - | - | - | - | . | - |
| Temple | . | . | X | . | . | X | X | - |
| Torch Room | . | . | X | . | . | . | . | - |
| **Volcano** (0/10 worked) | | | | | | | | |
| Dusty Room | - | - | - | - | - | - | . | - |
| Lava Room | - | - | - | - | - | - | . | - |
| Library | - | - | - | - | - | - | . | - |
| Narrow Ledge | - | - | - | - | - | - | . | - |
| Volcano Bottom | - | - | - | - | - | - | . | - |
| Volcano Core | - | - | - | - | - | - | . | - |
| Volcano Near Small Ledge | - | - | - | - | - | - | . | - |
| Volcano Near Viewing Ledge | - | - | - | - | - | - | . | - |
| Volcano Near Wide Ledge | - | - | - | - | - | - | . | - |
| Wide Ledge | - | - | - | - | - | - | . | - |

**Five regions are all-blank or near-blank.** Volcano 0/10, Palantir 0/5, Royal Puzzle 0/2,
Dam 0/8, Coal Mine 1/13 — thirty-eight rooms the committed route walks straight through and
nobody addressed a word to. Three prefixes pointed six of eight testers at three regions; the
map's other two thirds got driven past.

### Timer × exercise

**X** = fired and a charter was standing there reading it · **.** = fired only inside a pasted
prefix or a verifier replay, nobody judged it · **✗** = never fired in any artifact.
Signatures are the timers' own prose strings, grepped over all 133 transcripts.

| Timer | | Evidence |
|---|---|---|
| grue | X | `slavering fangs` ×3 sessions — explorer-3 and timekeeper-3 spent deaths on it |
| melee.troll | X | fought and written up by explorer-2, timekeeper-2, wrong-footer |
| thief.roams | ✗ | `shadowy figure` ×0 in ~18,900 commands |
| thief.steals | . | ×7 sessions, all inside the prefix |
| thief.fights | . | prefix only, then he is dead |
| thief.stashes | . | silent by construction; unreadable from a transcript |
| thief.opensEgg | . | silent; fired via route line 35 |
| thief.admires | . | silent; fired via route line 35 |
| forestSongbird | . | ×22, prefix and cold-start transit; nobody addressed the bird |
| brochureArrives | . | ×8; route line 1, never followed up |
| lanternDim | . | ×1, solver's route only |
| lanternLastGasp | . | ×1, solver's route only |
| lanternDies | . | ×1, solver `branch-008.txt:223` |
| matchBurnsOut | X | timekeeper-3 ran all five to "run out of matches" |
| damLeak | ✗ | `up to your ankles` / `done drowned yourself` ×0 |
| cageGas | X | timekeeper-1 ran it to death twice and cancelled it once |
| exorcismLapse | X | timekeeper-3, on-cell and displaced |
| bellCools | X | timekeeper-3 |
| candlesBurn | X | timekeeper-3, all three rungs plus the grue |
| balloonDrifts | . | solver's route |
| burnerBurnsOut | . | ×1, solver's route |
| gnomeArrives | ✗ | ×0 |
| gnomeLeaves | ✗ | ×0 |
| dustyRoomFalls | . | rumble arm only, solver ×1; the 5000-tons death arm ✗ |
| wideLedgeFalls | . | "narrow escape" arm only, solver ×1; both death arms ✗ |
| slideGrip | ✗ | `Your grip goes` ×0 |
| brickBlast | . | ×1, solver's route |
| endgame.blessing | X | solver minus-one-stepped SCORE-BLESS at 611 |
| endgame.herald | X | solver |
| endgame.crypt | . | fired; solver never claims to have read it |
| endgame.swordGlow | . | fired; unjudged |
| endgame.mirror | X | solver, one berth, one panel |
| endgame.pine | X | solver, one death |
| endgame.quiz | X | solver, five wrong answers to exhaustion |
| endgame.master | X | solver |

**13 of 35 exercised and read · 17 fired only in transit · 5 never fired at all.** Add the
never-fired *branches* of two more: nobody died in the Dusty Room and nobody died on the Wide
Ledge.

### Turns — the survey count is short by 7,646

| Class | Files | Turns |
|---|---|---|
| Sessions (transcripts) | 9 | 3,393 cost |
| Branches (rewound, really played) | 25 | 703 cost |
| MCP verifier replays `.replays/` | 60 | 7,142 cost |
| **`coverage.turns` total** | | **11,238** |
| CLI replays via `bin/playtest-replay` | 39 | **7,646 — uncounted** |
| **Real total** | 133 | **~18,884** |

`Dungeon-r1-play-solver/` (8 probes, 4,773 commands) and `Dungeon-r1-play-timekeeper-1/` (33
probes, 2,873 commands) are testers' own verification probes run through the CLI rather than
the MCP `replay`. **The CLI writes no `[status]` footers, so `coverage.turns` cannot see them
at all.** This is the same class of failure the report-shape doc records for the 2026-08-17
round, moved one layer down: the number is counted rather than asked, but only over the
artifacts that carry footers. Two thirds of the solver's actual work is invisible to it.

Testers spent 11,742; verifiers 7,142. **The round played more than it argued** — but the
authored-versus-replayed split the dispatch file asked for cannot be computed from these
artifacts, because a pasted route prefix and a tester's own command both land in `sessions`.
Against round 1's 50,479 total the round came in at roughly 37%.

### Forks nobody took — 30 of 38

`altar:open barrel:burn bell:open boat:drink bodies:open book:burn bottles:open bucket:burn
cage:open coal:burn egg:eat garlic:eat gate:open gates:open goop:drink lamp:burn
matchbook:open paper:burn pool:drink posts:burn remains:burn rope:burn shore:drink
spirits:open torch:burn trunk:open violin:open walls:open waterfall:drink whirring:open`

Only 8 were taken, all of them by the route rather than by choice. Note the correlation with
the grid: `coal:burn` (Dead End), `trunk:open` (Reservoir), `gate:open`/`gates:open` (Dam) and
`barrel:burn` (Loud Room) all sit in regions that are 100% transit — the forks were declined
because nobody was standing there, not because anybody weighed them.

### Unknown words — the raw count is misleading and the real result is clean

28 occurrences, 5 tokens: `,` ×24, `cakes` ×1, `play` ×1, `569` ×1, `frotz` ×1. **Twenty-four
of twenty-eight are a bare comma.** After `0812aba` a comma should never reach the vocabulary
as a token at all; the parse record still logs it. That is a harness/engine nit, not a game
defect, and nobody filed it. `cakes` is a tester-invented plural (`take all cakes`); `frotz`
is the deliberate parse-error verb. **No word the game itself printed went unanswered** — a
real, clean result the raw count hides.

### Charters — who found nothing, and why

- **`interrogator` never ran.** Zero artifacts bear that label; it filtered itself out on the
  absent `GnustoConversation`, as designed. Its whole class — ASK/TELL/SHOW/GIVE, the
  honorific-and-article sweep against a live NPC — is a **blank, not a clean bill**. It
  compounds with the thief: `interrogator` is the charter likeliest to have noticed that the
  game's principal NPC is dead in every session by move 48.
- **`timekeeper-2` ran and found its own class empty, correctly.** Its brief said "this is the
  one region where standing still moves you". That premise is false of Dungeon — `River.swift:24`
  and `FIDELITY.md:1904` both say there is no current — and the tester established it by sitting
  afloat at River-1 for ten turns and River-5 for eight. The region also holds no actor, so the
  on-cell/off-cell/ghost-cell/displacement passes were unrunnable by construction. **A genuine
  and useful negative result: the river has no clock hand. It must not be read as "timing was
  covered on the river."** Everything `timekeeper-2` filed is a room-and-state defect any
  charter standing there would have found. **The operator wrote that premise into the focus
  string; that is an operator error, not a tester error.**
- **`wrong-footer` ran badly and recovered.** Probe-001 was effectively lost — the troll killed
  it on entry three restores running, because the seed-52 melee draw depends on how many turns
  you spent getting there. Its Studio and Bank Viewing Room work survives only in
  `Dungeon-r1-session-wrong-footer/probe-001/branch-001.txt`. It re-opened as probe-002 on the
  walkthrough's 23-command opening and did the real work there. Four of its twelve article-sweep
  rows (gnome, dungeon master, robot, thief) were never run; three are structurally out of reach
  from a cold start, and the thief row is the one it expected to get and could never have got.
- **The other five all filed.** 42 findings across eight charters, no single charter dominating:
  explorer 23, timekeeper 9, solver 5, wrong-footer 5. But three of the eight are three *pairs*
  on three regions. **Six testers, three regions. That is the round's real shape and no
  per-charter tally shows it.**

### Sessions and dropped findings

9 sessions, all 9 wrote a closing record; **`sessionsUnfinished` is zero.** 133 transcripts in
all. One verifier directory, `Dungeon-r1-verify-b02-r2-wing/`, holds only a `mark` probe and no
rated replay.

**Dropped: none.** Every one of the 52 findings reached both raters (`bothRaters: 52`,
`singleRated: 0`). Nothing was dropped for budget and nothing failed to reproduce.

## Hygiene

- Seed `52`, pinned. Not negotiable: `97b5032` re-pinned `DungeonWalkthroughTests.seed` from 2
  to 52 after the troll and thief gained a strike-first probability, and 52 is the only seed
  below 400 the committed route still wins on.
- `verifyEffort` inherited — **not** turned down.
- `charters` derived from the survey and manifest, not pasted forward. Round 1's six charter
  names no longer exist.
- The round changed no code and ran no tests. It finds and files; it does not fix.

## What the next round should target

The critic's list, in its order. The first is the round's largest hole.

1. **`thief.roams` × {Cellar, Round Room, Temple, Maze}.** Build a prefix that omits
   `route616.txt` line 42, lift one underground treasure to place him, then hold station 200
   turns in each of the four lit prowl rooms. Confirm `Prose.thiefArrives`/`thiefLeaves` print
   at all. Cite against `Dungeon-critic/probe-001` and `probe-003`.
2. **`thief.steals` in a room the player is standing in, and `thief.fights` × Treasure Room with
   the player present** — same live-thief prefix. Both fired only inside the pasted route.
3. **`damLeak` × Maintenance Room, all nine flood rungs plus the drown.** The fuse never fired
   once, and the whole 8-room Dam bundle is 0/8 worked.
4. **`gnomeArrives`/`gnomeLeaves` × Wide Ledge.** Both at zero; pairs with Volcano 0/10.
5. **`slideGrip` × the Slide.** Never fired; the Palantir wing is 0/5 worked.
6. **The death arms nobody took** — `dustyRoomFalls` (`5000 tons of rock`) and `wideLedgeFalls`,
   both the on-foot death and the untied-balloon branch.
7. **Coal Mine, 12 of 13 rooms unworked** — Gas Room × open flame, Machine Room × coal-to-diamond,
   and the untaken `object:coal:burn` fork.
8. **`object:trunk:open` × Reservoir** — irreversible, in a room 0-worked across all eight
   charters, and squarely the state-blind-description class.
9. **`lanternDim`/`lanternLastGasp`/`lanternDies` in a room where the sentence has to be true.**
   All three fired, in the solver's route only, and nobody read them. Three timekeepers each
   wrote that the lamp was "not probed at all"; it was, and
   `Dungeon-r1-session-solver/probe-001/transcript.txt:5958` and `branch-008.txt:223` prove it.
10. **Harness, not game: make `closing.json` record the room ID beside the display name.** The
    195-ID roster and the name-keyed closing records can never be reconciled, which is why 72 of
    76 "never entered" rooms are unverifiable and why the survey published 119/195 against a real
    134 names / 81 worked.

Two harness gaps this round exposed, both worth fixing before the next one:

- **`bin/playtest-replay` writes no `[status]` footers**, so 7,646 real turns are invisible to
  the collator. Either the CLI writes footers, or the collator globs its probe directories too.
- **The verifiers' rationales are persisted nowhere.** The refuted section above is auditable
  only because the list reached the critic in its brief; nobody reading `.context/playtest/` in
  six months could reconstruct it.

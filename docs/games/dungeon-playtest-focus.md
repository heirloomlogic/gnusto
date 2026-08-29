# Dungeon — the play-test region split

`bin/playtest-preflight Dungeon` reads this file and passes it as the round's `focus`.
It lives here, committed, rather than being re-authored into a round's arguments each
time: Dungeon's map outruns any round's turn budget, and SKILL.md is explicit that a
game which gets no split produces a report describing wherever the charters happened to
wash up. Edit it between rounds; do not retype it into a JSON blob.

**Regions are written in affordances, never in room names.** A blind explorer is handed
its own region verbatim, so a display name here is a room the firewall was supposed to
withhold and just gave away. `bin/playtest-preflight Dungeon` checks that property
against the game's own room roster, which is the only place the roster is available;
`node .claude/workflows/playtest.dryrun.mjs` checks the same property against its own
fixture, and so proves the check exists without ever reading this file.

The `|` separates regions. There are more regions than a round has blind seats, on
purpose — the seating chunks them, and the count staying above the cap is the regression
test for a seating bug that once handed the fourth region to nobody.

**There are two `---` rules, and the second one is a firewall.** Everything between them
is chunked across the blind seats and pasted into their prompts verbatim. Everything
below the second rule reaches the *sighted* charters only — the solver, the
wrong-footer, anyone holding the room roster already.

A row goes below it when it is **keyed to a sighted charter** — `solver:`,
`wrong-footer:`, `interrogator:` — or when it names the **walkthrough by type**, the
**ledger**, or **a slot's contents**. It is not "anything mentioning a route index": a
region has to tell its tester how deep a slot stands, so `` `d-1` (cut at
`route[0:113]`) `` stays in the blind half, and that sentence is the one place slots
are declared.

Both rules are thematic breaks — a blank line, then `---` — so underlining a heading
does not accidentally move a region across one. It used to
be region four, which worked only because the old modulo seating handed region four to
nobody; `chunkRegions` fixed the seating and the same paragraph went straight into a
blind explorer's prompt, three lines under a brief telling it that it has no map.

**The slots are declared once, here, and cut by `bin/playtest-slots Dungeon`.** The line
below names the label they live under and the walkthrough they are cuts of; each
region names its own depth, in the shape `` `z-1` (cut at `route[0:29]`) ``, and the
script reads those sentences rather than a table beside them. `.context/` is gitignored,
so a checkout that has never run the script has none of the bytes however carefully this
file describes them — which is what `bin/playtest-preflight`'s `slots` row is for.

Only the regions are scanned for those declarations, so this header can show the shape
without declaring one, and a declaration that does not parse is an error rather than a
slot quietly missing from the plan.

**Do not tell a region how to restore.** `playtest.js` puts the `allowPrompts` recipe on
every tester's `open` line, generated from the round's own arguments, so a region that
repeats it costs every blind seat two and a half kilobytes and hands it a CLI and a
label its brief withholds. Say which slot and what is true there; the harness says how.

Slots: `Dungeon-r1-slots`, cut from `DungeonWalkthroughTests.route`

---

R1 — the wing behind a door that will not open from the near side, and the long one-way drop at the far end of it. No live tester has ever typed a command of their own anywhere in it: every artifact that has ever passed through was somebody's walkthrough scrolling by, so treat every line here as unread. It is 650+ moves from the start and is not walkable inside your budget, so you never walk in — type `restore`, answer the prompt with a slot name, and you are there for one free turn. Two slots: `p-1` (cut at `route[0:659]`) stands you in front of the way in, with the two things that work it already in your hands; `p-2` (cut at `route[0:719]`) stands you at the head of the way out, with something already tied off at the top of it and one heavy thing still in your hands. · explorer: burn the `coverage` queue in both halves. From `p-1` the way in is a lock being worked from the wrong side and the answer is what you are carrying, not what is in the room; from `p-2` the way down is one-way, so read everything at the top before you take it, and read what you land in afterwards. You hold the committing policy — when this wing offers you a move you cannot take back, take it and describe what it cost. · timekeeper: THIS REGION OWNS A CLOCK THAT HAS NEVER FIRED IN ANY ARTIFACT OF ANY ROUND. From `p-2`, go down and then let turns pass. How long you get is set by what you are carrying when you start down, so run it twice — once with your hands as they are, and once having put everything down first — and read what prints and where it puts you against where you were. Six commands from the restore; it has been checked to fire. | R2 — the workings under the shaft, where the air is bad and the light you carry is the problem. Two mechanisms in here have never been touched by anybody in any round: a hoist at the head of the shaft, and a machine with a lid further in. Both are 180-220 moves from the start, so use the saves: type `restore` and answer `c-1` (cut at `route[0:184]`) to stand at the head of the shaft with the hoist beside you, or `c-2` (cut at `route[0:224]`) to stand in front of the machine holding what goes into it and what turns it on. A restore is one free turn. WATCH THE HEADER: two rooms in this game print the same display name on purpose, and only one of them is in this region — judge which room you are in by what is in it, never by the line at the top. · explorer: the hoist is a two-way ride and it carries things you cannot. Work out what it is for by using it, not by looking at it, and check the far end of every ride. Past the hoist the way on is narrow and dark and what you are carrying can end the game; the queue is your map. You hold the abstaining policy: where a move cannot be taken back, describe the fork precisely and leave it. · timekeeper: nothing in here is on a published clock, so this is a pure cross-product seat. Ride the hoist, put things in it, send it away and stand where it went. Stand in the bad air and let turns pass. Read the same place before and after every mechanism you work. | R3 — the drained country north of the great wall, the reflecting pair beyond it, and the ransacked control room that runs the water. Three slots, all 110-130 moves in: `restore` and answer `m-1` (cut at `route[0:123]`) to stand on drained ground with something heavy half-buried in it, `m-2` (cut at `route[0:128]`) to stand in front of the first of a matched pair, or `d-1` (cut at `route[0:113]`) to stand in a ransacked room with a row of four coloured buttons on the wall and the tools nobody took still lying about. · explorer: `m-1` first, and it carries a standing order — type BOTH `open` and `search` at the half-buried thing and judge the two replies against each other; one of them is a stock line and one is written for it, and no verifier has ever been given the pair. Then the matched pair: whatever it does, do it and then read the room you are in, twice. You hold the deferring policy: where a move cannot be taken back, take the reversible half now and write down what you would have done. · timekeeper: THIS REGION OWNS A DAEMON THAT HAS NEVER FIRED ANYWHERE IN THE TREE. From `d-1`, push the buttons on the wall one colour at a time and read what each does; one of them starts something, and when it starts YOU MUST STAY IN THE ROOM. The line it prints prints in that room only and the ending carries its own room test, so a tester who wanders off costs the round the whole daemon. Let all of it run — it ends by killing you, and that is the daemon working, not a defect. Read the room's own description at each stage rather than only the one-line report, and go and try both doors of the room next door once the water has won. Twelve commands from the restore; it has been checked to run to the end. | R4 — the tangle of look-alike passages under the first fight, and the one inhabitant of this game who wants something from you. TWO THINGS MAKE THIS REGION NEW. He is ALIVE in both of this round's slots, and he has been dead in every save every previous round has ever shipped — cut past the fight that kills him — which silently removed him from three of four regions, so his listing line, his arrivals, his departures and everything he does to what you are carrying have never been read by a live tester at all. And he is genuinely lethal where he stands: the probe that checked this slot was killed in five turns of standing still in his company. Two slots, both under 40 moves in, so these two are also walkable if you would rather: `restore` and answer `z-1` (cut at `route[0:29]`) to be inside the passages with something valuable still in your hands, or `z-2` (cut at `route[0:35]`) to be standing in front of him one turn after he has been given it. · explorer: the passages are the region and they are meant to defeat a map — the `coverage` queue is your map, and blind turns here are worth the second look the queue keeps asking for. From `z-2`, leave his room before you spend any turns: something happens silently four turns after the gift, and you read it by coming back afterwards and looking at what you gave him. You hold the committing policy where a second seat holds it; if the fork you are offered is a fight, take it and describe it. · timekeeper: he moves, takes and leaves on his own count, and no round has ever watched him do it. Pass A: stand where he is and let turns pass. Pass B: stand where he is not and read what still prints about him. Pass C: be somewhere when he arrives and somewhere else when he goes, and judge each clause against where YOU are rather than against where he is. · Every seat: nothing on your do-not-report list was fixed — it is last round's REFUTED list only, and the 33 findings last round confirmed are still open and deliberately absent from it. If you meet one, report it.

---

solver: the winning chain is `DungeonWalkthroughTests.route`, 747 commands at seed 52, and all nine of this round's slots are cuts of it — at indices 29, 35, 113, 123, 128, 184, 224, 659 and 719. Do the minus-one-step gate checks from the slots rather than replaying the route: `p-1` gates on a lock, `c-1` gates on the hoist, `c-2` gates on the machine. Then check the three ways this round can lose — the water from `d-1`, the drop from `p-2`, and him from `z-2` — each read as a loss and each print prose that names what the player actually did. Then check the score line reads N of a possible N. Say plainly how deep a live turn you played.

wrong-footer: your generated article-sweep rows for an actor have never once been run against this game's only reachable one, because he was dead in every save ever shipped — `restore` `z-2` and run every one of them at him, including the orders and the greeting. Then `restore` `m-1` and type `open` and `search` at the half-buried thing. Then `eat garlic`, which is reachable thirteen turns from a cold start and which eight charters last round never typed.

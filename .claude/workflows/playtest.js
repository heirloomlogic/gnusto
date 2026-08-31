export const meta = {
  name: 'playtest',
  description:
    'Automated play-test round for a Gnusto demo game: charter-diverse subagents read transcripts as prose, every finding is replayed and then adversarially refuted by two independent raters, and a critic reads the coverage off what the sessions themselves wrote down rather than believing the testers.',
  whenToUse:
    'Invoked by /playtest <game>. Needs args {game, packagePath, docPath, capabilities, turns, charters, rounds}. The calling session builds the binary first (bin/playtest-replay --build <Game>) and writes the returned report; this script has no filesystem access of its own.',
  phases: [
    { title: 'Preflight', detail: 'one agent proves this session can reach the game’s MCP server, before eight testers find out it cannot' },
    { title: 'Survey', detail: 'one cartographer: rooms, timers, vocabulary, and which oracle tiers exist' },
    { title: 'Play', detail: 'one playtester per charter, each replaying its own reproducers' },
    { title: 'Cluster', detail: 'one agent maps each excerpt to the declaration that printed it' },
    { title: 'Triage', detail: 'dedup on the declaration, then two independent refuters per batch of 25, disagreement going to a person' },
    { title: 'Critic', detail: 'coverage collated off the sessions’ own closing records, and what the round missed' },
  ],
}

// ---------------------------------------------------------------------------
// Arguments
// ---------------------------------------------------------------------------

// Depending on the invoking runtime, args may arrive parsed or as raw JSON.
const ARGS =
  typeof args === 'string'
    ? (() => {
        try {
          return JSON.parse(args)
        } catch (e) {
          return { game: args }
        }
      })()
    : args || {}

const game = ARGS.game
if (!game || !/^[A-Za-z][A-Za-z0-9]*$/.test(game)) {
  throw new Error('playtest needs args like {game: "Fulminate", packagePath: ".", docPath: "docs/games/fulminate.md"}')
}

// The round's own identity, and the thing that keeps one round's arithmetic out of
// the next one's. Required rather than defaulted: a default is a collision that
// happens silently, which is the failure this exists to end — three rounds running
// reported turn and session counts that had a previous round's artifacts folded in,
// because every label the harness generates was keyed on the game and the *retry*
// round (r1, r2) and on nothing that distinguished Tuesday from Thursday.
//
// It arrives in args because a workflow script cannot call `Date.now()` — that would
// break resume — so the caller supplies it. `bin/playtest-preflight` derives today's
// date and writes it into the round args, which is also the date the report is filed
// under, so the label tree and `docs/games/<game>-playtest-<date>.md` agree by
// construction rather than by an operator typing the same string twice.
const roundId = String(ARGS.roundId || '').trim()
if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(roundId)) {
  throw new Error(
    'playtest needs a roundId — the round\'s date, e.g. roundId: "2026-08-26". '
    + 'Run `bin/playtest-preflight ' + game + '`, which derives it along with the rest of the args.'
  )
}

const EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max']

const pkg = ARGS.packagePath || '.'
if (/(^|\/)\.\.(\/|$)/.test(pkg) || pkg.startsWith('-')) {
  throw new Error(`unsafe packagePath ${JSON.stringify(pkg)}`)
}

// null for the four games with no design doc. Not a blocker on *finding*
// defects; it is a hard blocker on *fixing prose*, because the repo makes the
// design doc the copy source of truth and requires a prose change to land there
// in the same commit. No doc, nothing to keep in sync, so nothing to rewrite.
const docPath = ARGS.docPath || null
const capabilities = new Set(ARGS.capabilities || [])
const ledger = new Set(ARGS.ledgerKeys || [])
// [{number, owns}] — issues that are OPEN right now and own a defect class the
// round should forward rather than fix. Empty means every symptom is this round's
// to judge, which is the safe default.
const routedIssues = (ARGS.routedIssues || []).filter((i) => i && i.number)
const turnBudget = clamp(ARGS.turns, 20, 250, 60)
// The operator's coverage plan, in their own words, handed to every agent that
// judges prose. A game whose map is bigger than a round can walk cannot have its
// split decided by six testers who all start at the front door and spend the
// budget on the way in; the split has to be decided before dispatch and stated,
// or the report describes wherever the charters happened to wash up. Free text
// rather than a region schema because what a split needs to say differs per game
// — a route prefix here, an hour there — and a schema would only be guessed at.
const focus = typeof ARGS.focus === 'string' ? ARGS.focus.trim() : ''

// The half of the coverage plan the blind seats may not have, and the label the
// round's pre-cut saved games live under. Both come off the focus file, which
// `bin/playtest-preflight` reads; see `bin/lib/playtest-focus.js`.
//
// `focusSighted` exists because closing one firewall hole opened another. Regions
// used to be seated `regions[i % length]`, so with four regions and three copies
// the fourth reached nobody — and the Dungeon operator put the solver's and the
// wrong-footer's assignments there and relied on the bug to withhold them.
// `chunkRegions` fixed the seating and that paragraph, naming the walkthrough type
// and nine route indices, went straight into a blind explorer's prompt. A segment
// below the focus file's second `---` rule now reaches the sighted charters only:
// it is never chunked, never seated, and asserted absent from every blind prompt.
const focusSighted = typeof ARGS.focusSighted === 'string' ? ARGS.focusSighted.trim() : ''

// The deep starts this round can hand out: the names of the committed routes under
// `.playtest/<game>/routes/`, read by `bin/playtest-preflight` and passed straight
// through. A region that says "start from `d-1`" is obeyed by putting `start: "d-1"`
// on the `open` call, and a name that is not in this list has nothing behind it.
//
// **Names only, and never a landing.** A route's manifest also holds the room it ends
// in, and that room is exactly what the firewall withholds: the coverage plan is
// written in affordances because a display name pasted into a blind explorer's prompt
// is a room it was supposed to discover. `bin/playtest-preflight`'s `routes` row prints
// the landings for the operator, which is where they belong; this list is what travels.
const routes = Array.isArray(ARGS.routes) ? ARGS.routes : []
// The names as the prompt prints them, built here rather than inline: inline would be
// a third level of nested template literal, where the backticks around a route name
// need three escapes to survive. One level, one place to read.
const routeList = routes.map((r) => '`' + r + '`').join(', ')
// The paragraph's first sentence, hoisted so `playtest.dryrun.mjs` can read it out of
// this source with `layoutConst` and assert that it reached every seat. A dry run that
// hardcodes its own copy of a prompt sentence goes quietly vacuous the day the
// sentence is reworded, which is the failure `REGION_RESIDUAL` is declared this way to
// avoid.
const DEEP_START_LEAD = 'This round ships deep starts, and the routes it can hand you are'
// Reasoning effort for the verifiers, which are the round's largest fan-out: two
// independent raters over each batch of 25, so they set its cost. Left inheriting
// by default. Turning it down is a budget call and belongs to the operator, not to
// the file: a verifier that refutes real defects yields a thin round that reads as
// a clean one, and that failure is silent.
const verifyEffort = EFFORTS.includes(ARGS.verifyEffort) ? ARGS.verifyEffort : undefined
const maxRounds = clamp(ARGS.rounds, 1, 6, 1)
const dryTarget = clamp(ARGS.dryRounds, 1, 3, 2)
const seed = clamp(ARGS.seed, 0, Number.MAX_SAFE_INTEGER, 0)

function clamp(value, lo, hi, fallback) {
  const n = Number(value)
  if (!Number.isFinite(n)) return fallback
  return Math.max(lo, Math.min(hi, Math.floor(n)))
}

// ---------------------------------------------------------------------------
// Ground truth handed to every agent, verbatim and identically
// ---------------------------------------------------------------------------

// Identical is the point. N testers judging against N slightly different
// oracles produce findings that cannot be deduplicated or cross-verified.
const REF = '.claude/skills/playtest/references'

// Every agent is HANDED its replay label rather than asked to invent one. Asking
// produced `verify-1` from three verifiers at once, and before probe directories
// existed that meant three sessions written to one path — so a refutation cited a
// transcript that was by then somebody else's. Probe directories make the loss
// impossible; a label per agent is what keeps the *saves* separate, which is the
// other thing a label is for.
//
// **The game and the `roundId` both lead**, and the second of those is newer than
// the bug it fixes. This comment used to say "game and round are in the name so two
// rounds of the same game do not interleave either", and the `round` it meant was
// the *retry* round — r1, r2 — which distinguishes nothing between Tuesday's round
// and Thursday's. Both wrote `<Game>-r1-session-*`, both were caught by the same
// glob, and three rounds running reported coverage arithmetic with a previous
// round's sessions folded in. The date in front is what makes the globs below say
// what they always claimed to.
//
// `:` is not in the label alphabet the tool accepts, which is why an agent given a
// display label like `verify:frame` had to make one up. Sanitize instead.
const labelFor = (...parts) =>
  [game, roundId, ...parts].join('-').replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^[.-]+/, '')

// The game's own MCP server, as the tool namespace spells it. `.mcp.json` keys one
// server per game, and both the cartographer and every tester have to name its
// tools to fetch them — so the convention is stated once here rather than
// re-derived at each call site.
//
// **Derived when the caller knows, assumed only when it doesn't.** The lowercased
// game name is the convention every game in this repo follows and the one
// `Templates/NewGame` ships, but nothing enforces it, and a repo that spells its key
// differently gets no error at all: `ToolSearch` matches nothing and every tester
// fails identically, which is indistinguishable from the server being down. So
// `bin/playtest-preflight` reads the real key out of `.mcp.json` — matching on the
// `args` entry that names the product, because the server itself cannot be asked
// (`MCPServer.swift` reports the constant `gnusto-playtest` for every game) — and
// passes it here. The fallback keeps every existing caller working.
// Not lowercased again on the way out: the fallback already is, so the extra call
// could only ever change a key an operator passed in — and a repo whose `.mcp.json`
// key is not the lowercased product name is the single case this derivation exists
// to carry.
const mcpServer = ARGS.mcpServer || game.toLowerCase()
const mcpTools = (...names) => names.map((n) => `mcp__${mcpServer}__${n}`).join(',')

// What to do when the query comes back empty, said once and pasted wherever the
// query is. This is the single most expensive gap the harness has had: the tools
// are deferred, so a tester's first act is a `ToolSearch`, and when the server did
// not connect that search returns nothing and the prompt used to end there. The
// agent has a schema it cannot fill and no branch to take, so it improvises — and
// what it improvises is a report saying it does not know how to use MCP, which
// reads as a confused tester rather than as a dead server. Eight of those is what a
// failed round looked like.
//
// A blind charter cannot be given the CLI as a fallback: `groundBlind` withholds the
// replay how-to on purpose, and handing it over to route around a connection problem
// would breach the firewall to fix an operator's mistake. So the instruction is to
// stop, not to improvise — a round that reports one clear cause beats a round that
// reports eight confused symptoms of it.
const toolsOrStop = `
If that \`ToolSearch\` returns nothing, **stop and report that** — do not improvise,
do not look for another way to play the game, and do not describe the search itself as
a finding. Empty means the game's MCP server is not connected in this session, which is
an operator problem and never yours: it is fixed by \`bin/playtest-preflight ${game}\`
and, if that passes, by restarting the session. Try the search twice more before you
conclude it, because a server that was still starting can answer a later attempt. Then
return your normal result shape with no findings and say in one sentence that the tools
did not resolve.
`.trim()

// Where a *session* writes, as against a replay, and the glob that finds it
// again. The server makes `.context/playtest/<label>/<probe>/` out of whatever
// label `open` was given, and the collator globs that directory for
// `closing.json` — two facts six hundred lines apart with nothing between them
// to catch a drift.
//
// They drifted the moment testers moved off `bin/playtest-replay` onto the
// session server: `open` began passing a bare charter key while the glob went
// on expecting the game-prefixed replay label. Neither side is wrong on its
// own, and the failure is silent in the worst way, because the collator's
// answer to "no session wrote anything" is the same as its answer to "every
// tester crashed" — zero finished, and the critic told its coverage is a floor.
//
// So both are derived from one segment, and the dry run asserts they still
// agree. The segment also keeps replays *out*: a replay probe holds a
// `transcript.txt` and never a `closing.json`, so a glob loose enough to catch
// `<game>-r1-play-…` or `<game>-r1-verify-…` reports the round's own replays as
// testers who played and never accounted for it.
// The round's identity, written once. The three label globs below and the
// round-wide catch-all all lead with it, and they have to agree or the harness
// recipe's exclusions stop lining up with its scope — which is the exact class of
// bug adding `roundId` to the labels was fixing. Spelling it out four times left
// four places to get that wrong.
const ROUND_PREFIX = `${game}-${roundId}`

const SESSION_SEGMENT = 'session'
const sessionLabelFor = (round, key) => labelFor(`r${round}`, SESSION_SEGMENT, key)
const SESSION_GLOB = `${ROUND_PREFIX}-r*-${SESSION_SEGMENT}-*`

// The other two label trees, derived the same way and for the same reason. A
// tester replaying from the command line writes under its `play` label and a
// verifier under its `verify` one, and both hold a `transcript.txt` with a
// `[status]` footer on every turn — so they are countable, and until #288 they
// were counted by nobody. The 2026-08-18 round played 32,987 commands through
// them and reported 11,238 turns.
//
// They are separate constants rather than a wider `SESSION_GLOB` because the
// paragraph above is still true: these directories hold no `closing.json`, so a
// session glob loose enough to reach them answers "158 testers never finished".
// The rule is that the *turn count* may name every tree and *session
// accounting* may name only one, and the dry run asserts both halves.
//
// There is no third constant for the labels the round's own machinery replays
// under — `<game>-survey`, `-r<n>-cluster`, `-critic`, `-collator`, and whatever
// an operator invents to check a route prefix before dispatching anybody — and
// that is the point: an operator's label cannot be enumerated in advance, so the
// harness tree is defined as every probe that is none of the three above. See
// `countedTurns`, which is where that exclusion is spent.
//
// It used to be left out of the count entirely, on the reasoning that turns
// spent there are neither a tester's coverage nor a verifier's checking, and on
// the promise that `countedTurns`' residual would surface a tree that started
// spending a real budget. It did surface one — 8,095 turns on 2026-08-24 — and
// the round then had to hand the critic a mystery and ask it to name the
// directories. A tree that is *known* to exist and *known* not to be coverage
// wants a named row, not a residual; the residual is for the tree nobody has
// thought of yet.
const PLAY_SEGMENT = 'play'
const playLabelFor = (round, key) => labelFor(`r${round}`, PLAY_SEGMENT, key)
const PLAY_GLOB = `${ROUND_PREFIX}-r*-${PLAY_SEGMENT}-*`

const VERIFY_SEGMENT = 'verify'
const verifyLabelFor = (round, batch, rater) =>
  labelFor(
    `r${round}`,
    VERIFY_SEGMENT,
    `b${String(batch).padStart(2, '0')}`,
    `r${rater}`
  )
const VERIFY_GLOB = `${ROUND_PREFIX}-r*-${VERIFY_SEGMENT}-*`

// Everything this round wrote, under any label, which is what makes the harness
// pair below an exclusion *within a round* rather than an exclusion within the
// whole tree. It matters more than it looks: once the three globs above carry the
// round's date, a PREVIOUS round's sessions stop matching them — and a catch-all
// with no round in it would sweep every one of those into this round's "own
// machinery" row. The harness row is for the cartographer's survey and the labels
// an operator replayed under before dispatching; last month's testers are neither.
//
// They are not lost by being excluded here. `all` is still counted over the whole
// scratch tree with no glob at all, so a previous round's turns show up in the
// residual — which is exactly what the residual is for, and what the critic is
// told to name rather than absorb.
const ROUND_GLOB = `${ROUND_PREFIX}-*`

// There is no fifth tree, and there used to be. A round's deep starts were `.gnusto`
// saves cut under a label with no round id in it, because the bytes were cut once and
// reused by every round the walkthrough had not moved under — so no round glob could
// see them, and 758 turns arrived in `unattributed` on 2026-08-29 as a mystery for the
// critic to reconcile by hand. It cost a named row held out of `total`, an exclusion
// negating it out of the harness row, and an exemption from the rule that every glob
// carries a round id.
//
// A deep start is now a route the session plays inside the tester's own label, so those
// turns land in `sessions` where they were always going to, `prefixTurns` off each
// `closing.json` says how many the harness walked, and all three special cases went
// with the tree.

// The probe layout, declared once. Everything below that names a directory or a
// file under the scratch tree is built from these, and `playtest.dryrun.mjs`
// reads the three producers' own source — `bin/playtest-replay`, and the session
// server and its sessionless `replay` tool in Swift — and fails if any of them
// stops writing what is declared here. That is the same treatment
// `SESSION_SEGMENT` gets one screen up: a fact stated once, derived everywhere,
// and cross-checked against the other side by the dry run, because four
// languages share no module and nothing else stands between them.
//
// It had drifted twice by #299, both silently in this harness's signature way —
// a zero on stdout with the error on stderr, which an agent asked for an integer
// reports as an integer either way. `SKILL.md`'s "Measuring a change to the
// harness" tells that story once, and is where it belongs.
//
// The rule the recipes below keep: **start every `find` at `${SCRATCH}`**, which
// the round creates before any agent runs, and let the *pattern* do all the
// discriminating. A pattern that matches nothing prints `0` in every shell; a
// start directory that is not there prints an error instead.
const SCRATCH = '.context/playtest'
const REPLAY_TREE = '.replays'
const PROBE = 'probe-*'
const TRANSCRIPT = 'transcript.txt'
const BRANCH = 'branch-*.txt'
const CLOSING = 'closing.json'

// How to replay, said once for both ground blocks. It differs between them only in
// where it sits — after the briefs for an agent that judges prose, straight after the
// header for one that doesn't — so the drift between two copies would be invisible
// and the copy an agent read would be a coin flip.
const replayHowTo = (label) => `
Replay a probe with a single command:

    bin/playtest-replay ${game} --commands FILE --seed ${seed} --label ${label} --tail 60${pkg === '.' ? '' : ` --package-path ${pkg}`}

\`${label}\` is YOUR label for this round. Use it on every replay and do not invent
another: each run gets its own \`probe-NNN/\` directory beneath it, so replaying costs
you nothing and overwrites nothing. Cite the \`[playtest] transcript=…\` path the tool
prints — that path holds that run's transcript permanently, which is what makes a
finding auditable by somebody who was not here.

Read the transcript FILE it points at, never stdout — the plain IO handler prints
the "> " prompt but not the piped command, so stdout is answers with the questions
missing. Comments (\`//\` or \`#\`) are recorded and never reach the parser.

Write nothing outside \`${SCRATCH}/\`. It is the sanctioned scratch and the
only part of the tree that is gitignored for this purpose.
`.trim()

// Where and what, with no doctrine. Every agent gets this much; only the ones
// that actually judge prose pay for the briefs (`ground`, below).
const groundMin = (label) => `
You are working on the Gnusto engine repo. The package under test is at \`${pkg}\`
and the game is \`${game}\`. The pinned seed for this round is \`${seed}\`.

${replayHowTo(label)}
`.trim()

// The blind charters' preamble. Same repo, same seed, same finding contract —
// and no design doc, no `CLAUDE.md`, and no replay-tool how-to, because they play
// through the session server instead.
//
// It also carries **no coverage plan**, where every other charter gets the whole
// thing. The plan is written in room names, so pasting it handed a blind
// explorer nine of Fulminate's ten rooms three lines above its own brief telling
// it "you have no map, no room list" — a leak the dry run's firewall assertion
// caught, and the exact shape SKILL.md means by "a property of the *text*, and
// grepping it is how you know". A blind tester is told its own region a few
// lines further down, by the dispatcher, and that one line is all the assignment
// it needs.
//
// Dropping `CLAUDE.md` cost one known finding: the patrolman case, a rendered
// phrase interpolated sentence-initially without `GameText.sentenceCase`, which a
// tester found by having read the convention. That is now a sweep —
// `Tests/GnustoTests/ProseConventionTests.swift`, run by CI on every `swift test`
// — and a sweep is a strictly better detector than "a tester happened to remember
// the rule". It found the two live cases the tester had missed, and a third in a
// DocC article teaching the convention, so the trade came out ahead rather than
// merely even.
const groundBlind = (label) => `
You are play-testing \`${game}\` for the Gnusto engine repo. The pinned seed for this
round is \`${seed}\`.

Read \`${REF}/finding-contract.md\` before you report anything: it is what a finding must
carry. Read nothing else. In particular do **not** open the game's source, its design
doc, its tests, or \`CLAUDE.md\` — you are judging whether the prose is true of the
situation it printed in, and that is decided by what the game told you and nothing else.
Somebody handed the map navigates instead of exploring; somebody handed the vocabulary
can never discover that a printed noun has nothing behind it.

You will therefore report some things the design licenses. That is expected and it is
priced in: a verifier reads the doc whole and adjudicates afterwards. Report what you
observed, say plainly what you think is wrong with it, and let the verifier rule.

${routedIssues.length ? `**Owned elsewhere this round.** These issues are open and own a defect class. A
symptom that belongs to one of them is routed, not reported:

${routedIssues.map((i) => `- **#${i.number}** — ${i.owns}`).join('\n')}
` : ''}
Your label for this session is \`${label}\`.
`

const ground = (label) => `
You are working on the Gnusto engine repo. The package under test is at \`${pkg}\`
and the game is \`${game}\`. The pinned seed for this round is \`${seed}\`.

Read these before you do anything else:
- \`${REF}/playtester-brief.md\` — the doctrine, the judgement kernel K1..K13, and
  what is never a finding. This is your oracle when the design doc is silent.
- \`${REF}/finding-contract.md\` — what a finding must carry.
${docPath ? `- \`${docPath}\` — the design doc: the mechanics contract, the map, the timeline, the solution. Its "free to change" / "not free to change" lists decide what is even arguable.` : `- There is NO design doc for ${game}. Read \`Sources/${game}/${game}.swift\` instead: its type doc comment lists the idioms the game exists to demonstrate, which is the nearest thing to a contract, and \`maxScore\` plus the score line is a machine-checkable win oracle.`}
- \`CLAUDE.md\` — repo conventions. Its rules are load-bearing but it can be stale;
  where it disagrees with the code, the code wins and that disagreement is itself a
  \`doc-drift\` finding.

${replayHowTo(label)}
${focus ? `
**The operator's coverage plan for this round**, decided before dispatch. Find your own
charter in it and treat that row as your assignment; the rest is context for reading
somebody else's finding.

${focus}
` : ''}${focusSighted ? `
**Rows for the sighted seats only.** These name the walkthrough, the ledger's verdicts,
or the room a deep start lands in — answer-key material a blind charter is not given.
Find your own charter here too.

${focusSighted}
` : ''}
${routedIssues.length ? `**Owned elsewhere this round.** These issues are open and own a defect class. A
symptom that belongs to one of them is routed, not reported:

${routedIssues.map((i) => `- **#${i.number}** — ${i.owns}`).join('\n')}

Anything not on that list is yours to judge, however much it looks like an engine
concern.` : `**Nothing is owned elsewhere this round.** No open issue claims a defect class, so
every symptom you find is yours to judge. In particular, do not assume an unknown
word, an odd stock line or a rough edge is "already tracked" — check, or report it.`}
${pkg === '.' ? '' : `
**You are playing an OLDER TREE than the one the briefs describe.** The binary is built
from \`${pkg}\`; the judgement kernel, the checklists and \`CLAUDE.md\` all come from the
current checkout, because some of them did not exist at the commit under test. So engine
facts can legitimately disagree with what you were told: a stock text key the kernel
names may not exist yet, a verb the kernel treats as known may not be in the table yet,
and a refusal may take an older form.

When that happens it is an **anachronism, not a finding.** Note it in your coverage
note — "N checklist rows were vacuous at this commit" is useful — and move on. Do NOT
file it as \`doc-drift\` against the briefs: they are accurate about the tree they ship
with, which is not this one. \`doc-drift\` is for a disagreement between this tree's own
docs and this tree's own code.`}
`.trim()

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const CATEGORIES = [
  'presence-line-location-blind',
  'prose-untrue-of-frame',
  'prose-untrue-of-state',
  'unanswerable-noun',
  'stock-line-not-reskinned',
  'register-mismatch',
  'exit-prose-mismatch',
  'mechanic-contradicts-prose',
  'repeat-behavior',
  'unwinnable',
  'gate-not-gating',
  'doc-drift',
  'contract-violation',
  'crash-or-hang',
  'prose-taste',
]

// An issue number a finding was routed to, or empty. Deliberately NOT an enum of
// hardcoded numbers: this list went stale three merges running — #76, #77 and #78
// were each fixed while the harness still told testers to forward their symptoms
// elsewhere, which is worse than a wrong rule, because the failure mode is a
// regression getting discarded as somebody else's problem. The caller supplies the
// currently-open set per round (see `routedIssues` in the args), so an issue that
// closes stops suppressing findings the moment the next round runs.
const ROUTED_ISSUES = { type: 'string' }

// The two rosters this schema carries are the round's denominators, and both
// are **copied from the engine's `survey` tool**, not transcribed. That is
// #287's root cause written into the schema: the numerators come from the
// engine — `roomsVisited` off the status line's `locationID`, `firedTimers` off
// `GameWorld.firedTimers` — so a denominator an agent retyped out of
// `Sources/<Game>/` is a second key space, and a join between two key spaces
// silently scores the misses as zero.
//
// Rooms carry `id` as well as `name` for the sharper half of it: a display name
// is prose, and a game may give two rooms the same one — at which point a
// name-keyed roster cannot represent the answer whatever it is joined against.
// `visitedRooms` below has the numbers.
//
// The judgement fields stay the cartographer's: `at`, `readsPlayerLocation`,
// `kind` and the reachable/unreachable split are read out of the source, which
// is work only a reader can do. The split is exactly the line to draw — the
// engine owns the key space, the agent owns what the key space cannot say.
const ROOM_ROW = {
  type: 'object',
  additionalProperties: false,
  required: ['id', 'name'],
  properties: {
    id: { type: 'string', description: 'The room\'s declared id, copied exactly from the survey tool. This is the key everything else joins on.' },
    name: { type: 'string', description: 'Its display name, copied exactly. Not unique, and not a key.' },
  },
}

const SURVEY_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['rooms', 'timers', 'tiers', 'reskinnedTextKeys', 'printedNouns'],
  properties: {
    rooms: {
      type: 'array',
      description: 'Every reachable room, from the survey tool: one row per room it returned with isReachable true, id and name copied exactly.',
      items: ROOM_ROW,
    },
    unreachableRooms: {
      type: 'array',
      description: 'The rooms the survey tool returned with isReachable false — declared, but nothing leads to them.',
      items: ROOM_ROW,
    },
    timers: {
      type: 'array',
      description: 'Each alarm, fuse and timetable stop, and whether its body reads the player location. One row per timer the survey tool returned, no more and no fewer.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'kind', 'readsPlayerLocation'],
        properties: {
          name: { type: 'string', description: 'The timer\'s declared name, copied exactly from the survey tool. This is the key `firedTimers` is in.' },
          kind: { type: 'string', enum: ['alarm', 'fuse', 'daemon', 'stop'] },
          at: { type: 'string' },
          readsPlayerLocation: { type: 'boolean' },
        },
      },
    },
    stateAxes: {
      type: 'array',
      description: 'The axes a line could be wrong along: hours for a clock game, tide/spell/light state otherwise.',
      items: { type: 'string' },
    },
    printedNouns: {
      type: 'array',
      description: 'Nouns the prose prints, with whether the vocabulary answers them.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['noun', 'answerable', 'printedIn'],
        properties: {
          noun: { type: 'string' },
          answerable: { type: 'boolean' },
          printedIn: { type: 'string' },
        },
      },
    },
    reskinnedTextKeys: {
      type: 'array',
      description: 'Stock text keys the game overrides in its `text` block. The complement is the vandal target list.',
      items: { type: 'string' },
    },
    reskinnedStubs: {
      type: 'array',
      description:
        'Stub-verb replies the game overrides via `text.stubs.<verb>`. The engine ships ~48; anything absent here still answers in the engine voice rather than the game\'s.',
      items: { type: 'string' },
    },
    properNamedActors: { type: 'array', items: { type: 'string' } },
    tiers: {
      type: 'array',
      description: 'Which oracle tiers were actually available: T0 kernel, T1 design doc, T2 walkthrough test, T3 source, T4 ledger.',
      items: { type: 'string', enum: ['T0', 'T1', 'T2', 'T3', 'T4'] },
    },
    notes: { type: 'string' },
  },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['charter', 'findings', 'coverage'],
  properties: {
    charter: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['claim', 'category', 'severity', 'excerpt', 'frame', 'reproducer', 'fault', 'ownerFile', 'replayedCleanly'],
        properties: {
          claim: { type: 'string', description: 'One sentence: what is false.' },
          category: { type: 'string', enum: CATEGORIES },
          severity: { type: 'string', enum: ['blocking', 'major', 'minor', 'note'] },
          excerpt: { type: 'string', description: 'The offending text verbatim, with enough context to place it.' },
          // No `anchor`. It existed because a tester computing the hour from a
          // command count got it wrong — meta commands and parse failures cost
          // no turn — so the finding had to carry the transcript line that
          // proved the claim. Every turn now ends with a `[status]` footer
          // naming the room, the move counter and whether the command cost a
          // turn, so the hour is read rather than derived and the proof is in
          // the transcript by construction. A field asking a tester to
          // re-attest what the harness already recorded is a field that can
          // only be wrong.
          frame: {
            type: 'object',
            additionalProperties: false,
            required: ['room', 'state'],
            properties: {
              room: { type: 'string', description: 'Copied from the turn\'s `[status]` line.' },
              hour: { type: 'string' },
              state: { type: 'string' },
            },
          },
          reproducer: {
            type: 'array',
            description: 'Shortest command list from a clean start — or, when it begins `restore`, from the save you wrote yourself, named in `savesFrom`. A list taken from a deep start begins at the landing and needs no prologue: the verifier replays it with `--start`, which is a flag and not a command.',
            items: { type: 'string' },
          },
          startedFrom: {
            type: 'string',
            description: 'Set ONLY when the reproducer begins at a deep start: the name of the route you opened with, exactly as you passed it to `start`. The verifier replays it as `--start <name>`, which plays the committed route ahead of your list and takes the seed off its manifest. A deep finding filed without this is replayed from turn zero, where its commands mean something else or nothing at all.',
          },
          savesFrom: {
            type: 'string',
            description: 'Set ONLY when the reproducer begins `restore`: the play label holding the save it restores, which is the label you opened under. This is about a save YOU wrote mid-session — a deep start is a route and wants `startedFrom` instead. A reproducer that needs a save is a legitimate reproducer, and this field is how it says so; without it the replay answers "Restore failed." and the finding is dropped as not-reproducible, which is how four real defects were lost in the 2026-08-25 Dungeon round.',
          },
          replayedCleanly: {
            type: 'boolean',
            description: 'True only if the trimmed reproducer was re-run and produced the excerpt — from a clean start, from the route named in `startedFrom`, or from the save named in `savesFrom`. A staged or deep re-run counts; a re-run you did not do does not.',
          },
          transcriptPath: {
            type: 'string',
            description:
              'The `[playtest] transcript=…` path of the clean replay, verbatim. That directory is written once and never rewritten, so this is the evidence a reader follows a year from now.',
          },
          fault: { type: 'string', description: 'Which prose or rule is at fault, naming the mechanism.' },
          ownerFile: { type: 'string' },
          alsoSeenIn: { type: 'array', items: { type: 'string' } },
          routedTo: ROUTED_ISSUES,
        },
      },
    },
    // No `unknownWords`, no `roomsVisited` and no `turnsSpent`. All three used
    // to be asked of the tester and all three were wrong — 2 unknown-word
    // occurrences reported against transcripts holding 261, 112 rooms claimed
    // against 155 walked, and a 2026-08-17 round that reported 295 turns where
    // the artifacts held about 1,493. The session server writes the first two
    // into `closing.json` off the parse record and the status line; the third is
    // now counted off the `[status]` footers by the collator, which it could not
    // be until `replay` started writing a probe directory — before that a
    // verifier's turns existed in no file and only the tester could be asked.
    // A word the *game printed* and cannot answer is still a defect and still
    // gets filed as an ordinary finding; it was never the count that made it one.
    coverage: {
      type: 'object',
      additionalProperties: false,
      required: ['cellsSkipped', 'honestSummary'],
      properties: {
        cellsSkipped: { type: 'array', items: { type: 'string' } },
        droppedNonReproducible: { type: 'array', items: { type: 'string' } },
        honestSummary: {
          type: 'string',
          description: 'What you did NOT cover and why. Silence here reads as full coverage and would be a lie.',
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['index', 'verdict', 'reason', 'attemptedRefutation'],
  properties: {
    index: {
      type: 'integer',
      description: 'Which finding this verdict is for, as numbered in the prompt, 1-based. Every finding gets exactly one verdict and none may be skipped.',
    },
    verdict: {
      type: 'string',
      enum: ['confirmed-defect', 'refuted', 'route-elsewhere', 'needs-human'],
    },
    attemptedRefutation: {
      type: 'string',
      description:
        'The strongest case AGAINST this finding, written out, and required even when you confirm it. Not a formality: an agent that has to state the best argument for the other side cannot rubber-stamp cheaply, and a confirmation whose refutation attempt is thin is itself a signal a reader can act on. Say what would have to be true for the line to be correct, and why it is not.',
    },
    refutationKind: {
      type: 'string',
      enum: [
        'characterization',
        'licensed-by-doc',
        'required-by-contract',
        'stock-behavior-by-design',
        'owned-by-another-issue',
        'misquoted-prose',
        'frame-not-anchored',
        'not-reproducible',
        'none',
      ],
    },
    reason: { type: 'string' },
    correctedFrame: { type: 'string' },
    evidencePath: {
      type: 'string',
      description:
        'The `[playtest] transcript=…` path of the replay this verdict rests on, verbatim. A refutation is only auditable if its transcript is still the one it judged.',
    },
    routedTo: ROUTED_ISSUES,
    provenance: {
      type: 'object',
      additionalProperties: false,
      required: ['age'],
      description:
        'Whether the defect is newly introduced. A defect that arrived with a recent fix is the most valuable kind to catch and the easiest to lose.',
      properties: {
        age: { type: 'string', enum: ['introduced', 'preexisting', 'unknown'] },
        blamedCommit: { type: 'string' },
        blamedSubject: { type: 'string' },
        note: { type: 'string' },
      },
    },
  },
}

// One rater's verdicts on a whole batch. Batching is what takes verification
// from ~70 agents to two: declaration-keyed dedup already collapses Fulminate's
// findings to ~18-20 classes, and 25 classes is a size one agent can hold
// without the transcript work going shallow.
const VERDICT_BATCH_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['verdicts'],
  properties: {
    verdicts: {
      type: 'array',
      description: 'One entry per finding you were given, in any order, with no finding left out. A finding you cannot reach a view on is `needs-human`, never a silent omission.',
      items: VERDICT_SCHEMA,
    },
  },
}

const CLUSTER_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['assignments'],
  properties: {
    assignments: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['index', 'declaration'],
        properties: {
          index: { type: 'integer', description: 'The finding number as given, 1-based.' },
          declaration: {
            type: 'string',
            description: 'The emitting declaration as `<file>::<name>`, or the literal `unlocated` when no search found it. Never a guess.',
          },
        },
      },
    },
  },
}

/// What the sessions themselves wrote down, gathered off disk.
///
/// This replaces two Haiku censuses that grepped transcripts — one for
/// `I don't know the word "…"` replies, one for room headings — and the
/// word-subset matcher that reconciled both against what the testers claimed.
/// All of it existed because the numbers were asked rather than counted, and it
/// was wrong twice in ways that reached a report: 2 unknown-word replies claimed
/// against 261 in the transcripts, and 112 of 195 rooms claimed against 155
/// actually walked, with 43 of the 83 "never entered" rooms appearing as
/// headings in dozens of transcripts. A next-round planner handed that list
/// spends its budget re-walking walked rooms.
///
/// The session server now writes `closing.json` at `finish`, holding the rooms
/// off the status line and the unknown words off the parse record. So there is
/// nothing left to reconcile and no prose to grep: this agent exists only
/// because the orchestration script has no filesystem of its own. It reads
/// files and adds up integers, which is why it is on Haiku permanently.
const COLLATOR_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['rooms', 'roomsWorked', 'words', 'turns', 'sessionsFinished', 'sessionsUnfinished'],
  properties: {
    rooms: {
      type: 'array',
      description: 'Every distinct room `id` appearing in any closing.json `roomsVisited`, copied exactly. The id, not the name: two rooms may share a display name, and the survey roster this is scored against is keyed by id.',
      items: { type: 'string' },
    },
    roomsWorked: {
      type: 'array',
      description: 'Every distinct room `id` appearing in any closing.json `roomsWorked`, copied exactly and in the same key space as `rooms`. The engine\'s own subset: a room a session typed something in that was neither travel nor a meta command. Entered is not worked — a pasted routes/*.txt prefix walks dozens of rooms and reads a line of none of them — and the round reports both counts. A file with no `roomsWorked` key at all was written by a server older than the field: it contributes nothing, and if that is every file you read, say so in `note` rather than reporting an empty list as "nothing was worked".',
      items: { type: 'string' },
    },
    words: {
      type: 'array',
      description: 'One row per distinct token any session failed to parse, with its total count across all sessions.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['word', 'count'],
        properties: {
          word: { type: 'string' },
          count: { type: 'integer' },
        },
      },
    },
    forksNobodyTook: {
      type: 'array',
      description: 'Forks that appear in some closing.json with taken:false and in none with taken:true — a branch the whole round left alone. The ledger flags a fork BEFORE the command is typed, from what the tester holds and what the game has said, so read this as an upper bound on what was really committing.',
      items: { type: 'string' },
    },
    timers: {
      type: 'array',
      description: 'One row per distinct timer name appearing in any closing.json `firedTimers`, with its fire count summed across all sessions. The engine\'s own tally, so a name missing from every file fired nowhere this round. Empty is a real answer and means either that nothing fired or that the records predate the field — say which in `note`.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'count'],
        properties: {
          name: { type: 'string' },
          count: { type: 'integer' },
        },
      },
    },
    turns: {
      type: 'object',
      additionalProperties: false,
      required: [
        'sessions', 'branches', 'replays', 'replayProbes',
        'playReplays', 'playProbes', 'verifyReplays', 'verifyProbes',
        'harnessReplays', 'harnessProbes',
        'all', 'prefixTurns',
      ],
      description:
        'World turns counted off the `[status]` footers — every `turn=cost` is one turn the game charged, and every `turn=free` is a parse failure or a meta command that charged nothing. Counted, never asked: the 2026-08-17 round reported 295 against artifacts holding about 1,493, and the 2026-08-18 round reported 11,238 while 32,987 typed commands sat in trees nothing globbed.',
      properties: {
        sessions: { type: 'integer', description: 'In the testers\' canonical transcripts.' },
        branches: { type: 'integer', description: 'In branch-NNN.txt files — turns really played, then rewound out of the transcript.' },
        replays: { type: 'integer', description: 'In the replay probes the session server writes under `.replays/`. These are the TESTERS\': `replay` is an MCP tool and only a live play session can call it. A verifier has no session and replays through the CLI, which lands under its verify label instead.' },
        replayProbes: { type: 'integer', description: 'How many `.replays/` probe directories exist.' },
        playReplays: { type: 'integer', description: 'In the testers\' own `bin/playtest-replay` probes, under their play labels.' },
        playProbes: { type: 'integer', description: 'How many probe directories exist under the play labels.' },
        verifyReplays: { type: 'integer', description: 'In the verifiers\' `bin/playtest-replay` probes, under their verify labels. Usually the largest single number here.' },
        verifyProbes: { type: 'integer', description: 'How many probe directories exist under the verify labels.' },
        harnessReplays: { type: 'integer', description: 'In every other probe transcript this round wrote: the round\'s own machinery — the cartographer\'s survey session, and whatever ad-hoc label an operator replayed under to check a route prefix or a random rate before dispatching anybody. Counted by exclusion, because an operator\'s label cannot be listed in advance. This used to land in the residual and be handed to the critic as a mystery: 8,095 turns on 2026-08-24.' },
        harnessProbes: { type: 'integer', description: 'How many probe directories that count belongs to.' },
        prefixTurns: { type: 'integer', description: 'The `prefixTurns` of every `closing.json`, summed. Not a twelfth tree: these turns are already inside `sessions`, because a deep start is a route the server plays into the tester\'s own transcript. This is the share of that number the harness walked rather than the tester typed. Zero is the ordinary answer, since most sessions open at turn zero. A round whose servers all predate the field reports zero too, which is what `bin/playtest-preflight`\'s `closing.json` row is checked for before dispatch.' },
        all: { type: 'integer', description: 'Every `turn=cost` anywhere under `.context/playtest`, with no glob applied — the residual against the five turn counts above is how a label tree nobody globs for announces itself instead of reading as zero.' },
      },
    },
    sessionsFinished: { type: 'integer', description: 'Probe directories holding a closing.json.' },
    sessionsUnfinished: {
      type: 'array',
      description: 'Probe directories holding a transcript.txt with NO closing.json beside it: a session that never called finish. Name them; do not silently leave them out of the totals.',
      items: { type: 'string' },
    },
    note: { type: 'string', description: 'Only if the count needs one — an empty glob, an unreadable file.' },
  },
}

const CRITIC_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['coverageSection', 'refutedSection', 'charterSilence', 'nextRoundTargets', 'trustworthiness'],
  properties: {
    coverageSection: { type: 'string' },
    refutedSection: { type: 'string' },
    charterSilence: { type: 'string' },
    nextRoundTargets: { type: 'array', items: { type: 'string' } },
    trustworthiness: { type: 'string', enum: ['sound', 'round-is-thin', 'verifier-suspect'] },
  },
}

// The stock text keys that interpolate a bare name and are reachable with an
// actor as the object. These are engine facts, so they live here rather than
// being rediscovered per round. A game with proper-named actors must re-skin
// every one; the complement of what it re-skinned is the vandal's target list,
// and computing it here rather than asking the tester to derive it is
// deliberate — the first calibration round lost `cantTakeActor` precisely
// because the sweep was left as an exercise.
const ACTOR_DIRECTED_KEYS = [
  { key: 'cantTakeActor', probe: (name) => `take ${name}` },
  { key: 'cantSearchActor', probe: (name) => `search ${name}` },
  { key: 'notTakingOrders', probe: (name) => `${name}, go north` },
  { key: 'cantGreetThat', probe: (name) => `greet ${name}` },
  { key: 'cantFollowThat', probe: (name) => `follow ${name}` },
  { key: 'greets', probe: (name) => `${name}, hello` },
]

function articleSweep(survey) {
  const actors = survey.properNamedActors || []
  if (!actors.length) return 'No actors on stage, so no article sweep applies. Say so; do not return silence.'
  const done = new Set(survey.reskinnedTextKeys || [])
  const gaps = ACTOR_DIRECTED_KEYS.filter((k) => !done.has(k.key))
  if (!gaps.length) {
    return `The game re-skins every actor-directed stock line (${ACTOR_DIRECTED_KEYS.map((k) => k.key).join(', ')}). Verify two of them by hand anyway, then say in your coverage note that the sweep was clean.`
  }
  const lines = []
  for (const a of actors) for (const g of gaps) lines.push(`  ${g.probe(a)}          → would expose stock \`${g.key}\``)
  return `These ${gaps.length} actor-directed stock lines are NOT re-skinned by this game: ${gaps.map((g) => g.key).join(', ')}.
Every actor below has a proper name or an honorific, so each of these commands should
be answered in the game's own voice. Any that isn't is a \`register-mismatch\`: a stock
line printing a definite article in front of a proper name, "The Dr. Pike would take
exception to that." RUN THEM ALL:

${lines.join('\n')}

\`take <actor>\` is the oldest and most reliable row here — it is in the standard verb
table in every version of the engine. If a later row answers \`I don't know the word\`,
that verb does not exist in the tree you are playing: skip the row, say so in your
coverage note, and do not file it.

Look in each reply for \`the \` immediately before a capitalized name or an honorific —
"The Dr. Pike would take exception to that." is the whole class.`
}

// ---------------------------------------------------------------------------
// Charters
// ---------------------------------------------------------------------------

// Each is drawn from a defect this repo actually shipped. Diversity is the whole
// point: N identical testers find one bug N times.
// How many copies of a per-region charter one round runs, and the function that
// decides it. Past three the regions get too thin to be worth a whole agent and
// the divergence cycle stops covering forks and starts duplicating them.
//
// One constant because the number reaches three places — both per-region
// charters and the operator advice in the dispatch log — and a cap that is three
// literals is a cap that goes stale in two of them. The dry run deliberately
// holds no copy: it counts the seats the workflow actually made. Declaring MORE
// regions than this is not an error, they are split across the seats by
// `chunkRegions` and never dropped.
const REGION_SEATS = 3
const seatsFor = (regions) => Math.min(Math.max(regions.length, 1), REGION_SEATS)

const CHARTERS = [
  {
    key: 'explorer',
    // The only charter that plays blind, and the only one that instantiates more
    // than once. The cap and its reasoning are `REGION_SEATS`.
    copies: seatsFor,
    blind: true,
    brief: `Walk the map and burn the queue. You are the charter that finds the egg.

You have no map, no room list, no timer list, no vocabulary and no design doc, and you
must not go looking for any of them. That is not a handicap, it is the job: somebody
handed the map navigates instead of exploring, and somebody handed the vocabulary can
never discover that a noun the prose printed has nothing behind it.

\`coverage\` is your worklist. Every item is a command you can paste and a sentence
saying where the game showed you the thing. Work it down. The count it returns is a
countdown, not a statistic — the round is measured on whether you closed it.

Three things it will keep asking you for, and all three are the point:
- **a way out you have not taken.** Take it.
- **a verb you have not tried on a thing.** Try it. Most of what a game gets wrong, it
  gets wrong the first time somebody opens, burns, reads, climbs or searches a thing
  rather than looking at it.
- **a second look at something you just changed.** This is the one that finds real
  defects. Take a thing and examine it again; a description that still says where the
  thing used to be is a defect, and it is invisible to anybody who did not look twice.

Read every description as prose and ask whether it is true *here, now, in this state*.
When it is not, \`note\` it with \`suspicious: true\` at the turn that printed it, quoting
the line. A note costs no turn.

You own: a printed noun the parser then denies, a description that contradicts what you
were just told, a line that describes a state the world is no longer in, and an exit the
prose names that does not exist.

**Type the nouns a description hands you.** When one comes back "I don't know the word"
or "You can't see any such thing", that is the defect: \`note\` it at the turn that printed
the word and file it as \`unanswerable-noun\`. Your contract says why the round's
unknown-word tally is not a substitute.`,
  },
  {
    key: 'timekeeper',
    appliesTo: (survey) => (survey.timers || []).length > 0,
    // Instantiates per region for the same reason the explorer does, and capped
    // the same way. A single timekeeper handed no region covers whatever it
    // drifts into: on Fulminate 2026-08-17 it owned the whole cross-product,
    // spent three quarters of its probes on the first of two declared windows,
    // and left 6:30-6:50 unprobed in five of nine rooms — the one band the round
    // was dispatched to read. Splitting it is not about buying turns, it is
    // about the seat that owns the cross-product not choosing its own coverage.
    copies: seatsFor,
    brief: `A line has to know the room AND the moment. Only a cross-product finds the cell
where it does not. You are the charter that catches an NPC watching a fire from the
bottom of a dark cellar, and every marquee defect this harness has ever found was yours.

**You discover the timetable by watching, not by reading it.** You are not given the
timer list. Stand somewhere and let turns pass; \`coverage\` will tell you when a
do-nothing probe printed differently in one room at two moments with nothing you typed
to explain it, which is what a fuse or a daemon looks like from the player's chair.
Those items are not closed by looking once — they want a second frame and a note
quoting the printed line.

Pass A, on-cell. Get to a room, wait for the event, then \`look\`, \`x <actor>\`, and
examine everything the actor's listing line mentions. Judge the listing line against
THIS room at THIS moment. An arrival line masks the standing listing line on the turn
it prints, so probe the turn after as well — that is where a location-blind line shows.

Pass B, off-cell. Stand in the room for the moment before and the moment after. An actor
who leaves with no departure line, and one whose departure was narrated but who is still
listed, are both defects.

Pass C, ghost-cell. Stand where the actor is not. Does anything print about them? Does a
line name the room you are standing in as though it were somewhere else?

Pass D, displacement. Be in room A for the event and move to room B before its aftermath
fires. Judge each clause separately: does it belong to where you are now, or to where you
were then?

Use \`checkpoint\` and \`restore\` to hold an anchor rather than replaying dozens of waits.

Do not report a cell you never occupied — say you did not reach it. Do not report an
actor's listing line repeating across turns; that is by design.`,
  },
  {
    key: 'interrogator',
    appliesTo: (_survey, capabilities) => capabilities.has('talk'),
    brief: `Ask everyone about everyone, twice, and about things they cannot know yet.

For every (actor, topic): ask, ask AGAIN, then a THIRD time. Repeat-aware dialogue
retires prose, and the failure modes are a paragraph recited twice, or an "again"
variant that swallowed the only real answer.

Then every topic before its gate: ask about a thing before it exists, about an object
without holding it, about a fact not yet learned. Then ask everyone about a topic nobody
owns, to reach each per-actor fallback — everyone has one and there is no dead air. Then
show evidence to the wrong person.

Then the past-tense questions, which matter most: where an answer describes where someone
WAS, check it against what you have watched happen. A character whose account contradicts
the timetable is the defect this charter exists to prevent.

Do not report an actor declining a subject — that is characterization. But a topic the
prose NAMES and nobody answers is yours.`,
  },
  {
    key: 'solver',
    brief: `The only charter that checks the game can be won.

Take the route from the design doc's solution if you were given one, else the
walkthrough test's command list, else the score rules. Play it.

Then play it MINUS ONE STEP, once per step, to check each gate actually gates: win
without the evidence, win before the evidence exists, reach the fuller ending without the
fact it is supposed to require. Then let any deadline run out and check the losing ending
fires and reads as a loss. Then check the score line reads N of a possible N.

\`replay\` is stateless and cheap — use it for the minus-one-step runs rather than
walking each one by hand.

You own unwinnability (severity blocking), a win that fires without its gate, a
knowledge-gated tier firing when the fact was never learned, and an ending whose prose
does not name what the player actually did.

Do not report prose taste on the ending. Do not report a route that failed on your own
typo — replay it first; it is deterministic and cheap.`,
  },
  {
    key: 'wrong-footer',
    // Generated rather than described: the first calibration round lost
    // `cantTakeActor` because the sweep was left to the tester to derive.
    checklist: articleSweep,
    brief: `Type the wrong thing on purpose and judge the reply. You are three of the old
charters in one: the stock line nobody re-skinned, the beginner's mistake, and the line
that should have stopped repeating.

**STEP 1 IS MANDATORY AND COMES FIRST.** The article sweep below is the highest-yield
probe in this harness and it is two commands long. Work it literally; do not re-derive
which rows are worth trying.

STEP 2, the beginner's mistakes. Right verb, wrong noun. Right noun, wrong room. Verbs
out of order — unlock before taking the key, accuse on turn one. Ambiguous nouns, where
several characters answer to "man". Plurals. Empty input. A bare noun. A bare direction
into a wall. \`take all\`. Then the player themselves: \`x me\`, \`x myself\`, \`take me\`,
\`search me\`, \`i\`. The player is always in scope but placed nowhere, so it must answer
to all three words and must NOT appear in a room listing, an inventory, or \`take all\`.

STEP 3, the stub verbs. The engine answers ~48 verbs it has no mechanic for — \`sing\`,
\`dig\`, \`jump\`, \`pray\`, \`xyzzy\` — with one stock line each, and the ones the game has
not re-skinned are in the engine's voice rather than the game's. File a wrong register as
ONE finding per game listing the offenders, not forty findings. A stub whose prose is
actively *false* of the game is a finding in its own right.

STEP 4, the repeats. \`look\` five times in a room: an ITEM's first-sight line must stop
once the player touches it, an ACTOR's must NOT stop, ever. \`open\` a container twice.
\`z\` ten times, watching the room's per-turn lines — one printing every single turn reads
as a stuck record, one that printed once and never again reads as a bug too.

Judge every reply four ways: (a) \`the \` immediately before a capitalized name or an
honorific; (b) a register the game does not otherwise use; (c) a reply asserting
something HAPPENED that did not — "You find nothing of interest in the cook" claims a
search that never occurred; (d) prose claiming a mechanic the game does not enforce.

\`frotz\` is the reserved non-word and the only guaranteed parse error. Any *other*
"I don't know the word" is a noun the game printed and cannot answer, or a verb with no
stub yet. Collect them in one list with counts — **and file the printed nouns among them
as ordinary findings**, category \`unanswerable-noun\`, one per noun, each quoting the line
that printed it. The list with counts is your coverage note; it is not a substitute for a
finding, and a noun that only ever appears in it has not been reported.

Do not report an actor's presence line repeating. It is the most likely false positive
here and it is the exact opposite of a bug.`,
  },
]

// Divergence is assigned round-robin rather than drawn, which is risk 4 in the
// plan made concrete: three explorers left to chance can all draw `abstain`, and
// then nobody opens the egg and the round reports a fork it never tested.
const DIVERGENCE_CYCLE = ['commit', 'abstain', 'defer']

// ---------------------------------------------------------------------------
// Phase 0 — Preflight
// ---------------------------------------------------------------------------

// One agent, to answer one question: can THIS SESSION reach the game's server?
//
// `bin/playtest-preflight` cannot answer it. That script drives `bin/gnusto-mcp`
// over a pipe of its own, which is exactly why it works when registration has
// failed — and exactly why a pass there does not prove the session's MCP client
// ever connected. The two checks look alike and are not: one proves the server
// works, this proves the round can talk to it.
//
// It costs one agent. What it replaces is eight testers walking into the same wall
// and filing eight reports that say they could not find the tools, which is a
// mystery an operator then has to diagnose from the far end. A round that fails
// here fails in one place, with the remedy printed.
phase('Preflight')

const preflight = await agent(
  `${groundMin(labelFor('preflight'))}

You are checking one thing before this round dispatches: that the game's own MCP
server is reachable from this session. Do not play, do not read prose, do not report
findings.

1. \`ToolSearch\`, query \`select:${mcpTools('open', 'finish')}\`.
2. If it returns nothing, try twice more — a server that was still starting when the
   session began can answer a later attempt, and on one recorded round the tools
   arrived on the fourth try once the build tree was warm.
3. If they resolve, \`open\` a session with \`label: "${labelFor('preflight')}"\`,
   \`seed: ${seed}\`, then \`finish\` it immediately with a one-line summary.

Report \`toolsResolved: false\` if the search never returned the tools, and
\`toolsResolved: true\` only if you opened and finished a session. Put the tool names
you actually got in \`toolNames\`. If \`finish\` returned no \`roomsVisited\`, say so in
\`note\` — that is a server frozen at an older commit, and a round dispatched against
one collates nothing.`,
  {
    // The display label, which is what the progress tree and the dry run's stub
    // key on — `labelFor('preflight')` above is the replay label, a different
    // thing that happens to name the same agent.
    label: `preflight:${game}`,
    phase: 'Preflight',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['toolsResolved', 'toolNames'],
      properties: {
        toolsResolved: {
          type: 'boolean',
          description: 'True only if you opened AND finished a session through the server. A ToolSearch that returned names but a call that failed is false.',
        },
        toolNames: {
          type: 'array',
          items: { type: 'string' },
          description: 'The tool names ToolSearch actually returned, copied exactly. Empty if it returned nothing.',
        },
        note: { type: 'string', description: 'Only if something needs saying: an empty search, a finish with no roomsVisited, an error message.' },
      },
    },
  }
)

if (!preflight || !preflight.toolsResolved) {
  // Stop here rather than fanning out. Every later phase is downstream of a
  // working server, so dispatching eight testers past this point spends the
  // round's whole budget to rediscover what one agent already established.
  const note = (preflight && preflight.note) || 'the Preflight agent returned nothing'
  log(`Preflight FAILED: the game's MCP server is not reachable from this session. ${note}`)
  log(`Remedy, in order: run \`bin/playtest-preflight ${game}\` — it builds, and proves the`)
  log('server answers over a pipe of its own. If it passes and ToolSearch still finds')
  log('nothing, restart the session: a `.mcp.json` server is registered at session start,')
  log('and a server already running is frozen at the commit it started on.')
  return {
    dispatched: false,
    reason: 'mcp-unreachable',
    note,
    toolNames: (preflight && preflight.toolNames) || [],
    remedy: `bin/playtest-preflight ${game}, then restart the session if it passes`,
  }
}

// The tools resolved, so the round goes on — but the agent was also asked to say
// in `note` whether `finish` came back without `roomsVisited`, which is a server
// frozen at an older commit. That is the cheapest staleness signal the round has
// and it used to be read only on the failure path, so a preflight that reached a
// stale-but-answering server reported it into a field nothing looked at.
if (preflight.note) log(`Preflight note: ${preflight.note}`)

// ---------------------------------------------------------------------------
// Phase 1 — Survey
// ---------------------------------------------------------------------------

phase('Survey')

const survey = await agent(
  `${groundMin(labelFor('survey'))}

You are the cartographer for this play-test round. You do not play; you read the code
and the docs and produce the denominator every later phase measures itself against.

**The room roster and the timer roster are not yours to write. Copy them.** The game's
own MCP server will hand you both, exactly as the engine declared them, and the round's
numerators are counted in that same key space — so a name you retype, tidy or infer
scores as a room nobody entered and a timer that never fired. Fetch the tools with
\`ToolSearch\`, query \`select:${mcpTools('open', 'survey', 'finish')}\`.

${toolsOrStop}

Then:

    open  → label: "${labelFor('survey')}", seed: ${seed}   (take the default role: you are
                                                              the one agent this round that
                                                              is SUPPOSED to hold the answer key)
    survey → the rooms, the timers, the verb tables, maxScore, the bootstrap's warnings

Rooms with \`isReachable: true\` go in \`rooms\`; the rest go in \`unreachableRooms\`. Copy
\`id\` and \`name\` character for character in both, and copy each timer's \`name\` the same
way. Do not add a row the tool did not return and do not drop one it did. Call \`finish\`
when you are done.

Report:
1. Every reachable room, and any room that exists but nothing leads to — both off the
   tool, as above.
2. Every alarm, fuse, daemon and timetable stop — one row per timer the tool named — and
   for each, whether its body reads
   the player's location or a "was here when it happened" flag. That flag is what marks
   which timers need the full event x room cross-product, so get it right. \`kind\`, \`at\`
   and \`readsPlayerLocation\` are yours to read out of the source; only the name is the
   tool's.
3. The state axes a line could be wrong along.
4. Every noun the prose prints, crossed against the vocabulary (name, synonyms,
   adjectives), with whether it is answerable. Cross these two in code, not by playing:
   whether every printed noun has a word behind it is checkable before a single turn.
5. Which stock text keys the game overrides in its \`text\` block, AND which stub-verb
   replies it overrides via \`text.stubs.<verb>\`. The COMPLEMENT of each is a vandal
   target list. Read \`Sources/Gnusto/Actions/GameText.swift\` for the full stub roster
   (the \`StubReplies\` struct) — a game that overrides none of them answers ~48 verbs in
   the engine's voice.
6. Which actors have proper names or honorifics.
7. Which oracle tiers were actually available to you.

Read \`Sources/${game}/\` and ${docPath ? `\`${docPath}\`` : 'the game type\'s doc comment'} for everything above that the tool does not answer. The rosters themselves are the tool's, verbatim; that is what coverage is scored against.`,
  { label: `survey:${game}`, phase: 'Survey', schema: SURVEY_SCHEMA }
)

if (!survey) throw new Error('survey failed; a round without a denominator cannot report coverage honestly')

// Every room the game declares — the denominator, and *not* `survey.rooms`.
//
// `isReachable` is `definition.reachableRooms.contains(id)`, which walks the
// static exit table and nothing else. A room a rule moves the player into is
// declared, entered and playable, and it is `isReachable: false`: Dungeon has
// eight of them — the balloon's four air rooms, the bank curtain's two, the
// river current, the cage drop. Scoring against `survey.rooms` alone charged the
// 2026-08-24 round twice for that. The eight failed `reconcile` and were
// reported as ids "on no roster", which fired the critic's line about a
// `closing.json` written by an older build; and they were missing from the
// denominator, so the fraction was over the wrong total.
//
// Reachability stays as an annotation, because it is a real distinction — a room
// only a rule can reach is one no walker will find by trying exits, and that is
// worth a next-round planner knowing. What it is not is a roster.
//
// Deliberately not the union with the rooms anybody entered: that would make the
// denominator depend on the numerator, and a room nobody entered could then
// never be reported as missed, which is the one thing this fraction is for.
const ruleEnteredRooms = survey.unreachableRooms || []
const declaredRooms = [...survey.rooms, ...ruleEnteredRooms]

// A room as a reader should see it: `Name (id)`. Every room list a person reads
// goes through this, because the roster is keyed by id and a display name is not
// unique — a list that printed the name alone would say "Coal Mine" seven times
// and name nothing. An id on no roster prints alone rather than being dressed up
// as a room.
const roomNames = new Map(declaredRooms.map((r) => [r.id, r.name]))
const roomLabel = (id) => (roomNames.has(id) ? `${roomNames.get(id)} (${id})` : id)

// The whole roster, rendered once. It is an invariant of the round and it used
// to be rebuilt per non-blind charter per round.
//
// The rule-entered rooms are named separately rather than folded in, because
// what a sighted charter does with this list is plan a walk: a room reached only
// by pulling a lever cannot be routed to, and a charter told it is on the map
// with the rest spends turns hunting for an exit that is not there.
const roomRoster =
  survey.rooms.map((r) => roomLabel(r.id)).join(', ') +
  (ruleEnteredRooms.length
    ? `. Reached by a rule and not by any exit, so no walk will find them — ${ruleEnteredRooms.map((r) => roomLabel(r.id)).join(', ')}`
    : '')

// Each charter decides for itself whether this game gives it anything to do,
// reading the survey and the manifest capabilities directly. A predicate rather
// than a keyword means a new axis needs no new branch here.
const active = CHARTERS.filter((c) => !c.appliesTo || c.appliesTo(survey, capabilities))
const requested = ARGS.charters ? new Set(String(ARGS.charters).split(',').map((s) => s.trim())) : null
const chosen = requested ? active.filter((c) => requested.has(c.key)) : active
const skipped = CHARTERS.filter((c) => !chosen.includes(c))

// Regions come from `focus` when the operator split the map, and are otherwise
// one unnamed region — which is the right answer for a nine-room game and the
// wrong one for a 195-room game whose operator forgot.
const regions = String(ARGS.focus || '')
  .split(/\s*\|\s*/)
  .map((r) => r.trim())
  .filter(Boolean)

// Splits the declared regions into `seats` contiguous chunks, every region in
// exactly one of them.
//
// The seating used to be `regions[i % regions.length]`, which is wrong the
// moment the operator declares more regions than the copy cap allows: with four
// regions and three copies the modulo runs 0, 1, 2 and **region four is handed
// to nobody, silently**. That is what happened to the 2026-08-25 Dungeon round,
// and a region nobody was seated on reads afterwards exactly like a region
// nobody found anything in.
//
// Chunking rather than raising the cap, because the cap's own reasoning still
// holds — past three copies the regions get too thin to be worth a whole agent
// and the divergence cycle starts duplicating forks rather than covering them.
// Doubling a seat up costs that seat's attention; dropping a region costs all of
// it. The dispatch log says which seat took two.
// Balanced, not `ceil`-and-slice: four regions over three seats must be 2/1/1,
// and a flat `Math.ceil(4/3)` chunk of two makes it 2/2/0 — which leaves a seat
// with no assignment at all and is the bug this replaced wearing a hat.
const chunkRegions = (list, seats) => {
  const out = []
  const base = Math.floor(list.length / seats)
  const extra = list.length % seats
  let at = 0
  for (let i = 0; i < seats; i += 1) {
    const take = base + (i < extra ? 1 : 0)
    out.push(list.slice(at, at + take))
    at += take
  }
  return out
}

// A seat's chunk as one line of prose. Numbered only when there is more than
// one, because a region's own text says "and" often enough that a bare join
// reads as a single sentence.
const renderRegions = (chunk) =>
  chunk.length > 1 ? chunk.map((r, n) => `(${n + 1}) ${r}`).join('; ') : (chunk[0] ?? null)

// The seat's assignment as the tester reads it. Here rather than inline in the
// prompt because the plural case has to say how many, and a template that
// counted them in three separate ternaries said "two" whatever the number was.
// A room outside every declared region is owned by nobody, and reads afterwards
// exactly like a room nobody found anything in. Nothing here can catch that:
// `SKILL.md` forbids a region from naming rooms, so no code can compare a split
// against the roster. So the testers are told instead — one sentence, true of
// every split, turning "nobody was assigned this" into "whoever runs out of
// region first". `SKILL.md`, "A region is an assignment", has the two rounds
// that paid for it.
const REGION_RESIDUAL = '**Rooms this game has that no region describes are owned by nobody. If your own assignment runs dry before your budget does, they are yours — go there, and say in your report that that is where you went.**'

const regionBanner = (chunk) => {
  if (!chunk.length) return ''
  if (chunk.length === 1) return `\n**Your region is ${renderRegions(chunk)}.**\n`
  return (
    `\n**You have ${chunk.length} regions: ${renderRegions(chunk)}.** More regions than `
    + `seats were declared, so yours is ${chunk.length} of them. Split your budget between `
    + `them; do not spend it all on the first.\n`
  )
}

// One charter can run more than once. Only `explorer` does today, and the
// assignment it carries — a region and a divergence policy — is the reason: two
// explorers with the same policy in the same region are one explorer run twice.
const playRoster = chosen.flatMap((charter) => {
  const copies = charter.copies ? charter.copies(regions) : 1
  const chunks = charter.copies ? chunkRegions(regions, copies) : []
  return Array.from({ length: copies }, (_, i) => ({
    charter,
    key: copies > 1 ? `${charter.key}-${i + 1}` : charter.key,
    // Only a charter that instantiates per region gets one. A single-copy
    // charter handed `regions[0]` would be told its region is whichever the
    // operator happened to name first, which is worse than being told nothing:
    // the timekeeper would have skipped every clock cell outside it.
    // The chunk itself and nothing derived from it. Anything that has to count
    // a seat's regions counts them; anything that has to print them calls
    // `renderRegions`. A second stored field would be an invariant to keep.
    regions: copies > 1 ? chunks[i] : [],
    // Only the blind charters take a policy. The others are running fixed
    // rosters or a known route, so withholding a move from them would just make
    // their own job incomplete.
    divergence: charter.blind ? DIVERGENCE_CYCLE[i % DIVERGENCE_CYCLE.length] : 'commit',
  }))
})

log(
  `${game}: ${declaredRooms.length} rooms, ${(survey.timers || []).length} timers, tiers ${survey.tiers.join('+')}. ` +
    `Testers: ${playRoster.map((r) => `${r.key}${r.charter.blind ? `/${r.divergence}` : ''}`).join(', ')}` +
    `${skipped.length ? ` — not run: ${skipped.map((c) => c.key).join(', ')}` : ''}.`
)

// The seating, spelled out, because a doubled-up seat is the one thing about the
// split the operator can still act on — declare fewer regions, or accept that
// one agent reads two. It is printed even when nothing doubled: silence here is
// what let four regions go unseated for a whole round.
if (regions.length) {
  // Grouped by chunk, not listed per seat. Explorers and timekeepers are handed
  // identical chunks, so a per-seat listing prints the whole plan twice and
  // reports "2 seats took more than one" where one chunk is doubled and seated
  // twice — a number the operator would act on, and it would be wrong.
  const bySeat = new Map()
  for (const r of playRoster.filter((seat) => seat.regions.length)) {
    const key = renderRegions(r.regions)
    if (!bySeat.has(key)) bySeat.set(key, { keys: [], size: r.regions.length })
    bySeat.get(key).keys.push(r.key)
  }
  const doubled = [...bySeat.values()].filter((c) => c.size > 1)
  log(
    `Regions (${regions.length} declared over ${bySeat.size} chunk(s)): ` +
      `${[...bySeat].map(([text, c]) => `${c.keys.join('+')} → ${text}`).join('; ') || 'none seated — no charter runs per region'}` +
      `${doubled.length ? `. ${doubled.length} chunk(s) hold more than one region; declare at most ${REGION_SEATS} to give each its own.` : '.'}`
  )
}

// ---------------------------------------------------------------------------
// Phase 2 + 3 — Play, then Triage
// ---------------------------------------------------------------------------

// Every key this round already knows about, and the only thing that actually
// suppresses a rediscovery: `seen.has(key)` below runs over every finding no
// matter what its tester was told.
//
// Which is why the sighted charters get this pasted into their prompts and the
// blind ones do not. A key is `<ownerFile>::<the game's own prose>`, so the
// ledger is a room list, a source map and an excerpt file at once — handing 60
// of them to an explorer whose brief opens "you have no map, no room list, no
// vocabulary, and you must not go looking for any of them" gives away more than
// the survey ever would, and the leak grows with the ledger rather than with the
// game. Dungeon's rows 72 and 113 are both the Up a Tree room, its description
// and its file.
//
// The warning was only ever deterrence; dedup is code. So the blind charters
// lose nothing mechanical, and the dry run asserts no key reaches them.
const seen = new Set(ledger)
const confirmed = []
const refuted = []
const routed = []
const coverage = []
let dryRounds = 0

// How many findings one verifier judges, and how many verifiers judge each one.
// 25 is a size an agent can hold while still replaying every reproducer;
// declaration-keyed dedup already puts a Fulminate round at ~18-20 classes, so in
// practice this is one batch and two agents against the ~70 of the round before.
const VERIFY_BATCH_SIZE = 25
const VERIFY_RATERS = 2

// Inter-rater agreement, which the round has never had. `agreementTotal` counts
// only findings two raters both reached, so a rater that died does not read as
// disagreement — and `singleRated` says how often that happened, because an
// agreement figure over a thin denominator is worth less than it looks.
let agreementTotal = 0
let agreementMatched = 0
let singleRated = 0
const disagreements = []

for (let round = 1; round <= maxRounds && dryRounds < dryTarget; round++) {
  phase('Play')

  // A barrier, not a pipeline. It buys one thing: a round is a unit, so
  // `dryRounds` counts something meaningful and the ledger gets a coherent
  // batch. It costs wall-clock — no verification starts until the slowest
  // tester returns — and pipelining each charter into its own triage would
  // recover that, since `seen` is a running Set and the refuter is told about
  // one finding at a time. Worth doing when a round grows past a handful of
  // charters; not worth the round-boundary complication yet.
  const reports = (
    await parallel(
      playRoster.map((assignment) => () => {
        const { charter } = assignment
        // Rule 2: a blind charter is told nothing the game has not printed to
        // it. The survey still runs — the critic needs a denominator — it just
        // stops reaching the testers who are supposed to be discovering it.
        const mine = assignment.regions
        const oracle = charter.blind
          ? ''
          : `
The survey found:
- Rooms: ${roomRoster}
- State axes: ${(survey.stateAxes || []).join(', ') || 'none'}
- Stock keys the game re-skinned: ${(survey.reskinnedTextKeys || []).join(', ') || 'none'}
- Stub-verb replies the game re-skinned: ${(survey.reskinnedStubs || []).join(', ') || 'NONE — every stub answers in the engine voice'}
- Proper-named actors: ${(survey.properNamedActors || []).join(', ') || 'none'}
`
        // `rewind` and `export` were missing from this list while the collator
        // counted the `branch-*.txt` files a rewind writes as a named turn row —
        // one round found 102 real turns in six of them. A tool the harness
        // measures is a tool the prompt has to hand over.
        const tools = mcpTools(
          'open', 'move', 'recall', 'coverage', 'note', 'finish',
          'checkpoint', 'restore', 'rewind', 'export', 'replay')
        return agent(
          `${(charter.blind ? groundBlind : ground)(playLabelFor(round, assignment.key))}

Your charter is **${charter.key}**. Round ${round} of at most ${maxRounds}.

You play through the game's own MCP server. Its tools are deferred, so fetch them first
with \`ToolSearch\`, query \`select:${tools}\`.

${toolsOrStop}

Open with \`label: "${sessionLabelFor(round, assignment.key)}"\`, \`seed: ${seed}\`, \`role: "${charter.blind ? 'explorer' : 'unrestricted'}"\`${charter.blind ? `, \`divergence: "${assignment.divergence}"\`` : ''}.
${routes.length ? `${DEEP_START_LEAD} ${routeList}. Your assignment names the one it means; \`open\` takes it as \`start: "<name>"\`, the route's turns are not charged to you, and the commands are not yours to read. The tool's own description has the rest.
${routes.length > 1 ? `
A session takes one route, at \`open\`. If your assignment names a second, work the first to the end, \`finish\` it, then \`open\` a fresh session under \`label: "${sessionLabelFor(round, assignment.key)}-b"\` with the other \`start\`. Keep the suffix on the end of that label — everything the round counts is globbed off it.
` : ''}` : ''}
${charter.blind ? `**Read the \`instruction\` your open returns and follow it for the whole session.** It tells you what to do the first time the game offers you something you cannot take back. Another tester has been given the opposite orders, so the branch you leave alone is covered and the one you take is yours to describe.\n` : ''}
Every turn's output ends with a \`[status]\` line naming the room, the move counter and
whether the command cost a turn. \`note\` writes a comment into your transcript at the
current turn and costs nothing — use it the moment a line reads wrong, not forty turns
later from memory. \`finish\` ends the session.
${regionBanner(mine)}${regions.length ? `\n${REGION_RESIDUAL}\n` : ''}
${charter.brief}

Your turn budget is about ${turnBudget} engine turns, and it counts **every turn you
cause**, not just the ones in this session: the moves in your own transcript, the turns
inside any branch you rewind away from, and every turn of every \`replay\` probe and every
\`bin/playtest-replay\` probe you run. The \`[status]\` move counter shows you only the
first of those four, so a dozen forty-command replays will spend your budget several
times over without the counter moving. Add them up yourself. Spend the budget on breadth
first, then depth on whatever looked wrong.
${oracle}${charter.checklist ? `\nYOUR GENERATED CHECKLIST:\n${charter.checklist(survey)}\n` : ''}
${!charter.blind && seen.size ? `\nAlready seen in earlier rounds or the ledger — do NOT report these again:\n${[...seen].slice(0, 60).join('\n')}` : ''}

The session records to disk from the moment you open it, so the evidence is already
attached: carry the transcript path your \`open\` returned into \`transcriptPath\`. Use
\`replay\` to re-run a trimmed reproducer from a clean start before you report it — it
boots a fresh world and touches nothing, so it cannot disturb your session.

Two reproducers do not start clean, and each has one field that says so.

**One taken from a deep start** cannot go through \`replay\` at all, which always boots at
turn zero. Take a \`checkpoint\` on the turn your session opens — that is the frame the
route stopped on — and \`restore\` to it to re-run a trimmed list from exactly where you
began. **Put the route name in the finding's \`startedFrom\` field**, or the verifier
replays your commands from turn zero, where they mean something else or nothing at all.

**One that begins \`restore\`** needs the save you wrote: pass
\`savesFrom: "${sessionLabelFor(round, assignment.key)}"\` to \`replay\`, or the game answers
"Restore failed." and the verdict is about the harness rather than about your finding —
and the answer says so, on a \`restore-unreachable\` line. **Put that same label in the
finding's own \`savesFrom\` field.** A staged reproducer filed without it reaches the
verifier looking like one that starts clean, and is refuted for a reason that is about the
harness.

Set \`replayedCleanly\` honestly in all three cases — it means you re-ran the trimmed list
and saw the excerpt, from clean, from the route, or from your save. A finding whose
reproducer you did not re-verify is dropped at triage, so guessing gains you nothing.

Your coverage note is not a formality. Name what you did not reach. A charter that
reports findings and hides its gaps makes the round look thorough when it was not.`,
          { label: `play:${assignment.key}`, phase: 'Play', schema: FINDINGS_SCHEMA }
        // The label the tester actually opened under, attached here rather than
        // derived downstream from `report.charter` — which is the agent's own
        // free-text string and not a directory name. A verifier replaying a
        // reproducer that begins `restore` needs this exact label to reach the
        // slot, and having to guess it is what turned four real defects into
        // `not-reproducible` verdicts in the 2026-08-25 Dungeon round.
        ).then((out) => out && { ...out, sessionLabel: sessionLabelFor(round, assignment.key) })
      })
    )
  ).filter(Boolean)

  for (const r of reports) {
    coverage.push({ round, charter: r.charter, ...r.coverage })
  }

  phase('Cluster')

  const candidates = []
  for (const report of reports) {
    for (const f of report.findings || []) {
      f.charter = report.charter
      // The tester's own `savesFrom` wins over the label they opened under: a
      // reproducer may restore a save written under a different label, and the
      // session label is only the fallback for one that named none.
      f.sessionLabel = f.savesFrom || report.sessionLabel
      if (f.routedTo) {
        record(routed, f)
        continue
      }
      if (!f.replayedCleanly) {
        record(refuted, { ...f, refutationKind: 'not-reproducible', reason: 'The tester did not re-verify the trimmed reproducer — from a clean start, from the route its `startedFrom` named, or from the save its `savesFrom` named.' })
        continue
      }
      candidates.push(f)
    }
  }

  // Re-keying dedup from the excerpt to the emitting declaration is the lever
  // the whole round's cost sits on: keyed on text, Fulminate's findings stayed
  // ~70 classes and bought ~70 verifiers; keyed on the declaration that printed
  // them, they collapse to ~18-20. Six testers reading one location-blind
  // listing line in six rooms report six excerpts of one defect, and only the
  // declaration tells you that.
  //
  // **This is an agent, and the plan called for code.** It cannot be code: the
  // mapping is excerpt -> the declaration that emits it, which means searching
  // the source tree, and this script has no filesystem access. Nor can the
  // tester supply it, because the blind charters may not read source at all —
  // that is the point of them. So it is one cheap mechanical agent whose whole
  // job is the lookup, and the dedup below is plain code over what it returns.
  // One agent here removes tens of verifiers downstream.
  const clustered = candidates.length
    ? await agent(
        `${groundMin(labelFor(`r${round}`, 'cluster'))}

You are the clusterer. You do not judge findings; you locate the code that printed them.

For each finding below, find the **declaration** whose text the excerpt came from and
report its id as \`<file>::<declaration>\` — the property or constant the string is
declared on, not the line number and not the file alone. \`grep -rn\` a distinctive
fragment of the excerpt under \`${pkg}/Sources/\` and read outward to the enclosing
\`let\`/\`static let\`/trait. Prose tables are the common case in this repo: a hit in a
\`Prose\` enum is the declaration, and the entity that references it is not.

Two findings that quote different sentences of the same declaration get the SAME id.
Two findings quoting one sentence printed in different rooms get the same id as well —
one untrue sentence seen in two frames is one defect with two frames.

When you cannot find it, say \`unlocated\` rather than guessing. A wrong id merges two
real defects into one and the second is never fixed, which is worse than an extra class.

${candidates.map((f, i) => `${i + 1}. [${f.charter}] ${f.ownerFile}
   ${f.excerpt}`).join('\n')}`,
        { label: `cluster:r${round}`, phase: 'Cluster', schema: CLUSTER_SCHEMA, effort: 'low' }
      )
    : null

  const declarations = new Map(
    ((clustered && clustered.assignments) || []).map((a) => [a.index, a.declaration])
  )

  phase('Triage')

  const fresh = []
  const merged = []
  for (const [i, f] of candidates.entries()) {
    const declaration = declarations.get(i + 1)
    // Falling back to the old text key rather than dropping the finding: an
    // unlocated excerpt is still a defect, it just dedups less well.
    const key =
      declaration && declaration !== 'unlocated'
        ? `decl::${declaration}`
        : `${f.ownerFile}::${normalize(f.excerpt)}`
    if (seen.has(key)) {
      merged.push({ ...f, key })
      continue
    }
    seen.add(key)
    fresh.push({ ...f, key, declaration: declaration || null })
  }
  if (merged.length) {
    log(`Round ${round}: ${merged.length} finding(s) merged into a class already seen.`)
  }

  if (!fresh.length) {
    dryRounds++
    log(`Round ${round}: nothing new. Dry rounds: ${dryRounds}/${dryTarget}.`)
    continue
  }
  dryRounds = 0

  // Adversarial verification, batched, two independent raters per batch.
  //
  // Batching is the same shape as the failure this whole harness is being
  // rebuilt to escape: an agent burning a checklist down mechanically instead of
  // reading. Two things hold against it and both are load-bearing.
  // `attemptedRefutation` is required *per finding*, so a rater cannot pass one
  // without writing the strongest case against it. And the second rater turns a
  // rubber-stamping first rater into a visible drop in agreement rather than a
  // silent one — which is why the agreement figure goes in the report and why
  // the raters are not told they are being cross-checked. They cannot see each
  // other, so nothing is gained by conformity; telling them would only tempt
  // both toward whichever verdict looks most defensible.
  const batches = chunk(fresh, VERIFY_BATCH_SIZE)
  log(
    `Round ${round}: ${fresh.length} fresh finding(s) in ${batches.length} batch(es) of up to ` +
      `${VERIFY_BATCH_SIZE}, ${VERIFY_RATERS} independent raters each — ` +
      `${batches.length * VERIFY_RATERS} verifier(s).`
  )

  const rated = await parallel(
    batches.flatMap((batch, batchIndex) =>
      Array.from({ length: VERIFY_RATERS }, (_, rater) => () => {
        // Spreading the lens across the charters is what makes the panel diverse
        // rather than N copies of the same skepticism. A batch spans charters, so
        // the "not the charter that found it" rule is carried per finding in the
        // prompt rather than by picking one lens for the whole batch.
        const lens = playRoster.length
          ? playRoster[(batchIndex + rater) % playRoster.length].key
          : 'skeptic'
        const verifyLabel = verifyLabelFor(round, batchIndex + 1, rater + 1)
        return agent(
          `${ground(verifyLabel)}

You are verifying other people's play-test findings, and your job is to REFUTE them. You
found none of these. You are reading them through the ${lens} lens.

**Default to refuted.** If you cannot establish that a line is false of the frame it
printed in, refute it. A plausible-but-wrong finding that reaches a fixer is worse than no
finding at all, because the fixer will "correct" prose that was right.

There are ${batch.length} finding(s) below. Return one verdict for each, keyed by its
number. **Judge them one at a time and independently.** They came from different testers
in different parts of the game and share nothing but this prompt; a verdict that reads as
though it were reached by working down a list, rather than by replaying the reproducer, is
the specific way this step fails.

THE FINDINGS
${batch
  .map(
    (f, i) => `
[${i + 1}] found by the ${f.charter} charter
  Claim:      ${f.claim}
  Category:   ${f.category}   Severity: ${f.severity}
  Excerpt:    ${f.excerpt}
  Frame:      ${f.frame.room}${f.frame.hour ? ' @ ' + f.frame.hour : ''} — ${f.frame.state}
  Reproducer: ${JSON.stringify(f.reproducer)}
  Fault:      ${f.fault}
  Owner file: ${f.ownerFile}${f.startedFrom ? `
  Start:      ${f.startedFrom}` : ''}
  Saves:      ${f.sessionLabel || 'unknown'}`
  )
  .join('\n')}

Work this checklist IN ORDER, for each finding separately. These are the three ways this
repo's testers have actually been wrong, most frequent first.

1. **Is it intentional design?** A character declining to act is characterization, not
   a defect. ${docPath ? `Check the design doc's "free to change" list — a finding objecting to a name, a line of prose, the tone, or a plot choice is objecting to something the doc explicitly licenses, and is refuted on sight unless it ALSO shows the line is untrue of its frame. Check the mechanics contract too: a behaviour the contract REQUIRES is not a defect.` : `With no design doc, lean harder on this: you cannot tell authorial intent from the outside, so a finding that amounts to a preference is refuted.`}
2. **Is it owned by another issue?** Only if your prompt named one above — the open
   set is supplied per round, and it is often empty. If it is empty, nothing is owned
   elsewhere and this check cannot save the finding. Do not reach for an issue number
   from memory: #76, #77 and #78 all closed, and forwarding a symptom to a fixed issue
   silently discards a regression.
3. **Did the tester misread?** Replay the reproducer YOURSELF, once per finding:
   \`bin/playtest-replay ${game} --commands <file> --seed ${seed} --label ${verifyLabel}-<n>\`.
   Confirm the excerpt appears verbatim and in the frame claimed. The \`[status]\` footer
   on each turn names the room, the move counter and whether the command cost a turn, so
   check the claimed frame against that line rather than against a command count — meta
   commands and parse failures cost no turn. If the quoted text is not in the tree, or
   the frame does not match the footer, refute and say which.

${routes.length ? `   **A finding with a \`Start:\` row was taken from a deep start, and needs its route
   rather than a save.** One flag plays it ahead of your command list:
   \`bin/playtest-replay ${game} --start <that route> --commands <file> --seed ${seed} --label ${verifyLabel}-<n>\`.
   The seed above is the routes' own — a round takes its seed from them — so it agrees and
   the run proceeds; a \`--seed\` that DISAGREED would be refused rather than quietly
   winning, because a route replayed at another seed lands somewhere else. Drop the flag
   on a finding that carries the row and you walk its commands somewhere else entirely,
   then refute a real defect. No row means the reproducer begins at turn zero.
   \`bin/playtest-routes ${game} list\` says which routes exist and where each one lands.

` : ''}   **A reproducer whose first command is \`restore\` needs the save the tester wrote.**
   Add \`--saves-from <the finding's \`Saves:\` label>\` and those slots are copied into your
   own label before the run, so \`restore\` reaches the slot the tester wrote. The copy is
   one way and cannot touch their label. \`--saves-from\` also takes a **path** — anything
   holding a slash — so if the label is gone, the \`saves-in/\` directory beside any earlier
   staged probe's transcript holds the same bytes and works in its place. **A \`restore\` that fails is a fact about the
   harness, not about the finding** — never refute \`not-reproducible\` on it. If the
   label reads \`unknown\` or holds no slot, judge the excerpt alone and answer
   \`needs-human\` with a \`reason\` saying the save was unreachable. Four real defects
   were discarded this way in the 2026-08-25 Dungeon round.

   **A transcript with no \`[status]\` line at all means the check did not run** — a
   stale build or an older checkout, since \`bin/playtest-replay\` has set
   \`GNUSTO_STATUS\` unconditionally since #288. That is a fact about the binary and
   not about the finding, so do not refute on it: judge the excerpt alone, and if the
   finding survives steps 1, 2 and 4, answer \`needs-human\` with a \`reason\` saying
   the transcript held no footer, naming the probe you replayed into.

   Give each replay its own label suffix. A label is a namespace holding many probes,
   and a batch that replays everything under one label produces a directory nobody can
   point a verdict at — which is exactly how the 2026-07-30 round ended up with three
   refutations citing one directory that held none of them.

   Put the \`[playtest] transcript=…\` path of the replay you judged on into
   \`evidencePath\`, verbatim. Your verdict is the thing a reader audits first, and a
   verdict citing a path nobody can resolve is indistinguishable from one nobody
   checked.

4. **Then date it.** A defect that arrived with a recent fix is the most valuable kind
   to catch and the easiest to lose, because the fix looks like progress. Blame the
   offending sentence rather than guessing:

       git log -S '<a distinctive fragment of the excerpt>' --oneline HEAD -- <ownerFile> | grep -v ' checkpoint:'

   The **last** line is where the text entered the file; the first is the most recent
   touch. Filter the \`checkpoint:\` refs — this repo carries session checkpoints that
   will otherwise bury the answer. Set \`provenance.age\` to \`introduced\` when the
   sentence arrived in the last few commits (name the commit and its subject),
   \`preexisting\` when it has been there for a while, and \`unknown\` when the fragment
   is too generic to blame — do not guess. If the commit that introduced it describes
   itself as a fix, say so in the note: a fix that reintroduced the class it was
   repairing is the single most useful thing this harness can report.

Whatever you conclude, write the strongest case AGAINST each finding into its own
\`attemptedRefutation\` — including the ones you confirm. Say what would have to be true
for that line to be correct in its frame, and then why it is not. This is required for
every finding, and it is the check on you: a verifier that cannot argue the other side
has not really examined this one. A batch whose refutation attempts read
interchangeably has told the round nothing.

Then, only if it survives all four: is the fix a judgement call with more than one
reasonable answer? Answer needs-human rather than confirmed-defect. That is not a
hedge; it routes the finding to a person instead of to an agent that will pick a design
by coin flip.`,
          {
            label: `verify:b${batchIndex + 1}r${rater + 1}`,
            phase: 'Triage',
            schema: VERDICT_BATCH_SCHEMA,
            effort: verifyEffort,
          }
        )
          .then((v) => ({ batchIndex, rater, verdicts: (v && v.verdicts) || [] }))
          // Catch here rather than letting parallel() turn a throw into a bare
          // null: a batch has to survive its rater's death, or the findings in
          // it become invisible in the report instead of being counted.
          .catch((e) => ({ batchIndex, rater, verdicts: [], error: String(e) }))
      })
    )
  )

  // Collect each rater's verdicts against the finding they were about. A rater
  // that skipped an entry, or invented an index, contributes nothing for it —
  // which reads downstream as a missing rater, never as agreement.
  const byFinding = new Map(fresh.map((f) => [f.key, []]))
  for (const row of rated) {
    if (!row) continue
    const batch = batches[row.batchIndex] || []
    for (const verdict of row.verdicts) {
      const finding = batch[Number(verdict.index) - 1]
      if (!finding) continue
      byFinding.get(finding.key)?.push(verdict)
    }
  }

  // Reconcile in plain code. Agreement stands; disagreement goes to a person
  // rather than to whichever rater the loop happened to read last. `needs-human`
  // is therefore reached two ways — a rater saying the fix is a judgement call,
  // and two raters failing to agree — and both mean the same thing to a reader.
  for (const finding of fresh) {
    const views = byFinding.get(finding.key) || []
    if (!views.length) {
      record(refuted, {
        ...finding,
        refutationKind: 'none',
        reason:
          'No verifier returned a verdict for this finding, so it is dropped unverified rather than trusted.',
      })
      continue
    }

    const distinct = new Set(views.map((v) => v.verdict))
    if (views.length >= 2) {
      agreementTotal++
      if (distinct.size === 1) agreementMatched++
    } else {
      singleRated++
    }

    // Only the *verdict* is reconciled. A rationale is not a verdict, so it is
    // never merged away: `record` puts every rater's own words on the row,
    // whatever branch it takes.
    let verdict
    if (distinct.size === 1) {
      // The summary `reason` that reaches `verifierNote` is rater 1's, and that
      // is all that field claims to be. Reading it as the verdict's whole
      // reasoning is the trap; `raterViews` is what the independence check
      // downstream reads.
      verdict = views[0]
    } else {
      // Deliberately not a majority vote or a third rater: with two lenses
      // disagreeing, the interesting fact is that reasonable readers differ,
      // and that is the definition of the case a person should settle.
      verdict = {
        ...views[0],
        verdict: 'needs-human',
        reason: views
          .map((v, i) => `Rater ${i + 1} said ${v.verdict}: ${v.reason}`)
          .join(' — '),
      }
      disagreements.push({
        claim: finding.claim,
        ownerFile: finding.ownerFile,
        verdicts: views.map((v) => v.verdict),
      })
    }

    if (verdict.verdict === 'confirmed-defect' || verdict.verdict === 'needs-human') {
      record(confirmed, { ...finding, verdict: verdict.verdict, verifierNote: verdict.reason, correctedFrame: verdict.correctedFrame, provenance: verdict.provenance }, views)
      if (verdict.provenance && verdict.provenance.age === 'introduced') {
        log(`Newly introduced: "${String(finding.claim).slice(0, 70)}" — blamed on ${verdict.provenance.blamedCommit || '?'}${verdict.provenance.blamedSubject ? ` (${verdict.provenance.blamedSubject})` : ''}.`)
      }
    } else if (verdict.verdict === 'route-elsewhere') {
      record(routed, { ...finding, routedTo: verdict.routedTo, reason: verdict.reason }, views)
    } else {
      record(refuted, { ...finding, refutationKind: verdict.refutationKind, reason: verdict.reason }, views)
    }
  }

  if (disagreements.length) {
    log(
      `Round ${round}: ${disagreements.length} finding(s) split the raters and went to needs-human.`
    )
  }
}

/// The one door into `confirmed`, `refuted` and `routed`, so a verdict row
/// cannot exist without every rater's own words beside it — labelled, whole, and
/// in the order the raters were dispatched. Reconciliation used to pick one
/// rationale along with the one verdict, which discarded rater 2 on the 77% of
/// findings the two agreed about: precisely the case the rubber-stamp check
/// downstream is asked to judge. `VERDICT_SCHEMA` makes `reason` and
/// `attemptedRefutation` mandatory per rater so the two can be compared, and
/// keeping one of them is keeping a field the round then cannot audit.
///
/// A row no verifier ever saw — routed by its tester, or never replayed — gets
/// `[]`, which is the truth and is a different thing from a field that went
/// missing.
function record(list, row, views = []) {
  list.push({
    ...row,
    raterViews: views.map((v, i) => ({
      rater: i + 1,
      verdict: v.verdict,
      reason: v.reason,
      attemptedRefutation: v.attemptedRefutation,
    })),
  })
}

/// Whether both raters returned the same verdict for a row — the property the
/// rubber-stamp check is about, read off the raters rather than off the
/// reconciled verdict, so a `needs-human` row (where by definition they
/// differed) is not a pair.
function isAgreedPair(f) {
  const views = f.raterViews || []
  return views.length >= 2 && new Set(views.map((v) => v.verdict)).size === 1
}

/// Up to `n` rows taken round-robin across the lists rather than in list order.
/// Two raters rubber-stamping a *refutation* discard a real defect, which is the
/// more expensive direction — and a round with forty confirmed findings and ten
/// refuted ones would fill the whole sample from the first list and never show
/// one.
function roundRobin(lists, n) {
  const out = []
  for (let i = 0; out.length < n && lists.some((l) => l.length > i); i++) {
    for (const l of lists) {
      if (out.length >= n) break
      if (l[i]) out.push(l[i])
    }
  }
  return out
}

/// One agreed finding rendered for the rubber-stamp check: the claim, the
/// verdict both raters reached, and each rater's own attempt to knock it down,
/// printed whole. Two people arguing the same case from different angles do not
/// write the same sentence; two rubber-stampers do.
function pairedRow(f) {
  return (
    `**${f.claim || '(no claim)'}** — both raters said ${f.raterViews[0].verdict}.\n`
    + f.raterViews
      .map(
        (v) =>
          `  - Rater ${v.rater} tried to refute it: ${v.attemptedRefutation || '(left blank, which is itself a finding about this rater)'}`
      )
      .join('\n')
  )
}

/// Splits a list into runs of at most `size`. A trailing short batch is fine:
/// the raters are per batch, so a 26th finding costs two agents and not a
/// rewrite of the split.
function chunk(items, size) {
  const out = []
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size))
  return out
}

function normalize(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .replace(/[^a-z0-9 ]/g, '')
    .trim()
    .slice(0, 160)
}

// ---------------------------------------------------------------------------
// Phase 4 — Fix (opt-in)
// ---------------------------------------------------------------------------

// Classification is mechanical, from the owning file, computed here rather than
// asked of an agent — "is this an engine bug?" is exactly the question a
// motivated agent answers whichever way lets it start editing.
//
// `unknown` is the residual and means one thing: no rule below recognised the
// path. The harness's own files used to land there too, which made a real owner
// indistinguishable from a tester who invented or misspelled an `ownerFile`.
function ownerClass(file) {
  const f = String(file || '')
  // The harness itself: the workflow being executed, the briefs that define the
  // round's doctrine, the replay tool, and the hand-driven counterpart the same
  // skill documents itself in.
  if (f.startsWith('.claude/') || f.startsWith('bin/') || f === 'docs/playtesting.md') return 'harness'
  if (f.startsWith('Sources/Gnusto')) return 'engine'
  // Repo conventions, and the one genuinely arguable row. `ground` tells every
  // tester that a CLAUDE.md line the code contradicts is a doc-drift finding, so
  // the harness solicits these; filing them forever at every setting is the
  // complaint this classifier exists to answer. `engine` reaches them under
  // `fix: "all"` and nowhere narrower.
  if (f === 'CLAUDE.md') return 'engine'
  // The game suites share a tree with the engine's, so split them by name. A
  // suite not named for its game (CloakTranscriptTests.swift) reads as engine,
  // which is the safe direction for an issue checklist to guess.
  if (f.startsWith('Tests/')) return f.includes(game) ? 'game' : 'engine'
  if (f.startsWith(`Sources/${game}/`)) return 'game'
  if (f.startsWith('docs/games/')) return 'game'
  return 'unknown'
}

// ---------------------------------------------------------------------------
// Phase 4 — Critic
// ---------------------------------------------------------------------------

phase('Critic')

// `ownerClass` outlives the fix phase because `issue-shape.md` asks the operator
// to label every checklist row with its owner. It classifies; it no longer
// decides anything, since nothing in this round edits the tree.
for (const f of confirmed) {
  f.ownerClass = ownerClass(f.ownerFile)
}
const unrecognizedOwners = new Set(
  confirmed.filter((f) => f.ownerClass === 'unknown').map((f) => f.ownerFile)
)
if (unrecognizedOwners.size) {
  log(
    `Unrecognised ownerFile paths — most often a tester inventing or misspelling one: ${[...unrecognizedOwners].join(', ')}`
  )
}

// Coverage arithmetic in plain code, from the survey's denominator, so the
// critic judges numbers it did not produce. This is what turns "a clean round
// produces an empty report, not a plausible one" into a measurement.

// One join, both rosters. Rooms and timers ask the same question of two lists —
// which of the declared things did the round touch, which touched things are on
// no declared list — and until #287 they asked it in two hand-rolled loops, one
// of them O(n·m) over a 195-row roster.
//
// **Exact string equality, and deliberately so.** Both sides are the engine's
// key space now: the roster is copied out of the `survey` tool, and the
// observations are the engine's own — `roomsVisited` carries the room's
// `locationID` and `firedTimers` is keyed by `definition.timers`' keys. The
// normalizer that used to sit here lowercased and stripped punctuation, which
// was the right forgiveness when the roster was retyped prose and is the wrong
// one now: it can fold two distinct ids into one bucket, and one silently wins.
// Collapsing two declared things into one is the exact defect this change
// exists to remove, so a copy that drifts in case is reported rather than
// absorbed.
//
// That makes `offRoster` news instead of noise. It used to mean "an agent
// retyped a name badly", which the critic had to reason past every round; it now
// means the roster and the artifacts disagree about what this game *is* — a
// stale `closing.json` from an older build, another game's probes in the scratch
// tree, or a room the game names at runtime. Each of those wants saying out loud.
//
// `missing` is the reportable half in both cases. A declared thing that shows up
// in nothing is the coverage gap no transcript can display: an unentered room
// prints nothing, and a timer whose body only sets a flag prints nothing even
// when it fires.
//
// - `observed`: names/ids seen, in any order, possibly repeated.
// - `roster`:   the declared list, which sets the order of `missing`.
function reconcile(observed, roster) {
  const declared = new Set(roster || [])
  const matched = new Set()
  const offRoster = []
  for (const o of observed || []) {
    if (declared.has(o)) matched.add(o)
    else offRoster.push(o)
  }
  return { matched, offRoster, missing: (roster || []).filter((r) => !matched.has(r)) }
}

// The declared timers against the ones that actually ran their bodies.
//
// Both sides are counted rather than inferred. `GameWorld.firedTimers` counts
// every fuse and daemon body as it runs and the session server folds it into
// `closing.json` at `finish`; the roster is the `survey` tool's, in the same
// key space. Nothing here is read off prose, which matters because the prose may
// not exist — a timer whose body only sets a flag leaves no sentence for anybody
// to grep, so "did that ever fire?" is not recoverable from a transcript at all.
// See `SKILL.md` for the round that established that the expensive way.
function firedTimers(rows) {
  const declared = (survey.timers || []).map((t) => t.name).filter(Boolean)
  // Summed defensively. The collator is asked for one row per name, but a
  // duplicated name must add up rather than print twice in the critic's line.
  const fired = new Map()
  for (const row of rows || []) {
    if (!row || !row.name) continue
    fired.set(row.name, (fired.get(row.name) || 0) + (row.count || 0))
  }
  const { offRoster, missing } = reconcile([...fired.keys()], declared)
  return {
    declared,
    fired: [...fired]
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name)),
    neverFired: missing,
    offRoster,
  }
}

// The declared rooms against the ones a session actually stood in.
//
// The same join, and the same reason it is now honest. Before #287 the
// numerator was display names off the status line and the denominator was an
// agent's transcription of `Sources/<Game>/`, which is two key spaces — and the
// numerator's could not represent the answer, because a display name is prose
// and nothing stops two rooms sharing one. Dungeon declares 195 rooms under 138
// distinct names, seven of them "Coal Mine": a tester who walked all seven
// contributed one entry, and fifty-seven rooms could never be counted at all.
// (This pair used to read "143 rooms under 126 names", which counted only the
// literal `Location { }` declarations and missed the 52 that `Maze.swift` and
// `Palantir.swift` build from factory functions.) The
// 2026-08-18 round published "119 of 195 rooms visited" off that arithmetic and
// listed as never-entered five Frigid River stretches two charters had stood in.
//
// Both sides are room ids now. `names` is carried alongside so the report can
// say "Coal Mine (mine3)" rather than making a reader resolve an id.
//
// The roster is `declaredRooms` and not `survey.rooms` — see the note there. It
// took a second round to see that scoring against the reachable half made the
// eight rooms Dungeon enters by rule look simultaneously off-roster and
// never-entered, which are contradictory complaints about the same eight rooms.
//
// Called twice, over the two numerators the closing records carry: `roomsVisited`
// (stood in) and `roomsWorked` (did something in). One function, because the join
// is identical and the difference is entirely in what is handed to it.
function visitedRooms(ids) {
  const roster = declaredRooms.map((r) => r.id)
  const { matched, offRoster, missing } = reconcile(ids, roster)
  // `neverVisited` comes out rendered — `Name (id)` — because both its readers,
  // the critic's prompt and the returned `coverage.rooms`, want it that way and
  // rendering it twice is how the two came to disagree about turn counts once
  // already. Nothing downstream wants a bare room id.
  return { visited: matched, offRoster, neverVisited: missing.map(roomLabel) }
}

// The round's turn count, off the artifacts, split by who spent it rather than
// by how the turn was driven. A tester spends turns in its session transcript,
// in branches a rewind wrote off — a room worked for ten turns and then rewound
// out was still worked — in its own `bin/playtest-replay` probes, and through
// the server's `replay` tool. A verifier spends them replaying reproducers from
// the CLI. The harness spends them on its own errands before and around the
// dispatch. Nothing here is asked of an agent that played: see the note on
// COVERAGE's dropped `turnsSpent`.
//
// **`replays` is the testers', and used to be added to the verifiers'.** `replay`
// is an MCP tool on the play session, granted to the play-phase agent and to
// nobody else; a verifier has no session and is told to use
// `bin/playtest-replay --label <verify label>`, which is what `verifyReplays`
// counts. Crediting the `.replays/` tree to the verifiers reported the
// 2026-08-24 Dungeon round at a 3:1 verifier:tester ratio when it was 1.2:1, and
// tripped the "this round argued more than it played" warning on a number that
// was not real. All 63 of that round's `.replays/` probes were testers'.
//
// `unattributed` is the residual, and it is there because this number has now
// been quietly short three times — the branch files, then `.replays`, then both
// CLI trees. A sum over an enumerated list of globs cannot report the tree
// nobody listed; it reports a plausible total and waits a round. So the collator
// also counts every `turn=cost` under `.context/playtest` with no glob at all,
// and the difference is handed to the critic to judge. It is not folded into
// `total`, because the honest reading of a large residual is "some tree is
// uncounted, or another game's artifacts share this checkout" and those want
// different answers.
//
// The residual's fourth reader is `harness`, which is the tree the round's own
// machinery replays under — the cartographer's survey session, and whatever
// ad-hoc label an operator uses to check a route prefix or a random rate before
// dispatching anybody. That was 8,095 turns on 2026-08-24, resolving to
// `prefix-check`, `thief-rate`, `thief-prefix` and `Dungeon-survey`, and it
// arrived as an unattributed residual the critic was asked to explain from
// scratch. It is counted by exclusion rather than by enumeration, because an
// operator's label cannot be enumerated in advance; that is also what keeps
// `unattributed` meaning what it says, since a genuinely foreign tree still has
// no probe transcript under this scratch directory.
function countedTurns(turns) {
  const t = turns || {}
  const testers =
    (t.sessions || 0) + (t.branches || 0) + (t.playReplays || 0) + (t.replays || 0)
  const verifiers = t.verifyReplays || 0
  const harness = t.harnessReplays || 0
  // `prefixTurns` rides through on the spread and is added to nothing: a deep start
  // is a route the server plays into the tester's own transcript, so its turns are
  // already inside `sessions`. It replaces a sixth term that had to be held OUT of
  // `total` and subtracted from the residual, and the day that term stopped existing
  // the residual went back to meaning what it says.
  const total = testers + verifiers + harness
  return {
    ...t,
    testers,
    verifiers,
    harness,
    total,
    unattributed: Math.max(0, (t.all || 0) - total),
  }
}

// What the sessions wrote down, gathered off disk.
//
// One agent where there were two censuses and a reconciler. There is no
// judgement in it — it reads JSON files and adds up integers — which is why it
// is on Haiku permanently, and why what it returns can be trusted in a way the
// two greps it replaces could not be. `COLLATOR_SCHEMA` has the two rounds that
// made the difference matter.
//
// Started here and awaited by the critic rather than `await`ed on this line:
// nothing before the critic reads it, so blocking on a subagent round-trip in
// front of the critic is dead wall clock on every round.
const collatorPromise = agent(
  `${groundMin(labelFor('collator'))}

You are the closing-record collator. You read files and add up integers. You do
not judge, file, explain or play.

Every play-test session writes a \`closing.json\` beside its transcript when it
calls \`finish\`. From \`${pkg}\`, list them:

    find ${SCRATCH} -path "*/${SESSION_GLOB}/*/${CLOSING}"

Read every one. Each holds \`roomsVisited\` (one row per room, each with an \`id\`
and a \`name\`, in the order the session first stood in them),
\`roomsWorked\` (a bare list of ids, the subset of those the session did something
in rather than only stood in),
\`unknownWords\` (token → how many times it was typed),
\`forks\` (each with an \`id\`, a \`command\`, a \`room\` and a \`taken\` flag),
\`firedTimers\` (timer name → how many times the engine ran its body) and
\`prefixTurns\` (how many recorded lines a deep start took before that session's own
first line — \`0\` for a session that opened at turn zero, which is most of them).

Report:

- \`rooms\`: every distinct \`id\` appearing in any \`roomsVisited\`, copied exactly.
  The \`id\`, not the \`name\` — a name is prose and two rooms may carry the same
  one, so a list of names cannot be scored against a room roster. Do not tidy an
  id, expand it, or turn it back into the name beside it.
- \`roomsWorked\`: every distinct \`id\` appearing in any \`roomsWorked\`, copied
  exactly and by the same rules. This is the engine's own subset of the list
  above and the two are reported side by side, because entered is not worked: a
  session that pastes a \`${SCRATCH}/routes/\` walkthrough as a prefix walks
  dozens of rooms and reads a line of none of them, and only this list can tell
  the round which was which. A file with no \`roomsWorked\` key was written by a
  server older than the field: it contributes nothing, and if that is every file
  you read, say so in \`note\` rather than reporting an empty list as "nothing was
  worked".
- \`words\`: one row per distinct token, with its count summed across all files.
- \`forksNobodyTook\`: the \`id\` of every fork appearing with \`taken: false\` and
  never with \`taken: true\`. A fork no session took is a branch the whole round
  left alone, and nothing else in the harness can see it. The flag is raised
  before the command is typed, so it is a precaution and not a verdict: copy the
  ids and do not editorialise about how irreversible any of them was.
- \`timers\`: one row per distinct name in any \`firedTimers\`, with its count
  summed across all files. Copy the names exactly; do not tidy them, and do not
  add a row for a timer you know about but no file mentions — the whole use of
  this number is the *absence* of a row, which the critic reads against the
  declared roster. A file with no \`firedTimers\` key at all was written by a
  server older than the field: it contributes nothing, and if that is every file
  you read, say so in \`note\` rather than reporting an empty list as "nothing
  fired".
- \`turns\`: the round's world turns, counted off the \`[status]\` footers. Every
  footer says \`turn=cost\` or \`turn=free\`, and only the first is a turn the game
  charged — a parse failure and a meta command both print \`turn=free\` and cost
  nothing, which is why counting \`> \` lines instead would be wrong. Twelve numbers,
  run from \`${pkg}\`. Run them exactly as written; one shell invocation holding all
  twelve lines is fine and cheaper, since they print in the order below:

      find ${SCRATCH} -path "*/${SESSION_GLOB}/*/${TRANSCRIPT}" -exec grep -h 'turn=cost' {} + | wc -l
      find ${SCRATCH} -path "*/${SESSION_GLOB}/*/${BRANCH}" -exec grep -h 'turn=cost' {} + | wc -l
      find ${SCRATCH} -path "*/${REPLAY_TREE}/${PROBE}/${TRANSCRIPT}" -exec grep -h 'turn=cost' {} + | wc -l
      find ${SCRATCH} -type d -path "*/${REPLAY_TREE}/${PROBE}" | wc -l
      find ${SCRATCH} -path "*/${PLAY_GLOB}/*/${TRANSCRIPT}" -exec grep -h 'turn=cost' {} + | wc -l
      find ${SCRATCH} -path "*/${PLAY_GLOB}/*/${TRANSCRIPT}" | wc -l
      find ${SCRATCH} -path "*/${VERIFY_GLOB}/*/${TRANSCRIPT}" -exec grep -h 'turn=cost' {} + | wc -l
      find ${SCRATCH} -path "*/${VERIFY_GLOB}/*/${TRANSCRIPT}" | wc -l
      find ${SCRATCH} -path "*/${ROUND_GLOB}/${PROBE}/${TRANSCRIPT}" ! -path "*/${SESSION_GLOB}/*" ! -path "*/${PLAY_GLOB}/*" ! -path "*/${VERIFY_GLOB}/*" ! -path "*/${REPLAY_TREE}/*" -exec grep -h 'turn=cost' {} + | wc -l
      find ${SCRATCH} -path "*/${ROUND_GLOB}/${PROBE}/${TRANSCRIPT}" ! -path "*/${SESSION_GLOB}/*" ! -path "*/${PLAY_GLOB}/*" ! -path "*/${VERIFY_GLOB}/*" ! -path "*/${REPLAY_TREE}/*" | wc -l
      find ${SCRATCH} \\( -name ${TRANSCRIPT} -o -name '${BRANCH}' \\) -exec grep -h 'turn=cost' {} + | wc -l
      find ${SCRATCH} -path "*/${SESSION_GLOB}/*/${CLOSING}" -exec grep -ho '"prefixTurns":[0-9]*' {} + | awk -F: '{s+=$2} END {print s+0}'

  In order: \`sessions\`, \`branches\`, \`replays\`, \`replayProbes\`, \`playReplays\`,
  \`playProbes\`, \`verifyReplays\`, \`verifyProbes\`, \`harnessReplays\`,
  \`harnessProbes\`, \`all\`, \`prefixTurns\`. Use \`find\` and
  not a bare shell glob: \`find\` does its own matching, so a pattern that matches
  nothing prints \`0\` in every shell, where an unmatched glob **aborts the whole
  command** under zsh and would hand you a shell error to interpret as a count.
  A genuine zero is a real answer; say in \`note\` which of the twelve it was.

  For the same reason every one of them starts at \`${SCRATCH}\` and nowhere
  narrower. A start directory \`find\` cannot open is the one thing the pattern
  cannot forgive: it prints its complaint on stderr and the pipe still prints
  \`0\`, which is a shell error wearing the costume of a count. The two
  \`${REPLAY_TREE}\` recipes used to start inside that tree and did exactly this on
  every round whose verifiers had not replayed yet. If \`find\` does print
  \`No such file or directory\` — for \`${SCRATCH}\` itself, now the only way it
  can — that is not a zero either: report it in \`note\` and say the scratch tree
  is missing, because the round then wrote nothing anywhere and every other number
  here is meaningless too.

  None of them is a rounding error. One round held 102 real turns in six branch
  files. The \`play\` and \`verify\` four are \`bin/playtest-replay\` runs — a tester
  probing something it saw, a verifier replaying a reproducer — and on the round that
  found this they held 32,987 typed commands against a reported total of 11,238.

  The \`harness\` pair is the only one written as an exclusion, and that is
  deliberate: it is every other probe transcript **this round** wrote — the
  cartographer's survey session, plus whatever label an operator replayed under to
  check a route prefix or a random rate before dispatching anybody. Those labels
  cannot be listed in advance, so they are caught by what they are *not*. Type both
  lines exactly as written, negations and all; dropping one of the first three
  \`!\` clauses double-counts a tree that already has its own row, and dropping the
  \`${ROUND_GLOB}\` prefix sweeps every previous round of this game in the checkout
  into a row that says "this round's own machinery". The fourth,
  \`${REPLAY_TREE}\`, is belt-and-braces rather than load-bearing — that tree is a
  sibling of the label directories, so it cannot match the \`${ROUND_GLOB}\` scope
  in front of it — and it is kept because this recipe is meant to be pasted
  verbatim and a reader should not have to prove that to himself.

  \`all\` is the one number with no glob in it: every \`turn=cost\` anywhere under
  \`${SCRATCH}\`, which is what the ten above are a breakdown *of*. Report it
  exactly as \`find\` gives it, even when it exceeds their sum — that difference is
  the point of asking, and the critic is the one who judges it.

  \`prefixTurns\` is the twelfth, and the only one that is a sum rather than a count:
  it reads the number out of each \`closing.json\` and adds them. It is **not** a
  thirteenth tree and is added to nothing, because those turns are inside \`sessions\`
  already — a deep start is a route the server plays into the tester's own transcript,
  and this is the share of that number the harness walked rather than the tester typed.
  \`0\` is the ordinary answer and means every session opened at turn zero. Like the
  other eleven it is counted rather than asked: this block's whole history is of numbers
  that were asked of somebody and came back wrong by a factor of five, then three.
- \`sessionsFinished\`: how many \`closing.json\` files you read.
- \`sessionsUnfinished\`: probe directories holding a \`transcript.txt\` with no
  \`closing.json\` beside it. Find them with:

      find ${SCRATCH} -path "*/${SESSION_GLOB}/*/${TRANSCRIPT}" | while read t; do [ -f "$(dirname "$t")/${CLOSING}" ] || dirname "$t"; done

  Name them. A session that never called \`finish\` played the game and left no
  account of it; a round that drops the row rather than reporting it is claiming
  coverage it cannot show.

The session globs are narrow on purpose: only a session opened through the game's
own server lands under \`${SESSION_GLOB}\`. The round's replays and its own audit
runs write elsewhere — the session server's \`replay\` tool writes under
\`${SCRATCH}/${REPLAY_TREE}/\`, whose leading dot both reserves it against any
tester label and keeps it out of every unqualified glob, and \`bin/playtest-replay\`
writes under \`${PLAY_GLOB}\` and \`${VERIFY_GLOB}\`. All three hold a transcript
with no \`closing.json\` beside it, so a wider session glob would report the
round's own machinery as 150-odd testers who never finished.

So the rule has two halves, and they pull opposite ways. **The turn count names
every tree** — it is the one thing they are all read for, and every one of them is
named above, the harness tree by exclusion. **Session accounting names only
\`${SESSION_GLOB}\`** —
\`rooms\`, \`roomsWorked\`, \`words\`, \`forksNobodyTook\`, \`sessionsFinished\` and
\`sessionsUnfinished\` are all about \`closing.json\`, which nothing outside a
session writes. Do not widen the session globs, and do not narrow the turn count
back to them. If you think a session is missing, say so in \`note\`.

If the globs match nothing, report zeroes and empty lists and say so in \`note\`.
That is a real answer and it means the round wrote no sessions.`,
  // Haiku, hardcoded: a fact about the role rather than about any one round.
  // There is no judgement here to degrade — the numbers are the files' or they
  // are wrong, and the critic is told to spot-check them either way.
  { label: 'collator', phase: 'Critic', schema: COLLATOR_SCHEMA, effort: 'low', model: 'haiku' })

// Derived once, off the promise, so the critic's prompt and the returned
// coverage cannot disagree about what was walked.
const roomTallyPromise = collatorPromise.then((collated) => ({
  ...visitedRooms((collated && collated.rooms) || []),
  // The same join over the stricter numerator. Its `offRoster` is thrown away
  // deliberately: `roomsWorked` is a subset of `roomsVisited` by construction,
  // so anything foreign in it is already reported once by the line above and
  // saying it twice would read as two faults.
  worked: visitedRooms((collated && collated.roomsWorked) || []),
  timers: firedTimers(collated && collated.timers),
  forksNobodyTook: (collated && collated.forksNobodyTook) || [],
  sessionsFinished: (collated && collated.sessionsFinished) || 0,
  sessionsUnfinished: (collated && collated.sessionsUnfinished) || [],
  words: (collated && collated.words) || [],
  turns: countedTurns(collated && collated.turns),
}))

const criticThunk = async () => {
  const {
    visited, worked, offRoster, neverVisited, forksNobodyTook, sessionsFinished,
    sessionsUnfinished, words, turns, timers,
  } = await roomTallyPromise
  const unknownWordTotal = words.reduce((n, w) => n + (w.count || 0), 0)

  // The rubber-stamp check needs the raters' own words, not the name of a field.
  // It used to say "sample two or three `attemptedRefutation` fields from the
  // confirmed list", which asked the critic to read something no prompt
  // contained — and on an agreed finding, which is most of them, that field held
  // one rater's text anyway. So the pairs go in the brief, whole.
  //
  // Drawn from all three lists rather than `confirmed`, because agreement is the
  // property under test and not which way the verdict went.
  const agreedPairs = roundRobin(
    [confirmed, refuted, routed].map((l) => l.filter(isAgreedPair)),
    3
  )
  const pairedRationales =
    agreedPairs.map(pairedRow).join('\n\n')
    || '(none — no finding this round drew the same verdict from two raters, so rater independence cannot be judged off rationales at all. Say so rather than passing over it.)'

  // Built here rather than inline, because the three cases it has to keep apart
  // are the whole value of the field and a nested ternary inside a 1kB template
  // line is where that distinction goes to die. The cases: no roster to measure
  // against; a roster but no tally at all, which is ambiguous and must NOT read
  // as "everything is dead"; and a real tally, where the negative is the news.
  let timerNote = ''
  if (timers.declared.length === 0) {
    timerNote = ''
  } else if (timers.fired.length === 0) {
    timerNote =
      ` **No closing record carried a \`firedTimers\` tally at all**, so nothing here tells you`
      + ` a timer was dead — the records either predate the field or the collator's \`note\` says`
      + ` why. Do NOT report an unexercised timer off this; say the round cannot tell, or settle`
      + ` it from the transcripts.`
  } else {
    timerNote =
      ` Fired at least once, counted by the engine as each body ran rather than inferred from`
      + ` what printed: ${timers.fired.map((t) => `${t.name} (${t.count})`).join(', ')}.`
      + ` **Declared and never fired in any session: ${timers.neverFired.join(', ') || 'none'}.**`
      + ` That list is the one coverage gap no transcript can show you — a timer whose body only`
      + ` sets a flag prints nothing, so silence in the prose is not evidence either way. Name`
      + ` them in the coverage section and make one a target for next round.`
  }
  // Both sides are the engine's key space, so this list ought to be empty and a
  // non-empty one is news rather than noise. It used to mean an agent had
  // retyped a name badly; now it means the roster and the artifacts describe
  // different builds. Either way the two lists have to be read together — a
  // name that is `offRoster` here is very likely the same timer that is sitting
  // in `neverFired` under its other spelling, and read apart they are a dead
  // timer invented out of a mismatch.
  if (timers.offRoster.length) {
    timerNote +=
      ` ${timers.offRoster.length} fired name(s) match no declared timer`
      + ` (${timers.offRoster.join(', ')}). Both lists come from the engine — the roster from`
      + ` the survey tool, these from the sessions' own tallies — so they cannot disagree`
      + ` about a game unless a \`closing.json\` was written by an older or a different build,`
      + ` or another game's probes are in the scratch tree. Say which, and cross the two lists`
      + ` before you believe the never-fired one.`
  }

  return agent(
  `${groundMin(labelFor('critic'))}

You are the completeness critic. You do not look for defects; you look for what this
round MISSED. Silent truncation reads as "covered everything" when it wasn't, and your
whole job is to stop that.

Arithmetic computed from the survey's denominator — judge it, and **check it**. The rooms
and the unknown words are read from the \`closing.json\` each session wrote at \`finish\`,
so they are counted rather than recalled; the prose notes below them are still self-report
and can be flattering. The transcripts under \`${pkg}/${SCRATCH}/\` are the ground
truth and they win over anything here.
- Rooms: **${visited.size} of ${declaredRooms.length} entered, ${worked.visited.size} of ${declaredRooms.length} worked.** Both counted by room id rather than by display name — a name is prose and this game's rooms need not carry distinct ones. The denominator is every room the game declares${ruleEnteredRooms.length ? `, including the ${ruleEnteredRooms.length} the engine reports as unreachable: those are entered by a rule rather than through an exit, so a walker will never find one and a round that dropped them from the roster reported the same rooms as both off-roster and never-entered` : ''}. Never entered — a real gap, not a map artifact: ${neverVisited.join(', ') || 'none'}. Entered but never worked: ${worked.neverVisited.filter((r) => !neverVisited.includes(r)).join(', ') || 'none'}.${offRoster.length ? ` ${offRoster.length} room id(s) in the closing records are on no roster (${offRoster.slice(0, 12).join(', ')}). Both sides come from the engine and the roster now holds every declared room, so this is neither a transcription slip nor a rule-entered room: it means a \`closing.json\` was written by an older or a different build, another game's probes are in the scratch tree, or the game names a room at runtime. Say which, and treat the fractions above as approximate until you have.` : ''}
- **Entered is not covered, and the report must not conflate them.** The first count
  above is every room a session stood in, which includes rooms that only flashed past
  inside a replayed prefix from \`${SCRATCH}/routes/\` while the harness typed
  somebody else's walkthrough. The 2026-08-24 round published 128 of 181 entered while
  two explorers had typed 717 of 734 and 596 of 618 of their commands verbatim out of a
  route file, and between them contributed half that count for nine commands of their
  own. The **worked** count is the engine's own answer to that: a room a session typed
  something in that was neither travel nor a meta command. It is an upper bound rather
  than a measurement — the session cannot tell a pasted command from a composed one, so
  a route file's own \`take lamp\` still credits its room — so where the two counts are
  close, read the transcripts before believing the second one. Give the grid \`X\` for a
  room a charter worked in and \`.\` for one it only passed through, and where a
  transcript disagrees with the worked count, the transcript wins and the disagreement
  is worth a sentence.
- Sessions that wrote a closing record: ${sessionsFinished}.${sessionsUnfinished.length ? ` **${sessionsUnfinished.length} session(s) never called \`finish\`** (${sessionsUnfinished.slice(0, 8).join(', ')}) — their rooms and words are missing from every count above, so the coverage figure is a floor and you should say so in as many words.` : ''}
- Forks no session took: ${forksNobodyTook.length ? forksNobodyTook.join(', ') : 'none'}. Each is an action the ledger judged committing and every session declined, which is a coverage gap nothing else in the harness can see. **Read it as an upper bound.** The flag is raised before the command is typed, from what the tester was holding and what the game had said about the thing — so a row here may turn out to be a free refusal. Name the ones you believe, say which you do not, and make one a target for next round.
- Turns: **${turns.total} world turns**, counted off the \`[status]\` footers rather than asked of anybody. Testers spent ${turns.testers} of ~${turnBudget * playRoster.length} budgeted (${turns.sessions} in their session transcripts, ${turns.branches} in branches a rewind wrote off but that were really played, ${turns.replays} across ${turns.replayProbes} probes under \`${SCRATCH}/${REPLAY_TREE}/\`, ${turns.playReplays} across ${turns.playProbes} \`bin/playtest-replay\` probes of their own); the verifiers spent ${turns.verifiers} across ${turns.verifyProbes} \`bin/playtest-replay\` probes; the round's own machinery spent ${turns.harness} across ${turns.harnessProbes} probes under every other label.${turns.prefixTurns ? ` Of the ${turns.sessions} in the session transcripts, ${turns.prefixTurns} are the deep starts the server played before anybody's first line — the harness walking, not a tester, and inside the seats' own labels rather than beside them.` : ''} **The \`${REPLAY_TREE}/\` tree is the testers'**, and used to be credited to the verifiers: \`replay\` is an MCP tool on a play session and a verifier has no session, so it replays through the CLI under its verify label. That one term reported the 2026-08-24 round at 3:1 verifier-to-tester when it was 1.2:1. A round whose verifiers outspend its testers several times over is normal and not by itself a problem — but if \`${turns.testers}\` is far under budget while \`${turns.verifiers}\` is large, the round argued more than it played, and that is worth a sentence. This field used to be the sum of the testers' self-reports and was wrong by a factor of five; then it was counted off two trees out of four and wrong by a factor of three.${turns.unattributed ? ` **${turns.unattributed} further \`turn=cost\` lines sit under \`${SCRATCH}/\` and are attributed to none of the trees above.** The harness row already absorbs the round's own errands, so this is a tree nobody has thought of — or another game's artifacts sharing this checkout. Say which, name the directories, and treat the total as a floor until somebody does.` : ' The residual against an unglobbed count of the whole scratch tree is zero, so nothing was played under a label this round does not attribute.'}
- There is deliberately no "cells probed" count: free-text cell labels are not comparable between charters, so any total would be a number that means nothing. Build the real cross-product yourself from the transcripts, against the ${declaredRooms.length}-room roster and the timers above.
- Testers run: ${playRoster.map((r) => `${r.key}${r.charter.blind ? ` (${r.divergence}${r.regions.length ? `, ${renderRegions(r.regions)}` : ''})` : ''}`).join(', ')}. Charters NOT run: ${skipped.map((c) => c.key).join(', ') || 'none'}.
- The blind charters were given no room list, no timer list and no design doc, deliberately. A finding of theirs that the doc licenses is the expected cost of that, not a harness failure — but if more than about two in five are refuted that way, say so: the brief needs tightening, not the doc handing back.
- Confirmed ${confirmed.length}, refuted ${refuted.length}, findings routed to another issue ${routed.length}. Every confirmed finding is filed; this round edits nothing.
- **Verifier agreement: ${agreementTotal ? `${Math.round((agreementMatched / agreementTotal) * 100)}% (${agreementMatched} of ${agreementTotal} findings judged the same way by both raters)` : 'not measurable — no finding got two raters'}.**${singleRated ? ` ${singleRated} finding(s) got only one rater, so the denominator is thinner than the finding count.` : ''} Verification is batched now — up to ${VERIFY_BATCH_SIZE} findings per verifier, ${VERIFY_RATERS} raters each — and this number is the check on that. Near-total agreement is not automatically good news: it is what both careful raters and two rubber-stampers produce. **Read the paired refutation attempts printed below** and say whether the two raters reasoned separately or interchangeably. That judgement is yours and nothing else in the round makes it.
- Unknown words: ${unknownWordTotal} occurrence(s) over ${words.length} distinct token(s), taken from the parse record rather than by grepping for the engine's refusal line. Not findings in themselves and not coverage — but ~48 verbs are stubs now, so a large number here is worth a sentence. A word the *game itself printed* and could not answer is a defect and should have arrived as an ordinary finding; if the count is high and no such finding was filed, that is a gap in the round, not in the game.
- Timers declared: ${timers.declared.join(', ') || 'none'}.${timerNote}

Each charter's own coverage note:
${coverage.map((c) => `- ${c.charter} (round ${c.round}): ${c.honestSummary}${(c.cellsSkipped || []).length ? ` | skipped: ${c.cellsSkipped.join(', ')}` : ''}`).join('\n')}

Refuted this round, with reasons:
${refuted.map((r) => `- [${r.charter || '?'}] ${r.claim || '(no claim)'} → ${r.refutationKind}: ${r.reason}`).join('\n') || '- none'}

Paired refutation attempts, for the rubber-stamp check. Each finding below drew the
SAME verdict from both raters, and each rater's own attempt to knock it down is
printed whole. Two people arguing the same case from different angles do not write
the same sentence; two rubber-stampers do. Say plainly which of the two you are
looking at:

${pairedRationales}

Write the Coverage and Refuted sections of the report, per
\`${REF}/report-shape.md\`. Include the state cross-product as an actual grid of
ticks and blanks. Then answer three questions plainly:

1. **Which charters found nothing, and is that because the game is clean there or
   because the charter never really ran?** These must not look the same in the report.
2. **What would a second round probe first?** Name cells, not vibes.
3. **Is this round trustworthy?** If the refuted list is empty, say so and treat it as
   a warning sign — a verifier that refutes nothing is probably not refuting. If
   confirmed findings are all from one charter, say that too.

Be blunt. An honest thin round is useful; a thin round dressed as a thorough one is
worse than not running.`,
    { label: 'critic', phase: 'Critic', schema: CRITIC_SCHEMA, effort: 'high' }
  )
}

// The critic re-counts coverage from the transcripts. The collator, started
// above, finishes inside its own wait.
const critic = await criticThunk()

const roomTally = await roomTallyPromise

return {
  game,
  packagePath: pkg,
  seed,
  tiers: survey.tiers,
  charters: {
    run: playRoster.map((r) => ({ key: r.key, charter: r.charter.key, region: renderRegions(r.regions), divergence: r.charter.blind ? r.divergence : null })),
    skipped: skipped.map((c) => c.key),
  },
  confirmed,
  refuted,
  routed,
  // One list, off the parse record. There is no second number to keep beside it
  // any more: nobody was asked, so there is nothing to disagree with.
  unknownWords: [...roomTally.words].sort((a, b) => b.count - a.count),
  critic,
  // Inter-rater agreement over the batched verifiers. `singleRated` is here
  // because a high percentage over a thin denominator is the shape of a number
  // that flatters a round, and this is the harness that exists to stop that.
  verification: {
    batchSize: VERIFY_BATCH_SIZE,
    ratersPerFinding: VERIFY_RATERS,
    bothRaters: agreementTotal,
    agreed: agreementMatched,
    agreementRate: agreementTotal ? agreementMatched / agreementTotal : null,
    singleRated,
    disagreements,
  },
  coverage: {
    // Room ids on both sides — every room the game declares, against the ids the
    // sessions' own `roomsVisited` and `roomsWorked` carried. `total` counts the
    // rule-entered rooms too, and `ruleEntered` says how many of it they are: a
    // room only a lever reaches is playable and reportable, and scoring it out
    // of the roster reported the same rooms as both off-roster and never-entered.
    rooms: {
      visited: roomTally.visited.size,
      worked: roomTally.worked.visited.size,
      total: declaredRooms.length,
      ruleEntered: ruleEnteredRooms.length,
      neverVisited: roomTally.neverVisited,
      neverWorked: roomTally.worked.neverVisited,
      offRoster: roomTally.offRoster,
    },
    // Declared against fired, both counted rather than asked. `neverFired` is
    // the reportable half: nothing else in the round can distinguish a timer
    // that never ran from one that ran and said nothing.
    timers: roomTally.timers,
    forksNobodyTook: roomTally.forksNobodyTook,
    sessionsFinished: roomTally.sessionsFinished,
    sessionsUnfinished: roomTally.sessionsUnfinished,
    turns: roomTally.turns,
    perCharter: coverage,
  },
}

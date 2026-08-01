export const meta = {
  name: 'playtest',
  description:
    'Automated play-test round for a Gnusto demo game: charter-diverse subagents read transcripts as prose, every finding is replayed and then adversarially refuted, and the round is gated on swift test plus the strict lint.',
  whenToUse:
    'Invoked by /playtest <game>. Needs args {game, packagePath, docPath, capabilities, turns, charters, fix, rounds}. The calling session builds the binary first (bin/playtest-replay --build <Game>) and writes the returned report; this script has no filesystem access of its own.',
  phases: [
    { title: 'Survey', detail: 'one cartographer: rooms, timers, vocabulary, and which oracle tiers exist' },
    { title: 'Play', detail: 'one playtester per charter, each replaying its own reproducers' },
    { title: 'Triage', detail: 'dedup in plain code, then one adversarial refuter per survivor' },
    { title: 'Fix', detail: 'one fixer per owning file, test-first (opt-in)' },
    { title: 'Gate', detail: 'swift test, strict lint, and the completeness critic' },
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
const maxRounds = clamp(ARGS.rounds, 1, 6, 1)
const dryTarget = clamp(ARGS.dryRounds, 1, 3, 2)
const seed = clamp(ARGS.seed, 0, Number.MAX_SAFE_INTEGER, 0)

const FIX_MODES = ['none', 'game', 'all']
const requestedFix = FIX_MODES.includes(ARGS.fix) ? ARGS.fix : 'none'
const fixMode = docPath ? requestedFix : 'none'
if (requestedFix !== 'none' && !docPath) {
  log(
    `${game} has no design doc, so this round files findings without fixing them. The repo makes docs/games/<game>.md the copy source of truth and requires a prose change to land there in the same commit; a prose fix with no doc to update would break the rule it is meant to follow.`
  )
}

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
// other thing a label is for. Game and round are in the name so two rounds of the
// same game do not interleave either.
//
// `:` is not in the label alphabet the tool accepts, which is why an agent given a
// display label like `verify:frame` had to make one up. Sanitize instead.
const labelFor = (...parts) =>
  [game, ...parts].join('-').replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^[.-]+/, '')

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

Write nothing outside \`.context/playtest/\`. It is the sanctioned scratch and the
only part of the tree that is gitignored for this purpose.
`.trim()

// Where and what, with no doctrine. Every agent gets this much; only the ones
// that actually judge prose pay for the briefs (`ground`, below).
const groundMin = (label) => `
You are working on the Gnusto engine repo. The package under test is at \`${pkg}\`
and the game is \`${game}\`. The pinned seed for this round is \`${seed}\`.

${replayHowTo(label)}
`.trim()

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

const SURVEY_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['rooms', 'timers', 'tiers', 'reskinnedTextKeys', 'printedNouns'],
  properties: {
    rooms: {
      type: 'array',
      description: 'Every reachable room, by its display name.',
      items: { type: 'string' },
    },
    unreachableRooms: { type: 'array', items: { type: 'string' } },
    timers: {
      type: 'array',
      description: 'Each alarm, fuse and timetable stop, and whether its body reads the player location.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['label', 'kind', 'readsPlayerLocation'],
        properties: {
          label: { type: 'string' },
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
          frame: {
            type: 'object',
            additionalProperties: false,
            required: ['room', 'anchor', 'state'],
            properties: {
              room: { type: 'string' },
              hour: { type: 'string' },
              anchor: {
                type: 'string',
                description: 'The line IN THE TRANSCRIPT that proves the hour or turn. Arithmetic alone is not an anchor.',
              },
              state: { type: 'string' },
            },
          },
          reproducer: {
            type: 'array',
            description: 'Shortest command list from a clean start. Replayed before reporting.',
            items: { type: 'string' },
          },
          replayedCleanly: {
            type: 'boolean',
            description: 'True only if the trimmed reproducer was re-run from clean and produced the excerpt.',
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
    unknownWords: {
      type: 'array',
      description: 'Every word the parser did not know, with how many times you saw it. Collected as one list rather than filed one-by-one. This is a census and not a verdict: a word the game printed IS a K8 unanswerable-noun finding and you file it as one, AND it still belongs in this list — the two are not alternatives, and treating them as alternatives is how a round once reported 2 occurrences against transcripts holding 261. Set gamePrintedIt to tell the two kinds apart. Note that ~48 verbs are now stubs, so an unknown word that the game did NOT print is a verb with no stub yet.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['word', 'count', 'gamePrintedIt'],
        properties: {
          word: { type: 'string' },
          count: { type: 'integer' },
          gamePrintedIt: { type: 'boolean' },
        },
      },
    },
    coverage: {
      type: 'object',
      additionalProperties: false,
      required: ['roomsVisited', 'cellsSkipped', 'turnsSpent', 'honestSummary'],
      properties: {
        roomsVisited: { type: 'array', items: { type: 'string' } },
        cellsSkipped: { type: 'array', items: { type: 'string' } },
        turnsSpent: { type: 'integer' },
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
  required: ['verdict', 'reason'],
  properties: {
    verdict: {
      type: 'string',
      enum: ['confirmed-defect', 'refuted', 'route-elsewhere', 'needs-human'],
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

const FIX_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['fixed', 'testName', 'sawItFailFirst', 'filesTouched', 'assertionsRemoved', 'docUpdated', 'notes'],
  properties: {
    fixed: { type: 'boolean' },
    testName: { type: 'string' },
    sawItFailFirst: { type: 'boolean' },
    filesTouched: { type: 'array', items: { type: 'string' } },
    assertionsRemoved: { type: 'integer' },
    docUpdated: { type: 'boolean' },
    escalated: { type: 'string', description: 'Set when the only available fix would breach the mechanics contract.' },
    notes: { type: 'string' },
  },
}

/// Counted off the transcripts, not asked of the testers — see the census agent
/// in the Gate phase for why the difference matters.
const CENSUS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['totalOccurrences', 'words'],
  properties: {
    totalOccurrences: { type: 'integer', description: 'Every unknown-word reply in every transcript this round wrote.' },
    words: {
      type: 'array',
      description: 'One row per distinct word, with its count. Every word, not the interesting ones.',
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
    note: { type: 'string', description: 'Only if the count needs one — an empty glob, an unreadable transcript.' },
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

const GATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['testsPassed', 'testCount', 'lintPassed', 'assertionsWeakened', 'contractIntact', 'summary'],
  properties: {
    testsPassed: { type: 'boolean' },
    testCount: { type: 'integer' },
    failingTests: { type: 'array', items: { type: 'string' } },
    lintPassed: { type: 'boolean' },
    lintSkippedReason: { type: 'string' },
    assertionsWeakened: { type: 'boolean' },
    weakenedDetail: { type: 'string' },
    contractIntact: { type: 'boolean' },
    summary: { type: 'string' },
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
be answered in the game's own voice and any that isn't is a K9 finding. RUN THEM ALL:

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
const CHARTERS = [
  {
    key: 'tourist',
    // The survey already crossed every printed noun against the vocabulary in
    // code, which is cheaper and more complete than discovering it by playing.
    // Hand that list over as a worklist rather than making the tourist re-derive
    // it — its job is then to confirm each one in a real frame.
    checklist: (survey) => {
      const gaps = (survey.printedNouns || []).filter((n) => !n.answerable)
      if (!gaps.length) {
        return 'The survey crossed every printed noun against the vocabulary and found no gaps. Spot-check a handful anyway — the survey reads source, and prose assembled at runtime can print a noun the source does not show literally — then say in your coverage note that the static pass was clean.'
      }
      return `The survey found ${gaps.length} noun(s) the prose prints that the vocabulary does not answer. Confirm each in a real frame with \`x <noun>\`, and report them as ONE finding per owning text rather than one per word:

${gaps.map((n) => `  x ${n.noun}${n.printedIn ? `          (printed in ${n.printedIn})` : ''}`).join('\n')}

Then go looking for the ones the survey could not see: nouns in prose that is built at
runtime, in refusals, in blocked-exit text, and in topic answers.`
    },
    brief: `Walk every room. Type every noun the game puts on the page. You own K8.

BFS the exit graph from the survey's room list. In each room: \`look\`; then \`x <noun>\`
for every noun the description printed; then \`x <noun>\` for every noun those examine
texts printed, one level deep and no further. Walk every exit the description names,
and every exit the graph has that the description does not name. Type every blocked
direction and examine every noun its refusal prints. Then \`search\` and \`open\`
anything the room implies has an inside.

You own: unanswerable nouns, exits the prose names that do not exist, exits that
exist unnamed, disagreement between the design doc's map and the real graph, and
examine text that contradicts the room description.

Do not report the stock "You see nothing special about the X." — that is the correct
answer for a scenery stub whose only job is to make a noun answerable, which is
exactly the fix K8 prescribes. It becomes a finding only when the room description
gave X a distinguishing detail that the examine text then withholds.

You use only look / x / read / search / open and directions, so you should never see
an unknown-word reply. If you do, the game printed a noun it cannot answer: that is
K8 and it is yours — a noun the game printed and cannot answer, whoever else may own
unknown words this round.`,
  },
  {
    key: 'clock-watcher',
    appliesTo: (survey) => (survey.timers || []).length > 0,
    brief: `A line has to know the room AND the state. Only a cross-product finds the cell
where it does not. You are the charter that catches an NPC watching a fire from the
bottom of a dark cellar.

Read your axes off the survey's timers, not off the word "clock". For a clock game the
axis is the hour. Otherwise it is whatever the game's own timers branch on — tide
stage, spell state, light and dark. A game with no timers has no clock-watcher, and
you say so rather than inventing work.

Pass A, on-cell. One probe per scheduled stop. Get to the room, fill to the hour, then
\`time\`, \`look\`, \`x <actor>\`, and examine every thing the actor's listing line
mentions. Judge the listing line against THIS room at THIS hour, and the examine text
against what has and has not happened yet. Note: an actor's ARRIVAL line prints on the
turn they arrive and masks the standing listing line, so probe the turn after as well —
this is where the location-blind listing line actually shows.

Pass B, off-cell. Stand in the room for the stop before and the stop after. Per K4 an
actor is always listed if perceivable, so an actor who leaves with no departure line
and an actor whose departure was narrated but who is still listed are both defects.

Pass C, ghost-cell. Stand where the actor is not, at that hour. Does anything print
about them? Does a line name the room you are standing in as though it were elsewhere?

Pass D, event x room. Separate pass, and where aftermath defects live, because a fuse
prints once per game and cannot be found by walking. For each alarm and each fuse whose
body reads the player's location (the survey flags these), one fresh run per reachable
room that parks the player there through the event and its fuse turns.

Pass E, displacement. Per K10, be in room A for the event and move to room B before the
fuse fires. Judge each clause separately: does it belong to where the player is now, or
to where they were then?

Budget: save at the anchors the survey names and \`--restore\` per probe rather than
replaying dozens of waits.

Do not report a cell you never occupied — log it as uncovered. Do not report any hour
you did not anchor with a real reading. Do not report an actor's listing line repeating
across turns; per K1 that is by design.`,
  },
  {
    key: 'vandal',
    // Generated rather than described: the first calibration round lost
    // `cantTakeActor` because the sweep was left to the tester to derive.
    checklist: articleSweep,
    brief: `Reach every stock refusal the game did not re-skin, and every one whose register is
wrong for the game. You found \`cantTakeActor\`.

**STEP 1 IS MANDATORY AND COMES FIRST. Do it before you form any other plan, and
report its result even if it is "all clean".** The article sweep below is the single
highest-yield probe in this whole harness and it is two commands long. A round where
you skipped it to go exploring is a failed round, however interesting the things you
found instead. Work the checklist the survey handed you literally, command by command;
do not re-derive which ones are worth trying.

STEP 2 is everything the checklist does not already cover: \`x\` each actor, then run
the same verbs on one item of each kind — takeable, container, wearable, scenery, a
locked thing — and on a door. Use ONLY words in the known-verb list.

Judge four things:
(a) Any reply with \`the \` immediately before a capitalized name or Mr/Mrs/Miss/Dr/Sir
    — K9, the un-re-skinned stock line.
(b) Any reply in a register the game does not otherwise use.
(c) Any reply that asserts something HAPPENED. "You find nothing of interest in the
    cook" claims a search that did not occur.
(d) Prose claiming a mechanic the game does not enforce — a patrolman "keeping
    everybody out of it" while the player is standing in it.

STEP 3, the stub verbs, and this is new ground. The engine now answers ~48 verbs it has
no mechanic for — \`sing\`, \`smell\`, \`dig\`, \`climb\`, \`jump\`, \`pray\`, \`listen\`,
\`xyzzy\` — with one line of stock prose each, from \`GameText.stubs\`. They parse, they
cost a turn, and **the ones the game has not re-skinned are in the engine's voice, not
the game's.** The survey reports which stubs the game overrides; the complement is your
list. Run each one and judge the register exactly as in (b) above: "Your singing is
better kept to yourself." is fine in a generic engine and wrong in the mouth of a 1952
murder investigation.

Report a stub in the wrong register as \`register-mismatch\` at severity \`minor\` —
these are cheap to fix and there may be dozens, so file them as ONE finding per game
listing the offenders, not forty findings. A stub whose prose is actively *false* of the
game (it names a thing the game has no concept of) is a \`prose-untrue-of-frame\` finding
in its own right.

\`frotz\` is the engine's reserved non-word: it is guaranteed to fail to parse, so use it
when you need a known parse error. Any *other* \`I don't know the word\` is now worth
looking at — it means either a noun the game printed and cannot answer (K8, yours) or a
verb a player would reasonably reach for that has no stub yet.`,
  },
  {
    key: 'interrogator',
    appliesTo: (_survey, capabilities) => capabilities.has('talk'),
    brief: `Ask everyone about everyone, twice, and about things they cannot know yet.

Work the topic matrix from the design doc's evidence tables, or the topic rows in
source. For every (actor, topic): ask, ask AGAIN, then a THIRD time. Repeat-aware
dialogue retires prose, and the failure modes are a paragraph recited twice, or an
"again" variant that swallowed the only real answer.

Then every topic before its gate: ask about a thing before it exists, about an object
without holding it, about a fact not yet learned. Then ask everyone about a topic
nobody owns, to reach each per-actor fallback — the contract says everyone has a
fallback and there is no dead air. Then show evidence to the wrong person.

Then the past-tense questions, which are the most important: where a character's answer
describes where someone WAS, check it against the schedule. "Past-tense truth is read
from the timetable, never hand-written prose" is the single most load-bearing line in
the contract, and a character whose account contradicts the timetable is the defect it
exists to prevent. Where a character is documented as the deliberate exception who goes
on answering, check that they still do on the fourth ask.

Do not report an actor declining a subject — characterization. Do not report an unknown
word for a topic noun that no row claims and no prose names; that topic was never
promised. But a topic the prose NAMES and no row answers is K8, and is yours.`,
  },
  {
    key: 'solver',
    brief: `The only charter that checks the game can be won.

Take the route from the design doc's solution if there is one, else the walkthrough
test's command list, else maxScore plus the scoring rules. Play it.

Then play it MINUS ONE STEP, once per step, to check each gate actually gates: win
without the evidence, win before the evidence exists, reach the fuller ending without
the fact it is supposed to require. Then let any deadline run out and check the losing
ending fires and reads as a loss. Then check the score line reads N of a possible N on
the full route.

You own unwinnability (severity blocking), a win that fires without its gate, a
knowledge-gated tier firing when the fact was never learned, and an ending whose prose
does not name what the player actually did.

Do not report prose taste on the ending. Do not report a route that failed on your own
typo — replay it first; it is deterministic and cheap.`,
  },
  {
    key: 'idiot',
    brief: `Every wrong move a real player makes in the first five minutes, and what the game
says back.

Right verb, wrong noun. Right noun, wrong room. Verbs out of order — unlock before
taking the key, cast before memorizing, accuse on turn one. Ambiguous nouns: where
several characters answer to "man" or "woman", \`x man\` must disambiguate in the
game's own voice. Plurals. Empty input. A bare noun. A bare direction into a wall.
\`open\` something that does not open. \`take all\`.

Then the player themselves, which is newly answerable and therefore newly breakable:
\`x me\`, \`x myself\`, \`x self\`, \`take me\`, \`search me\`, \`i\`, \`take all\`, and
\`look\` in a room you are alone in. The player is always in scope but placed nowhere,
so it must answer to all three words and must NOT appear in a room listing, in the
inventory, or in what \`take all\` picks up. An unknown-word reply to \`x me\` is a
regression: the player is answerable now.

You own: a refusal that names something the player cannot know yet, or leaks an entity
from another room; a disambiguation prompt listing things the player cannot see; "You
can't see any such thing" for a thing that is right there (per K7 that is now a real
defect, not stock behaviour); a refusal in the stock voice where its neighbours were
re-skinned; \`take all\` picking up what it should not.

Unknown-word replies used to be somebody else's problem and are not any more: the engine
now stubs ~48 verbs, so \`I don't know the word "X"\` means either a noun the game
printed and cannot answer (K8 — yours) or a verb with no stub yet (worth one line in your
coverage note). \`frotz\` is the reserved non-word and is the only guaranteed parse
error. Still collect them in one list with counts rather than filing one finding each.`,
  },
  {
    key: 're-reader',
    brief: `Repeat a command until the prose repeats, and judge whether it should have.

Take every line that reads like a first-time line and repeat what produced it. \`look\`
five times in a room: an ITEM's first-sight line must stop once the player touches it,
and an ACTOR's must NOT stop, ever. \`x <item>\` after taking it. \`open\` a container
twice. \`search\` twice. \`ask X about Y\` three times. \`z\` ten times in each room,
watching the room's per-turn rules: an atmospheric line printing every single turn reads
as a stuck record, and one that printed once and never again reads as a bug too. Turn on
a lamp that is already on. Take a thing twice. Anything the design doc says happens
"once".

You own: a first-sight line outliving the touch; a once-only line printing twice or
never; an atmospheric line with no variation across ten turns; state that appears to
un-reveal (K5); and a distinctive phrase used for two different characters, which reads
as one character's voice leaking into another.

Do not report an actor's presence line repeating. This is the single most likely false
positive on this charter and it is the exact opposite of a bug (K1).`,
  },
]

// ---------------------------------------------------------------------------
// Phase 1 — Survey
// ---------------------------------------------------------------------------

phase('Survey')

const survey = await agent(
  `${groundMin(labelFor('survey'))}

You are the cartographer for this play-test round. You do not play; you read the code
and the docs and produce the denominator every later phase measures itself against.

Report:
1. Every reachable room, and any room that exists but nothing leads to.
2. Every alarm, fuse, daemon and timetable stop — and for each, whether its body reads
   the player's location or a "was here when it happened" flag. That flag is what marks
   which timers need the full event x room cross-product, so get it right.
3. The state axes a line could be wrong along.
4. Every noun the prose prints, crossed against the vocabulary (name, synonyms,
   adjectives), with whether it is answerable. Cross these two in code, not by playing:
   K8 is checkable before a single turn.
5. Which stock text keys the game overrides in its \`text\` block, AND which stub-verb
   replies it overrides via \`text.stubs.<verb>\`. The COMPLEMENT of each is a vandal
   target list. Read \`Sources/Gnusto/Actions/GameText.swift\` for the full stub roster
   (the \`StubReplies\` struct) — a game that overrides none of them answers ~48 verbs in
   the engine's voice.
6. Which actors have proper names or honorifics.
7. Which oracle tiers were actually available to you.

Read \`Sources/${game}/\` and ${docPath ? `\`${docPath}\`` : 'the game type\'s doc comment'}. Be exhaustive about rooms and timers; that is what coverage is scored against.`,
  { label: `survey:${game}`, phase: 'Survey', schema: SURVEY_SCHEMA }
)

if (!survey) throw new Error('survey failed; a round without a denominator cannot report coverage honestly')

// Each charter decides for itself whether this game gives it anything to do,
// reading the survey and the manifest capabilities directly. A predicate rather
// than a keyword means a new axis needs no new branch here.
const active = CHARTERS.filter((c) => !c.appliesTo || c.appliesTo(survey, capabilities))
const requested = ARGS.charters ? new Set(String(ARGS.charters).split(',').map((s) => s.trim())) : null
const playRoster = requested ? active.filter((c) => requested.has(c.key)) : active
const skipped = CHARTERS.filter((c) => !playRoster.includes(c))

log(
  `${game}: ${survey.rooms.length} rooms, ${(survey.timers || []).length} timers, tiers ${survey.tiers.join('+')}. ` +
    `Charters: ${playRoster.map((c) => c.key).join(', ')}${skipped.length ? ` — not run: ${skipped.map((c) => c.key).join(', ')}` : ''}.`
)

// ---------------------------------------------------------------------------
// Phase 2 + 3 — Play, then Triage
// ---------------------------------------------------------------------------

const seen = new Set(ledger)
const confirmed = []
const refuted = []
const routed = []
const unknownWords = new Map()
const coverage = []
let dryRounds = 0

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
      playRoster.map((charter) => () =>
        agent(
          `${ground(labelFor(`r${round}`, 'play', charter.key))}

Your charter is **${charter.key}**. Round ${round} of at most ${maxRounds}.

${charter.brief}

Your turn budget is about ${turnBudget} engine turns. Spend it on breadth first, then
depth on whatever looked wrong.

The survey found:
- Rooms: ${survey.rooms.join(', ')}
- State axes: ${(survey.stateAxes || []).join(', ') || 'none'}
- Timers: ${(survey.timers || []).map((t) => `${t.label} (${t.kind}${t.at ? ' @ ' + t.at : ''}${t.readsPlayerLocation ? ', reads player location' : ''})`).join('; ') || 'none'}
- Stock keys the game re-skinned: ${(survey.reskinnedTextKeys || []).join(', ') || 'none'}
- Stub-verb replies the game re-skinned: ${(survey.reskinnedStubs || []).join(', ') || 'NONE — every stub answers in the engine voice'}
- Proper-named actors: ${(survey.properNamedActors || []).join(', ') || 'none'}
${charter.checklist ? `\nYOUR GENERATED CHECKLIST:\n${charter.checklist(survey)}\n` : ''}
${seen.size ? `\nAlready seen in earlier rounds or the ledger — do NOT report these again:\n${[...seen].slice(0, 60).join('\n')}` : ''}

Annotate your command files with \`//\` as you go, and REPLAY EACH REPRODUCER FROM A
CLEAN START before you report it. Set replayedCleanly honestly; a finding whose
reproducer you did not re-verify is dropped at triage, so guessing gains you nothing.
Carry that clean replay's \`[playtest] transcript=…\` path into \`transcriptPath\`, so the
finding arrives with the evidence attached rather than with a description of it.

Your coverage note is not a formality. Name the cells you did not reach. A charter that
reports findings and hides its gaps makes the round look thorough when it was not.`,
          { label: `play:${charter.key}`, phase: 'Play', schema: FINDINGS_SCHEMA }
        )
      )
    )
  ).filter(Boolean)

  for (const r of reports) {
    coverage.push({ round, charter: r.charter, ...r.coverage })
    for (const w of r.unknownWords || []) {
      // A word the game itself printed is not a missing verb; it is an
      // unanswerable noun (K8), and it belongs to this round rather than to a bucket.
      if (w.gamePrintedIt) continue
      unknownWords.set(w.word, (unknownWords.get(w.word) || 0) + (w.count || 1))
    }
  }

  phase('Triage')

  const fresh = []
  for (const report of reports) {
    for (const f of report.findings || []) {
      f.charter = report.charter
      if (f.routedTo) {
        routed.push(f)
        continue
      }
      if (!f.replayedCleanly) {
        refuted.push({ ...f, refutationKind: 'not-reproducible', reason: 'The tester did not re-verify the trimmed reproducer from a clean start.' })
        continue
      }
      // Frame deliberately excluded from the key: one untrue sentence seen at
      // two hours is ONE defect with two frames. Keying on the frame would
      // dispatch two fixers at one branch.
      const key = `${f.ownerFile}::${normalize(f.excerpt)}`
      if (seen.has(key)) continue
      seen.add(key)
      fresh.push({ ...f, key })
    }
  }

  if (!fresh.length) {
    dryRounds++
    log(`Round ${round}: nothing new. Dry rounds: ${dryRounds}/${dryTarget}.`)
    continue
  }
  dryRounds = 0
  log(`Round ${round}: ${fresh.length} fresh findings to verify.`)

  // Adversarial verification, by an agent from a DIFFERENT charter, prompted to
  // refute, defaulting to refuted. Not optional: a tester will report intentional
  // design as a defect, will report gaps owned elsewhere, and will sometimes have
  // simply misread the prose — and a fixer acting on any of those makes the game
  // worse than it was.
  const verdicts = await parallel(
    fresh.map((f, index) => () => {
      // The verifier must not be the charter that found it, and spreading the
      // lens across the other charters is what makes the panel diverse rather
      // than N copies of the same skepticism.
      const others = playRoster.filter((c) => c.key !== f.charter)
      const lens = others.length ? others[index % others.length].key : 'skeptic'
      // Indexed, not categorized: two findings can share a category, and this is
      // the label whose collisions cost the round its evidence.
      const verifyLabel = labelFor(`r${round}`, 'verify', String(index + 1).padStart(2, '0'))
      return agent(
        `${ground(verifyLabel)}

You are verifying someone else's play-test finding, and your job is to REFUTE it. You
did not find this; the ${f.charter} charter did. You are reading it through the
${lens} lens.

**Default to refuted.** If you cannot establish that the line is false of the frame it
printed in, refute. A plausible-but-wrong finding that reaches a fixer is worse than no
finding at all, because the fixer will "correct" prose that was right.

THE FINDING
  Claim:      ${f.claim}
  Category:   ${f.category}   Severity: ${f.severity}
  Excerpt:    ${f.excerpt}
  Frame:      ${f.frame.room}${f.frame.hour ? ' @ ' + f.frame.hour : ''} — ${f.frame.state}
  Anchor:     ${f.frame.anchor}
  Reproducer: ${JSON.stringify(f.reproducer)}
  Fault:      ${f.fault}
  Owner file: ${f.ownerFile}

Work this checklist IN ORDER. These are the three ways this repo's testers have
actually been wrong, most frequent first.

1. **Is it intentional design?** A character declining to act is characterization, not
   a defect. ${docPath ? `Check the design doc's "free to change" list — a finding objecting to a name, a line of prose, the tone, or a plot choice is objecting to something the doc explicitly licenses, and is refuted on sight unless it ALSO shows the line is untrue of its frame. Check the mechanics contract too: a behaviour the contract REQUIRES is not a defect.` : `With no design doc, lean harder on this: you cannot tell authorial intent from the outside, so a finding that amounts to a preference is refuted.`}
2. **Is it owned by another issue?** Only if your prompt named one above — the open
   set is supplied per round, and it is often empty. If it is empty, nothing is owned
   elsewhere and this check cannot save the finding. Do not reach for an issue number
   from memory: #76, #77 and #78 all closed, and forwarding a symptom to a fixed issue
   silently discards a regression.
3. **Did the tester misread?** Replay the reproducer YOURSELF:
   \`bin/playtest-replay ${game} --commands <file> --seed ${seed} --label ${verifyLabel}\`.
   Confirm the excerpt appears verbatim, in the frame claimed, with the hour anchored by
   a real reading and not by counting commands — remember meta commands and parse
   failures cost no turn. If the quoted text is not in the tree, or the frame is wrong,
   refute and say which.

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

Then, only if it survives all four: is the fix a judgement call with more than one
reasonable answer? Answer needs-human rather than confirmed-defect. That is not a
hedge; it routes the finding to a person instead of to an agent that will pick a design
by coin flip.`,
        { label: `verify:${f.category}`, phase: 'Triage', schema: VERDICT_SCHEMA }
      )
        .then((v) => ({ finding: f, verdict: v }))
        // Catch here rather than letting parallel() turn a throw into a bare
        // null: the finding has to survive its verifier's death, or a dropped
        // finding becomes invisible in the report instead of being counted.
        .catch((e) => ({ finding: f, verdict: null, error: String(e) }))
    })
  )

  for (const row of verdicts) {
    // A dead verifier drops the finding too. A missing verdict is not a pass.
    if (!row || !row.verdict) {
      const lost = row && row.finding ? row.finding : { claim: '(finding lost with its verifier)' }
      refuted.push({ ...lost, refutationKind: 'none', reason: `Verifier returned nothing, so the finding is dropped unverified rather than trusted.${row && row.error ? ' ' + row.error : ''}` })
      continue
    }
    const { finding, verdict } = row
    if (verdict.verdict === 'confirmed-defect' || verdict.verdict === 'needs-human') {
      confirmed.push({ ...finding, verdict: verdict.verdict, verifierNote: verdict.reason, correctedFrame: verdict.correctedFrame, provenance: verdict.provenance })
      if (verdict.provenance && verdict.provenance.age === 'introduced') {
        log(`Newly introduced: "${String(finding.claim).slice(0, 70)}" — blamed on ${verdict.provenance.blamedCommit || '?'}${verdict.provenance.blamedSubject ? ` (${verdict.provenance.blamedSubject})` : ''}.`)
      }
    } else if (verdict.verdict === 'route-elsewhere') {
      routed.push({ ...finding, routedTo: verdict.routedTo, reason: verdict.reason })
    } else {
      refuted.push({ ...finding, refutationKind: verdict.refutationKind, reason: verdict.reason })
    }
  }
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
  // which is the safe direction: filed rather than fixed under `fix: "game"`.
  if (f.startsWith('Tests/')) return f.includes(game) ? 'game' : 'engine'
  if (f.startsWith(`Sources/${game}/`)) return 'game'
  if (f.startsWith('docs/games/')) return 'game'
  return 'unknown'
}

// Why a confirmed finding was NOT fixed, or null if it is fixable. Named rather
// than inferred, so `report-shape.md`'s "Why not fixed here" column is read off
// the return value instead of reconstructed by hand every round.
//
// `harness` is excluded by this rule and not by falling through to `unknown`: a
// fixer editing the workflow that is currently running it, or the briefs its
// sibling agents are still reading, changes the run underneath itself. The
// harness does not repair itself mid-round.
//
// `unclassified` is what a leftover `unknown` becomes here. The classifier's word
// is the state of the path; this one is the state of the finding, and the whole
// point of splitting `harness` out is that reaching it now means a path nothing
// recognises — usually a tester inventing or misspelling an `ownerFile`.
function notFixedReason(cls, verdict) {
  if (verdict === 'needs-human') return 'needs-human'
  if (cls === 'harness') return 'harness'
  if (cls === 'unknown') return 'unclassified'
  if (fixMode === 'all') return null
  if (fixMode === 'game' && cls === 'game') return null
  return 'out-of-mode'
}

// Fixed order and zero entries, so a round that fixed nothing still prints all four.
const FILED_REASONS = ['needs-human', 'harness', 'out-of-mode', 'unclassified']

const fixable = []
const filed = []
const filedByReason = Object.fromEntries(FILED_REASONS.map((r) => [r, 0]))
const unrecognizedOwners = new Set()
for (const f of confirmed) {
  // Carried on the finding rather than left to be recomputed: `issue-shape.md`
  // asks the operator to label each checklist row with the owner, and re-running
  // the ladder by hand is how the two drifted apart in the first place.
  const cls = ownerClass(f.ownerFile)
  const reason = notFixedReason(cls, f.verdict)
  if (!reason) {
    fixable.push({ ...f, ownerClass: cls })
    continue
  }
  filed.push({ ...f, ownerClass: cls, notFixedReason: reason })
  filedByReason[reason] += 1
  if (reason === 'unclassified') unrecognizedOwners.add(f.ownerFile)
}
const filedBreakdown = FILED_REASONS.map((r) => `${r} ${filedByReason[r]}`).join(', ')

// Unconditional: a round that fixed nothing has to say why, and that is exactly
// the round whose Fix phase never runs.
log(
  `Fix mode "${fixMode}": fixing ${fixable.length} of ${confirmed.length} confirmed findings; filing ${filed.length} (${filedBreakdown}).`
)

if (unrecognizedOwners.size) {
  log(
    `Unrecognised ownerFile paths, which no fix mode can reach — most often a tester inventing or misspelling one: ${[...unrecognizedOwners].join(', ')}`
  )
}

const fixes = []
if (fixable.length) {
  phase('Fix')

  // Cluster by owning file and give each fixer disjoint files. Several agents
  // editing one game file in parallel is a merge conflict with extra steps; for
  // a one-file game the cluster count is 1 and this degenerates to a serial
  // batch loop, which is correct.
  const clusters = new Map()
  for (const f of fixable) {
    const k = f.ownerFile
    if (!clusters.has(k)) clusters.set(k, [])
    clusters.get(k).push(f)
  }
  log(`Fixing ${fixable.length} findings across ${clusters.size} disjoint file clusters.`)

  const results = await parallel(
    [...clusters.entries()].map(([file, group]) => () =>
      agent(
        `${groundMin(labelFor('fix', file.split('/').pop()))}

Read \`${REF}/fixer-brief.md\` first and follow it exactly.

You own **${file}** and nothing else. Another fixer is working in a different file
right now, so do not touch theirs.

Fix these ${group.length} confirmed defects, TEST FIRST — write the failing transcript
test from the reproducer, run it, SEE IT FAIL, then fix, then see it pass:

${group.map((f, i) => `${i + 1}. ${f.claim}
   Frame:      ${f.frame.room}${f.frame.hour ? ' @ ' + f.frame.hour : ''} — ${f.frame.state}
   Excerpt:    ${f.excerpt}
   Reproducer: ${JSON.stringify(f.reproducer)}
   Fault:      ${f.fault}
   Verifier:   ${f.verifierNote || ''}${f.alsoSeenIn && f.alsoSeenIn.length ? `\n   Also false in: ${f.alsoSeenIn.join('; ')} — your fix must satisfy every one of these frames, not just the first` : ''}`).join('\n\n')}

${docPath ? `Any prose you change must also change in \`${docPath}\`, in this same commit.` : ''}
If the only fix you can see would change a count or structure the mechanics contract
pins, STOP and report it in \`escalated\` instead of doing it.

Report assertionsRemoved honestly. It is checked independently, and a fixer that
deleted an assertion has not fixed anything.`,
        { label: `fix:${file.split('/').pop()}`, phase: 'Fix', schema: FIX_SCHEMA }
      ).then((r) => ({ file, group, result: r }))
    )
  )
  fixes.push(...results.filter(Boolean))
}

// ---------------------------------------------------------------------------
// Phase 5 — Gate
// ---------------------------------------------------------------------------

phase('Gate')

const touched = fixes.flatMap((f) => (f.result && f.result.filesTouched) || [])

const gateThunk = () =>
  agent(
      `${groundMin(labelFor('gate'))}

You are the gate. Nothing you are told about the fixes is to be trusted; check it.

1. Run \`swift test --build-system swiftbuild\` and report the real count and any
   failures. (This repo needs --build-system swiftbuild because the test target
   imports the executable targets.)
2. Run the strict lint:
   \`xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests\`
   **\`.swift-format\` is gitignored and absent from a fresh clone** — it is generated by
   \`.build/checkouts/Persnicket/bin/ci-lint-setup\`. Run that first if the file is
   missing. If you cannot lint, set lintPassed false and say why in lintSkippedReason.
   Do not report a pass you did not observe.
3. \`git diff\` the test files and check whether any assertion was REMOVED or LOOSENED —
   a deleted \`#expect\`, a needle dropped from an expectInOrder list, a narrowed
   substring. Set assertionsWeakened and quote what you found. This is the check the
   fixers cannot be trusted to make about themselves.
4. ${docPath ? `Diff \`${docPath}\` and confirm no count or structure in its mechanics contract changed. Prose may change; the invariants may not.` : 'No design doc, so no contract to check: set contractIntact true.'}

Files the fixers say they touched: ${touched.join(', ')}`,
      { label: 'gate', phase: 'Gate', schema: GATE_SCHEMA, effort: 'high' }
    )

// Coverage arithmetic in plain code, from the survey's denominator, so the
// critic judges numbers it did not produce. This is what turns "a clean round
// produces an empty report, not a plausible one" into a measurement.
//
// Reconciled against the survey roster rather than unioned raw. A tester that
// writes "Landing" where the survey says "Upstairs Landing" would otherwise
// inflate the numerator past the denominator — the first calibration round
// printed "13 of 9 rooms visited", which is the exact shape of a number that
// makes a reader stop trusting the report.
const loose = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '')
const visited = new Set()
const unrecognized = new Set()
for (const name of coverage.flatMap((c) => c.roomsVisited || [])) {
  const match =
    survey.rooms.find((r) => loose(r) === loose(name)) ||
    survey.rooms.find((r) => loose(r).includes(loose(name)) || loose(name).includes(loose(r)))
  if (match) visited.add(match)
  else unrecognized.add(name)
}
const neverVisited = survey.rooms.filter((r) => !visited.has(r))
const turnsSpent = coverage.reduce((n, c) => n + (c.turnsSpent || 0), 0)
const reportedWordTotal = [...unknownWords.values()].reduce((a, b) => a + b, 0)

// The census, counted off the transcripts rather than asked of the testers.
// Self-reporting is what made this number wrong: the schema told testers that a
// word the game printed is a K8 finding, they read that as "file it there
// INSTEAD", and the 2026-07-31 round returned 2 occurrences against transcripts
// holding 261 over 59 words. The schema now says both; this counts anyway,
// because a derived number does not depend on seventy-nine agents reading a
// field description the same way.
// Started here, awaited by the critic — not `await`ed on this line. Nothing in
// the gate reads it, and the gate is the round's longest pole (`swift test`
// plus a strict recursive lint), so blocking on a subagent round-trip in front
// of it is dead wall clock on every round.
const censusPromise = agent(
  `${groundMin(labelFor('census'))}

You are the unknown-word census. You count; you do not judge, file or explain.

From \`${pkg}\`, run exactly this and read the output:

    grep -rhoE 'I don.t know the word "[a-z]+"' .context/playtest/${game}-*/*/transcript.txt | sort | uniq -c | sort -rn

Report every distinct word with its count, and the total number of occurrences.
Leave nothing out and open no findings: a word the game printed is somebody
else's K8 finding and it still counts here. If the glob matches no files, report
zero and say so in \`note\` — that is a real answer and it means the round wrote
no transcripts.`,
  { label: 'census', phase: 'Gate', schema: CENSUS_SCHEMA, effort: 'low' })

const criticThunk = async () => {
  const census = await censusPromise
  const unknownWordTotal = Math.max(reportedWordTotal, (census && census.totalOccurrences) || 0)
  const unknownWordDistinct = Math.max(unknownWords.size, ((census && census.words) || []).length)
  return agent(
  `${groundMin(labelFor('critic'))}

You are the completeness critic. You do not look for defects; you look for what this
round MISSED. Silent truncation reads as "covered everything" when it wasn't, and your
whole job is to stop that.

Arithmetic computed from the survey's denominator — judge it, and **check it**. These are
the testers' self-reports reconciled against the survey roster, so they can still be
wrong or flattering; the transcripts under \`${pkg}/.context/playtest/\` are the ground
truth and they win over anything below.
- Rooms: ${visited.size} of ${survey.rooms.length} visited. Never visited: ${neverVisited.join(', ') || 'none'}.${unrecognized.size ? ` Testers also named ${unrecognized.size} place(s) not on the survey roster (${[...unrecognized].join(', ')}) — reconcile these.` : ''}
- Turns spent by testers: ${turnsSpent} of ~${turnBudget * playRoster.length} budgeted. This EXCLUDES the verifiers' own probes, which are usually a large share of the round, so treat it as a floor and count the true total from the transcripts.
- There is deliberately no "cells probed" count: free-text cell labels are not comparable between charters, so any total would be a number that means nothing. Build the real cross-product yourself from the transcripts, against the ${survey.rooms.length}-room roster and the timers above.
- Charters run: ${playRoster.map((c) => c.key).join(', ')}. NOT run: ${skipped.map((c) => c.key).join(', ') || 'none'}.
- Confirmed ${confirmed.length}, refuted ${refuted.length}, findings routed to another issue ${routed.length}, fixed ${fixes.filter((f) => f.result && f.result.fixed).length}.
- Filed rather than fixed: ${filed.length} (${filedBreakdown}). \`${REF}/report-shape.md\` defines the four reasons.
- Unknown-word replies: ${unknownWordTotal} occurrences over ${unknownWordDistinct} distinct words, counted off the transcripts (the testers self-reported ${reportedWordTotal} over ${unknownWords.size}; a gap between the two is a reporting defect, not a coverage one, and is worth a line). Not findings in themselves and not coverage — but ~48 verbs are stubs now, so a large number here is itself worth a sentence.
- Timers, and whether any was left unexercised: ${(survey.timers || []).map((t) => t.label).join(', ') || 'none'}.

Each charter's own coverage note:
${coverage.map((c) => `- ${c.charter} (round ${c.round}): ${c.honestSummary}${(c.cellsSkipped || []).length ? ` | skipped: ${c.cellsSkipped.join(', ')}` : ''}`).join('\n')}

Refuted this round, with reasons:
${refuted.map((r) => `- [${r.charter || '?'}] ${r.claim || '(no claim)'} → ${r.refutationKind}: ${r.reason}`).join('\n') || '- none'}

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
    { label: 'critic', phase: 'Gate', schema: CRITIC_SCHEMA, effort: 'high' }
  )
}

// The gate runs the suite and the lint; the critic re-counts coverage from the
// transcripts. Neither reads the other's output, and both are slow, so they run
// together rather than one waiting on the other. The census, started above,
// finishes inside the critic's own wait.
const [gate, critic] = await parallel(
  touched.length ? [gateThunk, criticThunk] : [() => null, criticThunk])

const census = await censusPromise
const censusWords = (census && census.words) || []
const selfReportedWords = [...unknownWords.entries()]
  .map(([word, count]) => ({ word, count }))
  .sort((a, b) => b.count - a.count)

return {
  game,
  packagePath: pkg,
  seed,
  fixMode,
  tiers: survey.tiers,
  charters: { run: playRoster.map((c) => c.key), skipped: skipped.map((c) => c.key) },
  confirmed,
  filed,
  filedByReason,
  refuted,
  routed,
  // The census is the authority; what the testers said is kept beside it so a
  // reader can see the two disagree.
  unknownWords: censusWords.length ? [...censusWords].sort((a, b) => b.count - a.count) : selfReportedWords,
  unknownWordsSelfReported: selfReportedWords,
  fixes: fixes.map((f) => ({ file: f.file, ...(f.result || {}), findings: f.group.map((g) => g.claim) })),
  gate,
  critic,
  coverage: { rooms: { visited: visited.size, total: survey.rooms.length, neverVisited }, turnsSpent, perCharter: coverage },
}

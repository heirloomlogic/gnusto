export const meta = {
  name: 'playtest',
  description:
    'Automated play-test round for a Gnusto demo game: charter-diverse subagents read transcripts as prose, every finding is replayed and then adversarially refuted by two independent raters, and a critic reads the coverage off what the sessions themselves wrote down rather than believing the testers.',
  whenToUse:
    'Invoked by /playtest <game>. Needs args {game, packagePath, docPath, capabilities, turns, charters, rounds}. The calling session builds the binary first (bin/playtest-replay --build <Game>) and writes the returned report; this script has no filesystem access of its own.',
  phases: [
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
// Reasoning effort for the verifiers, which are the round's largest fan-out: one
// per fresh finding, so they set its cost. Left inheriting by default. Turning it
// down is a budget call and belongs to the operator, not to the file: a verifier
// that refutes real defects yields a thin round that reads as a clean one, and
// that failure is silent.
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
    // No `unknownWords` and no `roomsVisited`. Both used to be asked of the
    // tester and both were wrong — 2 occurrences reported against transcripts
    // holding 261, and 112 rooms claimed against 155 walked. The session server
    // now writes them into `closing.json` off the parse record and the status
    // line, so the round reads them instead. A word the *game printed* and
    // cannot answer is still a defect and still gets filed as an ordinary
    // finding; it was never the count that made it one.
    coverage: {
      type: 'object',
      additionalProperties: false,
      required: ['cellsSkipped', 'turnsSpent', 'honestSummary'],
      properties: {
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
  required: ['rooms', 'words', 'sessionsFinished', 'sessionsUnfinished'],
  properties: {
    rooms: {
      type: 'array',
      description: 'Every distinct room name appearing in any closing.json `roomsVisited`, copied exactly.',
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
      description: 'Forks that appear in some closing.json with taken:false and in none with taken:true — a branch the whole round left alone.',
      items: { type: 'string' },
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
    key: 'explorer',
    // The only charter that plays blind, and the only one that instantiates more
    // than once. `copies` is capped at 3: past that the regions get too thin to
    // be worth a whole agent, and the divergence cycle stops covering forks and
    // starts duplicating them.
    copies: (regions) => Math.min(Math.max(regions.length, 1), 3),
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
prose names that does not exist.`,
  },
  {
    key: 'timekeeper',
    appliesTo: (survey) => (survey.timers || []).length > 0,
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
stub yet. Collect them in one list with counts.

Do not report an actor's presence line repeating. It is the most likely false positive
here and it is the exact opposite of a bug.`,
  },
]

// Divergence is assigned round-robin rather than drawn, which is risk 4 in the
// plan made concrete: three explorers left to chance can all draw `abstain`, and
// then nobody opens the egg and the round reports a fork it never tested.
const DIVERGENCE_CYCLE = ['commit', 'abstain', 'defer']

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
const chosen = requested ? active.filter((c) => requested.has(c.key)) : active
const skipped = CHARTERS.filter((c) => !chosen.includes(c))

// Regions come from `focus` when the operator split the map, and are otherwise
// one unnamed region — which is the right answer for a nine-room game and the
// wrong one for a 195-room game whose operator forgot.
const regions = String(ARGS.focus || '')
  .split(/\s*\|\s*/)
  .map((r) => r.trim())
  .filter(Boolean)

// One charter can run more than once. Only `explorer` does today, and the
// assignment it carries — a region and a divergence policy — is the reason: two
// explorers with the same policy in the same region are one explorer run twice.
const playRoster = chosen.flatMap((charter) => {
  const copies = charter.copies ? charter.copies(regions) : 1
  return Array.from({ length: copies }, (_, i) => ({
    charter,
    key: copies > 1 ? `${charter.key}-${i + 1}` : charter.key,
    // Only a charter that instantiates per region gets one. A single-copy
    // charter handed `regions[0]` would be told its region is whichever the
    // operator happened to name first, which is worse than being told nothing:
    // the timekeeper would have skipped every clock cell outside it.
    region: copies > 1 && regions.length ? regions[i % regions.length] : null,
    // Only the blind charters take a policy. The others are running fixed
    // rosters or a known route, so withholding a move from them would just make
    // their own job incomplete.
    divergence: charter.blind ? DIVERGENCE_CYCLE[i % DIVERGENCE_CYCLE.length] : 'commit',
  }))
})

log(
  `${game}: ${survey.rooms.length} rooms, ${(survey.timers || []).length} timers, tiers ${survey.tiers.join('+')}. ` +
    `Testers: ${playRoster.map((r) => `${r.key}${r.charter.blind ? `/${r.divergence}` : ''}`).join(', ')}` +
    `${skipped.length ? ` — not run: ${skipped.map((c) => c.key).join(', ')}` : ''}.`
)

// ---------------------------------------------------------------------------
// Phase 2 + 3 — Play, then Triage
// ---------------------------------------------------------------------------

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
        const oracle = charter.blind
          ? ''
          : `
The survey found:
- Rooms: ${survey.rooms.join(', ')}
- State axes: ${(survey.stateAxes || []).join(', ') || 'none'}
- Stock keys the game re-skinned: ${(survey.reskinnedTextKeys || []).join(', ') || 'none'}
- Stub-verb replies the game re-skinned: ${(survey.reskinnedStubs || []).join(', ') || 'NONE — every stub answers in the engine voice'}
- Proper-named actors: ${(survey.properNamedActors || []).join(', ') || 'none'}
`
        const server = `mcp__${game.toLowerCase()}__`
        const tools = ['open', 'move', 'recall', 'coverage', 'note', 'finish', 'checkpoint', 'restore', 'replay']
        return agent(
          `${(charter.blind ? groundBlind : ground)(labelFor(`r${round}`, 'play', assignment.key))}

Your charter is **${charter.key}**. Round ${round} of at most ${maxRounds}.

You play through the game's own MCP server. Its tools are deferred, so fetch them first
with \`ToolSearch\`, query \`select:${tools.map((t) => server + t).join(',')}\`.

Open with \`label: "${assignment.key}"\`, \`seed: ${seed}\`, \`role: "${charter.blind ? 'explorer' : 'unrestricted'}"\`${charter.blind ? `, \`divergence: "${assignment.divergence}"\`` : ''}.
${charter.blind ? `**Read the \`instruction\` your open returns and follow it for the whole session.** It tells you what to do the first time the game offers you something you cannot take back. Another tester has been given the opposite orders, so the branch you leave alone is covered and the one you take is yours to describe.\n` : ''}
Every turn's output ends with a \`[status]\` line naming the room, the move counter and
whether the command cost a turn. \`note\` writes a comment into your transcript at the
current turn and costs nothing — use it the moment a line reads wrong, not forty turns
later from memory. \`finish\` ends the session.
${assignment.region ? `\n**Your region is ${assignment.region}.**\n` : ''}
${charter.brief}

Your turn budget is about ${turnBudget} engine turns. Spend it on breadth first, then
depth on whatever looked wrong.
${oracle}${charter.checklist ? `\nYOUR GENERATED CHECKLIST:\n${charter.checklist(survey)}\n` : ''}
${seen.size ? `\nAlready seen in earlier rounds or the ledger — do NOT report these again:\n${[...seen].slice(0, 60).join('\n')}` : ''}

The session records to disk from the moment you open it, so the evidence is already
attached: carry the transcript path your \`open\` returned into \`transcriptPath\`. Use
\`replay\` to re-run a trimmed reproducer from a clean start before you report it — it
boots a fresh world and touches nothing, so it cannot disturb your session. Set
\`replayedCleanly\` honestly; a finding whose reproducer you did not re-verify is dropped
at triage, so guessing gains you nothing.

Your coverage note is not a formality. Name what you did not reach. A charter that
reports findings and hides its gaps makes the round look thorough when it was not.`,
          { label: `play:${assignment.key}`, phase: 'Play', schema: FINDINGS_SCHEMA }
        )
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
      if (f.routedTo) {
        routed.push(f)
        continue
      }
      if (!f.replayedCleanly) {
        refuted.push({ ...f, refutationKind: 'not-reproducible', reason: 'The tester did not re-verify the trimmed reproducer from a clean start.' })
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
        const verifyLabel = labelFor(
          `r${round}`,
          'verify',
          `b${String(batchIndex + 1).padStart(2, '0')}`,
          `r${rater + 1}`
        )
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
  Anchor:     ${f.frame.anchor}
  Reproducer: ${JSON.stringify(f.reproducer)}
  Fault:      ${f.fault}
  Owner file: ${f.ownerFile}`
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
   Confirm the excerpt appears verbatim, in the frame claimed, with the hour anchored by
   a real reading and not by counting commands — remember meta commands and parse
   failures cost no turn. If the quoted text is not in the tree, or the frame is wrong,
   refute and say which.

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
      refuted.push({
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

    let verdict
    if (distinct.size === 1) {
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
        attemptedRefutation: views.map((v) => v.attemptedRefutation).filter(Boolean).join('\n\n'),
      }
      disagreements.push({
        claim: finding.claim,
        ownerFile: finding.ownerFile,
        verdicts: views.map((v) => v.verdict),
      })
    }

    if (verdict.verdict === 'confirmed-defect' || verdict.verdict === 'needs-human') {
      confirmed.push({ ...finding, verdict: verdict.verdict, verifierNote: verdict.reason, attemptedRefutation: verdict.attemptedRefutation, correctedFrame: verdict.correctedFrame, provenance: verdict.provenance, raters: views.length })
      if (verdict.provenance && verdict.provenance.age === 'introduced') {
        log(`Newly introduced: "${String(finding.claim).slice(0, 70)}" — blamed on ${verdict.provenance.blamedCommit || '?'}${verdict.provenance.blamedSubject ? ` (${verdict.provenance.blamedSubject})` : ''}.`)
      }
    } else if (verdict.verdict === 'route-elsewhere') {
      routed.push({ ...finding, routedTo: verdict.routedTo, reason: verdict.reason })
    } else {
      refuted.push({ ...finding, refutationKind: verdict.refutationKind, reason: verdict.reason })
    }
  }

  if (disagreements.length) {
    log(
      `Round ${round}: ${disagreements.length} finding(s) split the raters and went to needs-human.`
    )
  }
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
//
// Reconciled against the survey roster rather than unioned raw. A tester that
// writes "Landing" where the survey says "Upstairs Landing" would otherwise
// inflate the numerator past the denominator — the first calibration round
// printed "13 of 9 rooms visited", which is the exact shape of a number that
// makes a reader stop trusting the report.
const loose = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '')

// Exact match only, and anything else is reported off-roster rather than
// guessed at.
//
// The fuzzy word-subset matcher this replaces existed to forgive a tester who
// typed "Landing" for "Upstairs Landing". Nobody types the name any more — it
// comes off the status line, which prints what the engine calls the room — so
// the forgiveness has no job and the hazard it carried is not worth keeping. On
// Dungeon's 195-room roster "Maze 1" *uniquely* substring-matches "Maze 14", so
// even an unambiguous partial match was a coin flip. A name that does not match
// exactly is a fact about the survey or the game, and the critic should see it
// rather than have it quietly resolved.
function rosterMatch(name) {
  return survey.rooms.find((r) => loose(r) === loose(name)) || null
}

const turnsSpent = coverage.reduce((n, c) => n + (c.turnsSpent || 0), 0)

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

    ls .context/playtest/${game}-*/*/closing.json

Read every one. Each holds \`roomsVisited\` (room names, in the order the session
first stood in them), \`unknownWords\` (token → how many times it was typed) and
\`forks\` (each with an \`id\`, a \`command\`, a \`room\` and a \`taken\` flag).

Report:

- \`rooms\`: every distinct name appearing in any \`roomsVisited\`, copied exactly.
- \`words\`: one row per distinct token, with its count summed across all files.
- \`forksNobodyTook\`: the \`id\` of every fork appearing with \`taken: false\` and
  never with \`taken: true\`. A fork no session took is a branch the whole round
  left alone, and nothing else in the harness can see it.
- \`sessionsFinished\`: how many \`closing.json\` files you read.
- \`sessionsUnfinished\`: probe directories holding a \`transcript.txt\` with no
  \`closing.json\` beside it. Find them with:

      ls -d .context/playtest/${game}-*/*/ | while read d; do [ -f "$d/transcript.txt" ] && [ ! -f "$d/closing.json" ] && echo "$d"; done

  Name them. A session that never called \`finish\` played the game and left no
  account of it; a round that drops the row rather than reporting it is claiming
  coverage it cannot show.

Exclude any \`${game}-critic\`, \`${game}-collator\` or \`${game}-verify\` directory
the globs pick up — that is the round auditing itself, not playing it. Say so in
\`note\` if you had to.

If the globs match nothing, report zeroes and empty lists and say so in \`note\`.
That is a real answer and it means the round wrote no sessions.`,
  // Haiku, hardcoded: a fact about the role rather than about any one round.
  // There is no judgement here to degrade — the numbers are the files' or they
  // are wrong, and the critic is told to spot-check them either way.
  { label: 'collator', phase: 'Critic', schema: COLLATOR_SCHEMA, effort: 'low', model: 'haiku' })

// Derived once, off the promise, so the critic's prompt and the returned
// coverage cannot disagree about what was walked.
const roomTallyPromise = collatorPromise.then((collated) => {
  const visited = new Set()
  const offRoster = new Set()
  for (const name of (collated && collated.rooms) || []) {
    const match = rosterMatch(name)
    if (match) visited.add(match)
    else offRoster.add(name)
  }
  return {
    visited,
    offRoster,
    neverVisited: survey.rooms.filter((r) => !visited.has(r)),
    forksNobodyTook: (collated && collated.forksNobodyTook) || [],
    sessionsFinished: (collated && collated.sessionsFinished) || 0,
    sessionsUnfinished: (collated && collated.sessionsUnfinished) || [],
    words: (collated && collated.words) || [],
  }
})

const criticThunk = async () => {
  const {
    visited, offRoster, neverVisited, forksNobodyTook, sessionsFinished,
    sessionsUnfinished, words,
  } = await roomTallyPromise
  const unknownWordTotal = words.reduce((n, w) => n + (w.count || 0), 0)

  return agent(
  `${groundMin(labelFor('critic'))}

You are the completeness critic. You do not look for defects; you look for what this
round MISSED. Silent truncation reads as "covered everything" when it wasn't, and your
whole job is to stop that.

Arithmetic computed from the survey's denominator — judge it, and **check it**. The rooms
and the unknown words are read from the \`closing.json\` each session wrote at \`finish\`,
so they are counted rather than recalled; the prose notes below them are still self-report
and can be flattering. The transcripts under \`${pkg}/.context/playtest/\` are the ground
truth and they win over anything here.
- Rooms: ${visited.size} of ${survey.rooms.length} entered. Never entered: ${neverVisited.join(', ') || 'none'}.${offRoster.size ? ` ${offRoster.size} name(s) in the closing records match no roster room (${[...offRoster].slice(0, 12).join(', ')}) — either the survey's roster is short or the game renames a room at runtime. Say which.` : ''}
- **Entered is not covered, and the report must not conflate them.** The count above is
  every room a session stood in, which includes rooms that only flashed past inside a
  replayed prefix from \`.context/playtest/routes/\` while the harness typed somebody
  else's walkthrough. A room nobody typed their own command in is blank, however many
  times its name printed. Only the transcripts can tell the two apart — do that, and give
  the grid \`X\` for a room a charter worked in and \`.\` for one it only passed through.
- Sessions that wrote a closing record: ${sessionsFinished}.${sessionsUnfinished.length ? ` **${sessionsUnfinished.length} session(s) never called \`finish\`** (${sessionsUnfinished.slice(0, 8).join(', ')}) — their rooms and words are missing from every count above, so the coverage figure is a floor and you should say so in as many words.` : ''}
- Forks no session took: ${forksNobodyTook.length ? forksNobodyTook.join(', ') : 'none'}. Each is an irreversible action the whole round declined, which is a coverage gap nothing else in the harness can see. Name them in the coverage section and make one a target for next round.
- Turns spent by testers: ${turnsSpent} of ~${turnBudget * playRoster.length} budgeted. This EXCLUDES the verifiers' own probes, which are usually a large share of the round, so treat it as a floor and count the true total from the transcripts.
- There is deliberately no "cells probed" count: free-text cell labels are not comparable between charters, so any total would be a number that means nothing. Build the real cross-product yourself from the transcripts, against the ${survey.rooms.length}-room roster and the timers above.
- Testers run: ${playRoster.map((r) => `${r.key}${r.charter.blind ? ` (${r.divergence}${r.region ? `, ${r.region}` : ''})` : ''}`).join(', ')}. Charters NOT run: ${skipped.map((c) => c.key).join(', ') || 'none'}.
- The blind charters were given no room list, no timer list and no design doc, deliberately. A finding of theirs that the doc licenses is the expected cost of that, not a harness failure — but if more than about two in five are refuted that way, say so: the brief needs tightening, not the doc handing back.
- Confirmed ${confirmed.length}, refuted ${refuted.length}, findings routed to another issue ${routed.length}. Every confirmed finding is filed; this round edits nothing.
- **Verifier agreement: ${agreementTotal ? `${Math.round((agreementMatched / agreementTotal) * 100)}% (${agreementMatched} of ${agreementTotal} findings judged the same way by both raters)` : 'not measurable — no finding got two raters'}.**${singleRated ? ` ${singleRated} finding(s) got only one rater, so the denominator is thinner than the finding count.` : ''} Verification is batched now — up to ${VERIFY_BATCH_SIZE} findings per verifier, ${VERIFY_RATERS} raters each — and this number is the check on that. Near-total agreement is not automatically good news: it is what both careful raters and two rubber-stampers produce. Sample two or three \`attemptedRefutation\` fields from the confirmed list and say whether they read as separately reasoned or interchangeable. That judgement is yours and nothing else in the round makes it.
- Unknown words: ${unknownWordTotal} occurrence(s) over ${words.length} distinct token(s), taken from the parse record rather than by grepping for the engine's refusal line. Not findings in themselves and not coverage — but ~48 verbs are stubs now, so a large number here is worth a sentence. A word the *game itself printed* and could not answer is a defect and should have arrived as an ordinary finding; if the count is high and no such finding was filed, that is a gap in the round, not in the game.
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
    run: playRoster.map((r) => ({ key: r.key, charter: r.charter.key, region: r.region, divergence: r.charter.blind ? r.divergence : null })),
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
    rooms: {
      visited: roomTally.visited.size,
      total: survey.rooms.length,
      neverVisited: roomTally.neverVisited,
      offRoster: [...roomTally.offRoster],
    },
    forksNobodyTook: roomTally.forksNobodyTook,
    sessionsFinished: roomTally.sessionsFinished,
    sessionsUnfinished: roomTally.sessionsUnfinished,
    turnsSpent,
    perCharter: coverage,
  },
}

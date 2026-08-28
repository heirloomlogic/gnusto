// A zero-agent dry run of playtest.js: stubs `agent`, `parallel`, `phase` and
// `log`, feeds each stub a schema-shaped reply, and runs the real orchestration.
//
// It exists because the script is 1,400 lines that only execute inside a fan-out,
// so the cheap failures — a deleted helper, a phase name that no longer matches
// `meta`, an oracle field leaking into a blind tester's prompt — used to be
// discoverable only by spending a full round. It has already caught all three.
//
//   node .claude/workflows/playtest.dryrun.mjs
//
// Prompts land in /tmp/prompts.txt. Grep them: the firewall is a property of the
// generated text, and this is the only place it can be asserted cheaply.
import { readFileSync, writeFileSync } from 'node:fs'
const src = readFileSync('.claude/workflows/playtest.js', 'utf8').replace('export const meta =', 'const meta =')

const prompts = []
const phases = []
const logs = []

const survey = {
  // `{id, name}` since #287, and the last two rows are the whole reason: two
  // rooms under one display name is the case a name-keyed roster cannot
  // represent, and Dungeon has seventeen of them. The collator below reports one
  // of the pair and not the other, so the critic has to be able to say that
  // "Stair" was both entered and never entered — of different rooms.
  rooms: [
    { id: 'frontHall', name: 'Front Hall' },
    { id: 'parlour', name: 'Parlour' },
    { id: 'kitchen', name: 'Kitchen' },
    { id: 'cellar', name: 'Cellar' },
    { id: 'landing', name: 'Upstairs Landing' },
    { id: 'boardersRoom', name: "Boarder's Room" },
    { id: 'study', name: "Vane's Study" },
    { id: 'backYard', name: 'Back Yard' },
    { id: 'carriageHouse', name: 'Carriage House' },
    { id: 'avenue', name: 'Orange Grove Avenue' },
    { id: 'frontStair', name: 'Stair' },
    { id: 'backStair', name: 'Stair' },
  ],
  // Declared, playable, and on no exit table: the boiler room is reached by
  // pulling the dumbwaiter rope and by nothing else. `definition.reachableRooms`
  // walks the static exits, so the survey tool reports it `isReachable: false`
  // and the cartographer files it here — and it is still a room the round must
  // score, which is what the collator below exercises by entering it. Scoring it
  // out of the roster reported Dungeon's eight rule-entered rooms as
  // simultaneously off-roster and never-entered.
  unreachableRooms: [
    { id: 'boilerRoom', name: 'Boiler Room' },
  ],
  // Two, deliberately: the stub collator below reports a fire for one of them
  // and nothing for the other, so the critic's "declared and never fired" line
  // has both a positive and a negative to get right.
  timers: [
    { name: 'clock', kind: 'alarm', at: '20:15', readsPlayerLocation: true },
    { name: 'lamp', kind: 'fuse', readsPlayerLocation: false },
  ],
  stateAxes: ['hour'], tiers: ['source','doc'],
  printedNouns: [{ noun: 'grout', answerable: false, printedIn: 'Front Hall' }],
  reskinnedTextKeys: ['cantTakeActor'], reskinnedStubs: [], properNamedActors: ['Mrs. Vane','Dr. Pike'],
}
// Enough distinct findings to take every exit the reconciliation loop has. One
// finding on the confirmed path leaves four of the five push sites unexecuted,
// and the whole point of the rationale assertions is that they run against all
// of them.
//
// The interrogator's four are what make the *ordering* of the critic's paired
// sample testable: with `VERDICTS_BY_INDEX` below they produce three confirmed
// rows ahead of the first refuted one, so a sample drawn down `confirmed`
// instead of across the three lists shows one verdict and the assertion says so.
const bug = (claim, excerpt, ownerFile, extra = {}) => ({
  claim, excerpt, ownerFile,
  category: 'prose-untrue-of-frame', severity: 'minor',
  frame: { room: 'Parlour', state: 'after 20:15' },
  reproducer: ['z'], fault: 'unknown',
  replayedCleanly: true, transcriptPath: '/tmp/t.txt',
  ...extra,
})
const findings = (charter) => ({
  charter,
  findings: charter.startsWith('explorer')
    ? [bug('listing line is location-blind', 'Mrs. Vane is here, watching the fire.', 'Sources/Fulminate/Cast.swift',
          { category: 'prose-untrue-of-frame', severity: 'major', frame: { room: 'Cellar', state: 'after 20:15' },
            reproducer: ['down','z'], fault: 'presence line ignores room' })]
    : charter === 'interrogator'
    ? [bug('the study door refuses in the wrong words', 'The door is locked tight against you.', 'Sources/Fulminate/Doors.swift'),
       bug('the parlour clock ticks after it stops', 'The mantel clock ticks on, indifferent.', 'Sources/Fulminate/Clockwork.swift'),
       bug('the cellar smells of nothing', 'You smell nothing unexpected.', 'Sources/Fulminate/Cellar.swift'),
       bug('the grove is described at night as by day', 'Orange blossom hangs heavy in the sun.', 'Sources/Fulminate/Grove.swift')]
    // The two exits taken before any verifier sees a finding: routed by the
    // tester, and dropped for never having been replayed. Both land in the same
    // lists as a rated verdict, so both are checked for the same shape.
    : charter === 'solver'
    ? [bug('the lamp runs out early', 'The lamp gutters and dies.', 'Sources/Fulminate/Lamp.swift', { routedTo: '99' }),
       bug('the yard gate sticks', 'The gate will not budge.', 'Sources/Fulminate/Yard.swift', { replayedCleanly: false })]
    : [],
  // No `turnsSpent`: the round counts turns off the `[status]` footers now, and
  // the field is gone from COVERAGE, whose `additionalProperties: false` would
  // reject a tester that still sent one.
  coverage: { honestSummary: 'walked it', cellsSkipped: [] },
})

// The collator's turn counts, in one place: the stub returns them and the
// assertions at the bottom add them up. Two copies of these numbers would fail
// in the wrong direction — a drifted fixture reads as "playtest.js dropped a
// class of turn", which is the exact bug the assertions exist to catch.
//
// The figures are the 2026-08-18 Dungeon round's, which is the round that
// discovered the two CLI trees were invisible, plus the 2026-08-24 round's
// harness residual — 8,095 turns that resolved to `prefix-check`, `thief-rate`,
// `thief-prefix` and `Dungeon-survey` and were handed to the critic as a
// mystery. `all` deliberately exceeds the ten globbed numbers, so the residual
// path is still the one under test with a fourth tree named.
const stubTurns = {
  sessions: 252, branches: 102, replays: 1139, replayProbes: 71,
  playReplays: 7646, playProbes: 39, verifyReplays: 25341, verifyProbes: 119,
  harnessReplays: 8095, harnessProbes: 27,
  all: 44_000,
}

const stub = async (prompt, opts = {}) => {
  prompts.push({ label: opts.label, phase: opts.phase, prompt })
  const l = String(opts.label || '')
  // The preflight agent answers first, and answers yes. The no branch returns
  // early out of the whole script, so it gets its own run at the bottom of this
  // file rather than a flag here — a stub that could go either way would make
  // every assertion below conditional on which way it went.
  if (l.startsWith('preflight')) {
    return { toolsResolved: true, toolNames: ['mcp__fulminate__open', 'mcp__fulminate__finish'] }
  }
  if (l.startsWith('survey')) return survey
  if (l.startsWith('play:')) return findings(l.slice(5))
  if (l.startsWith('cluster')) return { assignments: [{ index: 1, declaration: 'Sources/Fulminate/Prose.swift::vaneHere' }] }
  // One verdict per finding the prompt actually numbered, so the stub stays
  // honest about batch size rather than assuming one: a reconciliation that
  // silently drops findings would otherwise dry-run green.
  // Each rater's text is keyed off its own label. Two raters returning the same
  // string is what the harness cannot tell from two raters who never read each
  // other — so the fixture makes them differ, and the assertions below check
  // that BOTH survive to the critic rather than that one of them does.
  if (l.startsWith('verify')) {
    const rater = (l.match(/r(\d+)$/) || [])[1] || '?'
    const count = (prompt.match(/^\[\d+\] found by the /gm) || []).length
    // Both raters agree on every finding — the case the reconciliation collapses
    // — but they do not all agree on the same *verdict*, so the loop takes all
    // three of its rated exits within one dry run. Deliberately front-loaded
    // rather than cycled: the confirmed rows have to outnumber and precede the
    // others for the critic's sampling assertion to be able to fail.
    const VERDICTS_BY_INDEX = [
      'confirmed-defect', 'confirmed-defect', 'confirmed-defect',
      'refuted', 'route-elsewhere', 'refuted',
    ]
    return {
      verdicts: Array.from({ length: count }, (_, i) => {
        const verdict = VERDICTS_BY_INDEX[i % VERDICTS_BY_INDEX.length]
        return {
          index: i + 1,
          verdict,
          reason: `rater ${rater} reason`,
          attemptedRefutation: `rater ${rater} tried the doc-licenses-it line and it does not hold`,
          ...(verdict === 'refuted' ? { refutationKind: 'licensed-by-doc' } : {}),
          ...(verdict === 'route-elsewhere' ? { routedTo: '99' } : {}),
        }
      }),
    }
  }
  if (l === 'collator') {
    return {
      // Room ids, as a `closing.json` carries them. `frontStair` and not
      // `backStair`, so the twin under the same display name has to come back as
      // never entered; `boilerRoom` is the rule-entered room, which is on the
      // roster and must NOT come back off it; and `shipsHold` belongs to no
      // declared room of this game at all, which is the branch that says the
      // artifacts and the roster describe different builds.
      rooms: ['frontHall', 'cellar', 'frontStair', 'boilerRoom', 'shipsHold'],
      // The stricter half. Two of the four rooms on the roster were typed in;
      // `cellar` and `frontStair` were only stood in, which is what a pasted
      // route prefix leaves behind. `shipsHold` is deliberately absent: a subset
      // by construction, so the off-roster complaint is made once by `rooms` and
      // not twice.
      roomsWorked: ['frontHall', 'boilerRoom'],
      words: [{ word: 'grout', count: 2 }],
      forksNobodyTook: ['fork:burn-the-letter@Parlour'],
      // One roster timer that fired, one roster timer that did not, and one
      // fired name the roster does not hold. The third is the case that says the
      // cartographer's roster is wrong, and it has to reach the critic as that
      // rather than as a fourth timer.
      timers: [{ name: 'clock', count: 4 }, { name: 'ghost', count: 1 }],
      turns: stubTurns,
      sessionsFinished: 3,
      sessionsUnfinished: ['.context/playtest/Fulminate-explorer-b/probe-002/'],
      note: '',
    }
  }
  if (l === 'critic') return { summary: 'thin but honest' }
  return {}
}

const body = `
return (async () => {
  const agent = __stub
  const parallel = (thunks) => Promise.all(thunks.map((t) => t()))
  const phase = (t) => { __phases.push(t) }
  const log = (m) => { __logs.push(m) }
  const args = __args
${src}
})()
`
// Real ledger keys, in the shape the ledgers actually record: an owner file and
// a chunk of the game's own prose. Dungeon's are used deliberately — they are
// the pair that proves the leak matters, naming a room, its description and its
// source file, and they are what the egg round has to pass in.
const dryLedgerKeys = [
  'Sources/Dungeon/Regions/AboveGround.swift::up up a tree you are about 10 feet above the ground nestled among some large branches',
  'Sources/Fulminate/Fulminate.swift::the dr pike would take exception to that',
]
// Fixed, never derived: a workflow script cannot call `Date.now()`, and a dry run
// that stamped itself with today's date would make every label assertion below
// depend on the day it ran.
const dryRoundId = '2026-08-26'
const dryArgs = {
  game: 'Fulminate', packagePath: '.', docPath: 'docs/games/fulminate.md',
  capabilities: ['clock','talk'], seed: 0, turns: 60, roundId: dryRoundId,
  // Deliberately written in affordances rather than room names, because a region
  // is pasted verbatim into a blind explorer's prompt. This fixture used to read
  // "ground floor: Front Hall, Parlour, Kitchen | upstairs: Landing, Boarder's
  // Room, Study | outside: Back Yard, Carriage House" and passed, because the
  // only region assertion counted regions and never read one — so the harness's
  // own worked example handed a blind charter eight of Fulminate's ten rooms.
  // Space is expressible without the roster: the game's opening paragraph itself
  // says "the stairs go up", so "the floor above" leaks nothing the player has
  // not already been shown, exactly as an hour leaks nothing the watch does not.
  //
  // **Four regions against a copy cap of three, deliberately.** That is the
  // shape the seating used to drop silently — `regions[i % regions.length]` ran
  // 0, 1, 2 and handed the fourth to nobody — and the assertions below are the
  // regression test for it, so the count must stay above the cap.
  focus:
    'the first hour, 5:30 to 6:20, on the floor you start on and outside the house'
    + ' | the last half hour, 6:20 to 6:50, on the floor you start on and outside'
    + ' | the whole evening on the floor above: the opening tells you the stairs go'
    + ' up, so go up early and stay up, waiting rather than coming down'
    + ' | the last ten minutes, 6:40 to 6:50: stop moving, pick one place and watch'
    + ' it to the end rather than covering ground',
  ledgerKeys: dryLedgerKeys,
}
const fn = new Function('__stub','__phases','__logs','__args', body)
const result = await fn(stub, phases, logs, dryArgs)

console.log('PHASES   :', phases.join(' -> '))
console.log('AGENTS   :', prompts.length)
for (const p of prompts) console.log('  ', String(p.phase).padEnd(8), p.label)
console.log('\nLOGS:'); for (const l of logs) console.log('  ', l)
console.log('\nRESULT KEYS:', Object.keys(result).join(', '))
console.log('CHARTERS RUN:', JSON.stringify(result.charters.run, null, 1))
console.log('CONFIRMED:', result.confirmed.length, '| key:', result.confirmed[0] && result.confirmed[0].key)
console.log('VERDICTS :', `confirmed ${result.confirmed.length}, refuted ${result.refuted.length}, routed ${result.routed.length}`)
writeFileSync('/tmp/prompts.txt', prompts.map(p => `===== ${p.label} =====\n${p.prompt}`).join('\n\n'))

// ---------------------------------------------------------------------------
// Assertions. Everything above is a smoke run; these are the properties that
// have actually broken and would otherwise cost a full round to notice.
// ---------------------------------------------------------------------------

const failures = []
const check = (ok, what) => { if (!ok) failures.push(what) }
const labels = prompts.map((p) => String(p.label || ''))
const promptText = prompts.map((p) => p.prompt).join('\n')

// The probe layout, read out of playtest.js rather than restated here.
//
// `playtest.js` declares the scratch root, the `.replays` tree, the probe name
// and the artifact filenames once and builds every recipe from them. This file
// is where those names are checked against the four languages that actually
// write the files, so it must not hold a copy of its own: everything below that
// needs a path takes it from here.
//
// Scraped rather than imported, because playtest.js is not importable on its
// own — its top level reads the injected `agent`, `parallel`, `phase`, `log`
// and `args`, which is why `body` above wraps the source instead of loading it.
const layoutConst = (name) => (src.match(new RegExp(`^const ${name} = '([^']*)'`, 'm')) || [])[1]
const LAYOUT = {
  SCRATCH: layoutConst('SCRATCH'),
  REPLAY_TREE: layoutConst('REPLAY_TREE'),
  PROBE: layoutConst('PROBE'),
  TRANSCRIPT: layoutConst('TRANSCRIPT'),
}
for (const [name, value] of Object.entries(LAYOUT)) {
  check(!!value, `playtest.js no longer declares ${name}, so the recipes restate the layout again`)
}
// A layout name spliced into a regex. The names carry `.` and `*`, both of which
// mean something else there.
const literal = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

// Every phase() call has a matching meta.phases entry, and vice versa. A title
// that drifts out of `meta` gets its own progress box and nobody notices.
const metaPhases = [...src.matchAll(/\{ title: '([^']+)'/g)].map((m) => m[1])
check(
  phases.every((t) => metaPhases.includes(t)),
  `phase() titles not declared in meta: ${phases.filter((t) => !metaPhases.includes(t)).join(', ')}`
)

// Verification is batched: 2 raters over 1 batch for a round this size, and
// never one agent per finding. This is the property the batching change exists
// to create, so it is the one worth pinning.
const verifiers = labels.filter((l) => l.startsWith('verify:'))
check(verifiers.length === 2, `expected 2 batched verifiers, got ${verifiers.length}: ${verifiers.join(', ')}`)
check(
  verifiers.every((l) => /^verify:b\d+r\d+$/.test(l)),
  `verifier labels are not batch/rater shaped: ${verifiers.join(', ')}`
)
check(
  result.verification && result.verification.bothRaters > 0,
  'no finding was judged by two raters, so agreement is unmeasurable'
)

// Both raters' rationales survive reconciliation, on every path. Reconciliation
// picks one verdict, and it used to pick one rationale with it — `views[0]` —
// which discarded rater 2 on the agreement case: 40 of 52 findings in the
// 2026-08-18 round. Nothing downstream could tell that from two raters who
// genuinely wrote the same thing, and the round's own rubber-stamp check was
// reading the survivor.
const allVerdicts = [...result.confirmed, ...result.refuted, ...result.routed]
check(
  allVerdicts.every((f) => Array.isArray(f.raterViews)),
  `a verdict carries no raterViews array: ${JSON.stringify(allVerdicts.find((f) => !Array.isArray(f.raterViews)))}`
)
// `|| []` rather than a bare `.length`: `check` records a failure and carries on,
// so a run that has already failed the line above must still reach the report
// instead of dying in a TypeError that names no property.
const paired = allVerdicts.filter((f) => (f.raterViews || []).length >= 2)
check(paired.length > 0, 'no verdict kept two raters, so reconciliation is still collapsing them')
for (const f of paired) {
  const texts = f.raterViews.map((v) => v.attemptedRefutation)
  check(
    texts.every(Boolean) && new Set(texts).size === texts.length,
    `raterViews lost or duplicated an attemptedRefutation: ${JSON.stringify(texts)}`
  )
  check(
    f.raterViews.every((v, i) => v.rater === i + 1 && v.verdict && v.reason),
    `a raterView is missing its rater number, verdict or reason: ${JSON.stringify(f.raterViews)}`
  )
}
const raterTexts = [...new Set(paired.flatMap((f) => f.raterViews.map((v) => v.attemptedRefutation)).filter(Boolean))]
// The collapsed single-rater field is gone rather than kept beside the array. A
// field that holds rater 1's text and reads like the verdict's whole reasoning
// is the trap this change exists to remove, not something to leave lying about.
check(
  !allVerdicts.some((f) => 'attemptedRefutation' in f),
  'a top-level attemptedRefutation is back on a verdict, alongside raterViews'
)

// The censuses are gone and the collator replaced them. A reintroduced census
// would mean the round is grepping prose for numbers the server already wrote.
check(!labels.includes('census'), 'the unknown-word census agent is back')
check(!labels.includes('room-census'), 'the room census agent is back')
check(labels.includes('collator'), 'the closing-record collator did not run')
check(!/CENSUS_SCHEMA/.test(src), 'CENSUS_SCHEMA is still declared')
// The roster join is an exact lookup on a normalized key and nothing else. The
// fuzzy word-subset matcher this replaced existed to forgive a tester who typed
// "Landing" for "Upstairs Landing"; nobody types a room name any more, and on
// Dungeon's roster "Maze 1" *uniquely* substring-matches "Maze 14", so even an
// unambiguous partial match was a coin flip. Named against `reconcile` since
// #287 merged the room and timer joins — the old spelling had stopped existing,
// which made this check pass for the wrong reason. The case/punctuation
// normalizer went with it: both sides are the engine's key space now, and a
// normalizer that folds two declared ids into one bucket is the very collapse
// #287 exists to remove.
check(
  !/function reconcile\([\s\S]{0,700}(wordSubset|loose\(|\.includes\(|\.startsWith\(|\.indexOf\()/
    .test(src),
  'the roster join matches loosely again instead of on exact string equality'
)

// Nothing asks a tester for a number the session server writes down.
check(!/roomsVisited: \{ type: 'array'/.test(src), 'roomsVisited is a tester-reported field again')
check(!/gamePrintedIt/.test(src), 'the tester-reported unknown-word census is back')

// The firewall: a blind charter's prompt carries no answer key. Only `explorer`
// is blind — the others read the doc by design and adjudicate against it. This
// is a property of the generated *text*, and grepping it is the only cheap way
// to know.
const blind = prompts.filter((p) => /^play:explorer/.test(String(p.label || '')))
check(blind.length > 0, 'no blind charters ran, so the firewall is untested')
const regions = String(dryArgs.focus || '').split('|').map((r) => r.trim()).filter(Boolean)
// The seat count, OBSERVED rather than re-derived. `blind.length` is how many
// blind seats the workflow actually made; restating `Math.min(Math.max(n,1),3)`
// here would copy `REGION_SEATS` across the `new Function` boundary, and then
// raising the cap to 4 would leave `chunkCap` computed against a stale 3 while
// the guard below read `4 > 3` and passed — the assertion that exists to
// guarantee the chunking path is exercised, silently no longer guaranteeing it.
const chunkCap = Math.ceil(regions.length / blind.length)
const seatedRegions = new Set()
check(
  regions.length > blind.length,
  'the fixture declares no more regions than seats, so the chunking path is untested'
)
for (const p of blind) {
  check(!p.prompt.includes('docs/games/'), `${p.label} was handed the design doc path`)
  check(!p.prompt.includes('playtester-brief'), `${p.label} was handed the judgement kernel`)
  check(!/\bsurvey\b/i.test(p.prompt), `${p.label} was told about the survey`)
  // Match the timer *data*, not the word: the brief says "no timer list" in so
  // many words, and a check that cannot tell a denial from a handout is worse
  // than none.
  for (const timer of survey.timers) {
    if (!timer.at) continue
    check(!p.prompt.includes(timer.at), `${p.label} was handed timer ${timer.name}'s schedule`)
  }
  for (const noun of survey.printedNouns) {
    check(!p.prompt.includes(noun.noun), `${p.label} was handed the vocabulary answer key`)
  }
  // `CLAUDE.md` and the source are named in the preamble as things NOT to open.
  // The prohibition is the point, so match the instruction rather than the word.
  check(
    !/Read [^\n]*CLAUDE\.md/.test(p.prompt),
    `${p.label} was told to read CLAUDE.md`
  )
  // Its own region is its assignment and is meant to be there. Every OTHER
  // region is the map, and pasting the whole coverage plan is how a blind
  // explorer once got nine of Fulminate's ten rooms three lines above being
  // told it had no room list.
  //
  // The bound is the seat's chunk, not one. A list longer than the copy cap is
  // now split across the seats rather than truncated, so the last seat legally
  // holds two — what must never happen is a blind prompt holding the *whole*
  // plan, which is the leak this check exists for.
  const mine = regions.filter((r) => p.prompt.includes(r))
  for (const r of mine) seatedRegions.add(r)
  check(
    mine.length <= chunkCap,
    `${p.label} was handed ${mine.length} regions — more than its chunk of ${chunkCap}, and `
      + `for any list of two or more that is the whole coverage plan`
  )
  // Counting regions is not the same as reading one. A single region naming
  // three rooms passes the count and is still the map, which is how this file's
  // own fixture handed a blind explorer eight of Fulminate's ten rooms for as
  // long as the count was the only test. The roster is the answer key the
  // explorer exists to reconstruct, so no room name belongs in its prompt at
  // all — not in a region, not in a routed issue's `owns` text, not anywhere.
  // Say "the floor above" and "outside the house"; the game's own opening prints
  // the exits, so an affordance leaks nothing an hour does not.
  //
  // This matches whole roster names, so it is a backstop and not the rule: an
  // operator who writes "Landing" and "Study" still passes it, because the
  // roster says "Upstairs Landing" and "Vane's Study". Matching the distinctive
  // word instead would false-positive on Room, Hall, Yard and Study, which are
  // ordinary English a brief has to be able to use. The rule stays "name no
  // room"; this catches the copy-paste version of breaking it.
  //
  // Both halves of a room row, since #287. The id is as much the answer key as
  // the name is — more, now that it is the key the whole round joins on — and a
  // brief that pasted `westOfHouse` would be handing over the roster in the one
  // spelling this file used not to look for.
  for (const room of survey.rooms) {
    for (const leak of [room.name, room.id]) {
      check(
        !p.prompt.includes(leak),
        `${p.label} was handed the room roster: "${leak}" appears in its prompt`
      )
    }
  }
  // A dedupe key is `<ownerFile>::<the game's own prose>`, so the ledger is a
  // room list, a source map and an excerpt file in one. Pasting it into a blind
  // prompt is the coverage-plan leak wearing a different hat, and it is worse:
  // the keys are supplied per round, so the size of the leak grows with the
  // ledger. Suppressing a rediscovery is done in plain code at `seen.has(key)`
  // and does not depend on the tester having been told anything.
  for (const key of dryLedgerKeys) {
    const [owner, prose] = key.split('::')
    check(!p.prompt.includes(owner), `${p.label} was handed the ledger's source map (${owner})`)
    check(!p.prompt.includes(prose), `${p.label} was handed a ledger excerpt: "${prose.slice(0, 48)}…"`)
  }
}

// **Every declared region reaches a seat.** The counterpart to the bound inside
// the loop, filled by the same `mine` it is computed from — asking "was this
// seat handed this region" twice, over long prompt strings, is how the two
// halves of one seating check drift apart.
//
// This is the assertion that would have caught the 2026-08-25 Dungeon round:
// with four regions and a copy cap of three, the old modulo seating ran 0, 1, 2
// and handed the fourth region to nobody without saying so. A region nobody was
// seated on reads afterwards exactly like a region nobody found anything in,
// which is why it is asserted and not logged.
//
// Stated at the altitude it is true at. With exactly one declared region the
// seating deliberately hands it to nobody — `copies > 1` — on the ground that a
// lone region IS the whole coverage plan and a blind explorer must not be given
// that. So the invariant is "every region reaches a seat once there is more
// than one", and asserting it unconditionally would be asserting a rule the
// harness does not hold.
if (regions.length > 1) {
  for (const r of regions) {
    check(seatedRegions.has(r), `no blind explorer was seated on region "${r.slice(0, 48)}…"`)
  }
}

// Sessions must write where the collator looks. `open` names the directory the
// server creates (`.context/playtest/<label>/<probe>/`) and the collator globs
// for it, and the two are in different files with no compiler between them.
// They drifted the moment testers moved off `bin/playtest-replay` onto the
// session server: `open` started passing a bare charter key while the glob went
// on expecting the game-prefixed replay label. Nothing downstream can tell an
// empty glob from a round where every tester crashed — the collator answers
// "0 sessions finished" to both, and the critic is told coverage is a floor.
const globToRe = (g) =>
  new RegExp(`^${g.split('*').map((s) => s.replace(/[.+?^${}()|[\]\\]/g, '\\$&')).join('[^/]*')}$`)

const openLabels = prompts
  .filter((p) => /^play:/.test(String(p.label || '')))
  .map((p) => (p.prompt.match(/Open with `label: "([^"]+)"`/) || [])[1])
check(
  openLabels.length > 0 && openLabels.every(Boolean),
  'could not read an `open` label out of every play prompt'
)

// The label globs, read out of the collator's own commands in both forms they
// can take: a bare shell glob under `.context/playtest/`, and `find -path` with
// the label between `*/` and the next path segment. The second is the current
// one — see the bare-glob check below for why the recipes moved. Requiring a
// segment *after* the label is what keeps `*/probe-*/transcript.txt` out of this
// list: that pattern names a probe, not a tester's label, and matching a label
// against it would be meaningless.
const extractGlobs = (text) => [
  ...new Set([
    ...[...text.matchAll(new RegExp(`${literal(LAYOUT.SCRATCH)}/([^/\\s"]*\\*[^/\\s"]*)/`, 'g'))].map((m) => m[1]),
    ...[...text.matchAll(/-path "\*\/([^/"]*\*[^/"]*)\/[^/"]*\//g)].map((m) => m[1]),
  ]),
]
const collator = prompts.find((p) => p.label === 'collator')
const collatorGlobs = collator ? extractGlobs(collator.prompt) : []
check(collatorGlobs.length > 0, 'the collator prompt names no .context/playtest glob')

// Session *accounting* is the narrow half, and the only recipes that do it are
// the ones that mention `closing.json`. A replay probe holds a `transcript.txt`
// and never a `closing.json`, because `bin/playtest-replay` does not write one —
// so a closing glob wide enough to catch the round's own replays reports 150-odd
// directories as testers who played and never accounted for it.
const closingGlobs = collator
  ? extractGlobs(collator.prompt.split('\n').filter((l) => l.includes('closing.json')).join('\n'))
  : []
check(closingGlobs.length > 0, 'no collator recipe globs for closing.json')
for (const label of openLabels.filter(Boolean)) {
  check(
    closingGlobs.some((g) => globToRe(g).test(label)),
    `sessions open under "${label}", which no closing-record glob matches (${closingGlobs.join(', ')})`
  )
}

// Every label the round hands `bin/playtest-replay`, read the way `openLabels`
// is read: off the command the prompt actually prints. Not just the testers' and
// the verifiers' — `replayHowTo` reaches `groundMin` too, so the survey, the
// cluster agent, the critic and the collator all carry one. Scanning every
// prompt rather than two label prefixes is the difference between guarding the
// mechanism and guarding the two trees already known to be broken.
//
// Each label is then in exactly one of two states, and both are asserted:
// *counted* by a `turn=cost` recipe with a glob in it, or one of the round's own,
// which the harness recipe counts by exclusion and so contributes no glob to
// match against. Until #288 the testers' and the verifiers' were in neither,
// which is not a state a reader can see — 32,987 typed commands reported as
// 11,238. These four are no longer uncounted either; they are the named fourth
// tree, and the harness recipe asserted below is what counts them.
const HARNESS_LABELS = ['preflight', 'survey', 'r1-cluster', 'critic', 'collator']
  .map((segment) => `Fulminate-${dryRoundId}-${segment}`)
const collatorLines = collator ? collator.prompt.split('\n') : []
const turnGlobs = extractGlobs(
  collatorLines.filter((l) => /-exec grep -h 'turn=cost'/.test(l)).join('\n')
)
const cliLabels = [
  ...new Set(
    prompts.map((p) => (p.prompt.match(/--label (\S+)/) || [])[1]).filter(Boolean)
  ),
]
check(cliLabels.length > 0, 'no prompt hands bin/playtest-replay a --label to count')
check(turnGlobs.length > 0, 'no collator recipe counts turn=cost under a label glob')
for (const label of cliLabels) {
  const counted = turnGlobs.some((g) => globToRe(g).test(label))
  check(
    counted || HARNESS_LABELS.includes(label),
    `"${label}" is replayed under, matched by no turn=cost glob (${turnGlobs.join(', ')}), and not one of the round's own labels the harness recipe sweeps up`
  )
  check(
    !closingGlobs.some((g) => globToRe(g).test(label)),
    `a closing-record glob matches "${label}", a replay label that never holds a closing.json`
  )
}

// Turns are counted, not asked — and the check is arithmetic rather than a
// keyword, because the failure it guards against is a number that *looks*
// counted. The 2026-08-17 round reported 295 turns, which was exactly the sum of
// six testers' self-reports against artifacts holding about 1,493; nothing in
// the round could tell the two apart, because both are integers in the same
// field. Here the collator's numbers are known, so the critic's prompt has to
// add up to them or the plumbing dropped a class of turn on the way.
//
// The branch total is the one most likely to be lost: it lives in
// `branch-NNN.txt` rather than in any transcript, and every earlier count in
// this harness's history missed it.
const promptFor = (match) =>
  (prompts.find((p) => (typeof match === 'function' ? match(p) : p.label === match)) || {}).prompt || ''
const criticPrompt = () => promptFor('critic')
const stubTesters =
  stubTurns.sessions + stubTurns.branches + stubTurns.playReplays + stubTurns.replays
const stubVerifiers = stubTurns.verifyReplays
const stubHarness = stubTurns.harnessReplays
const stubTotal = stubTesters + stubVerifiers + stubHarness
check(
  criticPrompt().includes(`**${stubTotal} world turns**`),
  'the critic was not given the counted turn total over all six turn counts'
)
// The split, which the total is invariant under. That is exactly why the
// `.replays/` misattribution survived three rounds: moving a term from one side
// to the other changes neither `total` nor any assertion written on it, and the
// only thing that reads differently is the ratio the critic is asked to judge.
// The 2026-08-24 round was reported at 3:1 verifier-to-tester against a real
// 1.2:1, and its header fired the "argued more than it played" warning on that.
//
// `replays` is the TESTERS': the `.replays/` tree is written by the MCP `replay`
// tool, which is granted to the play-phase agent and to nobody else. A verifier
// has no session and replays through `bin/playtest-replay` under its verify
// label, which is what `verifyReplays` counts.
check(
  criticPrompt().includes(`Testers spent ${stubTesters} of ~`),
  `the critic's tester turn total is not ${stubTesters} — the .replays/ tree is on the wrong side of the split`
)
check(
  criticPrompt().includes(`the verifiers spent ${stubVerifiers} across ${stubTurns.verifyProbes}`),
  `the critic's verifier turn total is not ${stubVerifiers} — a tree that is not theirs is being credited to them`
)

// The fork count is an upper bound and the critic has to be told so. The ledger
// flags a fork before the command is typed, from what the tester holds and what
// the game has said about the thing, so a row here can still turn out to be a
// free refusal — the 2026-08-25 Dungeon round reported "37 irreversible forks
// declined" when three of them committed to anything. The claim lives only in
// generated prose, so grepping it is the only place it can be pinned.
check(
  !/irreversible action the whole round declined/.test(criticPrompt()),
  'the critic is still told every untaken fork was an irreversible action'
)
check(
  /Forks no session took:[^\n]*\*\*Read it as an upper bound\.\*\*/.test(criticPrompt()),
  'the critic was not told the fork count is an upper bound'
)
check(
  result.coverage && result.coverage.turns
    && result.coverage.turns.testers === stubTesters
    && result.coverage.turns.verifiers === stubVerifiers,
  `coverage.turns splits testers/verifiers wrongly: ${JSON.stringify(result.coverage && result.coverage.turns)}`
)
// The fourth tree. Before it had a name, the round's own pre-dispatch errands —
// a route-prefix check, a random-rate measurement, the cartographer's own survey
// session — arrived as an unattributed residual and the critic was asked to
// resolve it from scratch, every round.
check(
  criticPrompt().includes(`machinery spent ${stubHarness} across ${stubTurns.harnessProbes}`),
  'the critic is not told what the round\'s own machinery spent, so it lands in the residual again'
)
check(
  result.coverage && result.coverage.turns && result.coverage.turns.harness === stubHarness,
  `coverage.turns has no named harness tree: ${JSON.stringify(result.coverage && result.coverage.turns)}`
)
// The residual against an unglobbed count of the whole scratch tree. It is the
// one number that cannot be short, and its whole job is to make the *next*
// uncounted tree loud instead of silent — so the fixture's `all` deliberately
// exceeds the sum, and the critic has to be told by how much.
check(
  criticPrompt().includes(`**${stubTurns.all - stubTotal} further \`turn=cost\` lines`),
  'the critic was not told about turns under labels no glob attributes'
)
check(
  criticPrompt().includes(`${stubTurns.branches} in branches`),
  'the critic\'s turn count drops the branch files, which hold turns that were really played'
)
check(
  criticPrompt().includes(`${stubTurns.replays} across ${stubTurns.replayProbes} probes`),
  'the critic was not told what the session server\'s replay tool spent'
)
// The two trees #288 found. They are the larger half of a round's replaying and
// were reported by nobody, so they get their own assertions rather than resting
// on the total above.
check(
  criticPrompt().includes(`${stubTurns.playReplays} across ${stubTurns.playProbes}`),
  'the critic\'s turn count drops the testers\' own bin/playtest-replay probes'
)
check(
  criticPrompt().includes(`${stubTurns.verifyReplays} across ${stubTurns.verifyProbes}`),
  'the critic\'s turn count drops the verifiers\' bin/playtest-replay probes'
)
check(
  collator ? /grep -h 'turn=cost'/.test(collator.prompt) : false,
  'the collator is not told to count turns off the [status] footers'
)
const replayRecipe = new RegExp(
  `-path "\\*/${literal(LAYOUT.REPLAY_TREE)}/${literal(LAYOUT.PROBE)}/${literal(LAYOUT.TRANSCRIPT)}" -exec grep -h 'turn=cost'`
)
check(
  collator ? replayRecipe.test(collator.prompt) : false,
  'the collator never reads the .replays/ probes, so a chunk of the testers\' replaying is invisible again'
)
// The round's own trees, counted by exclusion. An operator's ad-hoc label —
// `prefix-check`, `thief-rate` — cannot be enumerated in advance, so the recipe
// says what the tree is *not*: a probe transcript under none of the three label
// globs and not under `.replays/`. All four negations have to be there; dropping
// one double-counts a tree that already has its own row.
const harnessRecipe = collatorLines.find(
  (l) => /-exec grep -h 'turn=cost'/.test(l) && /! -path/.test(l)
)
check(
  Boolean(harnessRecipe),
  'no collator recipe counts the round\'s own pre-dispatch trees, so 8,000-odd turns land in the residual again'
)
// The round's own scope, which is a POSITIVE filter and not one of the rows. Once
// the three label globs carry the round's date, a previous round of the same game
// in the same checkout stops matching any of them — and a catch-all with no round
// in it would sweep all of last month's testers into a row labelled "this round's
// own machinery". So the harness recipe is scoped first and negated second, and the
// glob doing the scoping is exempt from the exclusion loop below: excluding it
// would exclude everything.
//
// Identified by the role it plays in the recipe — the glob that appears as a
// positive `-path` rather than behind a `!` — and not by what its characters look
// like. Sniffing the shape (`/^\w+-[\d-]+-\*$/`) made this assertion depend on the
// round id staying digits-and-dashes: give it a same-day suffix and the regex stops
// matching, `roundScope` goes undefined, and the loop below starts demanding the
// scope glob be excluded from itself.
const roundScope = turnGlobs.find(
  (g) => harnessRecipe && harnessRecipe.includes(`-path "*/${g}/`) && !harnessRecipe.includes(`! -path "*/${g}/`)
)
check(
  Boolean(roundScope) && harnessRecipe && harnessRecipe.includes(`-path "*/${roundScope}/`),
  'the harness turn recipe is not scoped to this round, so a previous round of the same '
  + 'game in this checkout is counted as this round\'s own machinery'
)
for (const excluded of [...new Set(turnGlobs), LAYOUT.REPLAY_TREE]) {
  if (excluded === roundScope) continue
  check(
    harnessRecipe ? harnessRecipe.includes(`! -path "*/${excluded}/`) : false,
    `the harness turn recipe does not exclude "${excluded}", so that tree is counted twice`
  )
}
// The unglobbed count that `unattributed` is measured against. Without it the
// residual is always zero and the check above passes on a harness that can no
// longer see a whole tree.
// "No glob" means no `-path`, which is now the whole of it: every other counting
// recipe discriminates with a pattern, including the `.replays` pair, which used
// to start inside its own subtree and had to be excluded by name.
check(
  collatorLines.some((l) => /-exec grep -h 'turn=cost'/.test(l) && !/-path/.test(l)),
  'no collator recipe counts turn=cost over the whole tree, so the residual is always zero'
)
// `find`, not a bare glob. An unmatched shell glob aborts the whole command under
// zsh, so a round whose testers all crashed would hand the collator a shell error
// where it needed a zero — and an agent asked for an integer will produce one
// anyway. This is the same class as the numbers being asked in the first place.
check(
  collator ? !/^\s*(grep|ls) [^\n]*\.context\/playtest/m.test(collator.prompt) : false,
  'the collator counts with a bare shell glob, which aborts under zsh when nothing matches'
)

// ---------------------------------------------------------------------------
// One artifact layout, held in step across the four languages that write it
// ---------------------------------------------------------------------------
//
// `playtest.js` holds the declaration (hoisted to `LAYOUT` at the top of these
// assertions); this is where it is checked against the shell, the Python and the
// Swift that actually create a probe directory. Nothing compiles those together,
// so reading their source is the only cross-check available — `SESSION_SEGMENT`'s
// treatment, applied to files instead of labels. `SKILL.md`'s "Measuring a change
// to the harness" tells the #299 story that made it necessary.
//
// Comment lines are stripped first. Every one of these files also *explains* the
// layout in prose, and two of them name the retired filename on purpose; a check
// that cannot tell a path from a paragraph would forbid a file from saying why a
// name changed.
const code = (path) =>
  readFileSync(path, 'utf8').split('\n').filter((l) => !/^\s*(#|\/\/|\*|\/\*)/.test(l)).join('\n')
const SOURCES = {
  replayScript: 'bin/playtest-replay',
  replayTool: 'Sources/Gnusto/Playtest/PlaytestReplay.swift',
  sessionServer: 'Sources/Gnusto/Playtest/PlaytestSession.swift',
  sessionDirectories: 'Sources/Gnusto/Playtest/PlaytestSessions.swift',
  measurer: 'bin/playtest-measure',
  tools: 'Sources/Gnusto/Playtest/PlaytestTools.swift',
  preflight: 'bin/playtest-preflight',
  fixerBrief: '.claude/skills/playtest/references/fixer-brief.md',
  findingContract: '.claude/skills/playtest/references/finding-contract.md',
  issueShape: '.claude/skills/playtest/references/issue-shape.md',
}
const SOURCE = Object.fromEntries(Object.entries(SOURCES).map(([k, path]) => [k, code(path)]))
const PRODUCERS = ['replayScript', 'replayTool', 'sessionServer']

// The evidence files, read OFF the consumer rather than written here, so this
// file holds no copy of the layout to drift on its own. Then: every producer
// writes every one of them, and *writes* rather than merely mentions — the name
// has to sit at the tail of a path being built, either after a `/` inside a
// quoted shell path or as the whole argument to `appendingPathComponent`. That
// is what tells a line of code from a line of documentation, and it is also what
// makes a rename fail here: `commands.effective.txt` does not end in
// `/commands.txt"`, so the one spelling of this bug that has actually shipped
// needs no special case of its own.
const artifacts = [
  ...new Set([...SOURCE.measurer.matchAll(/probe \/ "([^"]+)"/g)].map((m) => m[1])),
]
check(
  artifacts.length >= 2 && artifacts.includes(LAYOUT.TRANSCRIPT),
  `the layout cross-check reads ${JSON.stringify(artifacts)} out of ${SOURCES.measurer}; it should find at least ${LAYOUT.TRANSCRIPT} and a command list`
)
for (const key of PRODUCERS) {
  for (const artifact of artifacts) {
    check(
      new RegExp(`(?:/|\\(")${literal(artifact)}"`).test(SOURCE[key]),
      `${SOURCES[key]} builds no path ending in ${artifact}, which ${SOURCES.measurer} opens in every probe it is pointed at`
    )
  }
}

// The sessionless `replay` tool's tree, and the probe directory name. Both are
// the Swift side's to choose and the collator's to glob for. The zero padding
// lives here rather than in the declaration because the glob is all `playtest.js`
// needs to know; what the two minters share is the stem.
const replayLabel = (SOURCE.sessionDirectories.match(/replayLabel = "([^"]+)"/) || [])[1]
check(
  replayLabel === LAYOUT.REPLAY_TREE,
  `the session server writes sessionless replays under "${replayLabel}" and the collator globs "${LAYOUT.REPLAY_TREE}"`
)
// The save door, pinned across all three of its pieces. The brief telling a
// verifier to pass `--saves-from` is checked below, against the generated
// prompt; these check that the thing it names exists. Both harnesses grew the
// door at once and either could lose it alone — a CLI without the flag makes
// the instruction a lie, and a `replay` tool without `savesFrom` leaves the
// tester unable to verify its own `restore` reproducer before filing it.
check(
  SOURCE.replayScript.includes('--saves-from'),
  `${SOURCES.replayScript} has no --saves-from, so a verifier cannot replay a reproducer that begins \`restore\``
)
check(
  /"savesFrom"/.test(code(SOURCES.replayTool.replace('PlaytestReplay', 'PlaytestTools'))),
  'the replay tool takes no savesFrom argument, so a tester cannot re-verify its own restore reproducer'
)

// The tool table, which has three copies and just cost a round. `PlaytestTools.swift`
// declares the names, `bin/playtest-preflight` lists them so it can fail loudly on a
// server that declares fewer, and every tester prompt names the subset it will call.
// `rewind` and `export` were missing from the prompt list while the collator counted
// what `rewind` writes — 102 real turns in six branch files, uncounted — and adding
// them meant remembering the preflight copy separately. Nothing checked either.
//
// Two assertions, because they catch different mistakes. The first is a new tool the
// server declares and preflight does not know to demand; the second is a prompt that
// tells an agent to fetch a tool that does not exist, which fails at `ToolSearch` and
// looks exactly like an unreachable server.
const declaredTools = new Set(
  [...SOURCE.tools.matchAll(/PlaytestTool\(\s*\n\s*name: "([^"]+)"/g)].map((m) => m[1])
)
const expectedTools = new Set(
  ((SOURCE.preflight.match(/const EXPECTED_TOOLS = \[([\s\S]*?)\]/) || [])[1] || '')
    .split(',').map((t) => t.trim().replace(/^'|'$/g, '')).filter(Boolean)
)
check(
  declaredTools.size > 0 && expectedTools.size > 0
    && [...declaredTools].every((t) => expectedTools.has(t))
    && [...expectedTools].every((t) => declaredTools.has(t)),
  `${SOURCES.preflight}'s EXPECTED_TOOLS and ${SOURCES.tools}'s declarations disagree `
  + `(declared: ${[...declaredTools].sort().join(' ') || 'none parsed'}; expected: `
  + `${[...expectedTools].sort().join(' ') || 'none parsed'}) — preflight goes green on a server the round cannot drive`
)
const promptedTools = new Set(
  prompts.flatMap((p) => [...p.prompt.matchAll(/mcp__\w+__(\w+)/g)].map((m) => m[1]))
)
check(
  [...promptedTools].every((t) => declaredTools.has(t)),
  'a generated prompt names an MCP tool the server does not declare: '
  + `${[...promptedTools].filter((t) => !declaredTools.has(t)).join(', ')} — that agent fails at ToolSearch`
)

// `saves-in/` is the one probe artifact outside the `artifacts` cross-check
// above, because that list is derived from what `bin/playtest-measure` opens and
// the measurer never reads a save. It still has two independent minters, and a
// probe that kept only the *path* of a staged label stops reproducing the moment
// that label is cleaned — so the name gets its own check, in the shape of the
// replay-tree one below.
for (const key of ['replayScript', 'replayTool']) {
  check(
    new RegExp(`(?:/|\\(")${literal('saves-in')}`).test(SOURCE[key]),
    `${SOURCES[key]} builds no path ending in saves-in, so a staged probe keeps only the label's path and not its bytes`
  )
}

const probeStem = LAYOUT.PROBE.replace(/\*+$/, '')
for (const key of ['replayScript', 'sessionDirectories']) {
  check(
    SOURCE[key].includes(`${probeStem}%03d`),
    `${SOURCES[key]} names its probe directories something other than ${LAYOUT.PROBE}`
  )
}

// Every recipe starts where the round always creates. A pattern that matches
// nothing prints `0`; a start directory `find` cannot open prints its complaint
// on stderr and lets the pipe print `0` anyway, which is a shell error wearing
// the costume of a count. That is site 2 of #299, and it is a property of the
// generated text, so here is where it can be asserted.
const findStarts = [
  ...new Set(collatorLines.filter((l) => /^\s*find /.test(l)).map((l) => l.trim().split(/\s+/)[1])),
]
check(findStarts.length > 0, 'the collator prompt runs no find at all')
for (const start of findStarts) {
  check(
    start === LAYOUT.SCRATCH,
    `a collator recipe starts find at "${start}" rather than "${LAYOUT.SCRATCH}"; only the pattern may discriminate`
  )
}

// ---------------------------------------------------------------------------
// A check a rater cannot run is not a refutation
// ---------------------------------------------------------------------------
//
// The verifier brief tells every rater to check a claimed frame against the
// `[status]` footer. `bin/playtest-replay` has written one on every turn since
// #288, so an absent footer means a stale build — and without an instruction for
// that case the rater refutes, scoring the round's own plumbing as a defeated
// finding. Same read-a-zero-as-a-fact shape as the recipes above; different
// mechanism, so it gets its own heading.
const verifierPrompt = promptFor((p) => /^verify:/.test(String(p.label || '')))
check(
  /no .?\[status\].? line at all/.test(verifierPrompt) && /needs-human/.test(verifierPrompt),
  'the verifier brief says nothing about a transcript with no [status] footer, so a stale binary reads as a refutation'
)

// The save door, end to end: the brief tells the verifier to pass
// `--saves-from <the finding's Saves: label>`, and the finding block has to
// actually print a `Saves:` row for it to read. The two live ninety lines apart
// in `playtest.js` with nothing between them, and they were shipped apart once
// already — the instruction naming a field the listing did not emit. A
// reproducer that begins `restore` and cannot reach its slot is recorded
// `not-reproducible`, which is the harness scoring itself as a defeated
// finding; that cost four real defects on 2026-08-25.
check(
  /--saves-from/.test(verifierPrompt),
  'the verifier brief never mentions --saves-from, so a `restore` reproducer cannot be replayed'
)
check(
  /^ {2}Saves: +\S/m.test(verifierPrompt),
  'the finding block prints no `Saves:` row, so the --saves-from instruction names a field the verifier cannot see'
)
check(
  /never refute .?not-reproducible.? on it/.test(verifierPrompt),
  'the verifier is not told that a failed restore is a harness miss rather than a refutation'
)

// The rest of the door, which is every hop the label has to survive. Verify was
// wired first and alone, and that left three ways for a staged reproducer to die
// anyway: a tester with no field to declare one in, a report with nowhere to
// record it, and a fixer never told the flag exists. Each is the same defect as
// #332's — a `restore` that cannot reach its slot — moved one stage downstream,
// and each is invisible from the stage before it.
check(
  /savesFrom:\s*\{/.test(src),
  'the finding schema has no savesFrom field, so a tester with a `restore` reproducer can only file it as though it started clean'
)
const testerPrompt = promptFor((p) => /^play:/.test(String(p.label || '')))
check(
  /savesFrom/.test(testerPrompt),
  'the tester brief never names savesFrom, so a staged reproducer reaches the verifier looking like a clean one'
)
check(
  /--saves-from/.test(SOURCE.fixerBrief),
  `${SOURCES.fixerBrief} never mentions --saves-from, so a fixer replays a \`restore\` reproducer into the wrong game`
)
check(
  /saves-in/.test(SOURCE.fixerBrief),
  `${SOURCES.fixerBrief} does not name saves-in, and by the time a fixer runs the label the report named is usually cleaned`
)
check(
  /savesFrom/.test(SOURCE.findingContract),
  `${SOURCES.findingContract} does not carry savesFrom, so the contract still says every reproducer starts clean`
)
check(
  /saves-in/.test(SOURCE.issueShape),
  `${SOURCES.issueShape} does not require the save source beside a reproducer, so the provenance dies at the round boundary`
)
// Read off the answer rather than off the description: the reader who needs this
// is holding a bad verdict, not re-reading the schema that produced it.
check(
  /restore-unreachable/.test(SOURCE.tools),
  `${SOURCES.tools} never says restore-unreachable on a replay's answer, so an unstaged \`restore\` reads as a fact about the game`
)

// The critic gets the agreement figure and is told not to read a high one as
// good news on its own. That caution is the whole mitigation for batching.
const critic = prompts.find((p) => p.label === 'critic')
check(!!critic, 'the critic did not run')
if (critic) {
  check(/Verifier agreement/.test(critic.prompt), 'the critic was not given the agreement figure')
  check(/rubber-stamp/.test(critic.prompt), 'the critic was not warned about batched raters agreeing cheaply')
  check(/never called .finish./.test(critic.prompt), 'the critic was not told about unfinished sessions')
  check(/Forks no session took/.test(critic.prompt), 'the critic was not given the untaken forks')
  // The rubber-stamp warning is only a warning if the evidence is in the prompt.
  // It used to say "sample two or three `attemptedRefutation` fields from the
  // confirmed list", naming a field that reached the critic in no form at all —
  // so the one check the harness has against two raters agreeing cheaply was
  // asked to read something it had never been given.
  for (const t of raterTexts) {
    check(
      critic.prompt.includes(t),
      `the critic's prompt is missing a rater's own attempted refutation: "${t.slice(0, 48)}…"`
    )
  }
  check(
    /Paired refutation attempts/.test(critic.prompt),
    'the critic was not handed the paired refutation attempts'
  )
  // Sampled across the verdict lists, not down the first one. Two raters
  // rubber-stamping a refutation discard a real defect, and a round with far
  // more confirmed findings than refuted ones would fill the sample from
  // `confirmed` alone and never show the more expensive failure.
  const sampledVerdicts = [
    ...new Set(
      [...critic.prompt.matchAll(/^\*\*.*\*\* — both raters said (\S+)\.$/gm)].map((m) => m[1])
    ),
  ]
  check(
    sampledVerdicts.length >= 2,
    `the paired sample shows only one kind of verdict (${sampledVerdicts.join(', ') || 'none'}), so it was drawn down one list`
  )
  check(
    !/attemptedRefutation. fields from the confirmed list/.test(critic.prompt),
    'the critic is told to sample a field name again instead of reading the pairs it was given'
  )
  check(
    critic.prompt.includes('Timers declared: clock, lamp'),
    'the critic was not given the declared timer roster'
  )
  check(
    critic.prompt.includes('clock (4)'),
    'the critic was not told which timers actually fired, or how often'
  )
  // The negative is the whole point of the field: silence in the prose is not
  // evidence, so this sentence is the only place the round can say it.
  check(
    critic.prompt.includes('**Declared and never fired in any session: lamp.**'),
    'the critic was not told which declared timers nothing exercised'
  )
  // A fired name on no roster lands in BOTH lists at once — itself here, its
  // roster twin in `neverFired` — and read apart they are a dead timer invented
  // out of a mismatch. The critic has to be told to cross them.
  check(
    /1 fired name\(s\) match no declared timer \(ghost\)[\s\S]{0,400}before you believe the never-fired one/
      .test(critic.prompt),
    'a fired timer the roster does not hold was dropped, or not crossed against the never-fired list'
  )
}

// The fired-timer tally. `GameWorld.firedTimers` counted every body that ran and
// nothing downstream read it, so a round's only answer to "did that timer ever
// fire?" was to diff sentences across repeated `wait` output — which cannot see
// a timer whose body prints nothing. These assert the whole path: collator
// schema -> closing.json -> critic prompt.
check(
  collator ? /firedTimers/.test(collator.prompt) : false,
  'the collator is never told to read firedTimers out of the closing records'
)
// An empty tally is ambiguous — nothing fired, or every record predates the
// field — and the flattering reading of it is "every timer is dead". The guard
// cannot be exercised in the same run as the populated case, so the source
// carries it.
check(
  /No closing record carried a[^\n]*tally at all[\s\S]{0,400}Do NOT report an unexercised timer off this/.test(src),
  'the critic is not warned off reading an empty fired-timer tally as dead timers'
)
check(
  result.coverage && result.coverage.timers
    && JSON.stringify(result.coverage.timers.neverFired) === '["lamp"]',
  `coverage.timers.neverFired is not the unexercised roster: ${JSON.stringify(result.coverage && result.coverage.timers)}`
)

// The room key space. The 2026-08-18 Dungeon round published "119 of 195 rooms
// visited" from a numerator of display names and a denominator an agent had
// retyped out of `Sources/`. Neither half could be repaired on its own: names
// are not unique, so seventeen of that game's 143 rooms could not be counted at
// all whatever the two sides were matched with. These assert the whole path:
// the survey tool -> the roster -> the collator's ids -> the critic's line.
const surveyPrompt = promptFor((p) => /^survey:/.test(String(p.label || '')))
check(
  /select:[^\n]*mcp__fulminate__survey/.test(surveyPrompt),
  'the cartographer is no longer told to read the room and timer rosters off the survey tool'
)
check(
  /Copy[\s\S]{0,200}\bid\b[\s\S]{0,200}character for character/.test(surveyPrompt),
  'the cartographer is not told to copy the roster ids verbatim'
)
check(
  collator ? /every distinct .id. appearing in any/.test(collator.prompt) : false,
  'the collator is asked for room names again rather than room ids'
)
// The collision, end to end. `frontStair` was entered and `backStair` was not,
// and they share the display name "Stair" — so a round that had gone back to
// keying on the name would report neither or both.
// Both lists come off one line, so the split has to be on the sentence rather
// than on the newline: `frontStair` appears in the second of them, and a
// greedy `[^\n]*` would read it as belonging to the first and pass a harness
// that had gone back to keying on the display name.
const roomLists = (critic ? critic.prompt : '')
  .match(/Never entered[^:]*: ([^\n]*?)\. Entered but never worked: ([^\n]*?)\./)
const neverEntered = roomLists ? [roomLists[0], roomLists[1]] : null
check(
  /Stair \(backStair\)/.test(neverEntered ? neverEntered[1] : ''),
  "the critic's never-entered list cannot name one of two rooms that share a display name"
)
check(
  !/Stair \(frontStair\)/.test(neverEntered ? neverEntered[1] : ''),
  'a room a session stood in is listed as never entered — the join is not on the id'
)
// The denominator is every DECLARED room, not every statically reachable one.
// `boilerRoom` is on the survey's `unreachableRooms` and a session stood in it:
// scored against `survey.rooms` alone it was missing from the total AND reported
// as an id on no roster, which are contradictory complaints about one room. Both
// fractions are stated, because entered is not worked.
check(
  /- Rooms: \*\*4 of 13 entered, 2 of 13 worked\.\*\*/.test(critic ? critic.prompt : ''),
  'the room fraction is not the whole declared roster against the ids the sessions recorded, both ways'
)
check(
  /1 the engine reports as unreachable/.test(critic ? critic.prompt : ''),
  'the critic is not told how many of the roster are entered by a rule rather than through an exit'
)
check(
  !/on no roster \([^)]*boilerRoom/.test(critic ? critic.prompt : ''),
  'a rule-entered room is still being reported as an id on no roster'
)
// A room id on no roster is news now that both sides are the engine's and the
// roster holds every declared room, so the critic is told what it actually means
// rather than "the survey is short". `shipsHold` is nothing this game declares.
check(
  /1 room id\(s\) in the closing records are on no roster \(shipsHold\)/.test(critic ? critic.prompt : ''),
  'an off-roster room id was dropped instead of reported'
)
check(
  result.coverage && result.coverage.rooms
    && JSON.stringify(result.coverage.rooms.neverVisited).includes('Stair (backStair)')
    && result.coverage.rooms.total === 13
    && result.coverage.rooms.ruleEntered === 1
    && result.coverage.rooms.visited === 4
    && result.coverage.rooms.worked === 2,
  `coverage.rooms is not id-keyed over the whole declared roster: ${JSON.stringify(result.coverage && result.coverage.rooms)}`
)
// Entered is not worked, and the round now reports both. `cellar` and
// `frontStair` were stood in and never typed in — which is all a pasted
// `routes/*.txt` prefix ever does — so they are entered and unworked, and the
// critic has to be able to say so without reading a transcript first.
check(
  collator ? /every distinct .id. appearing in any .roomsWorked./.test(collator.prompt) : false,
  'the collator has no recipe for roomsWorked, so the round cannot tell entered from worked'
)
check(
  /Entered but never worked: [^\n]*Cellar \(cellar\)[^\n]*Stair \(frontStair\)/.test(critic ? critic.prompt : ''),
  'the critic is not told which rooms were entered and never worked'
)
check(
  result.coverage && result.coverage.rooms
    && !JSON.stringify(result.coverage.rooms.neverVisited).includes('(cellar)')
    && JSON.stringify(result.coverage.rooms.neverWorked).includes('Cellar (cellar)'),
  `coverage.rooms.neverWorked is not the stricter half: ${JSON.stringify(result.coverage && result.coverage.rooms)}`
)
// One join for both rosters. Rooms and timers ask the same question of two
// lists, and answering it twice is how the two halves of #287 drifted apart in
// the first place.
check(
  /function reconcile\(/.test(src) && !/function rosterMatch\(/.test(src),
  'rooms and timers have gone back to hand-rolling the same roster join twice'
)

// ---------------------------------------------------------------------------
// Getting the round started at all
// ---------------------------------------------------------------------------
//
// Everything above this line assumes a round that is running. These are about the
// step that kept failing before one: a round that dies at `ToolSearch` for every
// tester, because the game's MCP server never connected in the dispatching session.

// The round has an identity, and every label tree carries it. Without this a second
// round of the same game in the same checkout is globbed by the first one's recipes
// — which is not hypothetical: three rounds running reported coverage arithmetic
// with a previous round's sessions folded in.
for (const [name, globs] of [['session', closingGlobs], ['turn', turnGlobs]]) {
  const unscoped = globs.filter((g) => !g.includes(dryRoundId) && !g.startsWith('.'))
  check(
    unscoped.length === 0,
    `${name} glob(s) carry no roundId, so a previous round of this game is collated `
    + `into this one: ${unscoped.join(', ')}`
  )
}

const preflightPrompt = prompts.find((p) => String(p.label || '').startsWith('preflight'))

// A failed `ToolSearch` has somewhere to go. The tools are deferred, so a tester's
// first act is a search; when it returned nothing the prompt used to end there, and
// the agent improvised a report about not knowing how to use MCP. Eight of those is
// what a failed round looked like from the outside.
// The preflight agent is exempt: reporting the empty result IS its job, and it is
// given a schema field for it rather than a sentence. Every OTHER agent that
// searches has to be told, because for them an empty result is a dead end.
for (const p of prompts.filter((p) => /ToolSearch/.test(p.prompt))
  .filter((p) => !String(p.label || '').startsWith('preflight'))) {
  check(
    /returns nothing, \*\*stop and report that\*\*/.test(p.prompt),
    `"${p.label}" is told to fetch MCP tools with ToolSearch and given no branch for an empty result`
  )
  check(
    /playtest-preflight/.test(p.prompt),
    `"${p.label}" is not told what fixes an empty ToolSearch, so the failure reads as its own`
  )
}
check(
  preflightPrompt ? /toolsResolved: false/.test(preflightPrompt.prompt) : false,
  'the preflight agent is not told how to report a search that found nothing, which is the '
  + 'one answer it exists to give'
)

// The preflight agent runs before anything expensive, and is a phase of its own so
// the progress tree shows where a round died.
check(Boolean(preflightPrompt), 'nothing checks the MCP server before the round fans out')
check(
  preflightPrompt ? prompts.indexOf(preflightPrompt) === 0 : false,
  'the preflight check is not the first agent, so something expensive runs before the round knows it can play'
)
check(
  metaPhases.includes('Preflight') && phases.includes('Preflight'),
  'Preflight is not both declared in meta.phases and entered with phase(), so its agent '
  + 'lands in an unnamed progress group and a round that died there does not say where'
)

// A tool the harness MEASURES is a tool the prompt has to hand over. `rewind`
// writes the `branch-*.txt` files the collator counts as a named turn row, and was
// missing from the query for as long as that row existed.
const playPrompt = prompts.find((p) => String(p.label || '').startsWith('play:'))
for (const tool of ['rewind', 'replay', 'coverage', 'note']) {
  check(
    playPrompt ? playPrompt.prompt.includes(`__${tool}`) : false,
    `testers are never handed the \`${tool}\` tool, though the round is written as if they have it`
  )
}

// The tool namespace and the server registration are two halves of one fact that
// nothing compiles together. Get them out of step and every tester fails
// identically, with `ToolSearch` matching nothing and no diagnostic anywhere.
{
  const mcp = JSON.parse(readFileSync('.mcp.json', 'utf8'))
  const settings = JSON.parse(readFileSync('.claude/settings.json', 'utf8'))
  for (const key of settings.enabledMcpjsonServers || []) {
    check(
      Boolean((mcp.mcpServers || {})[key]),
      `.claude/settings.json enables the MCP server "${key}", which .mcp.json does not register`
    )
  }
  for (const [key, server] of Object.entries(mcp.mcpServers || {})) {
    check(
      (settings.enabledMcpjsonServers || []).includes(key),
      `.mcp.json registers "${key}" but .claude/settings.json does not enable it, so it never connects`
    )
    check(
      (server.args || []).some((a) => a.toLowerCase() === key),
      `.mcp.json keys "${key}" against args ${JSON.stringify(server.args)} — the workflow's `
      + 'fallback namespace is the lowercased product name, so this game resolves no tools'
    )
  }
  // Both remedies the round reports found the expensive way, set where a session
  // reads them rather than remembered by an operator.
  for (const v of ['MCP_TIMEOUT', 'CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS']) {
    check(
      Boolean(settings.env && settings.env[v] !== undefined),
      `.claude/settings.json sets no ${v}, so a round depends on whoever dispatched it remembering to`
    )
  }
}

// And the other half of the preflight phase: when the tools do NOT resolve, the
// round stops instead of fanning out. Re-run the whole script with a stub that says
// no, and check that nothing past the first agent ever ran.
{
  const noPrompts = []
  const noStub = async (prompt, opts = {}) => {
    noPrompts.push(opts.label)
    if (String(opts.label || '').startsWith('preflight')) {
      return { toolsResolved: false, toolNames: [], note: 'ToolSearch returned nothing' }
    }
    throw new Error(`agent "${opts.label}" ran after preflight failed`)
  }
  const noLogs = []
  const fn2 = new Function('__stub', '__phases', '__logs', '__args', body)
  const outcome = await fn2(noStub, [], noLogs, dryArgs)
  check(
    noPrompts.length === 1,
    `preflight failed and the round dispatched anyway: ${noPrompts.join(', ')}`
  )
  check(
    outcome && outcome.dispatched === false && outcome.reason === 'mcp-unreachable',
    `a round that cannot reach its server does not say so in its result: ${JSON.stringify(outcome)}`
  )
  check(
    noLogs.some((l) => /playtest-preflight/.test(l)) && noLogs.some((l) => /restart the session/.test(l)),
    'a round that cannot reach its server does not log the remedy, so the operator gets a mystery'
  )
}

console.log('\nASSERTIONS:', failures.length ? `${failures.length} FAILED` : 'all passed')
for (const f of failures) console.log('   ✗', f)
if (failures.length) process.exitCode = 1

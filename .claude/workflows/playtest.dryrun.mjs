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
  rooms: ['Front Hall','Parlour','Kitchen','Cellar','Upstairs Landing','Boarder\'s Room',"Vane's Study",'Back Yard','Carriage House','Orange Grove Avenue'],
  timers: [{ label: 'clock', kind: 'alarm', at: '20:15', readsPlayerLocation: true }],
  stateAxes: ['hour'], tiers: ['source','doc'],
  printedNouns: [{ noun: 'grout', answerable: false, printedIn: 'Front Hall' }],
  reskinnedTextKeys: ['cantTakeActor'], reskinnedStubs: [], properNamedActors: ['Mrs. Vane','Dr. Pike'],
}
const findings = (charter) => ({
  charter,
  findings: charter.startsWith('explorer')
    ? [{ claim: 'listing line is location-blind', category: 'prose-untrue-of-frame', severity: 'major',
         excerpt: 'Mrs. Vane is here, watching the fire.', frame: { room: 'Cellar', state: 'after 20:15' },
         reproducer: ['down','z'], fault: 'presence line ignores room', ownerFile: 'Sources/Fulminate/Cast.swift',
         replayedCleanly: true, transcriptPath: '/tmp/t.txt' }]
    : [],
  coverage: { honestSummary: 'walked it', cellsSkipped: [], turnsSpent: 40 },
})

const stub = async (prompt, opts = {}) => {
  prompts.push({ label: opts.label, phase: opts.phase, prompt })
  const l = String(opts.label || '')
  if (l.startsWith('survey')) return survey
  if (l.startsWith('play:')) return findings(l.slice(5))
  if (l.startsWith('cluster')) return { assignments: [{ index: 1, declaration: 'Sources/Fulminate/Prose.swift::vaneHere' }] }
  // One verdict per finding the prompt actually numbered, so the stub stays
  // honest about batch size rather than assuming one: a reconciliation that
  // silently drops findings would otherwise dry-run green.
  if (l.startsWith('verify')) {
    const count = (prompt.match(/^\[\d+\] found by the /gm) || []).length
    return {
      verdicts: Array.from({ length: count }, (_, i) => ({
        index: i + 1,
        verdict: 'confirmed-defect',
        reason: 'true',
        attemptedRefutation: 'the doc might license it; it does not',
      })),
    }
  }
  if (l === 'collator') {
    return {
      rooms: ['Front Hall', 'Cellar'],
      words: [{ word: 'grout', count: 2 }],
      forksNobodyTook: ['fork:burn-the-letter@Parlour'],
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
const dryArgs = {
  game: 'Fulminate', packagePath: '.', docPath: 'docs/games/fulminate.md',
  capabilities: ['clock','talk'], seed: 0, turns: 60,
  focus: 'ground floor: Front Hall, Parlour, Kitchen | upstairs: Landing, Boarder\'s Room, Study | outside: Back Yard, Carriage House',
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
writeFileSync('/tmp/prompts.txt', prompts.map(p => `===== ${p.label} =====\n${p.prompt}`).join('\n\n'))

// ---------------------------------------------------------------------------
// Assertions. Everything above is a smoke run; these are the properties that
// have actually broken and would otherwise cost a full round to notice.
// ---------------------------------------------------------------------------

const failures = []
const check = (ok, what) => { if (!ok) failures.push(what) }
const labels = prompts.map((p) => String(p.label || ''))
const promptText = prompts.map((p) => p.prompt).join('\n')

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

// The censuses are gone and the collator replaced them. A reintroduced census
// would mean the round is grepping prose for numbers the server already wrote.
check(!labels.includes('census'), 'the unknown-word census agent is back')
check(!labels.includes('room-census'), 'the room census agent is back')
check(labels.includes('collator'), 'the closing-record collator did not run')
check(!/CENSUS_SCHEMA/.test(src), 'CENSUS_SCHEMA is still declared')
check(!/rosterMatch\(name\)[\s\S]{0,400}wordSubset/.test(src), 'the fuzzy word-subset room matcher is back')

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
for (const p of blind) {
  check(!p.prompt.includes('docs/games/'), `${p.label} was handed the design doc path`)
  check(!p.prompt.includes('playtester-brief'), `${p.label} was handed the judgement kernel`)
  check(!/\bsurvey\b/i.test(p.prompt), `${p.label} was told about the survey`)
  // Match the timer *data*, not the word: the brief says "no timer list" in so
  // many words, and a check that cannot tell a denial from a handout is worse
  // than none.
  for (const timer of survey.timers) {
    check(!p.prompt.includes(timer.at), `${p.label} was handed timer ${timer.label}'s schedule`)
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
  const mine = regions.filter((r) => p.prompt.includes(r))
  check(mine.length <= 1, `${p.label} was handed ${mine.length} regions, not just its own`)
}

// The critic gets the agreement figure and is told not to read a high one as
// good news on its own. That caution is the whole mitigation for batching.
const critic = prompts.find((p) => p.label === 'critic')
check(!!critic, 'the critic did not run')
if (critic) {
  check(/Verifier agreement/.test(critic.prompt), 'the critic was not given the agreement figure')
  check(/rubber-stamp/.test(critic.prompt), 'the critic was not warned about batched raters agreeing cheaply')
  check(/never called .finish./.test(critic.prompt), 'the critic was not told about unfinished sessions')
  check(/Forks no session took/.test(critic.prompt), 'the critic was not given the untaken forks')
}

console.log('\nASSERTIONS:', failures.length ? `${failures.length} FAILED` : 'all passed')
for (const f of failures) console.log('   ✗', f)
if (failures.length) process.exitCode = 1

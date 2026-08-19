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
// discovered the two CLI trees were invisible. `all` deliberately exceeds the
// eight globbed numbers, so the residual path is the one under test.
const stubTurns = {
  sessions: 252, branches: 102, replays: 1139, replayProbes: 71,
  playReplays: 7646, playProbes: 39, verifyReplays: 25341, verifyProbes: 119,
  all: 34_600,
}

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
const dryArgs = {
  game: 'Fulminate', packagePath: '.', docPath: 'docs/games/fulminate.md',
  capabilities: ['clock','talk'], seed: 0, turns: 60,
  // Deliberately written in affordances rather than room names, because a region
  // is pasted verbatim into a blind explorer's prompt. This fixture used to read
  // "ground floor: Front Hall, Parlour, Kitchen | upstairs: Landing, Boarder's
  // Room, Study | outside: Back Yard, Carriage House" and passed, because the
  // only region assertion counted regions and never read one — so the harness's
  // own worked example handed a blind charter eight of Fulminate's ten rooms.
  // Space is expressible without the roster: the game's opening paragraph itself
  // says "the stairs go up", so "the floor above" leaks nothing the player has
  // not already been shown, exactly as an hour leaks nothing the watch does not.
  focus:
    'the first hour, 5:30 to 6:20, on the floor you start on and outside the house'
    + ' | the last half hour, 6:20 to 6:50, on the floor you start on and outside'
    + ' | the whole evening on the floor above: the opening tells you the stairs go'
    + ' up, so go up early and stay up, waiting rather than coming down',
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
  for (const room of survey.rooms) {
    check(
      !p.prompt.includes(room),
      `${p.label} was handed the room roster: "${room}" appears in its prompt`
    )
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
    ...[...text.matchAll(/\.context\/playtest\/([^/\s"]*\*[^/\s"]*)\//g)].map((m) => m[1]),
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
// *counted* by a `turn=cost` recipe, or listed in UNCOUNTED. Until #288 the
// testers' and the verifiers' were in neither, which is not a state a reader can
// see — 32,987 typed commands reported as 11,238.
const UNCOUNTED = ['Fulminate-survey', 'Fulminate-r1-cluster', 'Fulminate-critic', 'Fulminate-collator']
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
    counted || UNCOUNTED.includes(label),
    `"${label}" is replayed under, counted by no turn=cost recipe (${turnGlobs.join(', ')}), and not declared uncounted`
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
const criticPrompt = () => (prompts.find((p) => p.label === 'critic') || {}).prompt || ''
const stubTotal =
  stubTurns.sessions + stubTurns.branches + stubTurns.playReplays
  + stubTurns.replays + stubTurns.verifyReplays
check(
  criticPrompt().includes(`**${stubTotal} world turns**`),
  'the critic was not given the counted turn total over all five turn counts'
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
check(
  collator ? /find \.context\/playtest\/\.replays .*-exec grep -h 'turn=cost'/.test(collator.prompt) : false,
  'the collator never reads the replay probes, so verifier turns are invisible again'
)
// The unglobbed count that `unattributed` is measured against. Without it the
// residual is always zero and the check above passes on a harness that can no
// longer see a whole tree.
// "No glob" means no `-path` and no hand-picked subtree: `.replays`' recipe is
// also glob-free by `extractGlobs`' reckoning, and matching on that would let
// this pass on a prompt with no residual recipe in it at all.
check(
  collatorLines.some(
    (l) => /-exec grep -h 'turn=cost'/.test(l) && !/-path|\.replays/.test(l)
  ),
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

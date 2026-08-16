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
  coverage: { honestSummary: 'walked it', cellsSkipped: [], roomsVisited: ['Front Hall'], turnsSpent: 40 },
  unknownWords: [{ word: 'grout', count: 2, gamePrintedIt: true }],
})

const stub = async (prompt, opts = {}) => {
  prompts.push({ label: opts.label, phase: opts.phase, prompt })
  const l = String(opts.label || '')
  if (l.startsWith('survey')) return survey
  if (l.startsWith('play:')) return findings(l.slice(5))
  if (l.startsWith('cluster')) return { assignments: [{ index: 1, declaration: 'Sources/Fulminate/Prose.swift::vaneHere' }] }
  if (l.startsWith('verify')) return { verdict: 'confirmed-defect', reason: 'true', attemptedRefutation: 'the doc might license it; it does not' }
  if (l === 'census') return { words: [{ word: 'grout', count: 2 }], totalOccurrences: 2, note: '' }
  if (l === 'room-census') return { headings: [{ room: 'Front Hall', count: 3 }], note: '' }
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
const fn = new Function('__stub','__phases','__logs','__args', body)
const result = await fn(stub, phases, logs, {
  game: 'Fulminate', packagePath: '.', docPath: 'docs/games/fulminate.md',
  capabilities: ['clock','talk'], seed: 0, turns: 60,
  focus: 'ground floor: Front Hall, Parlour, Kitchen | upstairs: Landing, Boarder\'s Room, Study | outside: Back Yard, Carriage House',
})

console.log('PHASES   :', phases.join(' -> '))
console.log('AGENTS   :', prompts.length)
for (const p of prompts) console.log('  ', String(p.phase).padEnd(8), p.label)
console.log('\nLOGS:'); for (const l of logs) console.log('  ', l)
console.log('\nRESULT KEYS:', Object.keys(result).join(', '))
console.log('CHARTERS RUN:', JSON.stringify(result.charters.run, null, 1))
console.log('CONFIRMED:', result.confirmed.length, '| key:', result.confirmed[0] && result.confirmed[0].key)
writeFileSync('/tmp/prompts.txt', prompts.map(p => `===== ${p.label} =====\n${p.prompt}`).join('\n\n'))

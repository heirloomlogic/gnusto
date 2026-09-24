import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const repo = fileURLToPath(new URL('../..', import.meta.url))

// Issue #627: a flag that takes a value, typed last with no value after it.
// bin/playtest-replay parsed each one as `var="${2:-}"; shift 2` under `set -e`,
// so the failing `shift 2` ended the script with status 1 and printed nothing.
// bin/playtest-routes read the same mistake as an empty value, and for
// `--derived-from` and `--type-name` an empty value is the same as no flag, so
// the run went ahead as if the flag had not been typed. Each script now refuses
// a missing or empty value with status 2 and a line naming the flag, before it
// builds or spawns anything, which is why these run straight against the
// checkout.
function run(script, args) {
  return spawnSync(path.join(repo, 'bin', script), args, {
    cwd: repo, encoding: 'utf8', timeout: 10_000,
  })
}

function expectRefusal(result, script, flag) {
  assert.ifError(result.error)
  assert.equal(result.status, 2, result.stderr || result.stdout)
  assert.match(result.stderr, new RegExp(`^${script}: ${flag} needs a value$`, 'm'))
}

const REPLAY_FLAGS = [
  '--commands', '--seed', '--start', '--tail', '--label', '--probe', '--restore',
  '--save', '--saves-from', '--max-turns', '--timeout', '--package-path',
]
for (const flag of REPLAY_FLAGS) {
  test(`bin/playtest-replay refuses a trailing ${flag} by name`, () => {
    expectRefusal(run('playtest-replay', ['Zork1', flag]), 'playtest-replay', flag)
  })
  test(`bin/playtest-replay refuses an empty ${flag} by name`, () => {
    expectRefusal(run('playtest-replay', ['Zork1', flag, '']), 'playtest-replay', flag)
  })
}

const ROUTES_FLAGS = [
  '--from-commands', '--from-session', '--upto', '--budget', '--seed',
  '--derived-from', '--type-name',
]
for (const flag of ROUTES_FLAGS) {
  test(`bin/playtest-routes refuses a trailing ${flag} by name`, () => {
    expectRefusal(run('playtest-routes', ['Fulminate', 'cut', 'x', flag]), 'playtest-routes', flag)
  })
  test(`bin/playtest-routes refuses an empty ${flag}= by name`, () => {
    expectRefusal(run('playtest-routes', ['Fulminate', 'cut', 'x', `${flag}=`]), 'playtest-routes', flag)
  })
}

// The destination is never created: the flag is refused before it is read.
test('bin/new-game refuses a trailing --dep-path by name', () => {
  expectRefusal(run('new-game', ['Zwank', '/nonexistent/Zwank', '--dep-path']), 'new-game', '--dep-path')
})

// Not a value flag, but the same class of mistake: bin/gnusto-mcp passed its first
// argument straight to `swift build --product`, so a mistyped name started a build.
test('bin/gnusto-mcp refuses a malformed game name before building', () => {
  const result = run('gnusto-mcp', ['not a game'])
  assert.ifError(result.error)
  assert.equal(result.status, 2, result.stderr)
  assert.equal(result.stdout, '')
  assert.match(result.stderr, /^gnusto-mcp: bad game name 'not a game'$/m)
})

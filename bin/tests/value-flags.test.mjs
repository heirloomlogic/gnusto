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

// Catalog resolution rejects an unknown game before any Swift build begins.
test('bin/gnusto-mcp refuses an unknown game before building', () => {
  const result = run('gnusto-mcp', ['not a game'])
  assert.ifError(result.error)
  assert.equal(result.status, 2, result.stderr)
  assert.equal(result.stdout, '')
  assert.match(result.stderr, /Unknown game: not a game\. Available games:/)
})

for (const script of ['run-game', 'export-game']) {
  for (const args of [['Story', '--frontend'], ['Story', '--frontend', ''], ['Story', '--frontend=']]) {
    test(`bin/${script} refuses missing frontend value ${JSON.stringify(args)}`, () => {
      expectRefusal(run(script, args), script, '--frontend');
    });
  }
  for (const frontend of ['unknown']) {
    test(`bin/${script} refuses ${frontend} before package resolution or building`, () => {
      const result = spawnSync(path.join(repo, 'bin', script), ['Story', '--frontend', frontend], {env: {...process.env, GNUSTO_PACKAGE_PATH: '/nonexistent/package'}, encoding: 'utf8'});
      assert.equal(result.status, 2, result.stderr);
      assert.equal(result.stdout, '');
      assert.match(result.stderr, /unknown.*frontend/i);
    });
  }
}

test('bin/run-game refuses a missing Yonk checkout before package resolution or building', () => {
  const result = spawnSync(path.join(repo, 'bin/run-game'), ['Story', '--frontend', 'yonk'], {env: {...process.env, GNUSTO_PACKAGE_PATH: '/nonexistent/package', GNUSTO_YONK_PATH: ''}, encoding: 'utf8'});
  assert.equal(result.status, 2, result.stderr);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, process.platform === 'darwin' ? /GNUSTO_YONK_PATH/ : /requires macOS/);
});

test('bin/export-game refuses unavailable Yonk export', () => {
  const result = spawnSync(path.join(repo, 'bin/export-game'), ['Story', '--frontend', 'yonk'], {env: {...process.env, GNUSTO_PACKAGE_PATH: '/nonexistent/package'}, encoding: 'utf8'});
  assert.equal(result.status, 2, result.stderr);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /not available yet/);
});

import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const repo = fileURLToPath(new URL('../..', import.meta.url))

// Issue #448 item 5: "Treat -h/--help as success everywhere." An earlier pass
// (see PR #465) fixed only bin/playtest-preflight and left the other three
// scripts the issue named exiting 2 with an ordinary usage error — export-game
// even printed `error: unknown product '--help'`, mistaking the flag for a
// build target. bin/playtest-replay already handled it before this issue was
// filed, so it rides along here as the regression guard for the convention the
// others were brought into line with.
//
// No fixture package is spun up: every script answers -h/--help before it
// looks at cwd, builds anything or spawns swift, so this runs directly against
// the repo checkout and stays fast.
const SCRIPTS = ['export-game', 'new-game', 'playtest-preflight', 'playtest-routes', 'playtest-replay']

for (const script of SCRIPTS) {
  for (const flag of ['--help', '-h']) {
    test(`bin/${script} ${flag} exits 0 with usage on stdout`, () => {
      const result = spawnSync(`bin/${script}`, [flag], {
        cwd: repo, encoding: 'utf8', timeout: 10_000,
      })
      assert.ifError(result.error)
      assert.equal(result.status, 0, result.stderr || result.stdout)
      assert.ok(result.stdout.trim().length > 0, 'expected non-empty stdout')
      assert.ok(result.stdout.includes(script), result.stdout)
    })
  }
}

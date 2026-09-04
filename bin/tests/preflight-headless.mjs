// Exercise the real preflight and MCP handshake, substituting only the paid
// agent dispatch. Run against an already generated package, outside swift test.
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'

const [packagePath, game] = process.argv.slice(2)
assert.ok(packagePath && game, 'usage: node bin/tests/preflight-headless.mjs <package> <game>')
const root = realpathSync(packagePath)
const scratch = mkdtempSync(path.join(tmpdir(), 'gnusto-headless-'))
try {
  const receipt = path.join(scratch, 'dispatch.json')
  writeFileSync(path.join(scratch, 'claude'), `#!/usr/bin/env node
require('node:fs').writeFileSync(process.env.GNUSTO_TEST_RECEIPT, JSON.stringify({
  args: process.argv.slice(2), cwd: process.cwd(),
  timeout: process.env.MCP_TIMEOUT, wait: process.env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS,
}))
process.exit(7)
`, { mode: 0o755 })
  const result = spawnSync(path.join(root, 'bin/playtest-preflight'), [game, '--headless'], {
    cwd: root, encoding: 'utf8', timeout: 240_000,
    env: { ...process.env, PATH: `${scratch}:${process.env.PATH}`, GNUSTO_TEST_RECEIPT: receipt },
  })
  assert.ifError(result.error)
  assert.equal(result.status, 7, result.stdout + result.stderr)
  const dispatch = JSON.parse(readFileSync(receipt, 'utf8'))
  const args = JSON.parse(readFileSync(path.join(root, '.context/playtest-round-args.json'), 'utf8'))
  const settings = JSON.parse(readFileSync(path.join(root, '.claude/settings.json'), 'utf8'))
  assert.equal(dispatch.cwd, root)
  assert.deepEqual(dispatch.args, [
    '-p', 'Run the play-test round, and write the report it returns:'
      + ` Workflow({scriptPath: ${JSON.stringify(args.workflowPath)}, args: ${JSON.stringify(args)}})`,
  ])
  assert.equal(dispatch.timeout, settings.env.MCP_TIMEOUT)
  assert.equal(dispatch.wait, settings.env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS)
  console.log('Generated preflight passed; headless dispatch forwarded args, settings, package, and exit status.')
} finally {
  rmSync(scratch, { recursive: true, force: true })
}

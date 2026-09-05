// Exercise the real preflight and MCP handshake, substituting only the paid
// agent dispatch. Run against an already generated package, outside swift test.
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { checkHeadlessCLI, dispatchHeadless } from '../lib/playtest-headless.js'

const [packagePath, game] = process.argv.slice(2)
assert.ok(packagePath && game, 'usage: node bin/tests/preflight-headless.mjs <package> <game>')
const root = realpathSync(packagePath)
const scratch = mkdtempSync(path.join(tmpdir(), 'gnusto-headless-'))
try {
  const receipt = path.join(scratch, 'dispatch.json')
  writeFileSync(path.join(scratch, 'claude'), `#!/usr/bin/env node
if (process.argv[2] === '--help') {
  console.log('--allowedTools --disallowedTools --permission-mode dontAsk')
  process.exit(0)
}
require('node:fs').writeFileSync(process.env.GNUSTO_TEST_RECEIPT, JSON.stringify({
  args: process.argv.slice(2), cwd: process.cwd(),
  timeout: process.env.MCP_TIMEOUT, wait: process.env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS,
}))
process.exit(7)
`, { mode: 0o755 })
  // A reachable tracker must still become report-only when nobody can approve
  // filing. Stub only tracker detection; the round and MCP handshake stay real.
  writeFileSync(path.join(scratch, 'gh'), '#!/bin/sh\nexit 0\n', { mode: 0o755 })
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
  assert.equal(args.tracker, false, 'headless must persist report-only args even when gh finds a tracker')
  assert.ok(dispatch.args[dispatch.args.indexOf('-p') + 1].includes(`args: ${JSON.stringify(args)}`))
  assert.equal(dispatch.args[dispatch.args.indexOf('--permission-mode') + 1], 'dontAsk')
  assert.equal(dispatch.args[dispatch.args.indexOf('--disallowedTools') + 1], 'Bash(gh issue create:*)')
  const allowed = dispatch.args.slice(dispatch.args.indexOf('--allowedTools') + 1, dispatch.args.indexOf('--disallowedTools'))
  for (const tool of ['Workflow', `mcp__${args.mcpServer}`, 'Bash(bin/playtest-routes:*)', 'Write(/docs/games/*-playtest-*.md)']) assert.ok(allowed.includes(tool), tool)
  assert.equal(dispatch.timeout, settings.env.MCP_TIMEOUT)
  assert.equal(dispatch.wait, settings.env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS)
  assert.match(result.stderr, /Headless dispatch failed/)

  // Exercise success and a vanished CLI without rebuilding the same package.
  const options = { cwd: root, env: { ...process.env, PATH: `${scratch}:${process.env.PATH}`, GNUSTO_TEST_RECEIPT: receipt }, stdio: 'pipe' }
  writeFileSync(path.join(scratch, 'claude'), '#!/bin/sh\nexit 0\n', { mode: 0o755 })
  assert.equal(dispatchHeadless(args, options).status, 0)
  assert.match(checkHeadlessCLI(options), /Update claude/)
  rmSync(path.join(scratch, 'claude'))
  const missing = { ...options, env: { PATH: scratch } }
  assert.match(checkHeadlessCLI(missing), /claude.*PATH/)
  assert.equal(dispatchHeadless(args, missing).error.code, 'ENOENT')
  console.log('Generated preflight passed; headless dispatch is report-only, forwards args, permissions, settings and package, and preserves success, failure and missing-CLI diagnostics.')
} finally {
  rmSync(scratch, { recursive: true, force: true })
}

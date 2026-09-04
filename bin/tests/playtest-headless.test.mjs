import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'
import { checkHeadlessCLI, dispatchHeadless } from '../lib/playtest-headless.js'

function fixture(t, { help = '--allowedTools --disallowedTools --permission-mode dontAsk', exit = 0 } = {}) {
  const root = realpathSync(mkdtempSync(path.join(tmpdir(), 'gnusto-headless-cli-')))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  const receipt = path.join(root, 'dispatch.json')
  writeFileSync(path.join(root, 'claude'), `#!${process.execPath}
if (process.argv[2] === '--help') { console.log(${JSON.stringify(help)}); process.exit(0) }
require('node:fs').writeFileSync(process.env.RECEIPT, JSON.stringify({
  argv: process.argv.slice(2), cwd: process.cwd(), timeout: process.env.MCP_TIMEOUT,
  wait: process.env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS,
}))
process.exit(${exit})
`, { mode: 0o755 })
  return { cwd: root, env: { PATH: root, RECEIPT: receipt, MCP_TIMEOUT: '9876', CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS: '0' }, receipt }
}

test('dispatch allows the round tools without prompts and denies issue creation', (t) => {
  const f = fixture(t)
  assert.equal(checkHeadlessCLI(f), null)
  const args = { game: 'Zwank', mcpServer: 'zwank', workflowPath: '/engine with spaces/playtest.js', gameDocsDir: '', tracker: false, roundId: '2026-09-04' }
  const result = dispatchHeadless(args, { ...f, stdio: 'pipe' })
  assert.equal(result.status, 0)
  const dispatch = JSON.parse(readFileSync(f.receipt, 'utf8'))
  assert.equal(dispatch.cwd, f.cwd)
  assert.equal(dispatch.timeout, '9876')
  assert.equal(dispatch.wait, '0')
  const argv = dispatch.argv
  assert.equal(argv[argv.indexOf('--permission-mode') + 1], 'dontAsk')
  assert.equal(argv[argv.indexOf('--disallowedTools') + 1], 'Bash(gh issue create:*)')
  const allowed = argv.slice(argv.indexOf('--allowedTools') + 1, argv.indexOf('--disallowedTools'))
  for (const tool of ['Workflow', 'ToolSearch', 'Read', 'Glob', 'Grep', 'mcp__zwank', 'Bash(bin/playtest-replay:*)', 'Bash(bin/playtest-routes:*)', 'Bash(bin/playtest-measure:*)', 'Write(/.context/playtest/**)', 'Write(/*-playtest-*.md)']) {
    assert.ok(allowed.includes(tool), `missing ${tool}`)
  }
  for (const tool of ['Bash', 'Write', 'Edit', 'mcp__other', 'Bash(gh issue create:*)']) assert.ok(!allowed.includes(tool), tool)
  const prompt = argv[argv.indexOf('-p') + 1]
  assert.ok(prompt.includes(`args: ${JSON.stringify(args)}`))
  assert.match(prompt, /Workflow.*unavailable|unavailable.*Workflow/)
  assert.match(prompt, /Do not create GitHub issues/)
})

test('dispatch preserves a failing CLI exit status', (t) => {
  const f = fixture(t, { exit: 7 })
  assert.equal(dispatchHeadless({ mcpServer: 'zwank', tracker: false }, { ...f, stdio: 'pipe' }).status, 7)
})

test('missing executable and unsupported noninteractive permissions have actionable errors', (t) => {
  const f = fixture(t, { help: '--print' })
  assert.match(checkHeadlessCLI(f), /dontAsk.*update|update.*dontAsk/i)
  rmSync(path.join(f.cwd, 'claude'))
  assert.match(checkHeadlessCLI(f), /claude.*PATH|PATH.*claude/)
  const result = dispatchHeadless({ mcpServer: 'zwank', tracker: false }, { ...f, stdio: 'pipe' })
  assert.equal(result.error.code, 'ENOENT')
})

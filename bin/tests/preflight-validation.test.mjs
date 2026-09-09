// Exercises the three ways preflight used to stay green while broken (issue #448,
// items 1-3), against a minimal fixture package rather than a real game — nothing
// here needs a `swift build` or a live MCP handshake, so it runs in milliseconds.
//
// Each fixture fakes just enough to reach the row under test: `bin/playtest-replay`
// answers `--build` without compiling anything, `swift package describe` answers
// through a fake on PATH so `resolveGame` can find "Probe", and `bin/gnusto-mcp`
// exits immediately so `server.handshake()` fails fast instead of waiting out the
// real 240s timeout. None of that touches the row being asserted on: the `mcp key`
// row is computed right after the build step succeeds and before any of it runs.
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const repo = fileURLToPath(new URL('../..', import.meta.url))
const stripAnsi = (s) => s.replace(/\x1b\[[0-9]*m/g, '')

function fixture(t, { mcpCommand = 'bin/gnusto-mcp', projectEnabled = ['probe'], localEnabled = null } = {}) {
  const root = realpathSync(mkdtempSync(path.join(tmpdir(), 'gnusto-preflight-')))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  mkdirSync(path.join(root, 'bin'), { recursive: true })
  mkdirSync(path.join(root, '.claude'), { recursive: true })
  mkdirSync(path.join(root, 'fake-swift-bin'), { recursive: true })

  writeFileSync(path.join(root, 'bin/playtest-replay'), `#!/bin/sh
if [ "$1" = "--build" ]; then echo "$2"; exit 0; fi
exit 1
`, { mode: 0o755 })

  // Answers nothing; a live handshake is not what any of these three checks need.
  writeFileSync(path.join(root, 'bin/gnusto-mcp'), '#!/bin/sh\nexit 1\n', { mode: 0o755 })

  // `mcpCommand: null` means the entry has `args` but no `command` at all — the
  // shape that used to crash `resolveCommand` before any row was ever printed.
  const probeEntry = mcpCommand === null ? { args: ['Probe'] } : { command: mcpCommand, args: ['Probe'] }
  writeFileSync(path.join(root, '.mcp.json'), JSON.stringify({
    mcpServers: { probe: probeEntry },
  }))
  writeFileSync(path.join(root, '.claude/settings.json'), JSON.stringify({
    enabledMcpjsonServers: projectEnabled,
  }))
  if (localEnabled) {
    writeFileSync(path.join(root, '.claude/settings.local.json'), JSON.stringify({
      enabledMcpjsonServers: localEnabled,
    }))
  }

  writeFileSync(path.join(root, 'fake-swift-bin/swift'), `#!/bin/sh
case "$*" in
  'package describe --type json') printf '%s\\n' '{"products":[{"name":"Probe","type":{"executable":null}}]}' ;;
  *) exit 98 ;;
esac
`, { mode: 0o755 })

  function run(args) {
    return spawnSync(path.join(repo, 'bin/playtest-preflight'), args, {
      cwd: root, encoding: 'utf8', timeout: 20_000,
      env: {
        ...process.env,
        GNUSTO_PACKAGE_PATH: root,
        PATH: `${path.join(root, 'fake-swift-bin')}:${process.env.PATH}`,
      },
    })
  }
  return { root, run }
}

test('an unexecutable .mcp.json command reds the mcp key row instead of passing every row', (t) => {
  const f = fixture(t, { mcpCommand: 'bin/does-not-exist' })
  const result = f.run(['Probe'])
  const out = stripAnsi(result.stdout)
  assert.notEqual(result.status, 0, out)
  assert.match(out, /FAIL\s+Probe mcp key\s+probe — .*does-not-exist.* does not exist/)
})

test('a non-executable .mcp.json command is distinguished from a missing one', (t) => {
  const f = fixture(t, { mcpCommand: 'bin/playtest-replay-not-a-binary' })
  writeFileSync(path.join(f.root, 'bin/playtest-replay-not-a-binary'), 'not executable', { mode: 0o644 })
  const result = f.run(['Probe'])
  const out = stripAnsi(result.stdout)
  assert.notEqual(result.status, 0, out)
  assert.match(out, /FAIL\s+Probe mcp key\s+probe — .*is not executable/)
})

test('a healthy .mcp.json command still passes the mcp key row', (t) => {
  const f = fixture(t)
  const result = f.run(['Probe'])
  const out = stripAnsi(result.stdout)
  // stderr, not just stdout: preflight prints its rows only once every check has
  // run, so anything that throws mid-check leaves a header and nothing else — and
  // the reason is on the other stream. Asserting on stdout alone reported that as
  // "the row is missing", which is the one thing it never was.
  assert.match(out, /ok\s+Probe mcp key\s+probe\s*$/m, out + result.stderr)
})

test('a .mcp.json entry with args but no command reds the row instead of crashing', (t) => {
  const f = fixture(t, { mcpCommand: null })
  const result = f.run(['Probe'])
  const out = stripAnsi(result.stdout)
  assert.notEqual(result.status, 0, out + result.stderr)
  assert.doesNotMatch(result.stderr, /ERR_INVALID_ARG_TYPE/, result.stderr)
  assert.match(out, /FAIL\s+Probe mcp key\s+probe — missing "command"/)
})

test('the server row remedy names the command the .mcp.json entry actually spawned', (t) => {
  const f = fixture(t, { mcpCommand: 'bin/does-not-exist' })
  const result = f.run(['Probe'])
  const out = stripAnsi(result.stdout)
  assert.match(out, /FAIL\s+Probe server\s+.*\n\s*->\s+bin\/does-not-exist Probe\s/)
})

test('enabledMcpjsonServers merges .claude/settings.json and settings.local.json', (t) => {
  // Enabled only in the gitignored local file — the project file lists nothing.
  const f = fixture(t, { projectEnabled: [], localEnabled: ['probe'] })
  const result = f.run(['Probe'])
  const out = stripAnsi(result.stdout)
  assert.match(out, /ok\s+Probe mcp key\s+probe\s*$/m, out + result.stderr)
})

test('a key registered but enabled in neither settings file still reds the row', (t) => {
  const f = fixture(t, { projectEnabled: [], localEnabled: ['someone-else'] })
  const result = f.run(['Probe'])
  const out = stripAnsi(result.stdout)
  assert.match(out, /FAIL\s+Probe mcp key\s+probe — registered but not enabled/, out + result.stderr)
})

test('an unknown flag is rejected rather than silently dropped', (t) => {
  const result = spawnSync(path.join(repo, 'bin/playtest-preflight'), ['CloakOfDarkness', '--headles'], {
    cwd: repo, encoding: 'utf8', timeout: 20_000,
  })
  assert.equal(result.status, 2, result.stdout + result.stderr)
  assert.match(result.stderr, /unknown flag.*--headles/)
})

test('--headless keeps working after the flag check', (t) => {
  const okHeadless = spawnSync(path.join(repo, 'bin/playtest-preflight'), ['--headless'], {
    cwd: repo, encoding: 'utf8', timeout: 20_000,
  })
  // No game named and no --all: this is the pre-existing usage error, not the new
  // unknown-flag rejection — proving `--headless` itself was recognized.
  assert.equal(okHeadless.status, 2, okHeadless.stdout + okHeadless.stderr)
  assert.match(okHeadless.stderr, /usage: bin\/playtest-preflight/)
  assert.doesNotMatch(okHeadless.stderr, /unknown flag/)
})

test('--all keeps working after the flag check', (t) => {
  // Pairing --all with a bogus flag fails at the flag check itself, before any
  // game is resolved or built — cheap, and it still proves --all is on
  // KNOWN_FLAGS: the rejection names only --bogus, never --all.
  const okAll = spawnSync(path.join(repo, 'bin/playtest-preflight'), ['--all', '--bogus'], {
    cwd: repo, encoding: 'utf8', timeout: 20_000,
  })
  assert.equal(okAll.status, 2, okAll.stdout + okAll.stderr)
  assert.match(okAll.stderr, /unknown flag.*--bogus/)
  assert.doesNotMatch(okAll.stderr, /unknown flag.*--all/)
})

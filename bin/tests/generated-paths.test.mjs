import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { cpSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const repo = fileURLToPath(new URL('../..', import.meta.url))

function fixture(t) {
  const root = realpathSync(mkdtempSync(path.join(tmpdir(), 'gnusto-paths-')))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  const game = path.join(root, 'Game')
  const notes = path.join(game, 'notes')
  const fakeBin = path.join(root, 'fake-bin')
  mkdirSync(notes, { recursive: true })
  mkdirSync(fakeBin)
  cpSync(path.join(repo, 'bin/templates/bin'), path.join(game, 'bin'), { recursive: true })
  const env = { ...process.env, GNUSTO_REPO: repo, PATH: `${fakeBin}:${process.env.PATH}` }
  delete env.GNUSTO_PACKAGE_PATH
  delete env.GNUSTO_INVOCATION_DIR
  delete env.GNUSTO_MCP_BUILD
  function run(tool, args, shim = true) {
    const result = spawnSync(path.join(shim ? game : repo, 'bin', tool), args, {
      cwd: notes, env, encoding: 'utf8', timeout: 10_000,
    })
    assert.ifError(result.error)
    return result
  }
  return { game, fakeBin, run }
}

test('route input files keep the caller directory through a generated shim', (t) => {
  const f = fixture(t)
  writeFileSync(path.join(f.fakeBin, 'swift'), `#!/bin/sh
case "$*" in
  'package describe --type json') printf '%s\\n' '{"products":[{"name":"Probe","type":{"executable":null}}]}' ;;
  'build --product Probe') ;;
  'build --product Probe --show-bin-path') printf '%s/products\\n' "$PWD" ;;
  *) exit 98 ;;
esac
`, { mode: 0o755 })
  mkdirSync(path.join(f.game, 'products'))
  writeFileSync(path.join(f.game, 'products/Probe'), '#!/bin/sh\nexit 99\n', { mode: 0o755 })
  const probe = path.join(f.game, 'probe')
  mkdirSync(probe)
  writeFileSync(path.join(probe, 'commands.txt'), '')
  for (const input of ['../probe', probe]) {
    for (const [verb, flag, value] of [
      ['cut', '--from-commands', `${input}/commands.txt`],
      ['distill', '--from-session', input],
    ]) {
      const result = f.run('playtest-routes', ['Probe', verb, 'start', flag, value])
      assert.equal(result.status, 2, result.stderr)
      assert.match(result.stderr, /holds no commands/)
      assert.ok(result.stderr.includes(path.join(probe, 'commands.txt')), result.stderr)
    }
  }
})

test('measurement reads relative and absolute probe paths through the shim', (t) => {
  const f = fixture(t)
  const probe = path.join(f.game, 'probe')
  mkdirSync(probe)
  writeFileSync(path.join(probe, 'commands.txt'), 'look\nexamine lamp\n')
  writeFileSync(path.join(probe, 'transcript.txt'), '[status] room=Hall | moves=1 | turn=cost\n')
  for (const input of ['../probe', probe]) {
    const direct = f.run('playtest-measure', [input], false)
    const shim = f.run('playtest-measure', [input])
    assert.equal(direct.status, 0, direct.stderr)
    assert.equal(shim.status, 0, shim.stderr)
    assert.equal(shim.stdout, direct.stdout)
  }
})

test('export lists and builds the generated package from a subdirectory', (t) => {
  const f = fixture(t)
  const products = path.join(f.game, 'products')
  mkdirSync(products)
  writeFileSync(path.join(products, 'Probe'), '#!/bin/sh\necho playable\n', { mode: 0o755 })
  writeFileSync(path.join(f.fakeBin, 'swift'), `#!/bin/sh
printf '%s|%s\\n' "$PWD" "$*" >> "$GNUSTO_PACKAGE_PATH/swift.log"
case "$*" in
  'package describe') printf 'Name: Probe\\nType:\\n    Executable:\\n' ;;
  'build -c release --product Probe') ;;
  'build -c release --product Probe --show-bin-path') printf '%s/products\\n' "$PWD" ;;
  *) exit 98 ;;
esac
`, { mode: 0o755 })
  const listing = f.run('export-game', [])
  assert.equal(listing.status, 0, listing.stderr)
  assert.equal(listing.stdout, 'Probe\n')
  const exported = f.run('export-game', ['Probe'])
  assert.equal(exported.status, 0, exported.stderr)
  assert.equal(readFileSync(path.join(f.game, 'dist/Probe'), 'utf8'), '#!/bin/sh\necho playable\n')
  const calls = readFileSync(path.join(f.game, 'swift.log'), 'utf8').trim().split('\n')
  assert.equal(calls.length, 4)
  assert.ok(calls.every((line) => line.startsWith(`${f.game}|`)), calls.join('\n'))
  const refused = f.run('export-game', ['Unknown'])
  assert.equal(refused.status, 2)
  assert.match(refused.stdout, /unknown product/)
})

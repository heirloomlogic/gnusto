import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
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
  const engine = path.join(root, 'Engine')
  mkdirSync(notes, { recursive: true })
  mkdirSync(fakeBin)
  cpSync(path.join(repo, 'bin/templates/bin'), path.join(game, 'bin'), { recursive: true })
  mkdirSync(path.join(engine, 'Sources/Gnusto'), { recursive: true })
  mkdirSync(path.join(engine, 'bin/lib'), { recursive: true })
  for (const tool of ['gnusto-mcp', 'playtest-replay', 'playtest-routes', 'playtest-measure', 'run-game', 'export-game']) cpSync(path.join(repo, 'bin', tool), path.join(engine, 'bin', tool))
  cpSync(path.join(repo, 'bin/lib'), path.join(engine, 'bin/lib'), { recursive: true })
  writeFileSync(path.join(fakeBin, 'swift'), '#!/bin/sh\nexit 98\n', { mode: 0o755 })
  writeFileSync(path.join(game, 'gnusto-games.json'), JSON.stringify({ version: 1, package: 'AuthorPackage', games: [{ name: 'Probe', product: 'StoryLibrary', module: 'StoryModule', symbol: 'game' }] }))
  const products = path.join(game, '.build/gnusto/development/products')
  mkdirSync(products, { recursive: true })
  const binary = path.join(products, 'GnustoGeneratedLauncher')
  writeFileSync(binary, `#!/bin/sh
if [ "$1" = "--mcp" ]; then printf '%s\\n' '{"jsonrpc":"2.0","result":"author MCP"}'; exit 0; fi
if [ -n "$GNUSTO_TRANSCRIPT" ]; then cat > "$GNUSTO_TRANSCRIPT"; fi
echo "author-package:$GNUSTO_PACKAGE_PATH"
`, { mode: 0o755 })
  writeFileSync(path.join(engine, 'bin/build-game'), `#!/bin/sh
printf '%s|%s\\n' "$GNUSTO_PACKAGE_PATH" "$*" >> "$GNUSTO_PACKAGE_PATH/build.log"
printf '%s/.build/gnusto/development/products/GnustoGeneratedLauncher\\n' "$GNUSTO_PACKAGE_PATH"
`, { mode: 0o755 })
  writeFileSync(path.join(engine, 'bin/lib/game-build.mjs'), `import fs from 'node:fs'; import path from 'node:path';
export const findEngineRoot = () => ${JSON.stringify(engine)};
export const makeBuildSpec = spec => spec;
export async function buildGame(spec) { fs.appendFileSync(path.join(spec.packageRoot, 'build.log'), spec.packageRoot + '|' + spec.game.name + '|' + spec.mode + '\\n'); const binDirectory = path.join(spec.packageRoot, '.build/gnusto/development/products'); return {packageRoot: spec.packageRoot, binary: path.join(binDirectory, 'GnustoGeneratedLauncher'), binDirectory}; }
`)
  const env = { ...process.env, GNUSTO_REPO: engine, PATH: `${fakeBin}:${process.env.PATH}` }
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
  return { game, fakeBin, run, env, binary, engine, notes }
}

test('route input files keep the caller directory through a generated shim', (t) => {
  const f = fixture(t)
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

test('run and MCP use the generated author package binary through their shims', (t) => {
  const f = fixture(t)
  const run = f.run('run-game', ['Probe'])
  assert.equal(run.status, 0, run.stderr)
  assert.equal(run.stdout, `author-package:${f.game}\n`)
  const mcp = f.run('gnusto-mcp', ['Probe'])
  assert.equal(mcp.status, 0, mcp.stderr)
  assert.equal(mcp.stdout, '{"jsonrpc":"2.0","result":"author MCP"}\n')
  const forced = spawnSync(path.join(f.game, 'bin/gnusto-mcp'), ['Probe'], { cwd: f.notes, env: { ...f.env, GNUSTO_MCP_BUILD: '1' }, encoding: 'utf8' })
  assert.equal(forced.status, 0, forced.stderr)
  const calls = readFileSync(path.join(f.game, 'build.log'), 'utf8').trim().split('\n')
  assert.deepEqual(calls, [`${f.game}|Probe --frontend terminal --mode development`, `${f.game}|Probe --mode development`, `${f.game}|Probe --mode development --force`])
})

test('replay prints and validates an absolute author path while reading caller-relative commands', (t) => {
  const f = fixture(t)
  const built = f.run('playtest-replay', ['--build', 'Probe'])
  assert.equal(built.status, 0, built.stderr)
  assert.equal(built.stdout, `${f.binary}\n`)
  assert.equal(readFileSync(path.join(f.game, '.context/playtest/.bin/Probe.path'), 'utf8'), `${f.binary}\n`)
  // A foreign executable record is never trusted without the shared builder.
  writeFileSync(path.join(f.game, '.context/playtest/.bin/Probe.path'), '/bin/echo\n')
  writeFileSync(path.join(f.notes, 'commands.txt'), 'look\n')
  writeFileSync(path.join(f.game, 'commands.txt'), 'wrong-package-command\n')
  const result = f.run('playtest-replay', ['Probe', '--commands', 'commands.txt', '--label', 'caller', '--probe', 'receipt'])
  assert.equal(result.status, 0, result.stderr)
  const commands = readFileSync(path.join(f.game, '.context/playtest/caller/receipt/commands.txt'), 'utf8')
  assert.match(commands, /^look\n/)
  assert.doesNotMatch(commands, /wrong-package-command/)
  assert.equal(readFileSync(path.join(f.game, 'build.log'), 'utf8').trim().split('\n').length, 2)
  assert.equal(readFileSync(path.join(f.game, '.context/playtest/.bin/Probe.path'), 'utf8'), `${f.binary}\n`)
})

test('export lists and builds the generated package from a subdirectory', (t) => {
  const f = fixture(t)
  const listing = f.run('export-game', [])
  assert.equal(listing.status, 0, listing.stderr)
  assert.equal(listing.stdout, 'Probe\n')
  const exported = f.run('export-game', ['Probe'])
  assert.equal(exported.status, 0, exported.stderr)
  assert.equal(readFileSync(path.join(f.game, 'dist/Probe'), 'utf8'), readFileSync(f.binary, 'utf8'))
  assert.equal(readFileSync(path.join(f.game, 'build.log'), 'utf8'), `${f.game}|Probe|deployment\n`)
  const refused = f.run('export-game', ['Unknown'])
  assert.equal(refused.status, 2)
  assert.match(refused.stderr, /Unknown game: Unknown.*Probe/)
})


test('the internal build shim forwards its author root and mode arguments', (t) => {
  const f = fixture(t)
  const result = f.run('build-game', ['Probe', '--mode', 'development', '--force'])
  assert.equal(result.status, 0, result.stderr)
  assert.equal(result.stdout, `${f.binary}\n`)
  assert.equal(readFileSync(path.join(f.game, 'build.log'), 'utf8'), `${f.game}|Probe --mode development --force\n`)
})


test('MCP refuses path-bearing game words before writing its cache record', (t) => {
  const f = fixture(t)
  const result = f.run('gnusto-mcp', ['../Probe'])
  assert.equal(result.status, 2, result.stderr)
  assert.match(result.stderr, /bad game name/)
  assert.equal(existsSync(path.join(f.game, 'build.log')), false)
})

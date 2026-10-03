// Prepare real Linux exports for a separate recipient with no Swift toolchain.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath} from 'node:url';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {makeBuildSpec, buildGame, swiftStringLiteral} from '../lib/game-build.mjs';
import {stageTerminalExport} from '../lib/game-export.mjs';

const execute = promisify(execFile);
assert.equal(process.platform, 'linux', 'This acceptance fixture requires a native Linux build host');
assert.equal(process.argv.length, 3, 'Usage: node bin/tests/linux-recipient.mjs <artifact-directory>');
const output = path.resolve(process.argv[2]);
const engineRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const terminalRoot = process.env.GNUSTO_TERMINAL_PATH;
assert(terminalRoot, 'Set GNUSTO_TERMINAL_PATH to the reviewed companion');
const fixtureRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'gnusto-linux-recipient-'));
const environment = {...process.env};
delete environment.GNUSTO_MCP;
const evidence = {engineRevision: (await execute('git', ['rev-parse', 'HEAD'], {cwd: engineRoot})).stdout.trim(), terminalRevision: (await execute('git', ['rev-parse', 'HEAD'], {cwd: terminalRoot})).stdout.trim(), distributions: []};
try {
  await fs.mkdir(output, {recursive: true});
  const author = path.join(fixtureRoot, 'resource-story');
  await fs.cp(path.join(engineRoot, 'bin/tests/fixtures/game-build/resource-story'), author, {recursive: true});
  const manifest = await fs.readFile(path.join(author, 'Package.swift.in'), 'utf8');
  await fs.writeFile(path.join(author, 'Package.swift'), manifest.replace('ENGINE_DEPENDENCY', `.package(name: "Gnusto", path: ${swiftStringLiteral(engineRoot)}, traits: forwarded)`));
  for (const [packageRoot, game, name] of [[engineRoot, 'CloakOfDarkness', 'CloakOfDarkness'], [author, 'Story', 'ResourceStory']]) {
    const spec = makeBuildSpec({packageRoot, engineRoot, terminalRoot, game, mode: 'deployment'});
    assert.deepEqual(spec.defaultBuildFlags, ['--static-swift-stdlib', '-Xswiftc', '-static-stdlib']);
    const built = await buildGame(spec, {environment});
    const staged = await stageTerminalExport({...built, destination: path.join(fixtureRoot, 'exports', name)});
    const distribution = path.join(fixtureRoot, 'stage', name);
    await fs.mkdir(distribution, {recursive: true});
    if (staged.resources.length) {
      await fs.cp(path.dirname(await fs.realpath(staged.binary)), distribution, {recursive: true});
    } else await fs.copyFile(staged.binary, path.join(distribution, name));
    const binary = path.join(distribution, name);
    const [dynamic, program] = await Promise.all([
      execute('readelf', ['-dW', binary]), execute('readelf', ['-lW', binary]),
    ]);
    assert.doesNotMatch(dynamic.stdout, /Shared library: \[(?:libswift|libFoundation|libGnusto|libStory)/i);
    // stageTerminalExport validates every linked runtime; retain the raw loader graph.
    await fs.writeFile(path.join(output, `${name}.elf.txt`), dynamic.stdout + '\n' + program.stdout);
    const graph = await execute('swift', ['package', '--package-path', built.packageRoot, '--scratch-path', built.scratchPath, '--disable-default-traits', 'show-dependencies', '--format', 'json'], {env: {...environment, GNUSTO_ENGINE_PATH: spec.engineDependencyPath}, maxBuffer: 20 * 1024 * 1024});
    assert.doesNotMatch(graph.stderr, /Conflicting identity/);
    const nodes = new Map();
    const visit = node => {
      const previous = nodes.get(node.identity);
      if (previous) assert.equal(previous.path, node.path, 'Each dependency identity must resolve to one checkout');
      nodes.set(node.identity, node);
      for (const dependency of node.dependencies || []) visit(dependency);
    };
    visit(JSON.parse(graph.stdout));
    const engines = [...nodes.values()].filter(node => node.name === 'Gnusto');
    const terminals = [...nodes.values()].filter(node => node.name === 'GnustoTerminal');
    assert.equal(engines.length, 1);
    assert.equal(terminals.length, 1);
    assert.equal(await fs.realpath(engines[0].path), await fs.realpath(engineRoot));
    assert.equal(await fs.realpath(terminals[0].path), await fs.realpath(terminalRoot));
    assert.doesNotMatch(graph.stdout, /swift-docc|Persnicket/);
    await fs.writeFile(path.join(output, `${name}.dependencies.json`), graph.stdout);
    const resolved = path.join(built.packageRoot, 'Package.resolved');
    if (await fs.stat(resolved).then(() => true, () => false)) await fs.copyFile(resolved, path.join(output, `${name}.Package.resolved`));
    const archive = path.join(output, `${name}.tar.gz`);
    await execute('tar', ['czf', archive, '-C', distribution, '.']);
    evidence.distributions.push({game, name, archive: path.basename(archive), staticSwiftRuntimeRequested: true, resources: staged.resources.map(resource => path.basename(resource)), checks: ['production export loader validation', 'raw ELF dynamic/interpreter evidence', 'traits-off resolved dependency graph', 'complete archived distribution']});
  }
  assert.equal(evidence.distributions[1].resources.length, 1);
  await fs.writeFile(path.join(output, 'evidence.json'), JSON.stringify(evidence, null, 2) + '\n');
  await fs.writeFile(path.join(output, 'check.sh'), `#!/usr/bin/env bash
set -euo pipefail
if command -v swift >/dev/null || command -v node >/dev/null; then
  echo 'error: recipient contains a development toolchain' >&2
  exit 1
fi
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
for game in CloakOfDarkness ResourceStory; do
  mkdir -p "$scratch/$game" "$scratch/saves/$game"
  tar xzf "/recipient/$game.tar.gz" -C "$scratch/$game"
  binary="$scratch/$game/$game"
  test -x "$binary"
  cd "$scratch"
  printf 'look\\nquit\\ny\\n' | env -i PATH=/usr/bin:/bin HOME="$scratch" GNUSTO_PLAIN=1 GNUSTO_SEED=0 GNUSTO_SAVE_DIR="$scratch/saves/$game" "$binary" >"$scratch/$game.stdout" 2>"$scratch/$game.stderr"
  test ! -s "$scratch/$game.stderr"
  case "$game" in
    CloakOfDarkness) grep -q 'Cloak of Darkness' "$scratch/$game.stdout" ;;
    ResourceStory) grep -q 'BuildSourceOne ResourceOpeningOne' "$scratch/$game.stdout" ;;
  esac
  if env -i PATH=/usr/bin:/bin HOME="$scratch" GNUSTO_MCP=1 "$binary" </dev/null >"$scratch/$game.mcp.stdout" 2>"$scratch/$game.mcp.stderr"; then
    echo "error: deployed $game answered MCP" >&2
    exit 1
  fi
  test ! -s "$scratch/$game.mcp.stdout"
  grep -q 'built without' "$scratch/$game.mcp.stderr"
  printf '%s: toolchain-free relocated session and MCP refusal passed\\n' "$game"
done
`);
  console.log(JSON.stringify(evidence, null, 2));
} finally { await fs.rm(fixtureRoot, {recursive: true, force: true}); }

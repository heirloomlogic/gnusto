import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import path from 'node:path';
import {tmpdir} from 'node:os';
import {buildGame, makeBuildSpec, swiftStringLiteral} from '../lib/game-build.mjs';
import {loadGames} from '../lib/game-catalog.mjs';
const trait = 'traits: [.trait(name: "Playtest"), .default(enabledTraits: ["Playtest"])]';
function fixture(t, {url = false} = {}) {
  const root = fs.mkdtempSync(path.join(tmpdir(), 'gnusto-build-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const packageRoot = path.join(root, 'author-story');
  const engineRoot = path.join(root, 'engine space " $(touch sentinel)');
  const terminalRoot = path.join(root, 'terminal');
  for (const dir of [packageRoot, engineRoot, terminalRoot]) { fs.mkdirSync(path.join(dir, 'Sources'), {recursive: true}); fs.writeFileSync(path.join(dir, 'Sources', 'content.swift'), '// content'); }
  fs.writeFileSync(path.join(engineRoot, 'Package.swift'), `// swift-tools-version: 6.2\n${trait}`);
  fs.writeFileSync(path.join(terminalRoot, 'Package.swift'), `// swift-tools-version: 6.2\n${trait}`);
  fs.writeFileSync(path.join(packageRoot, 'Package.swift'), `// swift-tools-version: 6.2\n${trait}\n.package(name: "Gnusto", ${url ? 'url: "https://github.com/HeirloomLogic/Gnusto", branch: "main"' : `path: ${swiftStringLiteral(engineRoot)}`}, traits: forwarded)`);
  fs.writeFileSync(path.join(packageRoot, 'gnusto-games.json'), JSON.stringify({version: 1, package: 'Story', games: [{name: 'Story', product: 'StoryLibrary', module: 'Story', symbol: 'game'}]}));
  const swift = path.join(root, 'fake-swift');
  fs.writeFileSync(swift, `#!/usr/bin/env node\nimport fs from 'node:fs';\nimport path from 'node:path';\nconst a=process.argv.slice(2); fs.appendFileSync(process.env.LOG, JSON.stringify({args:a,engine:process.env.GNUSTO_ENGINE_PATH})+'\\n');\nif(a[0]==='--version'){console.log('Fake Swift 6.4');process.exit(0)}\nif(process.env.FAIL){process.exit(1)}\nconst scratch=a[a.indexOf('--scratch-path')+1]; const bin=path.join(scratch,'out','Products','Debug');\nif(a.includes('--show-bin-path')) console.log(bin);\nelse { await new Promise(r=>setTimeout(r,40)); fs.mkdirSync(bin,{recursive:true}); fs.writeFileSync(path.join(bin,a[a.indexOf('--product')+1]),'binary'); fs.chmodSync(path.join(bin,a[a.indexOf('--product')+1]),0o755); }\n`);
  fs.chmodSync(swift, 0o755);
  const environment = {...process.env, LOG: path.join(root, 'invocations'), GNUSTO_SWIFT_BUILD_FLAGS: '["--jobs","2"]'};
  const spec = makeBuildSpec({packageRoot, engineRoot, terminalRoot, game: loadGames(packageRoot).games[0], mode: 'development'});
  const log = () => fs.existsSync(environment.LOG) ? fs.readFileSync(environment.LOG, 'utf8').trim().split('\n').map(JSON.parse) : [];
  return {root, packageRoot, engineRoot, terminalRoot, swift, environment, spec, log};
}
test('manifest uses the product separately from the module and forwards conditional traits', t => {
  const f = fixture(t);
  assert.match(f.spec.manifest, /product\(name: "StoryLibrary", package: "Story"\)/);
  assert.match(f.spec.entryPoint, /TerminalLaunch.run\(Story.game\)/);
  assert.match(f.spec.manifest, /condition: .when\(traits: \["Playtest"\]\)/);
  assert.equal(f.spec.engineDependencyPath, f.engineRoot);
  assert.equal(f.spec.links.some(link => link.name === 'gnusto'), false);
  const url = fixture(t, {url: true});
  assert.match(url.spec.engineDependencyPath, /Dependencies\/gnusto$/);
  assert.match(url.spec.manifest, /package\(name: "Gnusto", path:/);
});
test('cache hits invoke no SwiftPM and simultaneous misses share one build', async t => {
  const f = fixture(t);
  const results = await Promise.all([buildGame(f.spec, f), buildGame(f.spec, f)]);
  assert.equal(results[0].binary, results[1].binary);
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 1);
  const count = f.log().length;
  assert.deepEqual(await buildGame(f.spec, f), results[0]);
  assert.equal(f.log().length, count);
  assert.equal(f.log().find(item => item.args.includes('--product')).engine, f.engineRoot);
  assert.equal(fs.existsSync(path.join(f.root, 'sentinel')), false);
  assert.equal(fs.existsSync('sentinel'), false);
  assert(f.log().find(item => item.args.includes('--product')).args.includes('--jobs'));
});
test('edits, deletions, catalog, frontend, flags and a missing executable invalidate cache', async t => {
  const f = fixture(t);
  let previous = await buildGame(f.spec, f);
  for (const mutate of [
    () => fs.writeFileSync(path.join(f.engineRoot, 'Sources/content.swift'), '// changed'),
    () => fs.unlinkSync(path.join(f.packageRoot, 'Sources/content.swift')),
    () => fs.appendFileSync(path.join(f.packageRoot, 'gnusto-games.json'), '\n'),
    () => fs.writeFileSync(path.join(f.terminalRoot, 'Sources/content.swift'), '// new frontend'),
    () => { f.environment.GNUSTO_SWIFT_BUILD_FLAGS = '["--jobs","3"]'; },
  ]) {
    mutate(); const next = await buildGame(f.spec, f); assert.notEqual(next.fingerprint, previous.fingerprint); previous = next;
  }
  fs.unlinkSync(previous.binary); await buildGame(f.spec, f);
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 7);
});
test('failed forced builds invalidate stale state and modes use distinct scratch directories', async t => {
  const f = fixture(t); await buildGame(f.spec, f);
  await assert.rejects(buildGame(f.spec, {...f, force: true, environment: {...f.environment, FAIL: '1'}}));
  const before = f.log().length; await buildGame(f.spec, f); assert(f.log().length > before);
  const deployed = makeBuildSpec({...f, game: loadGames(f.packageRoot).games[0], mode: 'deployment'});
  assert.notEqual(deployed.scratchPath, f.spec.scratchPath);
  await buildGame(deployed, f);
  assert(f.log().some(item => item.args.includes('--disable-default-traits')));
});
test('rejects identity collisions, missing trait support and invalid flags before invoking Swift', async t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.terminalRoot, 'Package.swift'), '// no trait');
  assert.throws(() => makeBuildSpec({...f, game: loadGames(f.packageRoot).games[0], mode: 'development'}), /GnustoTerminal.*Playtest/);
  await assert.rejects(buildGame(f.spec, {...f, environment: {...f.environment, GNUSTO_SWIFT_BUILD_FLAGS: '--jobs 2'}}), /JSON/);
  await assert.rejects(buildGame(f.spec, {...f, environment: {...f.environment, GNUSTO_SWIFT_BUILD_FLAGS: '["--scratch-path","bad"]'}}), /reserved/);
  assert.equal(f.log().length, 0);
  const collision = path.join(f.root, 'gnustoterminal'); fs.renameSync(f.packageRoot, collision);
  assert.throws(() => makeBuildSpec({...f, packageRoot: collision, game: loadGames(collision).games[0], mode: 'development'}), /identity.*collision/);
});

test('CLI prints one absolute binary path or JSON and rejects unknown games before Swift', async t => {
  const {spawnSync} = await import('node:child_process');
  const f = fixture(t);
  const cli = path.resolve('bin/build-game');
  const environment = {...f.environment, GNUSTO_PACKAGE_PATH: f.packageRoot, GNUSTO_REPO: f.engineRoot, GNUSTO_TERMINAL_PATH: f.terminalRoot, GNUSTO_SWIFT: f.swift};
  const unknown = spawnSync(cli, ['Nobody'], {env: environment, encoding: 'utf8'});
  assert.equal(unknown.status, 2); assert.equal(unknown.stdout, ''); assert.equal(f.log().length, 0);
  const built = spawnSync(cli, ['Story', '--json'], {env: environment, encoding: 'utf8'});
  assert.equal(built.status, 0, built.stderr); const result = JSON.parse(built.stdout); assert(path.isAbsolute(result.binary));
  const warmed = spawnSync(cli, ['Story'], {env: environment, encoding: 'utf8'});
  assert.equal(warmed.status, 0, warmed.stderr); assert.equal(warmed.stdout, result.binary + '\n');
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 1);
});

test('real path and URL author graphs share current Gnusto and resource-bearing source edits', {skip: process.env.GNUSTO_REAL_GRAPH !== '1', timeout: 1200000}, async t => {
  const {spawnSync} = await import('node:child_process');
  const engineRoot = fs.realpathSync(process.cwd());
  const terminalRoot = fs.realpathSync(process.env.GNUSTO_TERMINAL_PATH || '.context/companions/GnustoTerminal');
  const root = process.env.GNUSTO_GRAPH_ROOT || fs.mkdtempSync(path.join(tmpdir(), 'gnusto-real-graph-'));
  fs.mkdirSync(root, {recursive: true});
  const evidence = [];
  t.after(() => { if (!process.env.GNUSTO_GRAPH_KEEP) fs.rmSync(root, {recursive: true, force: true}); });
  for (const kind of ['path', 'url']) {
    const packageRoot = path.join(root, `author-${kind}`);
    fs.cpSync(path.resolve('bin/tests/fixtures/game-build/resource-story'), packageRoot, {recursive: true});
    const dependency = kind === 'path'
      ? `.package(name: "Gnusto", path: ${swiftStringLiteral(engineRoot)}, traits: forwarded)`
      : '.package(url: "https://github.com/HeirloomLogic/Gnusto", branch: "main", traits: forwarded)';
    fs.writeFileSync(path.join(packageRoot, 'Package.swift'), fs.readFileSync(path.join(packageRoot, 'Package.swift.in'), 'utf8').replace('ENGINE_DEPENDENCY', dependency));
    const spec = makeBuildSpec({packageRoot, engineRoot, terminalRoot, game: 'Story', mode: 'deployment'});
    const environment = {...process.env, GNUSTO_SWIFT_BUILD_FLAGS: process.env.GNUSTO_SWIFT_BUILD_FLAGS || '["--jobs","2"]'};
    let built = await buildGame(spec, {environment});
    const graph = spawnSync('swift', ['package', '--package-path', built.packageRoot, '--scratch-path', built.scratchPath, '--disable-default-traits', 'show-dependencies', '--format', 'json'], {encoding: 'utf8', env: {...environment, GNUSTO_ENGINE_PATH: spec.engineDependencyPath}, maxBuffer: 20 * 1024 * 1024});
    assert.equal(graph.status, 0, graph.stderr);
    const unique = new Map();
    const walk = node => {
      const previous = unique.get(node.identity);
      if (previous) assert.equal(fs.realpathSync(previous.path), fs.realpathSync(node.path), `Identity ${node.identity} must resolve to one checkout`);
      unique.set(node.identity, node); for (const dependency of node.dependencies || []) walk(dependency); };
    walk(JSON.parse(graph.stdout));
    const engines = [...unique.values()].filter(node => node.name === 'Gnusto');
    const terminals = [...unique.values()].filter(node => node.name === 'GnustoTerminal');
    assert.equal(engines.length, 1); assert.equal(terminals.length, 1);
    assert.equal(fs.realpathSync(engines[0].path), engineRoot);
    assert.equal(fs.realpathSync(terminals[0].path), terminalRoot);
    const author = [...unique.values()].find(node => node.name === 'Story');
    assert(author); assert.equal(fs.realpathSync(author.path), fs.realpathSync(packageRoot));
    const launch = result => spawnSync(result.binary, [], {input: 'quit\ny\n', encoding: 'utf8', env: {...process.env, GNUSTO_PLAIN: '1'}, timeout: 30000});
    let played = launch(built); assert.equal(played.status, 0, played.stderr); assert.match(played.stdout, /BuildSourceOne ResourceOpeningOne/);
    const source = path.join(packageRoot, 'Sources/Story/Story.swift');
    fs.writeFileSync(source, fs.readFileSync(source, 'utf8').replace('BuildSourceOne', 'BuildSourceTwo'));
    const before = built.fingerprint; built = await buildGame(spec, {environment}); assert.notEqual(before, built.fingerprint);
    played = launch(built); assert.equal(played.status, 0, played.stderr); assert.match(played.stdout, /BuildSourceTwo ResourceOpeningOne/);
    const catalogFile = path.join(packageRoot, 'gnusto-games.json');
    const sameNameCatalog = JSON.parse(fs.readFileSync(catalogFile, 'utf8'));
    sameNameCatalog.games[0].product = 'Story';
    fs.writeFileSync(catalogFile, JSON.stringify(sameNameCatalog));
    const manifestFile = path.join(packageRoot, 'Package.swift');
    fs.writeFileSync(manifestFile, fs.readFileSync(manifestFile, 'utf8').replace('.library(name: "StoryLibrary"', '.library(name: "Story"'));
    const sameNameSpec = makeBuildSpec({packageRoot, engineRoot, terminalRoot, game: 'Story', mode: 'deployment'});
    const sameNameBuild = await buildGame(sameNameSpec, {environment});
    played = launch(sameNameBuild); assert.equal(played.status, 0, played.stderr); assert.match(played.stdout, /BuildSourceTwo ResourceOpeningOne/);
    assert.notEqual(path.basename(sameNameBuild.binary), 'Story');
    evidence.push({kind, sameNameProductObserved: true, identities: [...unique.keys()], enginePath: engines[0].path, terminalPath: terminals[0].path, authorPath: author.path, binary: built.binary, currentSourceEditObserved: true, resourceObserved: true});
  }
  if (process.env.GNUSTO_GRAPH_EVIDENCE) fs.writeFileSync(process.env.GNUSTO_GRAPH_EVIDENCE, JSON.stringify({root, evidence}, null, 2) + '\n');
});

test('private launcher product and target avoid same-name game library exports', t => {
  const f = fixture(t);
  const value = JSON.parse(fs.readFileSync(path.join(f.packageRoot, 'gnusto-games.json'), 'utf8'));
  value.games[0].product = 'Story';
  fs.writeFileSync(path.join(f.packageRoot, 'gnusto-games.json'), JSON.stringify(value));
  const spec = makeBuildSpec({...f, game: 'Story', mode: 'development'});
  assert.notEqual(spec.launcherProduct, 'Story');
  assert.equal(typeof spec.launcherProduct, 'string');
  assert.equal(typeof spec.launcherTarget, 'string');
  assert.notEqual(spec.launcherTarget, 'Story');
  assert.match(spec.manifest, /product\(name: "Story", package: "Story"\)/);
});

test('source directory aliases and empty directory deletion participate in fingerprints', async t => {
  const f = fixture(t);
  let built = await buildGame(f.spec, f);
  fs.symlinkSync(path.join(f.engineRoot, 'Sources'), path.join(f.engineRoot, 'other-source'), 'dir');
  let next = await buildGame(f.spec, f); assert.notEqual(next.fingerprint, built.fingerprint); built = next;
  fs.mkdirSync(path.join(f.packageRoot, 'Empty'));
  next = await buildGame(f.spec, f); assert.notEqual(next.fingerprint, built.fingerprint); built = next;
  fs.rmdirSync(path.join(f.packageRoot, 'Empty'));
  next = await buildGame(f.spec, f); assert.notEqual(next.fingerprint, built.fingerprint);
});

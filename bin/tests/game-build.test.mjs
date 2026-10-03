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
  fs.writeFileSync(swift, `#!/usr/bin/env node\nimport fs from 'node:fs';\nimport path from 'node:path';\nconst a=process.argv.slice(2); fs.appendFileSync(process.env.LOG, JSON.stringify({args:a,engine:process.env.GNUSTO_ENGINE_PATH})+'\\n');\nif(a[0]==='--version'){console.log('Fake Swift 6.4');process.exit(0)}\nif(process.env.FAIL){process.exit(1)}\nif(a[0]==='package'){const scratch=a[a.indexOf('--scratch-path')+1]; fs.mkdirSync(scratch,{recursive:true}); const file=path.join(scratch,'workspace-state.json'); if(a.includes('edit')) fs.writeFileSync(file,JSON.stringify({object:{dependencies:[{packageRef:{identity:a[a.indexOf('edit')+1],kind:'remoteSourceControl',location:'https://github.com/HeirloomLogic/Gnusto'},state:{name:'edited',path:a[a.indexOf('--path')+1]}}]}})); else {const workspace=JSON.parse(fs.readFileSync(file));if(process.env.LOSE_EDIT){workspace.object.dependencies[0].state.name='sourceControlCheckout';fs.writeFileSync(file,JSON.stringify(workspace));}console.log(JSON.stringify({identity:'package',dependencies:[{identity:'gnusto',name:'Gnusto',path:workspace.object.dependencies[0].state.path}]}));} process.exit(0)}\nconst scratch=a[a.indexOf('--scratch-path')+1]; const bin=path.join(scratch,'out','Products','Debug');\nif(a.includes('--show-bin-path')) { if(process.env.MUTATE_SOURCE && !fs.existsSync(process.env.MUTATE_MARKER)){fs.writeFileSync(process.env.READ_SOURCE,'AfterEdit');fs.writeFileSync(process.env.MUTATE_MARKER,'done');} console.log(bin); }\nelse { await new Promise(r=>setTimeout(r,40)); fs.mkdirSync(bin,{recursive:true}); fs.writeFileSync(path.join(bin,a[a.indexOf('--product')+1]),process.env.READ_SOURCE ? fs.readFileSync(process.env.READ_SOURCE) : 'binary'); fs.chmodSync(path.join(bin,a[a.indexOf('--product')+1]),0o755); }\n`);
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
  assert.equal(url.spec.engineDependencyPath, null);
  assert.equal(url.spec.engineEdit.path, fs.realpathSync(url.engineRoot));
  assert.equal(url.spec.engineEdit.identity, 'gnusto');
  assert.doesNotMatch(url.spec.manifest, /package\(name: "Gnusto", path:/);
  assert.match(url.spec.manifest, /package\(url: "https:\/\/github.com\/HeirloomLogic\/Gnusto", branch: "main", traits: forwarded\)/);
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
  const swiftLog = path.join(root, 'swift-invocations.jsonl');
  const swift = path.join(root, 'swift-wrapper');
  fs.writeFileSync(swift, `#!/usr/bin/env node\nimport fs from 'node:fs'; import {spawnSync} from 'node:child_process';\nfs.appendFileSync(process.env.GNUSTO_GRAPH_SWIFT_LOG, JSON.stringify(process.argv.slice(2))+'\\n');\nconst result=spawnSync('swift',process.argv.slice(2),{stdio:'inherit'});process.exit(result.status ?? 1);\n`);
  fs.chmodSync(swift, 0o755);
  const logCount = () => fs.existsSync(swiftLog) ? fs.readFileSync(swiftLog, 'utf8').trim().split('\n').length : 0;
  t.after(() => { if (!process.env.GNUSTO_GRAPH_KEEP) fs.rmSync(root, {recursive: true, force: true}); });
  for (const kind of ['path', 'url']) {
    const packageRoot = path.join(root, `author-${kind}`);
    fs.cpSync(path.resolve('bin/tests/fixtures/game-build/resource-story'), packageRoot, {recursive: true});
    const dependency = kind === 'path'
      ? `.package(name: "Gnusto", path: ${swiftStringLiteral(engineRoot)}, traits: forwarded)`
      : '.package(url: "https://github.com/HeirloomLogic/Gnusto", from: "0.0.1", traits: forwarded)';
    fs.writeFileSync(path.join(packageRoot, 'Package.swift'), fs.readFileSync(path.join(packageRoot, 'Package.swift.in'), 'utf8').replace('ENGINE_DEPENDENCY', dependency));
    const spec = makeBuildSpec({packageRoot, engineRoot, terminalRoot, game: 'Story', mode: 'deployment'});
    const environment = {...process.env, GNUSTO_GRAPH_SWIFT_LOG: swiftLog, GNUSTO_SWIFT_BUILD_FLAGS: process.env.GNUSTO_SWIFT_BUILD_FLAGS || '["--jobs","2"]'};
    let built = await buildGame(spec, {environment, swift});
    const graph = spawnSync('swift', ['package', '--package-path', built.packageRoot, '--scratch-path', built.scratchPath, '--disable-default-traits', 'show-dependencies', '--format', 'json'], {encoding: 'utf8', env: {...environment, ...(spec.engineDependencyPath ? {GNUSTO_ENGINE_PATH: spec.engineDependencyPath} : {})}, maxBuffer: 20 * 1024 * 1024});
    assert.equal(graph.status, 0, graph.stderr);
    assert.doesNotMatch(graph.stderr, /Conflicting identity/);
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
    const before = built.fingerprint; built = await buildGame(spec, {environment, swift}); assert.notEqual(before, built.fingerprint);
    played = launch(built); assert.equal(played.status, 0, played.stderr); assert.match(played.stdout, /BuildSourceTwo ResourceOpeningOne/);
    const catalogFile = path.join(packageRoot, 'gnusto-games.json');
    const sameNameCatalog = JSON.parse(fs.readFileSync(catalogFile, 'utf8'));
    sameNameCatalog.games[0].product = 'Story';
    fs.writeFileSync(catalogFile, JSON.stringify(sameNameCatalog));
    const manifestFile = path.join(packageRoot, 'Package.swift');
    fs.writeFileSync(manifestFile, fs.readFileSync(manifestFile, 'utf8').replace('.library(name: "StoryLibrary"', '.library(name: "Story"'));
    const sameNameSpec = makeBuildSpec({packageRoot, engineRoot, terminalRoot, game: 'Story', mode: 'deployment'});
    const sameNameBuild = await buildGame(sameNameSpec, {environment, swift});
    played = launch(sameNameBuild); assert.equal(played.status, 0, played.stderr); assert.match(played.stdout, /BuildSourceTwo ResourceOpeningOne/);
    assert.notEqual(path.basename(sameNameBuild.binary), 'Story');
    const deployedMCP = spawnSync(sameNameBuild.binary, ['--mcp'], {input: '', encoding: 'utf8', timeout: 15000});
    assert.equal(deployedMCP.status, 1, deployedMCP.stderr); assert.match(deployedMCP.stderr, /without.*Playtest|unavailable/i);
    const warmedCount = logCount();
    assert.deepEqual(await buildGame(sameNameSpec, {environment, swift}), sameNameBuild); assert.equal(logCount(), warmedCount);
    let developmentMCP = false;
    if (kind === 'url') {
      const developmentSpec = makeBuildSpec({packageRoot, engineRoot, terminalRoot, game: 'Story', mode: 'development'});
      const development = await buildGame(developmentSpec, {environment, swift});
      const initialize = JSON.stringify({jsonrpc: '2.0', id: 1, method: 'initialize', params: {protocolVersion: '2024-11-05', capabilities: {}, clientInfo: {name: 'graph-integration', version: '1'}}}) + '\n';
      const response = spawnSync(development.binary, ['--mcp'], {input: initialize, encoding: 'utf8', timeout: 15000});
      assert.equal(response.status, 0, response.stderr);
      const protocol = JSON.parse(response.stdout.trim()); assert.equal(protocol.id, 1); assert(protocol.result?.protocolVersion); assert.equal(protocol.error, undefined);
      developmentMCP = true;
      const developmentCount = logCount();
      assert.deepEqual(await buildGame(developmentSpec, {environment, swift}), development); assert.equal(logCount(), developmentCount);
    }
    evidence.push({kind, sameNameProductObserved: true, warmZeroSwift: true, developmentMCP, deploymentMCPUnavailable: true, graphDiagnostics: graph.stderr, editedSourceControl: kind === 'url', identities: [...unique.keys()], enginePath: engines[0].path, terminalPath: terminals[0].path, authorPath: author.path, binary: built.binary, currentSourceEditObserved: true, resourceObserved: true});
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


test('source edits after compilation cannot publish an old executable as current', async t => {
  const f = fixture(t);
  const source = path.join(f.packageRoot, 'Sources/content.swift');
  fs.writeFileSync(source, 'BeforeEdit');
  const environment = {...f.environment, READ_SOURCE: source, MUTATE_SOURCE: '1', MUTATE_MARKER: path.join(f.root, 'mutated')};
  await assert.rejects(buildGame(f.spec, {...f, environment}), /inputs changed during build/);
  assert.equal(fs.existsSync(path.join(f.spec.generatedRoot, 'build-state.json')), false);
  const current = await buildGame(f.spec, {...f, environment});
  assert.equal(fs.readFileSync(current.binary, 'utf8'), 'AfterEdit');
  const count = f.log().length;
  await buildGame(f.spec, {...f, environment}); assert.equal(f.log().length, count);
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 2);
});

test('abandoned native locks and simultaneous recoverers preserve the live successor inode', {timeout: 30000}, async t => {
  const {spawn} = await import('node:child_process');
  const {once} = await import('node:events');
  const f = fixture(t);
  fs.mkdirSync(f.spec.generatedRoot, {recursive: true});
  const lockFile = path.join(f.spec.generatedRoot, 'build.lockfile');
  const command = process.platform === 'darwin' ? '/usr/bin/lockf' : 'flock';
  const holderCode = "console.log(process.pid); process.stdin.resume(); process.stdin.on('end',()=>process.exit(0));";
  const holder = spawn(command, [...(process.platform === 'darwin' ? ['-k'] : []), lockFile, process.execPath, '-e', holderCode], {stdio: ['pipe', 'pipe', 'inherit']});
  const holderPID = Number((await once(holder.stdout, 'data'))[0].toString().trim());
  const inode = fs.statSync(lockFile).ino;
  const clients = [];
  t.after(() => { holder.stdin.end(); for (const client of clients) { client.stdin.end(); client.kill(); } });
  const code = `import {acquireBuildLock} from ${JSON.stringify(new URL('../lib/game-build.mjs', import.meta.url).href)}; import {once} from 'node:events'; console.log('started'); const release = await acquireBuildLock(process.argv[1]); console.log('acquired'); process.stdin.resume(); await once(process.stdin,'end'); await release();`;
  const client = () => {
    const child = spawn(process.execPath, ['--input-type=module', '-e', code, f.spec.generatedRoot], {stdio: ['pipe', 'pipe', 'pipe']});
    clients.push(child);
    let text = '', errors = '';
    child.stderr.on('data', data => { errors += data; });
    const started = new Promise(resolve => child.stdout.on('data', data => { text += data; if (text.includes('started')) resolve(); }));
    const acquired = new Promise((resolve, reject) => {
      child.stdout.on('data', data => { if (data.toString().includes('acquired')) resolve(child); });
      child.on('exit', status => { if (status) reject(new Error(errors)); });
    });
    return {child, started, acquired, output: () => text};
  };
  const a = client(), b = client();
  await Promise.all([a.started, b.started]);
  await new Promise(resolve => setTimeout(resolve, 100));
  assert(!a.output().includes('acquired')); assert(!b.output().includes('acquired'));
  process.kill(holderPID, 'SIGKILL');
  const first = await Promise.race([a.acquired, b.acquired]);
  const remaining = first === a.child ? b : a;
  await new Promise(resolve => setTimeout(resolve, 100));
  assert(!remaining.output().includes('acquired'));
  assert.equal(fs.statSync(lockFile).ino, inode);
  first.stdin.end(); await once(first, 'exit');
  const second = await remaining.acquired; second.stdin.end(); await once(second, 'exit');
  assert.equal(fs.statSync(lockFile).ino, inode);
});


test('Linux deployments request the static Swift runtime and fingerprint platform policy', async t => {
  const f = fixture(t);
  const linux = makeBuildSpec({...f, game: 'Story', mode: 'deployment', platform: 'linux'});
  assert.deepEqual(linux.defaultBuildFlags, ['--static-swift-stdlib']);
  const built = await buildGame(linux, f);
  assert(f.log().find(item => item.args.includes('--product')).args.includes('--static-swift-stdlib'));
  const darwin = makeBuildSpec({...f, game: 'Story', mode: 'deployment', platform: 'darwin'});
  const other = await buildGame(darwin, f); assert.notEqual(other.fingerprint, built.fingerprint);
  assert.deepEqual(makeBuildSpec({...f, game: 'Story', mode: 'development', platform: 'linux'}).defaultBuildFlags, []);
});


test('editable URL attachment uses literal current sources and remains Swift-free when warm', async t => {
  const f = fixture(t, {url: true});
  const environment = {...f.environment, GNUSTO_ENGINE_PATH: 'must-not-turn-source-control-into-a-path'};
  const built = await buildGame(f.spec, {...f, environment});
  const edit = f.log().find(item => item.args.includes('edit'));
  assert.equal(edit.args[edit.args.indexOf('--path') + 1], fs.realpathSync(f.engineRoot));
  assert.equal(edit.engine, undefined);
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 1);
  assert.equal(fs.readFileSync(path.join(f.spec.packageRoot, 'Package.swift'), 'utf8'), f.spec.manifest);
  const count = f.log().length;
  assert.deepEqual(await buildGame(f.spec, {...f, environment}), built); assert.equal(f.log().length, count);
});

test('publication retains the validated snapshot when an edit races after validation', async t => {
  const f = fixture(t);
  const source = path.join(f.packageRoot, 'Sources/content.swift');
  const canonicalSource = fs.realpathSync(source);
  fs.writeFileSync(source, 'BeforeEdit');
  const original = fs.readFileSync;
  let reads = 0;
  fs.readFileSync = function(file, ...args) {
    const bytes = original.call(this, file, ...args);
    if (String(file) === canonicalSource && ++reads === 4) fs.writeFileSync(source, 'AfterEdit');
    return bytes;
  };
  let before;
  try { before = await buildGame(f.spec, {...f, environment: {...f.environment, READ_SOURCE: source}}); }
  finally { fs.readFileSync = original; }
  assert.equal(fs.readFileSync(source, 'utf8'), 'AfterEdit');
  assert.equal(fs.readFileSync(before.binary, 'utf8'), 'BeforeEdit');
  const current = await buildGame(f.spec, {...f, environment: {...f.environment, READ_SOURCE: source}});
  assert.notEqual(current.fingerprint, before.fingerprint);
  assert.equal(fs.readFileSync(current.binary, 'utf8'), 'AfterEdit');
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 2);
});


test('a resolver that drops editable state is refused before compilation', async t => {
  const f = fixture(t, {url: true});
  await assert.rejects(buildGame(f.spec, {...f, environment: {...f.environment, LOSE_EDIT: '1'}}), /refusing to compile released engine sources/);
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 0);
  assert.equal(fs.existsSync(path.join(f.spec.generatedRoot, 'build-state.json')), false);
});

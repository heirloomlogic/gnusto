import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import path from 'node:path';
import {tmpdir} from 'node:os';
import {acquireBuildLock, assertBuildCurrent, buildGame, makeBuildSpec, swiftStringLiteral} from '../lib/game-build.mjs';
import {loadGames} from '../lib/game-catalog.mjs';
const trait = 'traits: [.trait(name: "Playtest"), .default(enabledTraits: ["Playtest"])]';
function fixture(t, {url = false} = {}) {
  const root = fs.mkdtempSync(path.join(tmpdir(), 'gnusto-build-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const packageRoot = path.join(root, 'author-story');
  const engineRoot = path.join(root, 'engine space " $(touch sentinel)');
  const terminalRoot = path.join(root, 'terminal');
  const yonkRoot = path.join(root, 'yonk');
  for (const dir of [packageRoot, engineRoot, terminalRoot, yonkRoot]) { fs.mkdirSync(path.join(dir, 'Sources'), {recursive: true}); fs.writeFileSync(path.join(dir, 'Sources', 'content.swift'), '// content'); }
  fs.writeFileSync(path.join(engineRoot, 'Package.swift'), `// swift-tools-version: 6.2\n${trait}`);
  fs.writeFileSync(path.join(terminalRoot, 'Package.swift'), `// swift-tools-version: 6.2\n${trait}`);
  fs.mkdirSync(path.join(yonkRoot, 'Sources/Yonk'), {recursive: true});
  fs.writeFileSync(path.join(yonkRoot, 'Sources/Yonk/Yonk.swift'), '// Yonk source');
  fs.writeFileSync(path.join(yonkRoot, 'Package.swift'), `// swift-tools-version: 6.2\nimport PackageDescription\nlet package = Package(name: "Yonk", products: [.library(name: "Yonk", targets: ["Yonk"])], dependencies: [.package(url: "https://github.com/HeirloomLogic/Gnusto.git", revision: "${'3'.repeat(40)}")], targets: [.target(name: "Yonk", dependencies: [.product(name: "Gnusto", package: "Gnusto")])])`);
  fs.writeFileSync(path.join(packageRoot, 'Package.swift'), `// swift-tools-version: 6.2\n${trait}\n.package(name: "Gnusto", ${url ? 'url: "https://github.com/HeirloomLogic/Gnusto", branch: "main"' : `path: ${swiftStringLiteral(engineRoot)}`}, traits: forwarded)`);
  fs.writeFileSync(path.join(packageRoot, 'gnusto-games.json'), JSON.stringify({version: 1, package: 'Story', games: [{name: 'Story', product: 'StoryLibrary', module: 'Story', symbol: 'game'}]}));
  const swift = path.join(root, 'fake-swift');
  fs.writeFileSync(swift, `#!/usr/bin/env node\nimport fs from 'node:fs';\nimport path from 'node:path';\nconst a=process.argv.slice(2); fs.appendFileSync(process.env.LOG, JSON.stringify({args:a,engine:process.env.GNUSTO_ENGINE_PATH})+'\\n');\nif(a[0]==='--version'){console.log('Fake Swift 6.4');process.exit(0)}\nif(process.env.FAIL){process.exit(1)}\nif(a[0]==='package'){\n const scratch=a[a.indexOf('--scratch-path')+1], pkg=a[a.indexOf('--package-path')+1];fs.mkdirSync(scratch,{recursive:true});const file=path.join(scratch,'workspace-state.json');\n const workspace=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{object:{dependencies:[]}};\n if(a.includes('edit')){\n  const id=a[a.indexOf('edit')+1];const remote=id==='gnustoterminal';const location='https://github.com/HeirloomLogic/'+(remote?'GnustoTerminal':'Gnusto');\n  const dependency={packageRef:{identity:id,kind:'remoteSourceControl',location},state:{name:'edited',path:remote?null:a[a.indexOf('--path')+1]}};\n  if(remote){dependency.subpath=id;dependency.basedOn={packageRef:dependency.packageRef,state:{name:'sourceControlCheckout',checkoutState:{branch:'main',revision:'a'.repeat(40)}}};const dir=path.join(pkg,'Packages',id);fs.mkdirSync(path.join(dir,'.git'),{recursive:true});fs.writeFileSync(path.join(dir,'.git/HEAD'),'a'.repeat(40));fs.writeFileSync(path.join(dir,'Package.swift'),'traits: [.trait(name: "Playtest")]');fs.writeFileSync(path.join(dir,'source.swift'),'BeforeEdit');}\n  workspace.object.dependencies=workspace.object.dependencies.filter(d=>d.packageRef.identity!==id);workspace.object.dependencies.push(dependency);fs.writeFileSync(file,JSON.stringify(workspace));\n }else{\n  if(process.env.LOSE_EDIT){workspace.object.dependencies[0].state.name='sourceControlCheckout';fs.writeFileSync(file,JSON.stringify(workspace));}if(process.env.LOSE_FRONTEND_EDIT){workspace.object.dependencies.find(d=>d.packageRef.identity==='gnustoterminal').state.name='sourceControlCheckout';fs.writeFileSync(file,JSON.stringify(workspace));}\n  const edited=workspace.object.dependencies.find(d=>d.packageRef.identity==='gnusto');\n  const manifest=fs.readFileSync(path.join(pkg,'Package.swift'),'utf8');console.log(JSON.stringify({identity:'package',dependencies:[{identity:'gnusto',name:'Gnusto',path:edited?.state.path||process.env.GNUSTO_ENGINE_PATH},...workspace.object.dependencies.filter(d=>d.packageRef.identity==='gnustoterminal').map(d=>({identity:d.packageRef.identity,name:'GnustoTerminal',path:path.join(pkg,'Packages',d.subpath)})),...(manifest.includes('package: \"Yonk\"')?[{identity:'yonk',name:'Yonk',path:path.join(pkg,'Frontends/yonk')}]:[])]}));\n }process.exit(0);\n}\nconst scratch=a[a.indexOf('--scratch-path')+1]; const bin=path.join(scratch,'out','Products','Debug');\nif(a.includes('--show-bin-path')) { if(process.env.MUTATE_DEPENDENCY){if(process.env.DELETE_DEPENDENCY)fs.unlinkSync(process.env.MUTATE_DEPENDENCY);else fs.writeFileSync(process.env.MUTATE_DEPENDENCY,'AfterEdit');} if(process.env.MUTATE_FRONTEND){const pkg=a[a.indexOf('--package-path')+1];fs.writeFileSync(path.join(pkg,'Packages/gnustoterminal/source.swift'),'AfterEdit');} if(process.env.MUTATE_SOURCE && !fs.existsSync(process.env.MUTATE_MARKER)){fs.writeFileSync(process.env.READ_SOURCE,'AfterEdit');fs.writeFileSync(process.env.MUTATE_MARKER,'done');} console.log(bin); }\nelse { await new Promise(r=>setTimeout(r,40)); fs.mkdirSync(bin,{recursive:true}); fs.writeFileSync(path.join(bin,a[a.indexOf('--product')+1]),a.includes('--disable-default-traits') ? '#!/usr/bin/env node\\n' + (process.env.PROBE_MODE === 'enabled' ? 'process.exit(1)' : 'console.log("Gnusto.PlaytestLaunchError.unavailable")') : process.env.READ_SOURCE ? fs.readFileSync(process.env.READ_SOURCE) : 'binary'); fs.chmodSync(path.join(bin,a[a.indexOf('--product')+1]),0o755); }\n`);
  fs.chmodSync(swift, 0o755);
  const environment = {...process.env, LOG: path.join(root, 'invocations'), GNUSTO_SWIFT_BUILD_FLAGS: '["--jobs","2"]'};
  const spec = makeBuildSpec({packageRoot, engineRoot, terminalRoot, game: loadGames(packageRoot).games[0], mode: 'development'});
  const log = () => fs.existsSync(environment.LOG) ? fs.readFileSync(environment.LOG, 'utf8').trim().split('\n').map(JSON.parse) : [];
  return {root, packageRoot, engineRoot, terminalRoot, yonkRoot, swift, environment, spec, log};
}
test('Yonk development specs use the public scene contract and an isolated frontend cache', t => {
  const f = fixture(t);
  const yonk = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', mode: 'development', platform: 'darwin'});
  assert.match(yonk.entryPoint, /Yonk\(Story\.game\)/);
  assert.match(yonk.entryPoint, /import SwiftUI/);
  assert.match(yonk.manifest, /product\(name: "Yonk", package: "Yonk"\)/);
  assert.equal(yonk.frontend, 'yonk');
  assert.equal(yonk.frontendRoot, fs.realpathSync(f.yonkRoot));
  assert.match(yonk.generatedRoot, /Story\/yonk\/development$/);
  assert.match(f.spec.generatedRoot, /Story\/terminal\/development$/);
  assert.notEqual(yonk.scratchPath, f.spec.scratchPath);
});
test('Yonk rejects missing sources and unsupported platforms before Swift', t => {
  const f = fixture(t);
  assert.throws(() => makeBuildSpec({...f, frontend: 'yonk', yonkRoot: null, game: 'Story', platform: 'darwin'}), /GNUSTO_YONK_PATH/);
  assert.throws(() => makeBuildSpec({...f, frontend: 'yonk', game: 'Story', platform: 'linux'}), /macOS/);
  const deployed = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', mode: 'deployment', platform: 'darwin'});
  assert.match(deployed.entryPoint, /PlaytestLaunch.serve/);
  assert.match(deployed.entryPoint, /--gnusto-verify-app/);
  assert.match(deployed.generatedRoot, /yonk\/deployment$/);
  assert.throws(() => makeBuildSpec({...f, frontend: 'unknown', game: 'Story'}), /Unknown frontend/);
  assert.equal(f.log().length, 0);
});
test('Yonk source edits and deletions invalidate its warm development cache', async t => {
  const f = fixture(t);
  const spec = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', platform: 'darwin'});
  let previous = await buildGame(spec, f);
  const source = path.join(f.yonkRoot, 'Sources/Yonk/Yonk.swift');
  fs.writeFileSync(source, '// changed Yonk source');
  let next = await buildGame(spec, f); assert.notEqual(next.fingerprint, previous.fingerprint); previous = next;
  fs.unlinkSync(source);
  next = await buildGame(spec, f); assert.notEqual(next.fingerprint, previous.fingerprint);
  const count = f.log().length;
  assert.deepEqual(await buildGame(spec, f), next); assert.equal(f.log().length, count);
});
test('Yonk overlays retain frontend resources and bind URL authors to the edited engine', async t => {
  const f = fixture(t, {url: true});
  const manifestFile = path.join(f.yonkRoot, 'Package.swift');
  const original = fs.readFileSync(manifestFile, 'utf8').replace('package: "Gnusto")])]', 'package: "Gnusto")], resources: [.process("Resources")])]');
  fs.writeFileSync(manifestFile, original);
  const resource = path.join(f.yonkRoot, 'Sources/Yonk/Resources/shader.metal');
  fs.mkdirSync(path.dirname(resource), {recursive: true}); fs.writeFileSync(resource, 'shader source');
  const spec = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', platform: 'darwin'});
  await buildGame(spec, f);
  assert.match(spec.yonkOverlayManifest, /resources: \[.process\("Resources"\)\]/);
  assert.match(spec.yonkOverlayManifest, /url: "https:\/\/github.com\/HeirloomLogic\/Gnusto", branch: "main"/);
  assert.doesNotMatch(spec.yonkOverlayManifest, /name: "Gnusto", path:/);
  assert.equal(fs.realpathSync(path.join(spec.yonkOverlayRoot, 'Sources/Yonk/Resources/shader.metal')), fs.realpathSync(resource));
  assert.equal(fs.readFileSync(manifestFile, 'utf8'), original);
  const previous = await buildGame(spec, f);
  fs.unlinkSync(resource);
  assert.notEqual((await buildGame(spec, f)).fingerprint, previous.fingerprint);
});
test('Yonk refuses source mutation during compilation without publishing cache state', async t => {
  const f = fixture(t);
  const spec = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', platform: 'darwin'});
  await assert.rejects(buildGame(spec, {...f, environment: {...f.environment, MUTATE_DEPENDENCY: path.join(f.yonkRoot, 'Sources/Yonk/Yonk.swift')}}), /inputs changed/);
  assert.equal(fs.existsSync(path.join(spec.generatedRoot, 'build-state.json')), false);
});
for (const change of ['edit', 'delete']) {
  test(`Yonk rejects a ${change}d manifest after waiting for the actual build lock`, async t => {
    const f = fixture(t);
    const spec = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', platform: 'darwin'});
    const release = await acquireBuildLock(spec.generatedRoot);
    t.after(release);
    // buildGame reaches its lock await synchronously; this owner still holds it.
    const waiting = buildGame(spec, f).then(result => ({result}), error => ({error}));
    assert.equal(f.log().length, 0);
    const manifest = path.join(f.yonkRoot, 'Package.swift');
    if (change === 'delete') fs.unlinkSync(manifest);
    else fs.appendFileSync(manifest, '\npackage.targets[0].resources = [.process("NewResources")]\n');
    await release();
    const outcome = await waiting;
    assert(outcome.error, 'a stale manifest specification must not publish a build');
    assert.match(outcome.error.message, /Yonk manifest changed|ENOENT/);
    assert.equal(f.log().length, 0, 'reject before any Swift invocation');
    assert.equal(fs.existsSync(path.join(spec.generatedRoot, 'build-state.json')), false);
  });
}
test('Yonk refuses reused stale specs and a fresh spec preserves changed resource declarations', async t => {
  const f = fixture(t);
  const make = () => makeBuildSpec({...f, frontend: 'yonk', game: 'Story', platform: 'darwin'});
  const original = make();
  await buildGame(original, f);
  const stateFile = path.join(original.generatedRoot, 'build-state.json');
  const oldState = fs.readFileSync(stateFile, 'utf8');
  const manifest = path.join(f.yonkRoot, 'Package.swift');
  fs.appendFileSync(manifest, '\npackage.targets[0].resources = [.process("NewResources")]\n');
  const count = f.log().length;
  await assert.rejects(buildGame(original, f), /Yonk manifest changed/);
  assert.equal(f.log().length, count);
  assert.equal(fs.readFileSync(stateFile, 'utf8'), oldState);
  const current = make();
  const built = await buildGame(current, f);
  assert.match(fs.readFileSync(path.join(current.yonkOverlayRoot, 'Package.swift'), 'utf8'), /NewResources/);
  const warmCount = f.log().length;
  assert.deepEqual(await buildGame(current, f), built);
  assert.equal(f.log().length, warmCount);
  fs.unlinkSync(manifest);
  await assert.rejects(buildGame(current, f), /Yonk manifest changed|ENOENT/);
  assert.equal(f.log().length, warmCount);
});
for (const collision of ['directory', 'catalog', 'engine']) {
  test(`Yonk rejects an author ${collision} identity collision before workspace creation`, t => {
    const f = fixture(t);
    if (collision === 'directory') {
      const parent = path.join(f.root, 'authors'); fs.mkdirSync(parent);
      const renamed = path.join(parent, 'YoNk'); fs.renameSync(f.packageRoot, renamed); f.packageRoot = renamed;
    } else if (collision === 'catalog') {
      const file = path.join(f.packageRoot, 'gnusto-games.json');
      const catalog = JSON.parse(fs.readFileSync(file)); catalog.package = 'YoNk'; fs.writeFileSync(file, JSON.stringify(catalog));
    } else {
      const parent = path.join(f.root, 'engines'); fs.mkdirSync(parent);
      const renamed = path.join(parent, 'YoNk'); fs.renameSync(f.engineRoot, renamed); f.engineRoot = renamed;
      fs.writeFileSync(path.join(f.packageRoot, 'Package.swift'), `${trait}\n.package(name: "Gnusto", path: ${swiftStringLiteral(renamed)})`);
    }
    assert.throws(() => makeBuildSpec({...f, frontend: 'yonk', game: 'Story', platform: 'darwin'}), /identity collision.*Yonk|identity collision.*yonk/i);
    assert.equal(fs.existsSync(path.join(f.packageRoot, '.build-launchers')), false);
    assert.equal(f.log().length, 0);
    assert.doesNotThrow(() => makeBuildSpec({...f, frontend: 'terminal', game: 'Story', platform: 'darwin'}));
  });
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
  const environment = {...f.environment, GNUSTO_PACKAGE_PATH: f.packageRoot, GNUSTO_REPO: f.engineRoot, GNUSTO_TERMINAL_PATH: f.terminalRoot, GNUSTO_YONK_PATH: f.yonkRoot, GNUSTO_SWIFT: f.swift};
  const unknown = spawnSync(cli, ['Nobody'], {env: environment, encoding: 'utf8'});
  assert.equal(unknown.status, 2); assert.equal(unknown.stdout, ''); assert.equal(f.log().length, 0);
  const built = spawnSync(cli, ['Story', '--json'], {env: environment, encoding: 'utf8'});
  assert.equal(built.status, 0, built.stderr); const result = JSON.parse(built.stdout); assert(path.isAbsolute(result.binary));
  const warmed = spawnSync(cli, ['Story'], {env: environment, encoding: 'utf8'});
  assert.equal(warmed.status, 0, warmed.stderr); assert.equal(warmed.stdout, result.binary + '\n');
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 1);
  const beforeYonk = f.log().length;
  const yonk = spawnSync(cli, ['Story', '--frontend', 'yonk', '--json'], {env: environment, encoding: 'utf8'});
  if (process.platform === 'darwin') {
    assert.equal(yonk.status, 0, yonk.stderr); const yonkResult = JSON.parse(yonk.stdout);
    assert.match(yonkResult.packageRoot, /Story\/yonk\/development\/package$/);
    assert.match(fs.readFileSync(path.join(yonkResult.packageRoot, `Sources/${f.spec.launcherTarget}/main.swift`), 'utf8'), /Yonk\(Story\.game\)/);
    assert.equal(f.log().filter(item => item.args.includes('--product')).length, 2);
  } else {
    assert.equal(yonk.status, 2, yonk.stderr);
    assert.equal(yonk.stdout, '');
    assert.match(yonk.stderr, /Yonk development frontend requires macOS/);
    assert.equal(f.log().length, beforeYonk);
    assert.equal(fs.existsSync(path.join(f.packageRoot, '.build-launchers/Story/yonk')), false);
  }
});

test('real path and URL author graphs share current Gnusto and resource-bearing source edits', {skip: process.env.GNUSTO_REAL_GRAPH !== '1', timeout: 1200000}, async t => {
  const {spawnSync} = await import('node:child_process');
  const engineRoot = fs.realpathSync(process.cwd());
  const terminalRoot = process.env.GNUSTO_PUBLIC_TERMINAL_GRAPH === '1' ? null : fs.realpathSync(process.env.GNUSTO_TERMINAL_PATH || '.context/companions/GnustoTerminal');
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
    assert.equal(fs.realpathSync(terminals[0].path), terminalRoot || spec.terminalEdit.path);
    const terminalSource = spec.terminalEdit ? JSON.parse(fs.readFileSync(path.join(spec.generatedRoot, 'terminal-source.json'))) : null;
    if (terminalSource) { assert.equal(terminalSource.url, 'https://github.com/HeirloomLogic/GnustoTerminal'); assert.equal(terminalSource.branch, 'main'); assert.match(terminalSource.revision, /^[a-f0-9]{40}$/); }
    const author = [...unique.values()].find(node => node.name === 'Story');
    assert(author); assert.equal(fs.realpathSync(author.path), fs.realpathSync(packageRoot));
    const launch = result => spawnSync(result.binary, [], {input: 'frobnicate\nquit\ny\n', encoding: 'utf8', env: {...process.env, GNUSTO_PLAIN: '1'}, timeout: 30000});
    let played = launch(built); assert.equal(played.status, 0, played.stderr); assert.match(played.stdout, /BuildSourceOne ResourceOpeningOne/); if (process.env.GNUSTO_GRAPH_ENGINE_MARKER) assert(played.stdout.includes(process.env.GNUSTO_GRAPH_ENGINE_MARKER));
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
    evidence.push({kind, terminalSource, sameNameProductObserved: true, warmZeroSwift: true, developmentMCP, deploymentMCPUnavailable: true, graphDiagnostics: graph.stderr, editedSourceControl: kind === 'url', identities: [...unique.keys()], enginePath: engines[0].path, terminalPath: terminals[0].path, authorPath: author.path, binary: built.binary, currentSourceEditObserved: true, uncommittedEngineMarker: process.env.GNUSTO_GRAPH_ENGINE_MARKER || null, resourceObserved: true});
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
  assert.deepEqual(linux.defaultBuildFlags, ['--static-swift-stdlib', '-Xswiftc', '-static-stdlib']);
  const built = await buildGame(linux, f);
  const buildArguments = f.log().find(item => item.args.includes('--product')).args;
  assert.deepEqual(buildArguments.slice(buildArguments.indexOf('--static-swift-stdlib'), buildArguments.indexOf('--static-swift-stdlib') + 3), linux.defaultBuildFlags);
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


test('public SCM frontend uses a generated managed edit with exact revision provenance and zero warm Swift', async t => {
  const f = fixture(t);
  const spec = makeBuildSpec({...f, terminalRoot: null, game: 'Story'});
  assert.equal(spec.terminalEdit.identity, 'gnustoterminal');
  assert.match(spec.bootstrapManifest, /GnustoTerminal/);
  const built = await buildGame(spec, f);
  const edit = f.log().find(item => item.args.includes('edit'));
  assert.equal(edit.engine, undefined);
  assert.equal(edit.args.includes('--path'), false);
  assert.equal(f.log().find(item => item.args.includes('--product')).engine, f.engineRoot);
  const provenance = JSON.parse(fs.readFileSync(path.join(spec.generatedRoot, 'terminal-source.json')));
  assert.equal(provenance.revision, 'a'.repeat(40));
  assert.equal(provenance.url, 'https://github.com/HeirloomLogic/GnustoTerminal');
  assert.equal(provenance.branch, 'main');
  assert.equal(provenance.path, path.join(spec.packageRoot, 'Packages/gnustoterminal'));
  const count = f.log().length;
  assert.deepEqual(await buildGame(spec, f), built); assert.equal(f.log().length, count);
});

test('lost or stale managed frontend edits repair only generated state before compilation', async t => {
  const f = fixture(t, {url: true});
  const spec = makeBuildSpec({...f, terminalRoot: null, game: 'Story'});
  await buildGame(spec, f);
  const source = path.join(f.engineRoot, 'Sources/content.swift');
  const original = fs.readFileSync(source, 'utf8');
  fs.writeFileSync(path.join(spec.packageRoot, 'Packages/gnustoterminal/.git/HEAD'), 'b'.repeat(40));
  const before = f.log().filter(item => item.args.includes('edit')).length;
  await buildGame(spec, f);
  assert.equal(f.log().filter(item => item.args.includes('edit')).length, before + 2);
  assert.equal(fs.readFileSync(source, 'utf8'), original);
  fs.rmSync(path.join(spec.packageRoot, 'Packages/gnustoterminal'), {recursive: true});
  await buildGame(spec, f);
  assert.equal(f.log().filter(item => item.args.includes('edit')).length, before + 4);
  const managedSource = path.join(spec.packageRoot, 'Packages/gnustoterminal/source.swift');
  fs.writeFileSync(managedSource, 'unexpected edited frontend bytes');
  await buildGame(spec, f);
  assert.equal(f.log().filter(item => item.args.includes('edit')).length, before + 6);
  assert.equal(fs.readFileSync(managedSource, 'utf8'), 'BeforeEdit');
});

test('managed frontend source changes during compilation cannot publish a fresh fingerprint', async t => {
  const f = fixture(t);
  const spec = makeBuildSpec({...f, terminalRoot: null, game: 'Story'});
  const environment = {...f.environment, MUTATE_FRONTEND: '1'};
  await assert.rejects(buildGame(spec, {...f, environment}), /frontend compilation inputs changed/);
  assert.equal(fs.existsSync(path.join(spec.generatedRoot, 'build-state.json')), false);
});


test('real public SCM frontend builds a root game with current local engine and zero warm Swift', {skip: process.env.GNUSTO_REAL_GRAPH !== '1' || process.env.GNUSTO_PUBLIC_TERMINAL_GRAPH !== '1', timeout: 1200000}, async t => {
  const {spawnSync} = await import('node:child_process');
  const engineRoot = fs.realpathSync(process.cwd());
  const spec = makeBuildSpec({packageRoot: engineRoot, engineRoot, terminalRoot: null, game: 'CloakOfDarkness', mode: 'development'});
  const environment = {...process.env, GNUSTO_SWIFT_BUILD_FLAGS: process.env.GNUSTO_SWIFT_BUILD_FLAGS || '["--jobs","2"]'};
  const root = process.env.GNUSTO_GRAPH_ROOT || fs.mkdtempSync(path.join(tmpdir(), 'gnusto-public-root-'));
  fs.mkdirSync(root, {recursive: true});
  t.after(() => { if (!process.env.GNUSTO_GRAPH_KEEP) fs.rmSync(root, {recursive: true, force: true}); });
  const swift = path.join(root, 'swift-wrapper');
  fs.writeFileSync(swift, `#!/usr/bin/env node\nimport fs from 'node:fs'; import {spawnSync} from 'node:child_process';\nfs.appendFileSync(process.env.GNUSTO_GRAPH_SWIFT_LOG, JSON.stringify(process.argv.slice(2))+'\\n');\nconst result=spawnSync('swift',process.argv.slice(2),{stdio:'inherit'});process.exit(result.status ?? 1);\n`);
  fs.chmodSync(swift, 0o755);
  environment.GNUSTO_GRAPH_SWIFT_LOG = path.join(root, 'swift-invocations.jsonl');
  const built = await buildGame(spec, {environment, swift});
  const graph = spawnSync('swift', ['package', '--package-path', built.packageRoot, '--scratch-path', built.scratchPath, 'show-dependencies', '--format', 'json'], {encoding: 'utf8', env: {...environment, GNUSTO_ENGINE_PATH: spec.engineDependencyPath}, maxBuffer: 20 * 1024 * 1024});
  assert.equal(graph.status, 0, graph.stderr); assert.doesNotMatch(graph.stderr, /Conflicting identity/);
  const enginePaths = new Set(), engineIdentities = new Set();
  const walk = node => { if (node.name === 'Gnusto') { enginePaths.add(fs.realpathSync(node.path)); engineIdentities.add(node.identity); } for (const dependency of node.dependencies || []) walk(dependency); };
  walk(JSON.parse(graph.stdout)); assert.deepEqual([...enginePaths], [engineRoot]); assert.deepEqual([...engineIdentities], ['gnusto']);
  const played = spawnSync(built.binary, [], {input: 'frobnicate\nquit\ny\n', encoding: 'utf8', env: {...environment, GNUSTO_PLAIN: '1'}, timeout: 30000}); assert.equal(played.status, 0, played.stderr); if (process.env.GNUSTO_GRAPH_ENGINE_MARKER) assert(played.stdout.includes(process.env.GNUSTO_GRAPH_ENGINE_MARKER));
  const initialize = JSON.stringify({jsonrpc: '2.0', id: 1, method: 'initialize', params: {protocolVersion: '2024-11-05', capabilities: {}, clientInfo: {name: 'root-graph', version: '1'}}}) + '\n';
  const response = spawnSync(built.binary, ['--mcp'], {input: initialize, encoding: 'utf8', timeout: 15000}); assert.equal(response.status, 0, response.stderr); assert(JSON.parse(response.stdout.trim()).result?.protocolVersion);
  const count = fs.readFileSync(environment.GNUSTO_GRAPH_SWIFT_LOG, 'utf8').trim().split('\n').length;
  assert.deepEqual(await buildGame(spec, {environment, swift}), built); assert.equal(fs.readFileSync(environment.GNUSTO_GRAPH_SWIFT_LOG, 'utf8').trim().split('\n').length, count);
  fs.writeFileSync(path.join(root, 'root-graph-evidence.json'), JSON.stringify({built, terminalSource: JSON.parse(fs.readFileSync(path.join(spec.generatedRoot, 'terminal-source.json'))), currentEnginePaths: [...enginePaths], currentEngineIdentities: [...engineIdentities], warmZeroSwift: true, developmentMCP: true, uncommittedEngineMarker: process.env.GNUSTO_GRAPH_ENGINE_MARKER || null, graphDiagnostics: graph.stderr}, null, 2) + '\n');
});


test('a graph that loses frontend edit provenance is refused before compilation', async t => {
  const f = fixture(t);
  const spec = makeBuildSpec({...f, terminalRoot: null, game: 'Story'});
  await assert.rejects(buildGame(spec, {...f, environment: {...f.environment, LOSE_FRONTEND_EDIT: '1'}}), /refusing to compile/);
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 0);
});


function recordAdditionalDependency(f, kind) {
  const root = path.join(f.root, `separate-${kind}`);
  fs.mkdirSync(path.join(root, 'Sources'), {recursive: true});
  fs.writeFileSync(path.join(root, 'Sources/shared.swift'), 'BeforeEdit');
  fs.writeFileSync(path.join(root, 'resource.txt'), 'BeforeResource');
  fs.mkdirSync(f.spec.scratchPath, {recursive: true});
  fs.writeFileSync(path.join(f.spec.scratchPath, 'workspace-state.json'), JSON.stringify({object: {dependencies: [{packageRef: {identity: 'shared', kind: kind === 'edited' ? 'remoteSourceControl' : 'fileSystem', location: kind === 'edited' ? 'https://example.invalid/shared' : root}, state: {name: kind, path: root}, subpath: 'shared'}]}}));
  return root;
}
for (const kind of ['fileSystem', 'edited']) {
  test(`${kind} dependency source, resource and deletion invalidate warm caches without warm Swift`, async t => {
    const f = fixture(t);
    const dependency = recordAdditionalDependency(f, kind);
    let previous = await buildGame(f.spec, f);
    for (const change of [
      () => fs.writeFileSync(path.join(dependency, 'Sources/shared.swift'), 'AfterEdit'),
      () => fs.writeFileSync(path.join(dependency, 'resource.txt'), 'AfterResource'),
      () => fs.unlinkSync(path.join(dependency, 'Sources/shared.swift')),
      () => fs.unlinkSync(path.join(dependency, 'resource.txt')),
      () => fs.rmSync(dependency, {recursive: true}),
    ]) {
      change();
      const next = await buildGame(f.spec, f);
      assert.notEqual(next.fingerprint, previous.fingerprint);
      const count = f.log().length;
      assert.deepEqual(await buildGame(f.spec, f), next);
      assert.equal(f.log().length, count);
      previous = next;
    }
    assert.equal(f.log().filter(item => item.args.includes('--product')).length, 6);
  });
  test(`${kind} compilation rejects a dependency edit after compilation`, async t => {
    const f = fixture(t);
    const dependency = recordAdditionalDependency(f, kind);
    const environment = {...f.environment, READ_SOURCE: path.join(dependency, 'Sources/shared.swift'), MUTATE_SOURCE: '1', MUTATE_MARKER: path.join(f.root, 'mutated')};
    await assert.rejects(buildGame(f.spec, {...f, environment}), /inputs changed during build/);
    assert.equal(fs.existsSync(path.join(f.spec.generatedRoot, 'build-state.json')), false);
    const built = await buildGame(f.spec, {...f, environment});
    assert.equal(fs.readFileSync(built.binary, 'utf8'), 'AfterEdit');
  });
}

for (const kind of ['fileSystem', 'edited']) for (const input of ['Sources/shared.swift', 'resource.txt']) for (const deletion of [false, true]) {
  test(`${kind} ${input} ${deletion ? 'deletion' : 'edit'} during compilation refuses publication`, async t => {
    const f = fixture(t);
    const dependency = recordAdditionalDependency(f, kind);
    const environment = {...f.environment, MUTATE_DEPENDENCY: path.join(dependency, input), ...(deletion ? {DELETE_DEPENDENCY: '1'} : {})};
    await assert.rejects(buildGame(f.spec, {...f, environment}), /inputs changed during build/);
    assert.equal(fs.existsSync(path.join(f.spec.generatedRoot, 'build-state.json')), false);
    const built = await buildGame(f.spec, f);
    const count = f.log().length; assert.deepEqual(await buildGame(f.spec, f), built); assert.equal(f.log().length, count);
  });
}
test('deployment publishes state only after the direct engine probe returns unavailable', async t => {
  const f = fixture(t);
  const spec = makeBuildSpec({...f, game: 'Story', mode: 'deployment'});
  assert.match(spec.entryPoint, /try await PlaytestLaunch.serve/);
  assert.match(spec.entryPoint, /catch PlaytestLaunchError.unavailable/);
  await buildGame(spec, f);
  assert.equal(fs.existsSync(path.join(spec.generatedRoot, 'build-state.json')), true);
  // A failed forced build overwrites the old binary, then fails its engine probe.
  await assert.rejects(buildGame(spec, {...f, force: true, environment: {...f.environment, PROBE_MODE: 'enabled'}}), /engine.*Playtest/);
  assert.equal(fs.existsSync(path.join(spec.generatedRoot, 'build-state.json')), false);
  // Returning to unchanged inputs must rebuild, never reuse the earlier proof.
  const built = await buildGame(spec, f);
  assert.equal(f.log().filter(item => item.args.includes('--product')).length, 3);
  const count = f.log().length; assert.deepEqual(await buildGame(spec, f), built); assert.equal(f.log().length, count);
});

test('Yonk deployment checks the compiled engine trait and retains artifact provenance', async t => {
  const f = fixture(t);
  const spec = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', mode: 'deployment', platform: 'darwin'});
  const built = await buildGame(spec, f);
  await assertBuildCurrent(spec, built, f);
  fs.appendFileSync(built.binary, '\n// changed build output');
  await assert.rejects(assertBuildCurrent(spec, built, f), /artifacts changed/);
  await assert.rejects(buildGame(spec, {...f, force: true, environment: {...f.environment, PROBE_MODE: 'enabled'}}), /without Playtest/);
  assert.equal(fs.existsSync(path.join(spec.generatedRoot, 'build-state.json')), false);
});

test('app handoff refuses source edits after a successful build', async t => {
  const f = fixture(t);
  const spec = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', platform: 'darwin'});
  const built = await buildGame(spec, f);
  fs.appendFileSync(path.join(f.packageRoot, 'Sources/content.swift'), '\n// new source');
  await assert.rejects(assertBuildCurrent(spec, built, f), /inputs changed/);
});

for (const definition of ['catalog', 'author manifest', 'engine manifest']) {
  for (const change of ['edit', 'delete']) test(`app specification rejects ${definition} ${change} while waiting for the build lock`, async t => {
    const f = fixture(t);
    const spec = makeBuildSpec({...f, frontend: 'yonk', game: 'Story', mode: 'deployment', platform: 'darwin'});
    const release = await acquireBuildLock(spec.generatedRoot);
    t.after(release);
    const waiting = buildGame(spec, f).then(result => ({result}), error => ({error}));
    const file = definition === 'catalog' ? path.join(f.packageRoot, 'gnusto-games.json') : path.join(definition === 'author manifest' ? f.packageRoot : f.engineRoot, 'Package.swift');
    if (change === 'delete') fs.unlinkSync(file);
    else fs.appendFileSync(file, '\n');
    await release();
    const outcome = await waiting;
    assert(outcome.error, 'a captured app specification must not label old metadata with a new definition fingerprint');
    assert.match(outcome.error.message, /definition changed|ENOENT/);
    assert.equal(f.log().length, 0);
    assert.equal(fs.existsSync(path.join(spec.generatedRoot, 'build-state.json')), false);
  });
}

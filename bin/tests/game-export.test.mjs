import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {watch} from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import test from 'node:test';
import {spawnSync} from 'node:child_process';
import {stageTerminalExport} from '../lib/game-export.mjs';

async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'gnusto-export-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const binDirectory = path.join(root, 'build');
  const binary = path.join(binDirectory, 'Story');
  const destination = path.join(root, 'dist', 'Story');
  await fs.mkdir(binDirectory, {recursive: true});
  await fs.mkdir(path.dirname(destination), {recursive: true});
  await fs.writeFile(destination, '#!/bin/sh\necho previous\n', {mode: 0o755});
  await fs.writeFile(binary, '#!/bin/sh\necho replacement\n', {mode: 0o755});
  return {root, binDirectory, binary, destination};
}
const run = binary => spawnSync(binary, {encoding: 'utf8'});

test('a missing build output leaves the previous executable usable', async t => {
  const f = await fixture(t);
  await fs.rm(f.binary);
  await assert.rejects(stageTerminalExport(f));
  assert.equal(run(f.destination).stdout, 'previous\n');
});

test('resource-free exports atomically replace the inode and preserve execute permissions', async t => {
  const f = await fixture(t);
  const before = await fs.stat(f.destination);
  const staged = await stageTerminalExport(f);
  assert.equal(staged.binary, f.destination);
  assert.deepEqual(staged.resources, []);
  assert.notEqual((await fs.stat(f.destination)).ino, before.ino);
  assert.equal(run(f.destination).stdout, 'replacement\n');
  assert.equal((await fs.lstat(f.destination)).isSymbolicLink(), false);
});

test('nonexecutable build output cannot replace an existing export', async t => {
  const f = await fixture(t);
  await fs.chmod(f.binary, 0o644);
  await assert.rejects(stageTerminalExport(f), /executable/i);
  assert.equal(run(f.destination).stdout, 'previous\n');
});

async function resources(f, suffix = '.bundle') {
  const name = `Story_Story${suffix}`;
  await fs.mkdir(path.join(f.binDirectory, name));
  await fs.writeFile(path.join(f.binDirectory, name, 'text.txt'), 'resource');
  const accessor = path.join(f.binDirectory, 'Story.build', 'DerivedSources', 'resource_bundle_accessor.swift');
  await fs.mkdir(path.dirname(accessor), {recursive: true});
  await fs.writeFile(accessor, `let mainPath = Bundle.main.bundleURL.appendingPathComponent("${name}").path`);
  const object = path.join(f.binDirectory, 'Story.build', 'resource_bundle_accessor.swift.o');
  await fs.writeFile(path.join(f.binDirectory, 'description.json'), JSON.stringify({
    writeCommands: {[path.join(f.binDirectory, 'Story.product', 'Objects.LinkFileList')]: {inputs: [{kind: 'file', name: object}]}},
    swiftCommands: {Story: {moduleName: 'Story', objects: [object], inputs: [{name: accessor}]}}
  }));
  await fs.mkdir(path.join(f.binDirectory, 'Stale_Deleted.bundle'));
  await fs.mkdir(path.join(f.binDirectory, 'GnustoTestSupport_GnustoTestSupport.bundle'));
  return name;
}

for (const suffix of ['.bundle', '.resources']) {
  test(`resources in the linked graph are staged adjacent with a relative deployment link (${suffix})`, async t => {
    const f = await fixture(t);
    const name = await resources(f, suffix);
    const first = await stageTerminalExport(f);
    assert.equal((await fs.lstat(f.destination)).isSymbolicLink(), true);
    assert.equal(path.isAbsolute(await fs.readlink(f.destination)), false);
    assert.deepEqual(first.resources.map(resource => path.basename(resource)), [name]);
    assert.equal(await fs.realpath(path.dirname(first.resources[0])), path.dirname(await fs.realpath(f.destination)));
    assert.equal(await fs.readFile(path.join(first.resources[0], 'text.txt'), 'utf8'), 'resource');
    assert.equal(run(f.destination).stdout, 'replacement\n');
    const oldDistribution = path.dirname(await fs.realpath(f.destination));
    await stageTerminalExport(f);
    assert.notEqual(path.dirname(await fs.realpath(f.destination)), oldDistribution);
    assert.equal(run(path.join(oldDistribution, 'Story')).stdout, 'replacement\n');
  });
}

test('a missing linked bundle leaves the previous export usable', async t => {
  const f = await fixture(t);
  const name = await resources(f);
  await fs.rm(path.join(f.binDirectory, name), {recursive: true});
  await assert.rejects(stageTerminalExport(f), /resource|ENOENT/i);
  assert.equal(run(f.destination).stdout, 'previous\n');
});

test('an interrupted stage leaves the previous export usable', async t => {
  const f = await fixture(t);
  await resources(f);
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(stageTerminalExport({...f, signal: controller.signal}), /abort/i);
  assert.equal(run(f.destination).stdout, 'previous\n');
});

async function cliFixture(t) {
  const f = await fixture(t);
  const author = path.join(f.root, 'author space $(touch sentinel)');
  const engine = path.join(f.root, 'engine');
  const terminal = path.join(f.root, 'terminal space $(touch sentinel)');
  for (const dir of [author, engine, terminal]) await fs.mkdir(dir, {recursive: true});
  const traits = 'traits: [.trait(name: "Playtest"), .default(enabledTraits: ["Playtest"])]';
  await fs.writeFile(path.join(engine, 'Package.swift'), `// swift-tools-version: 6.2\n${traits}`);
  await fs.writeFile(path.join(terminal, 'Package.swift'), `// swift-tools-version: 6.2\n${traits}`);
  await fs.writeFile(path.join(author, 'Package.swift'), `// swift-tools-version: 6.2\n${traits}\n.package(name: "Gnusto", path: ${JSON.stringify(engine)})`);
  await fs.writeFile(path.join(author, 'gnusto-games.json'), JSON.stringify({version: 1, package: 'Story', games: [{name: 'Story', product: 'StoryLibrary', module: 'Story', symbol: 'game'}]}));
  const swift = path.join(f.root, 'swift');
  await fs.writeFile(swift, `#!/usr/bin/env node\nimport fs from 'node:fs';import path from 'node:path';\nconst a=process.argv.slice(2);fs.appendFileSync(process.env.LOG,JSON.stringify(a)+'\\n');\nif(a[0]==='--version'){console.log('Swift fixture');process.exit(0)}\nif(process.env.FAIL_BUILD){process.exit(1)}\nconst scratch=a[a.indexOf('--scratch-path')+1];const bin=path.join(scratch,'bin');\nif(a.includes('--show-bin-path'))console.log(bin);\nelse{fs.mkdirSync(bin,{recursive:true});fs.writeFileSync(path.join(bin,a[a.indexOf('--product')+1]),'#!/bin/sh\\nIFS= read -r text\\nprintf "%s\\\\n" "$text"\\nexit 7\\n',{mode:0o755})}\n`, {mode: 0o755});
  const environment = {...process.env, GNUSTO_PACKAGE_PATH: author, GNUSTO_REPO: engine, GNUSTO_TERMINAL_PATH: terminal, GNUSTO_SWIFT: swift, LOG: path.join(f.root, 'swift.log')};
  const command = (script, args = [], env = {}) => spawnSync(path.resolve('bin', script), args, {cwd: os.tmpdir(), env: {...environment, ...env}, encoding: 'utf8', input: 'literal input\n', timeout: 30_000});
  return {...f, author, engine, terminal, environment, command};
}

test('run-game preserves stdin and game exit status through the development launcher', async t => {
  const f = await cliFixture(t);
  const result = f.command('run-game', ['Story']);
  assert.equal(result.status, 7, result.stderr);
  assert.equal(result.stdout, 'literal input\n');
  const args = (await fs.readFile(f.environment.LOG, 'utf8')).trim().split('\n').map(JSON.parse).find(args => args.includes('--product'));
  assert.equal(args[args.indexOf('--configuration') + 1], 'debug');
  assert.equal(args.includes('--disable-default-traits'), false);
  assert.equal(await fs.access(path.join(f.root, 'sentinel')).then(() => true, () => false), false);
});

test('export lists catalog names without Swift and builds deployment separately', async t => {
  const f = await cliFixture(t);
  const listed = f.command('export-game');
  assert.equal(listed.status, 0, listed.stderr);
  assert.equal(listed.stdout, 'Story\n');
  assert.equal(await fs.access(f.environment.LOG).then(() => true, () => false), false);
  const exported = f.command('export-game', ['Story']);
  assert.equal(exported.status, 0, exported.stderr);
  const args = (await fs.readFile(f.environment.LOG, 'utf8')).trim().split('\n').map(JSON.parse).find(args => args.includes('--product'));
  assert.equal(args[args.indexOf('--configuration') + 1], 'release');
  assert.equal(args.includes('--disable-default-traits'), true);
  assert.match(args[args.indexOf('--scratch-path') + 1], /deployment/);
  assert.equal(spawnSync(path.join(f.author, 'dist', 'Story'), {input: 'deployed\n', encoding: 'utf8'}).stdout, 'deployed\n');
});

for (const scenario of ['missing terminal', 'unknown frontend', 'missing frontend', 'failed Swift']) {
  test(`failed export (${scenario}) preserves the prior executable`, async t => {
    const f = await cliFixture(t);
    const destination = path.join(f.author, 'dist', 'Story');
    await fs.mkdir(path.dirname(destination));
    await fs.copyFile(f.destination, destination);
    let args = ['Story'], env = {};
    if (scenario === 'missing terminal') env.GNUSTO_TERMINAL_PATH = path.join(f.root, 'absent');
    if (scenario === 'unknown frontend') args.push('--frontend', 'unknown');
    if (scenario === 'missing frontend') args.push('--frontend');
    if (scenario === 'failed Swift') env.FAIL_BUILD = '1';
    const failed = f.command('export-game', args, env);
    assert.equal(failed.status, 2, failed.stderr);
    assert.equal(run(destination).stdout, 'previous\n');
  });
}


test('an interruption after distribution staging begins leaves the previous executable usable', async t => {
  const f = await fixture(t);
  const name = await resources(f);
  // APFS clones a large file immediately; many entries keep staging in flight
  // while the real filesystem watcher delivers its creation event.
  for (let i = 0; i < 100; i++) await fs.writeFile(path.join(f.binDirectory, name, `entry-${i}.dat`), 'resource');
  const controller = new AbortController();
  let observedStaging = false;
  const watcher = watch(path.dirname(f.destination), (event, filename) => {
    if (filename?.startsWith('Story-')) {
      observedStaging = true;
      controller.abort();
    }
  });
  try {
    await assert.rejects(stageTerminalExport({...f, signal: controller.signal}), /abort/i);
    assert.equal(observedStaging, true);
    assert.equal(run(f.destination).stdout, 'previous\n');
    assert.deepEqual(await fs.readdir(path.dirname(f.destination)), ['Story']);
  } finally { watcher.close(); }
});

test('the Swift build linked graph refuses test-only modules before replacing an export', async t => {
  const f = await fixture(t);
  const binDirectory = path.join(f.root, 'scratch', 'out', 'Products', 'Release');
  await fs.mkdir(binDirectory, {recursive: true});
  const binary = path.join(binDirectory, 'PrivateLauncher');
  await fs.copyFile(f.binary, binary);
  const metadata = path.join(f.root, 'scratch', 'out', 'Intermediates.noindex', 'XCBuildData', 'current.xcbuilddata');
  await fs.mkdir(metadata, {recursive: true});
  await fs.writeFile(path.join(metadata, 'manifest.json'), JSON.stringify({commands: {link: {description: 'Ld PrivateLauncher normal', outputs: [await fs.realpath(binary)], inputs: [path.join(f.root, 'GnustoTestSupport.build', 'helper.o')]}}}));
  await assert.rejects(stageTerminalExport({...f, binary, binDirectory}), /test.only module/i);
  assert.equal(run(f.destination).stdout, 'previous\n');
});

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {stageApp, appIdentity, appFilename} from '../lib/game-app.mjs';

async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'gnusto-app-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const binDirectory = path.join(root, 'build');
  await fs.mkdir(binDirectory);
  const binary = path.join(binDirectory, 'Launcher');
  await fs.writeFile(binary, '#!/bin/sh\necho replacement\n', {mode: 0o755});
  const destination = path.join(root, 'Story.app');
  await fs.mkdir(destination);
  await fs.writeFile(path.join(destination, 'old'), 'qualified');
  const accessor = path.join(binDirectory, 'resource_bundle_accessor.swift');
  await fs.writeFile(accessor, 'let mainPath = Bundle.main.resourceURL.appendingPathComponent("Yonk_Yonk.bundle").path');
  await fs.writeFile(path.join(binDirectory, 'description.json'), JSON.stringify({writeCommands: {[path.join(binDirectory, 'Launcher.product/Objects.LinkFileList')]: {inputs: [{kind: 'file', name: 'yonk.o'}]}}, swiftCommands: {Yonk: {moduleName: 'Yonk', objects: ['yonk.o'], inputs: [{name: accessor}]}}}));
  await fs.mkdir(path.join(binDirectory, 'Yonk_Yonk.bundle'));
  await fs.writeFile(path.join(binDirectory, 'Yonk_Yonk.bundle/CRTShaders.metal'), 'shader');
  await fs.mkdir(path.join(binDirectory, 'Unlinked.bundle'));
  const calls = [];
  const operations = {
    sign: async app => { calls.push('sign'); await fs.writeFile(path.join(app, 'signature'), 'signed'); },
    verify: async app => { calls.push('verify'); assert.equal(await fs.readFile(path.join(app, 'signature'), 'utf8'), 'signed'); },
    publish: async (app, target) => { calls.push('publish'); await fs.rm(target, {recursive: true}); await fs.rename(app, target); }
  };
  return {root, binary, binDirectory, destination, title: 'A & B', identifier: appIdentity('Author', 'Story'), operations, calls};
}

test('app names encode unsafe title characters without collisions; identity is stable and package-specific', () => {
  assert.equal(appFilename('A/B'), 'A%2FB.app');
  assert.notEqual(appFilename('A/B'), appFilename('A%2FB'));
  assert.notEqual(appIdentity('Author', 'Story'), appIdentity('Other', 'Story'));
  assert.equal(appIdentity('Author', 'Story'), appIdentity('Author', 'Story'));
  assert.throws(() => appFilename(''), /title/i);
});

test('app stages only linked resources, signs after assembly, and relocates as one real directory', async t => {
  const f = await fixture(t);
  await stageApp({...f, validate: async app => {
    f.calls.push('validate');
    assert.equal(await fs.readFile(path.join(app, 'Contents/Resources/Yonk_Yonk.bundle/CRTShaders.metal'), 'utf8'), 'shader');
  }});
  assert.deepEqual(f.calls, ['sign', 'verify', 'validate', 'verify', 'publish']);
  const moved = path.join(f.root, 'recipient.app');
  await fs.rename(f.destination, moved);
  await fs.rm(f.binDirectory, {recursive: true});
  assert.equal((await fs.lstat(moved)).isSymbolicLink(), false);
  assert.equal(await fs.readFile(path.join(moved, 'Contents/Resources/Yonk_Yonk.bundle/CRTShaders.metal'), 'utf8'), 'shader');
  assert.deepEqual(await fs.readdir(path.join(moved, 'Contents/Resources')), ['GnustoBuild.json', 'Yonk_Yonk.bundle']);
  assert.match(await fs.readFile(path.join(moved, 'Contents/Info.plist'), 'utf8'), /A &amp; B/);
});

for (const step of ['sign', 'verify', 'validate', 'source stability', 'publish']) test(`failed ${step} preserves the prior complete app`, async t => {
  const f = await fixture(t);
  const fail = async () => { throw new Error(`failed ${step}`); };
  if (['sign', 'verify', 'publish'].includes(step)) f.operations[step] = fail;
  await assert.rejects(stageApp({...f, validate: step === 'validate' ? fail : undefined, assertCurrent: step === 'source stability' ? fail : undefined}), /failed/);
  assert.equal(await fs.readFile(path.join(f.destination, 'old'), 'utf8'), 'qualified');
  assert.deepEqual((await fs.readdir(f.root)).sort(), ['Story.app', 'build']);
});

for (const mutation of ['missing', 'symlink', 'edited while signing', 'deleted while signing']) test(`resource ${mutation} cannot publish a new app`, async t => {
  const f = await fixture(t), resource = path.join(f.binDirectory, 'Yonk_Yonk.bundle/CRTShaders.metal');
  if (mutation === 'missing') await fs.rm(path.dirname(resource), {recursive: true});
  if (mutation === 'symlink') { await fs.rm(resource); await fs.symlink(f.binary, resource); }
  if (mutation.includes('signing')) f.operations.sign = async () => { if (mutation.startsWith('edited')) await fs.writeFile(resource, 'changed'); else await fs.rm(resource); };
  await assert.rejects(stageApp(f));
  assert.equal(await fs.readFile(path.join(f.destination, 'old'), 'utf8'), 'qualified');
});

test('native resource accessors that rely on the build directory are rejected before signing', async t => {
  const f = await fixture(t);
  await fs.writeFile(path.join(f.binDirectory, 'resource_bundle_accessor.swift'), 'Bundle.main.bundleURL.appendingPathComponent("Yonk_Yonk.bundle")');
  await assert.rejects(stageApp(f), /cannot relocate.*swiftbuild/);
  assert.deepEqual(f.calls, []);
  assert.equal(await fs.readFile(path.join(f.destination, 'old'), 'utf8'), 'qualified');
});

test('actual macOS signatures and directory swap survive relocation and preserve the prior app on failure', {skip: process.platform !== 'darwin'}, async t => {
  const f = await fixture(t);
  const {execFile} = await import('node:child_process');
  const {promisify} = await import('node:util');
  const execute = promisify(execFile);
  const source = path.join(f.root, 'main.c');
  await fs.writeFile(source, '#include <stdio.h>\nint main(void) { puts("APP_RELOCATED"); return 0; }\n');
  await execute('xcrun', ['clang', source, '-o', f.binary]);
  const options = {...f, operations: undefined};
  await fs.rm(f.destination, {recursive: true});
  await stageApp(options);
  const oldInode = (await fs.stat(f.destination)).ino;
  await stageApp(options);
  assert.notEqual((await fs.stat(f.destination)).ino, oldInode);
  await assert.rejects(stageApp({...options, validate: async () => { throw new Error('failed qualification'); }}), /failed qualification/);
  await assert.rejects(stageApp({...options, validate: app => fs.writeFile(path.join(app, 'Contents/Resources/Yonk_Yonk.bundle/CRTShaders.metal'), 'unsigned mutation')}));
  const icon = path.join(f.root, 'empty.icns');
  await fs.writeFile(icon, Buffer.from([105, 99, 110, 115, 0, 0, 0, 8]));
  await assert.rejects(stageApp({...options, icon}), /iconutil/);
  await execute('/usr/bin/codesign', ['--verify', '--deep', '--strict', f.destination]);
  const relocated = path.join(f.root, 'Recipient.app');
  await fs.rename(f.destination, relocated);
  await fs.rm(f.binDirectory, {recursive: true});
  await execute('/usr/bin/codesign', ['--verify', '--deep', '--strict', relocated]);
  assert.equal((await execute(path.join(relocated, 'Contents/MacOS/Game'))).stdout, 'APP_RELOCATED\n');
});

test('interruption after validation preserves the previous app', async t => {
  const f = await fixture(t), controller = new AbortController();
  await assert.rejects(stageApp({...f, signal: controller.signal, validate: async () => controller.abort()}), /abort/i);
  assert.equal(await fs.readFile(path.join(f.destination, 'old'), 'utf8'), 'qualified');
});

test('invalid icon input preserves the prior app before signing', async t => {
  const f = await fixture(t), icon = path.join(f.root, 'bad.icns');
  await fs.writeFile(icon, 'not an icon');
  await assert.rejects(stageApp({...f, icon}), /ICNS/);
  assert.deepEqual(f.calls, []);
  assert.equal(await fs.readFile(path.join(f.destination, 'old'), 'utf8'), 'qualified');
});

for (const cleanup of ['displaced app', 'publication helper']) test(`${cleanup} cleanup failure after commit does not report a failed replacement`, {skip: process.platform !== 'darwin'}, async t => {
  const f = await fixture(t);
  const {execFile} = await import('node:child_process'), {promisify} = await import('node:util');
  const execute = promisify(execFile), source = path.join(f.root, 'main.c');
  await fs.writeFile(source, 'int main(void) { return 0; }');
  await execute('xcrun', ['clang', source, '-o', f.binary]);
  const original = fs.rm, leftovers = [];
  fs.rm = async function(file, ...args) {
    const target = String(file);
    if ((cleanup === 'displaced app' && target.startsWith(path.join(f.root, '.Story.app.'))) || (cleanup === 'publication helper' && path.basename(target).startsWith('gnusto-publish-'))) {
      leftovers.push(target);
      throw Object.assign(new Error('injected cleanup failure'), {code: 'EACCES'});
    }
    return original.call(this, file, ...args);
  };
  let result;
  try { result = await stageApp({...f, operations: undefined}); }
  finally { fs.rm = original; for (const file of leftovers) await fs.rm(file, {recursive: true, force: true}); }
  assert.equal(result.app, f.destination);
  await execute('/usr/bin/codesign', ['--verify', '--deep', '--strict', f.destination]);
});

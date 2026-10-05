import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath} from 'node:url';
import {randomUUID} from 'node:crypto';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {linkedResources, validateRuntime, validateTree, digestFiles} from './game-export.mjs';
import {acquireBuildLock, assertBuildCurrent} from './game-build.mjs';
const execute = promisify(execFile);
const here = path.dirname(fileURLToPath(import.meta.url));
const xml = value => String(value).replace(/[<>&"']/g, c => ({'<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;'}[c]));
export function appFilename(title) {
  if (typeof title !== 'string' || !title.trim() || /[\x00-\x1f\x7f]/.test(title)) throw new Error('App title must be nonempty printable text');
  return encodeURIComponent(title).replace(/%20/g, ' ') + '.app';
}
export {appIdentity} from './game-build.mjs';
async function publish(app, destination, {signal} = {}) {
  const work = await fs.mkdtemp(path.join(os.tmpdir(), 'gnusto-publish-'));
  try {
    const helper = path.join(work, 'publish');
    await execute('xcrun', ['clang', '-Wall', '-Werror', path.join(here, 'atomic-app-publish.c'), '-o', helper], {signal, timeout: 60000});
    signal?.throwIfAborted();
    await execute(helper, [app, destination], {timeout: 15000});
  } finally { await fs.rm(work, {recursive: true, force: true}); }
}
const nativeOperations = {
  verifyIcon: async icon => {
    const work = await fs.mkdtemp(path.join(os.tmpdir(), 'gnusto-icon-'));
    try { await execute('/usr/bin/iconutil', ['--convert', 'iconset', '--output', path.join(work, 'Game.iconset'), icon], {timeout: 15000}); }
    finally { await fs.rm(work, {recursive: true, force: true}); }
  },
  sign: app => execute('/usr/bin/codesign', ['--force', '--sign', '-', '--timestamp=none', app], {timeout: 30000}),
  verify: app => execute('/usr/bin/codesign', ['--verify', '--deep', '--strict', app], {timeout: 30000}),
  publish
};
export async function stageApp({binary, binDirectory = path.dirname(binary), destination, title, identifier, icon, fingerprint, signal, validate = async () => {}, assertCurrent = async () => {}, operations = nativeOperations}) {
  signal?.throwIfAborted();
  appFilename(title);
  if (!/^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(identifier)) throw new Error('Invalid app bundle identifier');
  if (!destination.endsWith('.app')) throw new Error('App destination must end in .app');
  const previous = await fs.lstat(destination).catch(error => { if (error.code !== 'ENOENT') throw error; });
  if (previous && (!previous.isDirectory() || previous.isSymbolicLink())) throw new Error('App destination must be a real directory');
  const stat = await fs.lstat(binary);
  if (!stat.isFile() || !(stat.mode & 0o111)) throw new Error('Build output is not an executable file');
  await validateRuntime(binary);
  const names = await linkedResources(binary, binDirectory, {app: true});
  for (const name of names) {
    if (!(await fs.lstat(path.join(binDirectory, name))).isDirectory()) throw new Error(`Resource is not a bundle directory: ${name}`);
    await validateTree(path.join(binDirectory, name));
  }
  if (icon) {
    const bytes = await fs.readFile(icon);
    if (bytes.length < 8 || bytes.subarray(0, 4).toString() !== 'icns' || bytes.readUInt32BE(4) !== bytes.length) throw new Error('App icon must be an ICNS file');
  }
  const sources = [['binary', binary], ...names.map(name => [name, path.join(binDirectory, name)]), ...(icon ? [['icon', icon]] : [])];
  const before = await digestFiles(sources);
  const parent = path.dirname(destination);
  await fs.mkdir(parent, {recursive: true});
  const temporary = path.join(parent, `.${path.basename(destination)}.${randomUUID()}.app`);
  try {
    const contents = path.join(temporary, 'Contents'), resources = path.join(contents, 'Resources');
    await fs.mkdir(path.join(contents, 'MacOS'), {recursive: true});
    await fs.mkdir(resources);
    const stagedBinary = path.join(contents, 'MacOS/Game');
    await fs.copyFile(binary, stagedBinary, fs.constants.COPYFILE_EXCL);
    await fs.chmod(stagedBinary, stat.mode & 0o777);
    for (const name of names) await fs.cp(path.join(binDirectory, name), path.join(resources, name), {recursive: true, errorOnExist: true, force: false});
    if (icon) {
      await fs.copyFile(icon, path.join(resources, 'Game.icns'));
      await operations.verifyIcon?.(path.join(resources, 'Game.icns'));
    }
    const fields = {CFBundleExecutable: 'Game', CFBundleIdentifier: identifier, CFBundleName: title, CFBundleDisplayName: title, CFBundlePackageType: 'APPL', CFBundleShortVersionString: '1.0', CFBundleVersion: '1', LSMinimumSystemVersion: '15.0', NSMicrophoneUsageDescription: 'Use the microphone to speak commands in this game.', NSSpeechRecognitionUsageDescription: 'Recognize spoken commands in this game.', ...(icon ? {CFBundleIconFile: 'Game.icns'} : {})};
    await fs.writeFile(path.join(contents, 'Info.plist'), '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict>\n' + Object.entries(fields).map(([key, value]) => `<key>${key}</key><string>${xml(value)}</string>`).join('\n') + '\n<key>NSHighResolutionCapable</key><true/>\n</dict></plist>\n');
    await fs.writeFile(path.join(resources, 'GnustoBuild.json'), JSON.stringify({fingerprint, identifier, title, resources: names, inputDigest: before}, null, 2) + '\n');
    await validateTree(temporary);
    const copies = [['binary', stagedBinary], ...names.map(name => [name, path.join(resources, name)]), ...(icon ? [['icon', path.join(resources, 'Game.icns')]] : [])];
    if (await digestFiles(copies) !== before) throw new Error('App inputs changed while staging');
    await validateRuntime(stagedBinary);
    signal?.throwIfAborted();
    await operations.sign(temporary);
    await operations.verify(temporary);
    await validate(temporary);
    await operations.verify(temporary);
    if (await digestFiles(sources) !== before) throw new Error('App inputs changed during qualification');
    await assertCurrent();
    signal?.throwIfAborted();
    await operations.publish(temporary, destination, {signal});
    return {app: destination, binary: path.join(destination, 'Contents/MacOS/Game'), resources: names.map(name => path.join(destination, 'Contents/Resources', name))};
  } finally { await fs.rm(temporary, {recursive: true, force: true}); }
}

export async function assembleGameApp(spec, built, {destinationDirectory = spec.generatedRoot, environment = process.env, swift = environment.GNUSTO_SWIFT || 'swift', signal} = {}) {
  if (process.platform !== 'darwin' || spec.frontend !== 'yonk') throw new Error('App assembly requires the Yonk frontend on macOS');
  const unlock = await acquireBuildLock(spec.generatedRoot);
  try {
    const assertCurrent = () => assertBuildCurrent(spec, built, {swift, environment});
    await assertCurrent();
    const {stdout} = await execute(built.binary, ['--gnusto-app-metadata'], {timeout: 15000, maxBuffer: 1024 * 1024});
    const {title} = JSON.parse(stdout);
    const destination = path.join(destinationDirectory, appFilename(title));
    return await stageApp({...built, destination, title, identifier: environment.GNUSTO_APP_BUNDLE_ID || spec.appIdentifier, icon: environment.GNUSTO_APP_ICON, signal, assertCurrent, validate: async app => {
      const result = await execute(path.join(app, 'Contents/MacOS/Game'), ['--gnusto-verify-app'], {timeout: 30000, maxBuffer: 1024 * 1024});
      if (JSON.parse(result.stdout).title !== title) throw new Error('Staged game metadata differs from the built game');
    }});
  } finally { await unlock(); }
}

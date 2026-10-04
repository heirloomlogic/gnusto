import fs from 'node:fs/promises';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';

const bundleSuffix = /\.(bundle|resources)$/;
const forbidden = /(^|[/_])(?:GnustoTestSupport|Testing|SwiftTesting)(?:[._/]|$)/i;
async function readJSON(file) { return JSON.parse(await fs.readFile(file, 'utf8')); }
async function exists(file) { try { await fs.access(file); return true; } catch (error) { if (error.code === 'ENOENT') return false; throw error; } }

// Derive resources from linked modules, rather than copying stale bundles left
// beside an executable by a previous dependency graph.
async function linkedResources(binary, binDirectory) {
  const description = path.join(binDirectory, 'description.json');
  const names = new Set();
  if (await exists(description)) {
    const graph = await readJSON(description);
    const link = Object.entries(graph.writeCommands ?? {}).find(([name]) => path.basename(path.dirname(name)) === `${path.basename(binary)}.product` && path.basename(name) === 'Objects.LinkFileList');
    if (!link) throw new Error('Cannot resolve executable resource graph from SwiftPM description');
    const objects = new Set(link[1].inputs.filter(input => input.kind === 'file').map(input => input.name));
    for (const command of Object.values(graph.swiftCommands ?? {})) {
      if (!command.objects?.some(object => objects.has(object))) continue;
      if (forbidden.test(command.moduleName)) throw new Error(`Test-only module in deployment graph: ${command.moduleName}`);
      for (const input of command.inputs ?? []) if (path.basename(input.name) === 'resource_bundle_accessor.swift') {
        const source = await fs.readFile(input.name, 'utf8');
        for (const match of source.matchAll(/appendingPathComponent\("([^"/\\]+\.(?:bundle|resources))"\)/g)) names.add(match[1]);
      }
    }
  } else {
    const metadata = path.resolve(binDirectory, '../../Intermediates.noindex/XCBuildData');
    if (await exists(metadata)) {
      const candidates = await Promise.all((await fs.readdir(metadata)).filter(name => name.endsWith('.xcbuilddata')).map(async name => {
        const file = path.join(metadata, name, 'manifest.json');
        return {file, modified: (await fs.stat(file)).mtimeMs};
      }));
      candidates.sort((a, b) => b.modified - a.modified);
      const actualBinary = await fs.realpath(binary);
      let found = false;
      for (const {file} of candidates) {
        const graph = await readJSON(file);
        const commands = Object.values(graph.commands ?? {});
        const root = commands.find(command => command.description?.startsWith('Ld ') && command.outputs?.includes(actualBinary));
        if (!root) continue;
        found = true;
        const producers = new Map();
        for (const command of commands) for (const output of command.outputs ?? []) {
          if (!producers.has(output)) producers.set(output, []);
          producers.get(output).push(command);
        }
        const pending = [...root.inputs], visited = new Set();
        const actualBin = await fs.realpath(binDirectory);
        while (pending.length) {
          const node = pending.pop();
          if (visited.has(node)) continue;
          visited.add(node);
          if (forbidden.test(node) && (/\.(?:o|a|dylib)$/.test(node) || node.includes('.framework/'))) throw new Error(`Test-only module in deployment graph: ${node}`);
          if (node.startsWith(actualBin + path.sep)) {
            const name = path.relative(actualBin, node).split(path.sep)[0];
            if (bundleSuffix.test(name)) names.add(name);
          }
          for (const command of producers.get(node) ?? []) pending.push(...(command.inputs ?? []));
        }
        break;
      }
      if (!found) throw new Error('Cannot resolve executable resource graph from Swift build manifest');
    } else if ((await fs.readdir(binDirectory)).some(name => bundleSuffix.test(name))) {
      throw new Error('Resource bundles exist but the executable dependency graph is unavailable');
    }
  }
  for (const name of names) if (forbidden.test(name)) throw new Error(`Test-only resource in deployment graph: ${name}`);
  return [...names].sort();
}

const execute = promisify(execFile);
const macSystem = file => file.startsWith('/usr/lib/') || file.startsWith('/System/Library/');
const linuxSystem = file => /^\/(?:usr\/)?lib(?:64)?\//.test(file);
// Linux exports require the recipient's base C/C++/POSIX runtime, not a Swift
// toolchain installation. Swift/Foundation and package shared products must be
// linked statically; their filenames alone never establish runtime availability.
const linuxRuntime = new Set(['libc.so.6', 'libm.so.6', 'libdl.so.2', 'libpthread.so.0', 'librt.so.1', 'libgcc_s.so.1', 'libstdc++.so.6', 'libatomic.so.1', 'libresolv.so.2', 'libutil.so.1']);
// ELF e_machine: EM_X86_64 = 62, EM_AARCH64 = 183. Loaders may also
// appear in DT_NEEDED, independently of the executable's PT_INTERP record.
const linuxLoader = new Map([[62, 'ld-linux-x86-64.so.2'], [183, 'ld-linux-aarch64.so.1']]);
/**
 * Classifies a Linux base-runtime SONAME; resolved path and ELF machine validation remain mandatory.
 * @param {string} soname Runtime library basename.
 * @param {number} machine Executable's ELF e_machine value.
 * @returns {boolean} Whether the SONAME belongs to the supported base runtime.
 */
export function isLinuxRuntimeLibrary(soname, machine) {
  return linuxRuntime.has(soname) || linuxLoader.get(machine) === soname;
}
const unsupportedLibrary = (library, detail) => new Error(`Unsupported shared library dependency ${library}${detail ? ` (${detail})` : ''}; use static SwiftPM library products and statically link non-system runtimes before exporting.`);
async function inspect(tool, arguments_) {
  try { return (await execute(tool, arguments_, {maxBuffer: 8 * 1024 * 1024, env: {PATH: process.env.PATH, LC_ALL: 'C'}})).stdout; }
  catch (error) { throw new Error(`Cannot validate executable runtime dependencies with ${tool}: ${error.stderr?.trim() || error.message}`); }
}
async function header(file) {
  const handle = await fs.open(file, 'r');
  try { const bytes = Buffer.alloc(256); const {bytesRead} = await handle.read(bytes, 0, bytes.length, 0); return bytes.subarray(0, bytesRead); }
  finally { await handle.close(); }
}
async function macRuntime(candidate) {
  if (!macSystem(candidate)) return false;
  try {
    // Some OS dylibs exist only in dyld's shared cache; filesystem existence
    // alone cannot classify them. dyld_info resolves that cache as dyld does.
    const actual = await fs.realpath(candidate).catch(error => { if (error.code === 'ENOENT') return candidate; throw error; });
    if (!macSystem(actual)) return false;
    const result = await inspect('/usr/bin/dyld_info', ['-platform', candidate]);
    return result.includes('-platform:') && /macOS|zippered/.test(result);
  } catch { return false; }
}
async function validateMachO(binary) {
  const linked = await inspect('/usr/bin/otool', ['-L', binary]);
  const commands = await inspect('/usr/bin/otool', ['-l', binary]);
  const libraries = [...linked.matchAll(/^\s+(.+?) \(compatibility version/gm)].map(match => match[1]);
  const loadCount = [...commands.matchAll(/cmd LC_(?:LOAD_DYLIB|LOAD_WEAK_DYLIB|REEXPORT_DYLIB|LOAD_UPWARD_DYLIB|LAZY_LOAD_DYLIB)\n/g)].length;
  if (libraries.length !== loadCount) throw new Error('Cannot classify all Mach-O runtime dependency records');
  const rpaths = [...commands.matchAll(/cmd LC_RPATH\n\s*cmdsize \d+\n\s*path (.+?) \(offset \d+\)/g)].map(match => match[1]);
  const origin = path.dirname(await fs.realpath(binary));
  const expand = value => value.replace(/^@(?:loader_path|executable_path)(?=\/|$)/, origin);
  for (const library of new Set(libraries)) {
    const candidates = library.startsWith('@rpath/') ? rpaths.map(rpath => path.resolve(expand(rpath), library.slice('@rpath/'.length))) : [expand(library)];
    let classified = false;
    for (const raw of candidates) {
      if (!path.isAbsolute(raw) || raw.includes('@')) continue;
      const candidate = path.normalize(raw);
      if (await macRuntime(candidate)) { classified = true; break; }
      if (await exists(candidate)) throw unsupportedLibrary(library, `resolved to ${candidate}`);
    }
    if (!classified) throw unsupportedLibrary(library, 'not resolved to an OS runtime or framework');
  }
}
function elfMachine(bytes) {
  if (bytes.length < 20 || bytes[0] !== 0x7f || bytes.subarray(1, 4).toString() !== 'ELF' || ![1, 2].includes(bytes[5])) return null;
  return bytes[5] === 1 ? bytes.readUInt16LE(18) : bytes.readUInt16BE(18);
}
async function validateELF(binary, bytes) {
  const dynamic = await inspect('readelf', ['-dW', binary]);
  const program = await inspect('readelf', ['-lW', binary]);
  const interpreter = /Requesting program interpreter: ([^\]]+)\]/.exec(program)?.[1];
  const machine = elfMachine(bytes);
  const systemELF = async candidate => {
    try { const actual = await fs.realpath(candidate); return linuxSystem(actual) && elfMachine(await header(actual)) === machine; } catch { return false; }
  };
  if (interpreter && (!/^ld-(?:linux(?:-[a-zA-Z0-9_-]+)?\.so\.\d+|musl-[a-zA-Z0-9_-]+\.so\.1)$/.test(path.basename(interpreter)) || !await systemELF(interpreter))) throw unsupportedLibrary(interpreter, 'unclassified ELF interpreter');
  const libraries = [...dynamic.matchAll(/\(NEEDED\).*Shared library: \[([^\]\r\n]+)\]\s*$/gm)].map(match => match[1]);
  if (libraries.length !== [...dynamic.matchAll(/\(NEEDED\)/g)].length) throw new Error('Cannot classify all ELF runtime dependency records');
  if (!libraries.length) return;
  const runpath = /\(RUNPATH\).*Library runpath: \[([^\]]*)\]/.exec(dynamic)?.[1];
  const rpath = /\(RPATH\).*Library rpath: \[([^\]]*)\]/.exec(dynamic)?.[1];
  const origin = path.dirname(await fs.realpath(binary));
  const paths = (runpath ?? rpath ?? '').split(':').filter(Boolean).map(value => value.replace(/\$\{ORIGIN\}|\$ORIGIN/g, origin));
  const cache = await inspect('ldconfig', ['-p']);
  const cached = [...cache.matchAll(/^\s*(\S+)\s+\([^\n]+?\) => (\S+)$/gm)];
  for (const library of new Set(libraries)) {
    const candidates = library.includes('/') ? [library] : [...paths.map(directory => path.join(directory, library)), ...cached.filter(match => match[1] === library).map(match => match[2])];
    let classified = false;
    for (const candidate of candidates) {
      if (!path.isAbsolute(candidate) || candidate.includes('$')) throw unsupportedLibrary(library, 'unclassified relative loader path');
      if (!await exists(candidate)) continue;
      if (elfMachine(await header(candidate)) !== machine) continue;
      if (!isLinuxRuntimeLibrary(path.basename(library), machine) || !await systemELF(candidate)) throw unsupportedLibrary(library, `resolved to ${candidate}`);
      classified = true; break;
    }
    if (!classified) throw unsupportedLibrary(library, 'not resolved to the supported OS runtime');
  }
}
async function validateRuntime(binary) {
  const bytes = await header(binary);
  if (bytes.subarray(0, 2).toString() === '#!') {
    // CLI test/build shims are scripts; their interpreter is explicit, unlike a
    // native loader graph. Only the OS-provided shell is a portable interpreter.
    const interpreter = /^#!\s*(\S+)/.exec(bytes.toString())?.[1];
    if (!['/bin/sh', '/bin/bash'].includes(interpreter)) throw unsupportedLibrary(interpreter, 'unsupported executable interpreter');
    return;
  }
  const magic = bytes.length >= 4 ? bytes.readUInt32LE(0) : 0;
  if (process.platform === 'darwin' && [0xfeedface, 0xfeedfacf, 0xcefaedfe, 0xcffaedfe, 0xbebafeca, 0xbfbafeca, 0xcafebabe, 0xcafebabf].includes(magic)) return validateMachO(binary);
  if (process.platform === 'linux' && elfMachine(bytes) !== null) return validateELF(binary, bytes);
  throw new Error(`Cannot classify executable runtime dependencies on ${process.platform}: ${binary}`);
}

async function validateTree(directory) {
  for (const entry of await fs.readdir(directory, {withFileTypes: true})) {
    const file = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) throw new Error(`Resource bundle contains a nonportable symbolic link: ${file}`);
    if (entry.isDirectory()) await validateTree(file);
    else if (!entry.isFile()) throw new Error(`Unsupported resource entry: ${file}`);
    else await fs.access(file, fs.constants.R_OK);
  }
}

export async function stageTerminalExport({binary, binDirectory = path.dirname(binary), destination, signal}) {
  signal?.throwIfAborted();
  const stat = await fs.stat(binary);
  if (!stat.isFile() || !(stat.mode & 0o111)) throw new Error(`Build output is not executable: ${binary}`);
  await fs.access(binary, fs.constants.X_OK);
  await validateRuntime(binary);
  const names = await linkedResources(binary, binDirectory);
  for (const name of names) {
    const source = path.join(binDirectory, name);
    if (!(await fs.lstat(source)).isDirectory()) throw new Error(`Resource is not a bundle directory: ${source}`);
    await validateTree(source);
  }
  const parent = path.dirname(destination), name = path.basename(destination);
  await fs.mkdir(parent, {recursive: true});
  const identifier = randomUUID();
  const temporary = path.join(parent, `.${name}.${identifier}.tmp`);
  const distribution = path.join(parent, `${name}-${identifier}`);
  let committed = false;
  try {
    const stagedBinary = names.length ? path.join(distribution, name) : temporary;
    if (names.length) await fs.mkdir(distribution);
    await fs.copyFile(binary, stagedBinary, fs.constants.COPYFILE_EXCL);
    await fs.chmod(stagedBinary, stat.mode & 0o777);
    for (const resource of names) {
      signal?.throwIfAborted();
      await fs.cp(path.join(binDirectory, resource), path.join(distribution, resource), {recursive: true, errorOnExist: true, force: false});
      await validateTree(path.join(distribution, resource));
    }
    await fs.access(stagedBinary, fs.constants.X_OK);
    await validateRuntime(stagedBinary);
    signal?.throwIfAborted();
    if (names.length) await fs.symlink(path.relative(parent, stagedBinary), temporary);
    signal?.throwIfAborted();
    await fs.rename(temporary, destination);
    committed = true;
    return {binary: destination, resources: names.map(resource => path.join(distribution, resource))};
  } finally {
    await fs.rm(temporary, {force: true});
    if (!committed && names.length) await fs.rm(distribution, {recursive: true, force: true});
  }
}

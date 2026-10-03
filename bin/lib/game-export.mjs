import fs from 'node:fs/promises';
import path from 'node:path';
import {randomUUID} from 'node:crypto';

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

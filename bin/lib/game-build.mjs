import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
import {createHash, randomUUID} from 'node:crypto';
import {loadGames, resolveCatalogGame} from './game-catalog.mjs';
const TOOL_VERSION = 1;
const TOOL_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const REMOTE_TERMINAL = 'https://github.com/HeirloomLogic/GnustoTerminal';
const identity = location => path.basename(location.replace(/\/$/, '')).replace(/\.git$/i, '').toLowerCase();
export function swiftStringLiteral(value) {
  return '"' + String(value).replace(/[\\"\x00-\x1f\x7f]/g, character => ({'\\': '\\\\', '"': '\\"', '\n': '\\n', '\r': '\\r', '\t': '\\t'}[character] ?? `\\u{${character.charCodeAt(0).toString(16)}}`)) + '"';
}
function decodeSwiftLiteral(value) {
  return value.replace(/\\(u\{[0-9a-fA-F]+\}|[\\"nrt0])/g, (_, escape) => escape.startsWith('u{') ? String.fromCodePoint(parseInt(escape.slice(2, -1), 16)) : ({'\\': '\\', '"': '"', n: '\n', r: '\r', t: '\t', 0: '\0'}[escape]));
}
function engineDeclaration(packageRoot) {
  const text = fs.readFileSync(path.join(packageRoot, 'Package.swift'), 'utf8');
  const literal = '"((?:[^"\\\\]|\\\\.)*)"';
  const namedPath = new RegExp('\\.package\\(\\s*name:\\s*"Gnusto"\\s*,\\s*path:\\s*' + literal).exec(text);
  if (namedPath) return {kind: 'path', location: path.resolve(packageRoot, decodeSwiftLiteral(namedPath[1]))};
  const paths = [...text.matchAll(new RegExp('\\.package\\(\\s*path:\\s*' + literal, 'g'))];
  for (const match of paths) {
    const location = path.resolve(packageRoot, decodeSwiftLiteral(match[1]));
    try { if (/name:\s*"Gnusto"/.test(fs.readFileSync(path.join(location, 'Package.swift'), 'utf8'))) return {kind: 'path', location}; } catch {}
  }
  const urls = [...text.matchAll(new RegExp('\\.package\\(\\s*(?:name:\\s*"Gnusto"\\s*,\\s*)?url:\\s*' + literal, 'g'))];
  for (const match of urls) {
    const location = decodeSwiftLiteral(match[1]);
    if (identity(location) === 'gnusto') return {kind: 'url', location};
  }
  throw new Error(`Cannot identify Gnusto dependency in ${packageRoot}/Package.swift; use a literal Gnusto path or URL dependency.`);
}
export function findEngineRoot(packageRoot, environment = process.env) {
  if (environment.GNUSTO_REPO) return path.resolve(environment.GNUSTO_REPO);
  if (path.resolve(packageRoot) === TOOL_ROOT) return TOOL_ROOT;
  const checkouts = path.join(packageRoot, '.build', 'checkouts');
  if (fs.existsSync(checkouts)) for (const entry of fs.readdirSync(checkouts)) {
    const candidate = path.join(checkouts, entry);
    if (fs.existsSync(path.join(candidate, 'Sources/Gnusto')) && fs.existsSync(path.join(candidate, 'bin/lib/playtest-focus.js'))) return fs.realpathSync(candidate);
  }
  const dependency = engineDeclaration(packageRoot);
  if (dependency.kind === 'path') return fs.realpathSync(dependency.location);
  throw new Error('No Gnusto checkout found. Build the game package first or set GNUSTO_REPO.');
}
function requireTrait(root, name) {
  if (!/\.trait\(\s*name:\s*"Playtest"/.test(fs.readFileSync(path.join(root, 'Package.swift'), 'utf8'))) throw new Error(`${name} does not declare the required Playtest trait`);
}
export function makeBuildSpec({packageRoot, engineRoot, terminalRoot = process.env.GNUSTO_TERMINAL_PATH, game, mode = 'development'}) {
  if (!['development', 'deployment'].includes(mode)) throw new Error(`Unknown build mode: ${mode}`);
  packageRoot = fs.realpathSync(packageRoot);
  engineRoot = fs.realpathSync(engineRoot ?? findEngineRoot(packageRoot));
  terminalRoot = terminalRoot ? fs.realpathSync(terminalRoot) : null;
  const catalog = loadGames(packageRoot);
  game = resolveCatalogGame(catalog, typeof game === 'string' ? game : game?.name);
  const sameEngine = packageRoot === engineRoot;
  const declaration = sameEngine ? null : engineDeclaration(packageRoot);
  if (declaration?.kind === 'path' && fs.realpathSync(declaration.location) !== engineRoot) throw new Error('The author path dependency and selected engine checkout differ; keep the exact engine path declared by the author.');
  const forbiddenLauncherNames = new Set([game.name, game.product, game.module]);
  let launcherProduct = 'GnustoGeneratedLauncher';
  while (forbiddenLauncherNames.has(launcherProduct)) launcherProduct += '_';
  const launcherTarget = launcherProduct;
  const generatedRoot = path.join(packageRoot, '.build-launchers', game.name, mode);
  const generatedPackage = path.join(generatedRoot, 'package');
  const scratchPath = path.join(generatedRoot, 'scratch');
  const links = [{name: sameEngine ? 'gnusto' : identity(packageRoot), source: packageRoot}];
  const gameIdentity = links[0].name;
  const engineIdentity = declaration?.kind === 'path' ? identity(declaration.location) : declaration?.kind === 'url' ? identity(declaration.location) : 'gnusto';
  if (!sameEngine && (gameIdentity === engineIdentity || gameIdentity === 'gnustoterminal' || catalog.package.toLowerCase() === 'gnusto' || catalog.package.toLowerCase() === 'gnustoterminal')) throw new Error(`Package identity collision: ${gameIdentity}; independent authors must use a distinct package identity.`);
  if (engineIdentity === 'gnustoterminal') throw new Error('Engine package identity collision with GnustoTerminal');
  requireTrait(packageRoot, catalog.package);
  requireTrait(engineRoot, 'Gnusto');
  if (terminalRoot) { requireTrait(terminalRoot, 'GnustoTerminal'); links.push({name: 'gnustoterminal', source: terminalRoot}); }
  if (!sameEngine && declaration.kind === 'url') links.push({name: engineIdentity, source: engineRoot});
  const engineDependencyPath = declaration?.kind === 'path' ? declaration.location : path.join(generatedPackage, 'Dependencies', engineIdentity);
  const dependency = (name, location) => `.package(name: ${swiftStringLiteral(name)}, path: ${swiftStringLiteral(location)}, traits: forwarded)`;
  const dependencies = [dependency(catalog.package, `Dependencies/${gameIdentity}`), terminalRoot ? dependency('GnustoTerminal', 'Dependencies/gnustoterminal') : `.package(url: ${swiftStringLiteral(REMOTE_TERMINAL)}, branch: "main", traits: forwarded)`];
  if (!sameEngine && declaration.kind === 'url') dependencies.push(dependency('Gnusto', `Dependencies/${engineIdentity}`));
  const manifest = `// swift-tools-version: 6.2\nimport PackageDescription\n\nlet forwarded: Set<Package.Dependency.Trait> = [\n    .trait(name: "Playtest", condition: .when(traits: ["Playtest"]))\n]\nlet package = Package(\n    name: ${swiftStringLiteral(game.name + 'TerminalBuild')},\n    platforms: [.macOS(.v15)],\n    products: [.executable(name: ${swiftStringLiteral(launcherProduct)}, targets: [${swiftStringLiteral(launcherTarget)}])],\n    traits: [\n        .trait(name: "Playtest", description: "Enable the development MCP server."),\n        .default(enabledTraits: ["Playtest"]),\n    ],\n    dependencies: [\n        ${dependencies.join(',\n        ')},\n    ],\n    targets: [\n        .executableTarget(name: ${swiftStringLiteral(launcherTarget)}, dependencies: [\n            .product(name: ${swiftStringLiteral(game.product)}, package: ${swiftStringLiteral(catalog.package)}),\n            .product(name: "GnustoTerminal", package: "GnustoTerminal"),\n        ]),\n    ]\n)\n`;
  const entryPoint = `import GnustoTerminal\nimport ${game.module}\n\n#if canImport(Darwin)\nimport Darwin\n#elseif canImport(Glibc)\nimport Glibc\n#endif\n\nlet result = await TerminalLaunch.run(${game.module}.${game.symbol})\nexit(result)\n`;
  return {packageRoot: generatedPackage, gamePackageRoot: packageRoot, engineRoot, terminalRoot, game, mode, manifest, entryPoint, scratchPath, generatedRoot, links, engineDependencyPath, launcherProduct, launcherTarget};
}
function buildFlags(environment) {
  let flags;
  try { flags = JSON.parse(environment.GNUSTO_SWIFT_BUILD_FLAGS || '[]'); } catch { throw new Error('GNUSTO_SWIFT_BUILD_FLAGS must be a JSON argument array'); }
  if (!Array.isArray(flags) || flags.some(flag => typeof flag !== 'string' || flag.includes('\0'))) throw new Error('GNUSTO_SWIFT_BUILD_FLAGS must be a JSON array of strings');
  const reserved = ['--package-path', '--scratch-path', '--product', '--show-bin-path', '--disable-default-traits', '--enable-default-traits', '--traits', '--configuration', '-c'];
  if (flags.some(flag => reserved.some(option => flag === option || flag.startsWith(option + '=')))) throw new Error('GNUSTO_SWIFT_BUILD_FLAGS contains a reserved build option');
  return flags;
}
const excluded = name => ['.git', '.context', '.superpowers', '.swiftpm', 'node_modules', 'DerivedData', 'dist', '.docs-build'].includes(name) || name.startsWith('.build');
function hashTree(hash, root, relative = '', visited = new Set()) {
  if (!fs.existsSync(root)) { hash.update(`missing:${root}`); return; }
  const actual = fs.realpathSync(root);
  const stat = fs.statSync(root);
  hash.update(JSON.stringify([relative, stat.isDirectory() ? 'directory' : 'file', fs.lstatSync(root).isSymbolicLink() ? fs.readlinkSync(root) : null]));
  if (visited.has(actual)) return;
  if (stat.isDirectory()) {
    visited.add(actual);
    for (const name of fs.readdirSync(root).sort()) if (!excluded(name)) hashTree(hash, path.join(root, name), path.join(relative, name), visited);
  } else if (stat.isFile()) hash.update(fs.readFileSync(root));
}
function swiftExecutable(swift, environment) {
  if (swift.includes(path.sep)) return path.resolve(swift);
  for (const dir of (environment.PATH || '').split(path.delimiter)) {
    const candidate = path.join(dir, swift);
    try { fs.accessSync(candidate, fs.constants.X_OK); return candidate; } catch {}
  }
  throw new Error(`Swift executable not found: ${swift}`);
}
function fingerprint(spec, swift, flags, environment) {
  const hash = createHash('sha256');
  let selectedDeveloper = environment.DEVELOPER_DIR;
  if (!selectedDeveloper && process.platform === 'darwin') {
    try { selectedDeveloper = fs.readlinkSync('/var/db/xcode_select_link'); } catch {}
  }
  hash.update(JSON.stringify({selectedDeveloper, version: TOOL_VERSION, manifest: spec.manifest, entry: spec.entryPoint, mode: spec.mode, swift, flags, toolchain: [environment.DEVELOPER_DIR, environment.TOOLCHAINS, environment.SDKROOT, environment.SWIFT_EXEC]}));
  for (const file of [fileURLToPath(import.meta.url), path.join(path.dirname(fileURLToPath(import.meta.url)), 'game-catalog.mjs'), swift]) {
    hash.update(file); hashTree(hash, file);
  }
  if (selectedDeveloper) hashTree(hash, path.join(selectedDeveloper, 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swift'));
  for (const root of new Set([spec.gamePackageRoot, spec.engineRoot, spec.terminalRoot].filter(Boolean))) { hash.update(root); hashTree(hash, root); }
  hashTree(hash, path.join(spec.packageRoot, 'Package.resolved'));
  const checkouts = path.join(spec.scratchPath, 'checkouts');
  hashTree(hash, checkouts);
  // SwiftPM symlinks URL overrides through scratch/checkouts; hashing follows them once.
  return hash.digest('hex');
}
function resultFor(spec, state) { return {binary: state.binary, binDirectory: state.binDirectory, packageRoot: spec.packageRoot, scratchPath: spec.scratchPath, fingerprint: state.fingerprint}; }
function cacheHit(spec, expected) {
  try {
    const state = JSON.parse(fs.readFileSync(path.join(spec.generatedRoot, 'build-state.json'), 'utf8'));
    fs.accessSync(state.binary, fs.constants.X_OK);
    if (state.fingerprint === expected && fs.statSync(state.binary).isFile()) return resultFor(spec, state);
  } catch {}
  return null;
}
function atomicWrite(file, text) {
  fs.mkdirSync(path.dirname(file), {recursive: true});
  if (fs.existsSync(file) && fs.readFileSync(file, 'utf8') === text) return;
  const temporary = `${file}.${randomUUID()}.tmp`;
  fs.writeFileSync(temporary, text); fs.renameSync(temporary, file);
}
async function lock(spec) {
  fs.mkdirSync(spec.generatedRoot, {recursive: true});
  const directory = path.join(spec.generatedRoot, 'build.lock');
  for (;;) {
    try { fs.mkdirSync(directory); fs.writeFileSync(path.join(directory, 'owner'), String(process.pid)); return () => fs.rmSync(directory, {recursive: true, force: true}); }
    catch (error) {
      if (error.code !== 'EEXIST') throw error;
      try {
        const pid = Number(fs.readFileSync(path.join(directory, 'owner'), 'utf8'));
        try { process.kill(pid, 0); } catch (error) { if (error.code === 'ESRCH') fs.rmSync(directory, {recursive: true, force: true}); }
      } catch (error) {
        if (error.code === 'ENOENT' && fs.existsSync(directory) && Date.now() - fs.statSync(directory).mtimeMs > 30000) fs.rmSync(directory, {recursive: true, force: true});
      }
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }
}
function run(swift, args, environment, capture = false) {
  return new Promise((resolve, reject) => {
    const child = spawn(swift, args, {env: environment, stdio: ['ignore', 'pipe', 'inherit']});
    let output = '';
    child.stdout.on('data', data => { if (capture) output += data; else process.stderr.write(data); });
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(output.trim()) : reject(new Error(`Swift exited ${code}: ${args[0]}`)));
  });
}
export async function buildGame(spec, {force = false, swift = 'swift', environment = process.env} = {}) {
  const flags = buildFlags(environment);
  swift = swiftExecutable(swift, environment);
  let expected = fingerprint(spec, swift, flags, environment);
  if (!force) { const hit = cacheHit(spec, expected); if (hit) return hit; }
  const unlock = await lock(spec);
  try {
    expected = fingerprint(spec, swift, flags, environment);
    if (!force) { const hit = cacheHit(spec, expected); if (hit) return hit; }
    fs.rmSync(path.join(spec.generatedRoot, 'build-state.json'), {force: true});
    for (const link of spec.links) {
      const target = path.join(spec.packageRoot, 'Dependencies', link.name);
      fs.mkdirSync(path.dirname(target), {recursive: true});
      if (fs.existsSync(target) && fs.realpathSync(target) === fs.realpathSync(link.source)) continue;
      fs.rmSync(target, {force: true, recursive: true}); fs.symlinkSync(link.source, target, 'dir');
    }
    atomicWrite(path.join(spec.packageRoot, 'Package.swift'), spec.manifest);
    atomicWrite(path.join(spec.packageRoot, `Sources/${spec.launcherTarget}/main.swift`), spec.entryPoint);
    const env = {...environment, GNUSTO_ENGINE_PATH: spec.engineDependencyPath};
    const toolchainVersion = await run(swift, ['--version'], env, true);
    const args = ['build', '--package-path', spec.packageRoot, '--scratch-path', spec.scratchPath, '--configuration', spec.mode === 'deployment' ? 'release' : 'debug', ...(spec.mode === 'deployment' ? ['--disable-default-traits'] : []), ...flags];
    await run(swift, [...args, '--product', spec.launcherProduct], env);
    const binDirectory = await run(swift, [...args, '--show-bin-path'], env, true);
    if (!path.isAbsolute(binDirectory)) throw new Error(`Swift returned a nonabsolute binary directory: ${binDirectory}`);
    const binary = path.join(binDirectory, spec.launcherProduct);
    fs.accessSync(binary, fs.constants.X_OK);
    if (!spec.terminalRoot) {
      const remote = path.join(spec.scratchPath, 'checkouts', 'GnustoTerminal');
      requireTrait(remote, 'GnustoTerminal');
    }
    const state = {binary, binDirectory, fingerprint: fingerprint(spec, swift, flags, environment), toolchainVersion};
    atomicWrite(path.join(spec.generatedRoot, 'build-state.json'), JSON.stringify(state, null, 2) + '\n');
    return resultFor(spec, state);
  } finally { unlock(); }
}

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
import {createHash, randomUUID} from 'node:crypto';
import {loadGames, resolveCatalogGame} from './game-catalog.mjs';
const TOOL_VERSION = 4;
const DEPLOYMENT_PROBE = '--gnusto-verify-engine-without-playtest';
const DEPLOYMENT_PROOF = 'Gnusto.PlaytestLaunchError.unavailable';
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
function yonkContract(root) {
  const manifest = fs.readFileSync(path.join(root, 'Package.swift'), 'utf8');
  if (!/name:\s*"Yonk"/.test(manifest) || !/\.library\(\s*name:\s*"Yonk"/.test(manifest) || !/\.target\(\s*name:\s*"Yonk"/.test(manifest) || !fs.existsSync(path.join(root, 'Sources/Yonk'))) throw new Error(`${root} is not a supported Yonk source package`);
  const requirement = /\.package\(\s*url:\s*"(https:\/\/github\.com\/HeirloomLogic\/Gnusto(?:\.git)?)"\s*,\s*revision:\s*"([a-f0-9]{40})"\s*\)/.exec(manifest);
  if (!requirement) throw new Error(`${root}/Package.swift does not declare Yonk's supported fixed Gnusto revision`);
  return {engineURL: requirement[1], engineRevision: requirement[2], manifest, engineDeclaration: requirement[0]};
}
export function makeBuildSpec({packageRoot, engineRoot, terminalRoot = process.env.GNUSTO_TERMINAL_PATH, yonkRoot = process.env.GNUSTO_YONK_PATH, frontend = 'terminal', game, mode = 'development', platform = process.platform}) {
  if (!['development', 'deployment'].includes(mode)) throw new Error(`Unknown build mode: ${mode}`);
  if (!['terminal', 'yonk'].includes(frontend)) throw new Error(`Unknown frontend: ${frontend}`);
  if (frontend === 'yonk' && mode !== 'development') throw new Error('Yonk deployment and app export belong to not available yet; use development mode.');
  if (frontend === 'yonk' && platform !== 'darwin') throw new Error('The Yonk development frontend requires macOS.');
  if (frontend === 'yonk' && !yonkRoot) throw new Error('The coordinated prerelease Yonk frontend requires GNUSTO_YONK_PATH.');
  packageRoot = fs.realpathSync(packageRoot);
  engineRoot = fs.realpathSync(engineRoot ?? findEngineRoot(packageRoot));
  terminalRoot = frontend === 'terminal' && terminalRoot ? fs.realpathSync(terminalRoot) : null;
  yonkRoot = frontend === 'yonk' ? fs.realpathSync(yonkRoot) : null;
  const selectedYonkContract = yonkRoot ? yonkContract(yonkRoot) : null;
  const catalog = loadGames(packageRoot);
  game = resolveCatalogGame(catalog, typeof game === 'string' ? game : game?.name);
  const sameEngine = packageRoot === engineRoot;
  const declaration = sameEngine ? null : engineDeclaration(packageRoot);
  if (declaration?.kind === 'path' && fs.realpathSync(declaration.location) !== engineRoot) throw new Error('The author path dependency and selected engine checkout differ; keep the exact engine path declared by the author.');
  const forbiddenLauncherNames = new Set([game.name, game.product, game.module]);
  let launcherProduct = 'GnustoGeneratedLauncher';
  while (forbiddenLauncherNames.has(launcherProduct)) launcherProduct += '_';
  const launcherTarget = launcherProduct;
  const generatedRoot = path.join(packageRoot, '.build-launchers', game.name, frontend, mode);
  const generatedPackage = path.join(generatedRoot, 'package');
  const scratchPath = path.join(generatedRoot, 'scratch');
  const gameIdentity = sameEngine ? 'gnusto' : identity(packageRoot);
  const links = sameEngine ? [{name: gameIdentity, source: packageRoot}] : [];
  const engineIdentity = declaration?.kind === 'path' ? identity(declaration.location) : declaration?.kind === 'url' ? identity(declaration.location) : 'gnusto';
  if (!sameEngine && (gameIdentity === engineIdentity || gameIdentity === 'gnustoterminal' || catalog.package.toLowerCase() === 'gnusto' || catalog.package.toLowerCase() === 'gnustoterminal')) throw new Error(`Package identity collision: ${gameIdentity}; independent authors must use a distinct package identity.`);
  if (engineIdentity === 'gnustoterminal') throw new Error('Engine package identity collision with GnustoTerminal');
  requireTrait(packageRoot, catalog.package);
  requireTrait(engineRoot, 'Gnusto');
  if (terminalRoot) { requireTrait(terminalRoot, 'GnustoTerminal'); links.push({name: 'gnustoterminal', source: terminalRoot}); }
  const engineEdit = declaration?.kind === 'url' ? {identity: engineIdentity, path: engineRoot, url: declaration.location} : null;
  const engineDependencyPath = engineEdit ? null : declaration?.kind === 'path' ? declaration.location : path.join(generatedPackage, 'Dependencies', engineIdentity);
  // SwiftBuild 6.3 also needs compile-time static module autolinks (CoreFoundation/ICU).
  const defaultBuildFlags = mode === 'deployment' && platform === 'linux' ? ['--static-swift-stdlib', '-Xswiftc', '-static-stdlib'] : [];
  const terminalEdit = frontend === 'terminal' && !terminalRoot ? {identity: 'gnustoterminal', url: REMOTE_TERMINAL, branch: 'main', path: path.join(generatedPackage, 'Packages/gnustoterminal')} : null;
  const bootstrapDependencies = [engineEdit && `.package(url: ${swiftStringLiteral(engineEdit.url)}, branch: "main", traits: forwarded)`, terminalEdit && `.package(url: ${swiftStringLiteral(terminalEdit.url)}, branch: "main", traits: forwarded)`].filter(Boolean);
  const bootstrapManifest = bootstrapDependencies.length ? `// swift-tools-version: 6.2\nimport PackageDescription\nlet forwarded: Set<Package.Dependency.Trait> = [.trait(name: "Playtest", condition: .when(traits: ["Playtest"]))]\nlet package = Package(name: "GnustoDependencyEditBootstrap", traits: [.trait(name: "Playtest", description: "Attach exact development sources."), .default(enabledTraits: ["Playtest"])], dependencies: [${bootstrapDependencies.join(', ')}])\n` : null;
  const dependency = (name, location) => `.package(name: ${swiftStringLiteral(name)}, path: ${swiftStringLiteral(location)}, traits: forwarded)`;
  // Keep independent authors at their real location so relative sibling dependencies resolve.
  const dependencies = [dependency(catalog.package, sameEngine ? `Dependencies/${gameIdentity}` : packageRoot)];
  if (frontend === 'terminal') {
    dependencies.push(terminalRoot ? dependency('GnustoTerminal', 'Dependencies/gnustoterminal') : `.package(url: ${swiftStringLiteral(REMOTE_TERMINAL)}, branch: "main", traits: forwarded)`);
    if (!sameEngine && !engineEdit) dependencies.push(dependency('Gnusto', declaration.location));
    if (engineEdit) dependencies.push(`.package(url: ${swiftStringLiteral(engineEdit.url)}, branch: "main", traits: forwarded)`);
  } else dependencies.push(dependency('Yonk', 'Frontends/yonk'));
  const targetDependencies = frontend === 'terminal' ? [`.product(name: ${swiftStringLiteral(game.product)}, package: ${swiftStringLiteral(catalog.package)})`, '.product(name: "GnustoTerminal", package: "GnustoTerminal")', `.product(name: "Gnusto", package: ${swiftStringLiteral(sameEngine ? catalog.package : "Gnusto")})`] : [`.product(name: ${swiftStringLiteral(game.product)}, package: ${swiftStringLiteral(catalog.package)})`, '.product(name: "Yonk", package: "Yonk")'];
  const manifest = `// swift-tools-version: 6.2\nimport PackageDescription\n\nlet forwarded: Set<Package.Dependency.Trait> = [\n    .trait(name: "Playtest", condition: .when(traits: ["Playtest"]))\n]\nlet package = Package(\n    name: ${swiftStringLiteral(game.name + (frontend === 'terminal' ? 'TerminalBuild' : 'YonkBuild'))},\n    platforms: [.macOS(.v15)],\n    products: [.executable(name: ${swiftStringLiteral(launcherProduct)}, targets: [${swiftStringLiteral(launcherTarget)}])],\n    traits: [\n        .trait(name: "Playtest", description: "Enable the development MCP server."),\n        .default(enabledTraits: ["Playtest"]),\n    ],\n    dependencies: [\n        ${dependencies.join(',\n        ')},\n    ],\n    targets: [\n        .executableTarget(name: ${swiftStringLiteral(launcherTarget)}, dependencies: [\n            ${targetDependencies.join(',\n            ')},\n        ]),\n    ]\n)\n`;
  const terminalEntry = `import Gnusto\nimport GnustoTerminal\nimport ${game.module}\n\n#if canImport(Darwin)\nimport Darwin\n#elseif canImport(Glibc)\nimport Glibc\n#endif\n\n${mode === 'deployment' ? `// Build verification calls the engine directly; frontend policy cannot mask its trait.\nif CommandLine.arguments.dropFirst().elementsEqual([${swiftStringLiteral(DEPLOYMENT_PROBE)}]) {\n    do {\n        try await PlaytestLaunch.serve(${game.module}.${game.symbol}, environment: [:])\n    } catch PlaytestLaunchError.unavailable {\n        print(${swiftStringLiteral(DEPLOYMENT_PROOF)})\n        exit(0)\n    } catch {}\n    exit(1)\n}\n\n` : ''}let result = await TerminalLaunch.run(${game.module}.${game.symbol})\nexit(result)\n`;
  const yonkEntry = `import AppKit\nimport SwiftUI\nimport Yonk\nimport ${game.module}\n\n@main\nstruct ${launcherTarget}App: App {\n    init() {\n        NSApplication.shared.setActivationPolicy(.regular)\n    }\n\n    var body: some Scene {\n        Yonk(${game.module}.${game.symbol})\n    }\n}\n`;
  const yonkOverlayRoot = yonkRoot ? path.join(generatedPackage, 'Frontends/yonk') : null;
  const yonkEnginePath = sameEngine ? path.join(generatedPackage, 'Dependencies', gameIdentity) : engineRoot;
  const yonkEngineDependency = engineEdit ? `.package(url: ${swiftStringLiteral(engineEdit.url)}, branch: "main", traits: [.trait(name: "Playtest", condition: .when(traits: ["Playtest"]))])` : `.package(name: "Gnusto", path: ${swiftStringLiteral(yonkEnginePath)}, traits: [.trait(name: "Playtest", condition: .when(traits: ["Playtest"]))])`;
  // Preserve frontend targets, resources and settings; replace only its engine edge.
  const yonkOverlayManifest = yonkRoot ? selectedYonkContract.manifest.replace(selectedYonkContract.engineDeclaration, yonkEngineDependency) + '\npackage.traits.insert(.trait(name: "Playtest", description: "Forward the development engine trait."))\n' : null;
  return {packageRoot: generatedPackage, gamePackageRoot: packageRoot, engineRoot, terminalRoot, yonkRoot, frontendRoot: terminalRoot || yonkRoot, frontend, game, mode, manifest, entryPoint: frontend === 'terminal' ? terminalEntry : yonkEntry, scratchPath, generatedRoot, links, engineDependencyPath, launcherProduct, launcherTarget, engineEdit, terminalEdit, bootstrapManifest, platform, defaultBuildFlags, selectedYonkContract, yonkOverlayRoot, yonkOverlayManifest};
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
function combineFingerprints(localInputs, resolution) { return createHash('sha256').update(localInputs).update(resolution).digest('hex'); }
function resolutionFingerprint(spec) {
  const hash = createHash('sha256');
  hashTree(hash, path.join(spec.packageRoot, 'Package.resolved'));
  hashTree(hash, path.join(spec.scratchPath, 'checkouts'));
  hashTree(hash, path.join(spec.scratchPath, 'workspace-state.json'));
  hashTree(hash, path.join(spec.packageRoot, 'Packages'));
  hashTree(hash, path.join(spec.generatedRoot, 'terminal-source.json'));
  hashTree(hash, path.join(spec.generatedRoot, 'frontend-source.json'));
  return hash.digest('hex');
}
function resolvedLocalFingerprint(spec) {
  const hash = createHash('sha256');
  const stateFile = path.join(spec.scratchPath, 'workspace-state.json');
  const dependencies = fs.existsSync(stateFile) ? JSON.parse(fs.readFileSync(stateFile, 'utf8')).object.dependencies : [];
  const principalRoots = new Set([spec.gamePackageRoot, spec.engineRoot, spec.frontendRoot].filter(Boolean).map(root => fs.realpathSync(root)));
  const roots = new Set();
  for (const dependency of dependencies) {
    const state = dependency.state;
    const root = state.name === 'fileSystem' ? state.path : state.name === 'edited' ? state.path ?? path.join(spec.packageRoot, 'Packages', dependency.subpath) : null;
    if (root === null) continue;
    if (typeof root !== 'string' || !path.isAbsolute(root)) throw new Error('SwiftPM recorded a nonabsolute local dependency path.');
    roots.add(root);
  }
  for (const root of [...roots].sort()) {
    const actual = fs.existsSync(root) ? fs.realpathSync(root) : null;
    hash.update(JSON.stringify([root, actual]));
    // Principal sources already belong to the independent pre-resolution snapshot.
    if (!principalRoots.has(actual)) hashTree(hash, root);
  }
  return hash.digest('hex');
}
function fingerprint(spec, swift, flags, environment, withResolution = true) {
  if (withResolution) return combineFingerprints(combineFingerprints(fingerprint(spec, swift, flags, environment, false), resolvedLocalFingerprint(spec)), resolutionFingerprint(spec));
  const hash = createHash('sha256');
  let selectedDeveloper = environment.DEVELOPER_DIR;
  if (!selectedDeveloper && process.platform === 'darwin') {
    try { selectedDeveloper = fs.readlinkSync('/var/db/xcode_select_link'); } catch {}
  }
  hash.update(JSON.stringify({selectedDeveloper, version: TOOL_VERSION, manifest: spec.manifest, entry: spec.entryPoint, bootstrapManifest: spec.bootstrapManifest, engineEdit: spec.engineEdit, terminalEdit: spec.terminalEdit, mode: spec.mode, platform: spec.platform, defaultBuildFlags: spec.defaultBuildFlags, swift, flags, toolchain: [environment.DEVELOPER_DIR, environment.TOOLCHAINS, environment.SDKROOT, environment.SWIFT_EXEC]}));
  for (const file of [fileURLToPath(import.meta.url), path.join(path.dirname(fileURLToPath(import.meta.url)), 'game-catalog.mjs'), swift]) {
    hash.update(file); hashTree(hash, file);
  }
  if (selectedDeveloper) hashTree(hash, path.join(selectedDeveloper, 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swift'));
  for (const root of new Set([spec.gamePackageRoot, spec.engineRoot, spec.frontendRoot].filter(Boolean))) { hash.update(root); hashTree(hash, root); }
  return hash.digest('hex');
}
function engineEditReady(spec) {
  if (!spec.engineEdit) return true;
  try {
    const dependencies = JSON.parse(fs.readFileSync(path.join(spec.scratchPath, 'workspace-state.json'), 'utf8')).object.dependencies;
    const engine = dependencies.find(dependency => dependency.packageRef.identity === spec.engineEdit.identity);
    return engine?.packageRef.kind === 'remoteSourceControl' && engine.packageRef.location === spec.engineEdit.url && engine.state.name === 'edited' && fs.realpathSync(engine.state.path) === spec.engineRoot;
  } catch { return false; }
}
function terminalSource(spec) {
  const terminal = JSON.parse(fs.readFileSync(path.join(spec.scratchPath, 'workspace-state.json'), 'utf8')).object.dependencies.find(dependency => dependency.packageRef.identity === spec.terminalEdit.identity);
  const reference = terminal?.packageRef, base = terminal?.basedOn;
  const checkout = base?.state.checkoutState;
  if (reference?.kind !== 'remoteSourceControl' || reference.location !== spec.terminalEdit.url || terminal.state.name !== 'edited' || terminal.state.path !== null || terminal.subpath !== spec.terminalEdit.identity || base?.packageRef.identity !== spec.terminalEdit.identity || base.packageRef.kind !== 'remoteSourceControl' || base.packageRef.location !== spec.terminalEdit.url || base.state.name !== 'sourceControlCheckout' || checkout?.branch !== spec.terminalEdit.branch || !/^[a-f0-9]{40}$/.test(checkout.revision)) throw new Error('Generated frontend edit lost its exact SCM provenance.');
  if (fs.realpathSync(spec.terminalEdit.path) !== spec.terminalEdit.path || fs.readFileSync(path.join(spec.terminalEdit.path, '.git/HEAD'), 'utf8').trim() !== checkout.revision) throw new Error('Generated frontend checkout no longer matches its resolved revision.');
  requireTrait(spec.terminalEdit.path, 'GnustoTerminal');
  return {identity: reference.identity, url: reference.location, branch: checkout.branch, revision: checkout.revision, path: spec.terminalEdit.path, sourceFingerprint: frontendFingerprint(spec)};
}
function terminalEditReady(spec) {
  if (!spec.terminalEdit) return true;
  try { return JSON.stringify(terminalSource(spec)) === JSON.stringify(JSON.parse(fs.readFileSync(path.join(spec.generatedRoot, 'terminal-source.json'), 'utf8'))); } catch { return false; }
}
function frontendFingerprint(spec) {
  const hash = createHash('sha256');
  if (spec.terminalEdit) hashTree(hash, spec.terminalEdit.path);
  else if (spec.frontendRoot) hashTree(hash, spec.frontendRoot);
  return hash.digest('hex');
}
function frontendSource(spec) {
  if (spec.frontend !== 'yonk') return null;
  return {frontend: 'yonk', kind: 'path', path: spec.yonkRoot, engineURL: spec.selectedYonkContract.engineURL, engineRevision: spec.selectedYonkContract.engineRevision, sourceFingerprint: frontendFingerprint(spec)};
}
function yonkOverlayEntries(spec) {
  return fs.readdirSync(spec.yonkRoot).filter(name => name !== 'Package.swift' && !excluded(name));
}
function prepareYonkOverlay(spec) {
  if (spec.frontend !== 'yonk') return;
  fs.mkdirSync(spec.yonkOverlayRoot, {recursive: true});
  const names = yonkOverlayEntries(spec);
  for (const name of fs.readdirSync(spec.yonkOverlayRoot)) {
    if (name !== 'Package.swift' && !names.includes(name)) fs.rmSync(path.join(spec.yonkOverlayRoot, name), {recursive: true, force: true});
  }
  for (const name of names) {
    const source = path.join(spec.yonkRoot, name), target = path.join(spec.yonkOverlayRoot, name);
    let current = null;
    try { current = fs.realpathSync(target); } catch {}
    if (current !== fs.realpathSync(source)) {
      fs.rmSync(target, {recursive: true, force: true});
      fs.symlinkSync(source, target);
    }
  }
  atomicWrite(path.join(spec.yonkOverlayRoot, 'Package.swift'), spec.yonkOverlayManifest);
  atomicWrite(path.join(spec.generatedRoot, 'frontend-source.json'), JSON.stringify(frontendSource(spec), null, 2) + '\n');
}
function yonkOverlayReady(spec) {
  if (spec.frontend !== 'yonk') return true;
  try {
    return yonkOverlayEntries(spec).every(name => fs.realpathSync(path.join(spec.yonkOverlayRoot, name)) === fs.realpathSync(path.join(spec.yonkRoot, name))) && fs.readFileSync(path.join(spec.yonkOverlayRoot, 'Package.swift'), 'utf8') === spec.yonkOverlayManifest && JSON.stringify(JSON.parse(fs.readFileSync(path.join(spec.generatedRoot, 'frontend-source.json'), 'utf8'))) === JSON.stringify(frontendSource(spec));
  } catch { return false; }
}
function resultFor(spec, state) { return {binary: state.binary, binDirectory: state.binDirectory, packageRoot: spec.packageRoot, scratchPath: spec.scratchPath, fingerprint: state.fingerprint}; }
function cacheHit(spec, expected) {
  try {
    const state = JSON.parse(fs.readFileSync(path.join(spec.generatedRoot, 'build-state.json'), 'utf8'));
    fs.accessSync(state.binary, fs.constants.X_OK);
    if (engineEditReady(spec) && terminalEditReady(spec) && yonkOverlayReady(spec) && state.fingerprint === expected && fs.statSync(state.binary).isFile()) return resultFor(spec, state);
  } catch {}
  return null;
}
function atomicWrite(file, text) {
  fs.mkdirSync(path.dirname(file), {recursive: true});
  if (fs.existsSync(file) && fs.readFileSync(file, 'utf8') === text) return;
  const temporary = `${file}.${randomUUID()}.tmp`;
  fs.writeFileSync(temporary, text); fs.renameSync(temporary, file);
}
export async function acquireBuildLock(generatedRoot) {
  fs.mkdirSync(generatedRoot, {recursive: true});
  const token = randomUUID();
  const lockFile = path.join(generatedRoot, 'build.lockfile');
  // Keep the same inode forever: unlinking it can let a successor lock a different file.
  // The native advisory lock is released by the OS, including after an abandoned owner.
  const command = process.platform === 'darwin' ? '/usr/bin/lockf' : 'flock';
  const helper = `process.stdout.write(${JSON.stringify(token)}); process.stdin.resume(); process.stdin.on('end', () => process.exit(0));`;
  const child = spawn(command, [...(process.platform === 'darwin' ? ['-k'] : []), lockFile, process.execPath, '-e', helper], {stdio: ['pipe', 'pipe', 'pipe']});
  let errors = '';
  child.stderr.on('data', data => { errors += data; });
  const closed = new Promise(resolve => child.on('close', code => resolve(code)));
  await new Promise((resolve, reject) => {
    let received = '';
    child.stdout.on('data', data => { received += data; if (received === token) resolve(); });
    child.on('error', reject);
    child.on('close', code => reject(new Error(`Unable to acquire build lock (${command}, ${code}): ${errors.trim()}`)));
  });
  let released = false;
  return async () => {
    if (released) return;
    released = true;
    child.stdin.end();
    const code = await closed;
    if (code !== 0) throw new Error(`Build lock helper exited ${code}: ${errors.trim()}`);
  };
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
async function verifyDeploymentEngine(binary, environment) {
  await new Promise((resolve, reject) => {
    // Closed stdin makes a trait-enabled MCP server terminate; the deadline also
    // bounds bootstrap failures/hangs. Only the engine's exact error is success.
    const child = spawn(binary, [DEPLOYMENT_PROBE], {env: environment, stdio: ['ignore', 'pipe', 'pipe']});
    let stdout = '', stderr = '', limited = false;
    const timer = setTimeout(() => { limited = true; child.kill('SIGKILL'); }, 15_000);
    const collect = (stream, data) => {
      if (stream === 'stdout') stdout += data; else stderr += data;
      if (stdout.length + stderr.length > 1024 * 1024) { limited = true; child.kill('SIGKILL'); }
    };
    child.stdout.on('data', data => collect('stdout', data));
    child.stderr.on('data', data => collect('stderr', data));
    child.on('error', error => { clearTimeout(timer); reject(new Error(`Cannot verify deployment engine Playtest exclusion: ${error.message}`)); });
    child.on('close', code => {
      clearTimeout(timer);
      if (!limited && code === 0 && stdout === DEPLOYMENT_PROOF + '\n' && stderr === '') resolve();
      else reject(new Error('Deployment requires a Gnusto engine built without Playtest; the compiled engine did not return PlaytestLaunchError.unavailable. Check every incoming dependency trait selection.'));
    });
  });
}
export async function buildGame(spec, {force = false, swift = 'swift', environment = process.env} = {}) {
  const flags = buildFlags(environment);
  swift = swiftExecutable(swift, environment);
  let expected = fingerprint(spec, swift, flags, environment);
  if (!force) { const hit = cacheHit(spec, expected); if (hit) return hit; }
  const unlock = await acquireBuildLock(spec.generatedRoot);
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
    prepareYonkOverlay(spec);
    atomicWrite(path.join(spec.packageRoot, 'Package.swift'), spec.manifest);
    atomicWrite(path.join(spec.packageRoot, `Sources/${spec.launcherTarget}/main.swift`), spec.entryPoint);
    const stableInputs = fingerprint(spec, swift, flags, environment, false);
    const env = {...environment};
    if (spec.engineEdit) delete env.GNUSTO_ENGINE_PATH;
    else env.GNUSTO_ENGINE_PATH = spec.engineDependencyPath;
    const toolchainVersion = await run(swift, ['--version'], env, true);
    if (!engineEditReady(spec) || !terminalEditReady(spec)) {
      // All editable dependencies are attached together in this generated workspace.
      // Resolve the remote frontend without path environment first; its managed edit
      // then permits the final manifest to bind exactly the selected local engine.
      fs.rmSync(path.join(spec.scratchPath, 'workspace-state.json'), {force: true});
      fs.rmSync(path.join(spec.packageRoot, 'Packages'), {recursive: true, force: true});
      fs.rmSync(path.join(spec.generatedRoot, 'terminal-source.json'), {force: true});
      atomicWrite(path.join(spec.packageRoot, 'Package.swift'), spec.bootstrapManifest);
      const bootstrapEnvironment = {...env}; delete bootstrapEnvironment.GNUSTO_ENGINE_PATH;
      const packageArgs = ['package', '--package-path', spec.packageRoot, '--scratch-path', spec.scratchPath, ...(spec.mode === 'deployment' ? ['--disable-default-traits'] : [])];
      try {
        if (spec.engineEdit) await run(swift, [...packageArgs, 'edit', spec.engineEdit.identity, '--path', spec.engineEdit.path], bootstrapEnvironment);
        if (spec.terminalEdit) {
          await run(swift, [...packageArgs, 'edit', spec.terminalEdit.identity], bootstrapEnvironment);
          atomicWrite(path.join(spec.generatedRoot, 'terminal-source.json'), JSON.stringify(terminalSource(spec), null, 2) + '\n');
        }
      } finally { atomicWrite(path.join(spec.packageRoot, 'Package.swift'), spec.manifest); }
      if (!engineEditReady(spec) || !terminalEditReady(spec)) throw new Error('SwiftPM did not attach the exact editable dependencies.');
    }
    {
      // Resolve before snapshotting every local/editable dependency, including siblings.
      const graph = JSON.parse(await run(swift, ['package', '--package-path', spec.packageRoot, '--scratch-path', spec.scratchPath, ...(spec.mode === 'deployment' ? ['--disable-default-traits'] : []), 'show-dependencies', '--format', 'json'], env, true));
      const identities = new Set(), paths = new Set(), terminals = new Set(), yonks = new Set();
      const visit = node => {
        if (node.name === 'Gnusto' || node.identity === spec.engineEdit?.identity) { identities.add(node.identity); paths.add(fs.realpathSync(node.path)); }
        if (node.identity === spec.terminalEdit?.identity) terminals.add(fs.realpathSync(node.path));
        if (node.name === 'Yonk') yonks.add(fs.realpathSync(node.path));
        for (const dependency of node.dependencies || []) visit(dependency);
      };
      visit(graph);
      if (!engineEditReady(spec) || identities.size !== 1 || (spec.engineEdit && !identities.has(spec.engineEdit.identity)) || paths.size !== 1 || !paths.has(spec.engineRoot)) throw new Error('Generated graph lost the editable current engine dependency; refusing to compile released engine sources.');
      if (!terminalEditReady(spec) || (spec.terminalEdit && (terminals.size !== 1 || !terminals.has(spec.terminalEdit.path)))) throw new Error('Generated graph lost its exact edited frontend; refusing to compile.');
      if (!yonkOverlayReady(spec) || (spec.frontend === 'yonk' && (yonks.size !== 1 || !yonks.has(fs.realpathSync(spec.yonkOverlayRoot))))) throw new Error('Generated graph lost its exact Yonk source overlay; refusing to compile.');
    }
    const stableLocalDependencies = resolvedLocalFingerprint(spec);
    const stableTerminalSource = spec.terminalEdit ? terminalSource(spec) : null;
    const stableFrontendSource = frontendSource(spec);
    const stableFrontend = frontendFingerprint(spec);
    const args = ['build', '--package-path', spec.packageRoot, '--scratch-path', spec.scratchPath, '--configuration', spec.mode === 'deployment' ? 'release' : 'debug', ...(spec.mode === 'deployment' ? ['--disable-default-traits'] : []), ...spec.defaultBuildFlags, ...flags];
    await run(swift, [...args, '--product', spec.launcherProduct], env);
    const binDirectory = await run(swift, [...args, '--show-bin-path'], env, true);
    if (!path.isAbsolute(binDirectory)) throw new Error(`Swift returned a nonabsolute binary directory: ${binDirectory}`);
    const binary = path.join(binDirectory, spec.launcherProduct);
    fs.accessSync(binary, fs.constants.X_OK);
    if (spec.mode === 'deployment') await verifyDeploymentEngine(binary, env);
    if (frontendFingerprint(spec) !== stableFrontend) throw new Error('Managed frontend compilation inputs changed during build; retry to compile the resolved sources.');
    if (!engineEditReady(spec) || !terminalEditReady(spec) || !yonkOverlayReady(spec)) throw new Error('Generated workspace lost its exact editable dependencies during build; refusing to publish current state.');
    const resolvedInputs = resolutionFingerprint(spec);
    if (frontendFingerprint(spec) !== stableFrontend) throw new Error('Managed frontend compilation inputs changed during build; retry to compile the resolved sources.');
    if (fingerprint(spec, swift, flags, environment, false) !== stableInputs) throw new Error('Local compilation inputs changed during build; retry to compile the current sources.');
    if (resolvedLocalFingerprint(spec) !== stableLocalDependencies) throw new Error('Resolved local dependency compilation inputs changed during build; retry to compile the current sources.');
    const state = {binary, binDirectory, fingerprint: combineFingerprints(combineFingerprints(stableInputs, stableLocalDependencies), resolvedInputs), toolchainVersion, ...(spec.terminalEdit ? {terminalSource: stableTerminalSource} : {}), ...(stableFrontendSource ? {frontendSource: stableFrontendSource} : {})};
    atomicWrite(path.join(spec.generatedRoot, 'build-state.json'), JSON.stringify(state, null, 2) + '\n');
    return resultFor(spec, state);
  } finally { await unlock(); }
}

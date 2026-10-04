// Explicit real SwiftPM qualification; GNUSTO_FINAL_FIXES_ROOT retains graphs and logs.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {buildGame, makeBuildSpec, swiftStringLiteral} from '../lib/game-build.mjs';
import {stageTerminalExport} from '../lib/game-export.mjs';

const sourceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const engineRoot = fs.realpathSync(process.env.GNUSTO_FINAL_FIXES_ENGINE || sourceRoot);
const terminalRoot = fs.realpathSync(process.env.GNUSTO_TERMINAL_PATH);
const root = process.env.GNUSTO_FINAL_FIXES_ROOT || fs.mkdtempSync(path.join(os.tmpdir(), 'gnusto-final-fixes-'));
fs.mkdirSync(root, {recursive: true});
const author = path.join(root, 'author');
const shared = path.join(root, 'Shared');
const swift = path.join(root, 'swift-wrapper');
const swiftLog = path.join(root, 'swift-invocations.jsonl');
fs.writeFileSync(swift, `#!/usr/bin/env node\nimport fs from 'node:fs'; import {spawnSync} from 'node:child_process';\nfs.appendFileSync(${JSON.stringify(swiftLog)}, JSON.stringify(process.argv.slice(2))+'\\n');\nconst result=spawnSync('swift', process.argv.slice(2), {stdio:'inherit'});process.exit(result.status ?? 1);\n`, {mode: 0o755});
const invocationCount = () => fs.existsSync(swiftLog) ? fs.readFileSync(swiftLog, 'utf8').trim().split('\n').length : 0;
const environment = {...process.env, GNUSTO_SWIFT_BUILD_FLAGS: process.env.GNUSTO_SWIFT_BUILD_FLAGS || '["--jobs","4"]'};
delete environment.GNUSTO_MCP;
const options = {swift, environment};
const literal = swiftStringLiteral;
const forwarded = 'let forwarded: Set<Package.Dependency.Trait> = [.trait(name: "Playtest", condition: .when(traits: ["Playtest"]))]';
const traits = 'traits: [.trait(name: "Playtest"), .default(enabledTraits: ["Playtest"])]';
fs.mkdirSync(path.join(shared, 'Sources/Shared/Resources'), {recursive: true});
fs.writeFileSync(path.join(shared, 'Sources/Shared/Shared.swift'), 'import Foundation\npublic let sourceText = "SharedSourceOne"\npublic var resourceText: String { try! String(contentsOf: Bundle.module.url(forResource: "message", withExtension: "txt")!, encoding: .utf8) }\n');
fs.writeFileSync(path.join(shared, 'Sources/Shared/Resources/message.txt'), 'SharedResourceOne');
fs.writeFileSync(path.join(shared, 'Sources/Shared/Unused.swift'), '// Deleted source input');
fs.writeFileSync(path.join(shared, 'Sources/Shared/Resources/unused.txt'), 'Deleted resource input');
fs.cpSync(path.join(sourceRoot, 'bin/tests/fixtures/game-build/resource-story'), author, {recursive: true});
const story = path.join(author, 'Sources/Story/Story.swift');
fs.writeFileSync(story, fs.readFileSync(story, 'utf8').replace('import Gnusto', 'import Gnusto\nimport Shared').replace('"BuildSourceOne " +', 'sourceText + " " + resourceText + " " +'));
function manifests(kind) {
  const dependency = `.package(name: "Gnusto", path: ${literal(engineRoot)}${kind === 'unforwarded' ? '' : ', traits: forwarded'})`;
  fs.writeFileSync(path.join(author, 'Package.swift'), fs.readFileSync(path.join(author, 'Package.swift.in'), 'utf8').replace('ENGINE_DEPENDENCY', `${dependency}, .package(name: "Shared", path: "../Shared", traits: forwarded)`).replace('dependencies: [.product(name: "Gnusto", package: "Gnusto")]', 'dependencies: [.product(name: "Gnusto", package: "Gnusto"), .product(name: "Shared", package: "Shared")]'));
  fs.writeFileSync(path.join(shared, 'Package.swift'), `// swift-tools-version: 6.2\nimport PackageDescription\n${forwarded}\nlet package = Package(name: "Shared", platforms: [.macOS(.v15)], products: [.library(name: "Shared", targets: ["Shared"])], ${traits}, dependencies: [.package(name: "Gnusto", path: ${literal(engineRoot)}${kind === 'extra-default-edge' ? '' : ', traits: forwarded'})], targets: [.target(name: "Shared", dependencies: [.product(name: "Gnusto", package: "Gnusto")], resources: [.process("Resources")])])\n`);
}
const spec = mode => makeBuildSpec({packageRoot: author, engineRoot, terminalRoot, game: 'Story', mode});
const destination = path.join(root, 'dist/Story');
const evidence = {engineRoot, terminalRoot, root, checks: []};
const save = () => fs.writeFileSync(path.join(root, 'evidence.json'), JSON.stringify(evidence, null, 2) + '\n');
const play = binary => {
  const result = spawnSync(binary, [], {env: {...environment, GNUSTO_PLAIN: '1'}, input: 'quit\ny\n', encoding: 'utf8', timeout: 15000});
  assert.equal(result.status, 0, result.stderr); return result.stdout;
};
const handshake = binary => {
  const request = {jsonrpc: '2.0', id: 1, method: 'initialize', params: {protocolVersion: '2024-11-05', capabilities: {}, clientInfo: {name: 'final-fixes', version: '1'}}};
  const result = spawnSync(binary, ['--mcp'], {env: environment, input: JSON.stringify(request) + '\n', encoding: 'utf8', timeout: 15000});
  assert.equal(result.status, 0, result.stderr); assert(JSON.parse(result.stdout.trim()).result?.protocolVersion);
};
const failures = [];
try {
  if (process.env.GNUSTO_FINAL_FIXES_RED !== '1') {
    manifests('forwarded');
    const development = await buildGame(spec('development'), options);
    handshake(development.binary);
    evidence.development = development;
    let previous = await buildGame(spec('deployment'), options);
    assert.match(play(previous.binary), /SharedSourceOne SharedResourceOne/);
    const workspace = JSON.parse(fs.readFileSync(path.join(previous.scratchPath, 'workspace-state.json')));
    const sharedDependency = workspace.object.dependencies.find(item => item.packageRef.identity === 'shared');
    assert.equal(fs.realpathSync(sharedDependency.state.path), shared);
    evidence.relativeSibling = sharedDependency;
    evidence.checks.push({name: 'ordinary relative sibling resolves outside principal roots', path: shared});
    for (const [name, mutate, text] of [
      ['source edit', () => fs.writeFileSync(path.join(shared, 'Sources/Shared/Shared.swift'), fs.readFileSync(path.join(shared, 'Sources/Shared/Shared.swift'), 'utf8').replace('SharedSourceOne', 'SharedSourceTwo')), /SharedSourceTwo SharedResourceOne/],
      ['resource edit', () => fs.writeFileSync(path.join(shared, 'Sources/Shared/Resources/message.txt'), 'SharedResourceTwo'), /SharedSourceTwo SharedResourceTwo/],
      ['source deletion', () => fs.unlinkSync(path.join(shared, 'Sources/Shared/Unused.swift')), /SharedSourceTwo SharedResourceTwo/],
      ['resource deletion', () => fs.unlinkSync(path.join(shared, 'Sources/Shared/Resources/unused.txt')), /SharedSourceTwo SharedResourceTwo/],
    ]) {
      mutate(); const built = await buildGame(spec('deployment'), options);
      assert.notEqual(built.fingerprint, previous.fingerprint, name);
      assert.match(play(built.binary), text);
      const count = invocationCount(); assert.deepEqual(await buildGame(spec('deployment'), options), built); assert.equal(invocationCount(), count);
      evidence.checks.push({name, currentBinary: true, warmSwiftCalls: 0}); previous = built; save();
    }
    const staged = await stageTerminalExport({...previous, destination});
    for (const [args, extra] of [[['--mcp'], {}], [[], {GNUSTO_MCP: '1'}]]) {
      const result = spawnSync(staged.binary, args, {env: {...environment, ...extra}, encoding: 'utf8', timeout: 15000});
      assert.equal(result.status, 1); assert.equal(result.stdout, ''); assert.match(result.stderr, /built without it/);
    }
    evidence.checks.push({name: 'valid deployment and both MCP refusals', resources: staged.resources});
    // The source changes also invalidate development. Rebuild once, then prove export isolation.
    const refreshed = await buildGame(spec('development'), options); handshake(refreshed.binary);
    const count = invocationCount(); assert.deepEqual(await buildGame(spec('development'), options), refreshed); assert.equal(invocationCount(), count);
    evidence.checks.push({name: 'development MCP after export', warmSwiftCalls: 0}); save();
  } else {
    fs.mkdirSync(path.dirname(destination), {recursive: true}); fs.writeFileSync(destination, 'previous export');
  }
  const previousPath = fs.realpathSync(destination), previousBytes = fs.readFileSync(destination);
  for (const kind of ['unforwarded', 'extra-default-edge']) {
    manifests(kind);
    let rejection;
    try { const built = await buildGame(spec('deployment'), options); handshake(built.binary); evidence.checks.push({name: kind, unexpectedDevelopmentMCP: true}); await stageTerminalExport({...built, destination}); }
    catch (error) { rejection = error; }
    try {
      assert.match(rejection?.message || '', /engine.*Playtest|Playtest.*engine/i, `${kind} must reject the actual trait-enabled engine`);
      assert.equal(fs.existsSync(path.join(spec('deployment').generatedRoot, 'build-state.json')), false);
      assert.equal(fs.realpathSync(destination), previousPath); assert.deepEqual(fs.readFileSync(destination), previousBytes);
      evidence.checks.push({name: kind, rejected: rejection.message, priorExportPreserved: true});
    } catch (error) { failures.push(error); evidence.checks.push({name: kind, failed: error.message, rejection: rejection?.message || null}); }
    save();
  }
  assert.equal(failures.length, 0, failures.map(error => error.message).join('\n'));
  console.log(JSON.stringify(evidence, null, 2));
} finally { save(); }

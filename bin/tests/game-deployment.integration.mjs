// Run explicitly with GNUSTO_TERMINAL_PATH set to the coordinated companion.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {spawn, spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {makeBuildSpec, buildGame, swiftStringLiteral} from '../lib/game-build.mjs';
import {stageTerminalExport} from '../lib/game-export.mjs';

const engineSource = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const terminalSource = process.env.GNUSTO_TERMINAL_PATH;
assert(terminalSource, 'Set GNUSTO_TERMINAL_PATH to the coordinated GnustoTerminal checkout');
const root = await fs.mkdtemp(path.join(os.tmpdir(), 'gnusto-deployment-integration-'));
const packageRoot = path.join(root, 'resource-author');
const engineRoot = path.join(root, 'Gnusto');
const terminalRoot = path.join(root, 'GnustoTerminal');
const hidden = path.join(root, 'source-unavailable');
const swiftLog = path.join(root, 'swift-invocations');
const swift = path.join(root, 'swift-wrapper');
const realSwift = process.env.GNUSTO_SWIFT || 'swift';
await fs.writeFile(swift, `#!/usr/bin/env node
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
fs.appendFileSync(${JSON.stringify(swiftLog)}, JSON.stringify(process.argv.slice(2)) + '\\n');
const result = spawnSync(${JSON.stringify(realSwift)}, process.argv.slice(2), {stdio: 'inherit'});
if (result.error) throw result.error;
process.exit(result.status ?? 1);
`, {mode: 0o755});
async function handshake(binary) {
  const environment = {...process.env};
  delete environment.GNUSTO_MCP;
  const child = spawn(binary, ['--mcp'], {env: environment, stdio: ['pipe', 'pipe', 'pipe']});
  let stdout = '', stderr = '';
  child.stderr.on('data', data => { stderr += data; });
  try {
    const response = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`MCP initialize timed out: ${stderr}`)), 15_000);
      child.on('error', error => { clearTimeout(timer); reject(error); });
      child.on('exit', code => { clearTimeout(timer); reject(new Error(`MCP exited ${code}: ${stderr}`)); });
      child.stdout.on('data', data => {
        stdout += data;
        if (!stdout.includes('\n')) return;
        clearTimeout(timer);
        try { resolve(JSON.parse(stdout.trim().split('\n')[0])); } catch (error) { reject(error); }
      });
      child.stdin.write(JSON.stringify({jsonrpc: '2.0', id: 1, method: 'initialize', params: {protocolVersion: '2024-11-05', capabilities: {}, clientInfo: {name: 'deployment-integration', version: '1'}}}) + '\n');
    });
    assert.equal(response.id, 1);
    assert.equal(response.jsonrpc, '2.0');
    assert(response.result?.protocolVersion, JSON.stringify(response));
    assert.equal(response.error, undefined);
    return response;
  } finally { child.kill(); }
}
try {
  // Other migration workers may edit the live checkout during compilation.
  // Freeze its current contents so cache isolation is tested against stable inputs.
  const capturedAt = new Date().toISOString();
  for (const [source, snapshot] of [[engineSource, engineRoot], [terminalSource, terminalRoot]]) {
    await fs.mkdir(snapshot, {recursive: true});
    for (const input of ['Package.swift', 'Package.resolved', 'Sources', 'Tests']) {
      const file = path.join(source, input);
      if (await fs.access(file).then(() => true, () => false)) await fs.cp(file, path.join(snapshot, input), {recursive: true});
    }
  }
  const revision = source => spawnSync('git', ['rev-parse', 'HEAD'], {cwd: source, encoding: 'utf8'}).stdout.trim();
  const sourceCapture = {capturedAt, engineSource, engineRevision: revision(engineSource), terminalSource, terminalRevision: revision(terminalSource), inputs: ['Package.swift', 'Package.resolved', 'Sources', 'Tests']};
  await fs.mkdir(path.join(packageRoot, 'Sources', 'ResourceStory', 'Resources'), {recursive: true});
  await fs.writeFile(path.join(packageRoot, 'Package.swift'), `// swift-tools-version: 6.2\nimport PackageDescription\nlet forwarded: Set<Package.Dependency.Trait> = [.trait(name: "Playtest", condition: .when(traits: ["Playtest"]))]\nlet package = Package(name: "ResourceStory", platforms: [.macOS(.v15)], products: [.library(name: "ResourceStory", targets: ["ResourceStory"])], traits: [.trait(name: "Playtest"), .default(enabledTraits: ["Playtest"])], dependencies: [.package(name: "Gnusto", path: ${swiftStringLiteral(engineRoot)}, traits: forwarded)], targets: [.target(name: "ResourceStory", dependencies: [.product(name: "Gnusto", package: "Gnusto")], resources: [.process("Resources")])])\n`);
  await fs.writeFile(path.join(packageRoot, 'gnusto-games.json'), JSON.stringify({version: 1, package: 'ResourceStory', games: [{name: 'ResourceStory', product: 'ResourceStory', module: 'ResourceStory', symbol: 'game'}]}));
  await fs.writeFile(path.join(packageRoot, 'Sources', 'ResourceStory', 'Resources', 'opening.txt'), 'RELOCATED_RESOURCE_ACCESSOR_OK');
  await fs.writeFile(path.join(packageRoot, 'Sources', 'ResourceStory', 'Packaged.swift'), `import Foundation\nimport Gnusto\npublic let game = PackagedGame { ResourceGame() }\nstruct ResourceGame: Game {\n    let title = "Resource Fixture"\n    let intro = try! String(contentsOf: Bundle.module.url(forResource: "opening", withExtension: "txt")!, encoding: .utf8)\n    let room = Location { name("Fixture Room"); description("A resource-bearing fixture.") }\n    var map: WorldMap { player.starts(in: room) }\n}\n`);
  const common = {packageRoot, engineRoot, terminalRoot, game: 'ResourceStory'};
  const developmentSpec = makeBuildSpec({...common, mode: 'development'});
  const deploymentSpec = makeBuildSpec({...common, mode: 'deployment'});
  assert.notEqual(developmentSpec.scratchPath, deploymentSpec.scratchPath);
  console.error('Building resource fixture development launcher');
  const development = await buildGame(developmentSpec, {swift});
  await handshake(development.binary);
  console.error('Development initialize handshake passed; building deployment launcher');
  const deployed = await buildGame(deploymentSpec, {swift});
  assert.notEqual(development.binary, deployed.binary);
  const staged = await stageTerminalExport({...deployed, destination: path.join(packageRoot, 'dist', 'ResourceStory')});
  assert.equal(staged.resources.length, 1);
  for (const [args, env] of [[['--mcp'], {}], [[], {GNUSTO_MCP: '1'}]]) {
    const result = spawnSync(staged.binary, args, {env: {...process.env, ...env}, encoding: 'utf8', timeout: 15_000});
    assert.ifError(result.error);
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
    assert.match(result.stderr, /built without.*Playtest|built without.*play.?test/i);
  }
  const before = (await fs.stat(development.binary)).mtimeMs;
  await handshake(development.binary);
  assert.equal((await fs.stat(development.binary)).mtimeMs, before);
  const stateBefore = await fs.readFile(path.join(developmentSpec.generatedRoot, 'build-state.json'), 'utf8');
  const invocationLog = await fs.readFile(swiftLog, 'utf8');
  const cached = await buildGame(developmentSpec, {swift});
  assert.equal(cached.binary, development.binary);
  assert.equal((await fs.stat(development.binary)).mtimeMs, before);
  assert.equal(await fs.readFile(swiftLog, 'utf8'), invocationLog, 'warm development lookup must not invoke Swift');
  assert.equal(await fs.readFile(path.join(developmentSpec.generatedRoot, 'build-state.json'), 'utf8'), stateBefore);
  const distribution = path.dirname(await fs.realpath(staged.binary));
  const relocated = path.join(root, 'recipient', 'ResourceStory');
  await fs.mkdir(path.dirname(relocated), {recursive: true});
  await fs.cp(distribution, relocated, {recursive: true});
  await fs.rename(packageRoot, hidden);
  try {
    const environment = {...process.env, GNUSTO_PLAIN: '1'};
    delete environment.GNUSTO_MCP;
    const result = spawnSync(path.join(relocated, 'ResourceStory'), [], {cwd: path.dirname(relocated), env: environment, input: 'quit\ny\n', encoding: 'utf8', timeout: 15_000});
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /RELOCATED_RESOURCE_ACCESSOR_OK/);
    assert.match(result.stdout, /Fixture Room/);
  } finally { await fs.rename(hidden, packageRoot); }
  console.log(JSON.stringify({sourceCapture, developmentBinary: development.binary, developmentScratch: development.scratchPath, deploymentBinary: deployed.binary, deploymentScratch: deployed.scratchPath, resources: staged.resources, checks: ['development MCP initialize', 'deployment --mcp refusal', 'deployment GNUSTO_MCP refusal', 'development reconnect without rebuild', 'relocated Bundle.module with source and build unavailable']}, null, 2));
} finally { await fs.rm(root, {recursive: true, force: true}); }

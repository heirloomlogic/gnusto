import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {loadGames} from '../lib/game-catalog.mjs';

const root = fileURLToPath(new URL('../..', import.meta.url));
const manifest = fs.readFileSync(path.join(root, 'Package.swift'), 'utf8');
const games = loadGames(root).games;
assert.equal(games.length, 7);
for (const game of games) {
  assert(manifest.includes(`.library(name: "${game.product}", targets: ["${game.module}"])`), `${game.name} must be a library product`);
  const source = fs.readFileSync(path.join(root, 'Sources', game.module, 'Packaged.swift'), 'utf8');
  assert.match(source, /public let game = PackagedGame/);
}
assert.doesNotMatch(manifest, /\.executable(?:Target)?\(/);
for (const name of ['GameMain', 'ConsoleIOHandler', 'TerminalIOHandler', 'KeyDecoder', 'PlaytestMode']) {
  assert(!fs.existsSync(path.join(root, 'Sources/Gnusto/IO', `${name}.swift`)), `${name} must leave the engine`);
}
if (process.argv.includes('--structure-only')) {
  console.log('PASS: seven library exports and retired engine terminal source');
  process.exit(0);
}
const banners = {
  CloakOfDarkness: 'Cloak of Darkness', Lighthouse: 'The Lighthouse',
  Zork1: 'Zork I: The Great Underground Empire', Dungeon: 'Dungeon',
  Gramarye: 'Gramarye', Fulminate: 'Fulminate', KindlyDeep: 'The Kindly Deep',
};
const openings = {
  CloakOfDarkness: 'Hurrying through the rainswept November night',
  Lighthouse: "The keeper's boat brought you out",
  Zork1: 'An adventure awaits amid a ruined empire buried underground.',
  Dungeon: 'Somewhere under a white house on a forgotten lawn lies',
  Gramarye: 'The tower has been in an uproar since dawn',
  Fulminate: 'The letter said somebody had been in his lab',
  KindlyDeep: 'The roof gave no more warning than a handful of dust',
};
const evidence = path.join(root, '.context/task-5-demos');
fs.mkdirSync(evidence, {recursive: true});
for (const game of games) {
  const build = spawnSync(path.join(root, 'bin/build-game'), [game.name], {cwd: root, env: process.env, encoding: 'utf8', timeout: 900_000});
  fs.writeFileSync(path.join(evidence, `${game.name}-build.log`), build.stderr || '');
  assert.ifError(build.error);
  assert.equal(build.status, 0, build.stderr);
  const binary = build.stdout.trim();
  assert(path.isAbsolute(binary));
  assert(binary.startsWith(path.join(root, '.build-launchers', game.name, 'development')));
  const saves = path.join(evidence, game.name, 'saves');
  fs.mkdirSync(saves, {recursive: true});
  const transcript = path.join(evidence, `${game.name}.transcript`);
  fs.rmSync(transcript, {force: true});
  const play = spawnSync(binary, [], {cwd: evidence, env: {...process.env, GNUSTO_PLAIN: '1', GNUSTO_SEED: '0', GNUSTO_SAVE_DIR: saves, GNUSTO_TRANSCRIPT: transcript}, input: 'look\nquit\nyes\n', encoding: 'utf8', timeout: 30_000});
  assert.ifError(play.error);
  fs.writeFileSync(path.join(evidence, `${game.name}.stdout`), play.stdout);
  fs.writeFileSync(path.join(evidence, `${game.name}.stderr`), play.stderr);
  assert.equal(play.status, 0, play.stderr);
  assert(play.stdout.trimStart().startsWith(openings[game.name]), `${game.name} wrong opening banner: ${play.stdout.slice(0, 200)}`);
  assert(play.stdout.includes(banners[game.name]), `${game.name} missing own banner`);
  assert.doesNotMatch(play.stdout, /Building for|Compiling|import Gnusto/);
  const recorded = fs.readFileSync(transcript, 'utf8');
  assert.match(recorded, /> look\n/);
  assert.match(recorded, /> quit\n/);
  console.log(`PASS: ${game.name} banner, look, quit; ${binary}`);
}
// Zork1 has no deep-start manifest. Replay its committed complete seed-0 walkthrough.
const walkthrough = fs.readFileSync(path.join(root, 'Tests/GnustoTests/Zork1WalkthroughTests.swift'), 'utf8').split('private enum Walkthrough {')[1];
const arrays = [...walkthrough.matchAll(/static let \w+: \[String\] = \[([\s\S]*?)\n    \]/g)];
const commands = arrays.flatMap(match => [...match[1].split('\n').map(line => line.split('//')[0]).join('\n').matchAll(/"([^"\n]+)"/g)].map(value => value[1]));
assert(commands.length > 300, `walkthrough extraction lost commands: ${commands.length}`);
const zorkBinary = spawnSync(path.join(root, 'bin/build-game'), ['Zork1'], {cwd: root, env: process.env, encoding: 'utf8'});
assert.equal(zorkBinary.status, 0, zorkBinary.stderr);
const zork = spawnSync(zorkBinary.stdout.trim(), [], {cwd: evidence, env: {...process.env, GNUSTO_PLAIN: '1', GNUSTO_STATUS: '1', GNUSTO_SEED: '0', GNUSTO_SAVE_DIR: path.join(evidence, 'Zork1-walkthrough-saves')}, input: `${commands.join('\n')}\n`, encoding: 'utf8', timeout: 120_000});
assert.ifError(zork.error);
fs.writeFileSync(path.join(evidence, 'Zork1-walkthrough.stdout'), zork.stdout);
fs.writeFileSync(path.join(evidence, 'Zork1-walkthrough.stderr'), zork.stderr);
assert.equal(zork.status, 0, zork.stderr);
assert.match(zork.stdout, /Your score is 350 of a possible 350/);
assert.match(zork.stdout, /mastered ZORK: The Great Underground Empire/);
assert.match(zork.stdout, /\[status\] room=Inside the Barrow[^\n]*score=350/);
console.log(`PASS: Zork1 committed seed-0 walkthrough, ${commands.length} commands, Inside the Barrow landing, score 350`);
const dungeon = spawnSync(path.join(root, 'bin/playtest-routes'), ['Dungeon', 'verify', 'd-1'], {cwd: root, env: process.env, encoding: 'utf8', timeout: 120_000});
assert.ifError(dungeon.error);
fs.writeFileSync(path.join(evidence, 'Dungeon-d-1.log'), dungeon.stdout + dungeon.stderr);
assert.equal(dungeon.status, 0, dungeon.stdout + dungeon.stderr);
console.log('PASS: Dungeon committed d-1 seed-52 route landing verification');

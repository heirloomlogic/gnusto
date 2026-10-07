import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import test from 'node:test';

test('new-game excludes populated template launcher caches from the archive', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'gnusto-new-game-cache-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  // Exercise the actual generator with a private template, without altering a live cache.
  fs.cpSync('bin', path.join(root, 'bin'), {recursive: true, filter: source => !source.split(path.sep).some(part => part.startsWith('.build') || part === 'node_modules')});
  const cache = path.join(root, 'bin/templates/.build-launchers/MyGame/deployment/scratch');
  fs.mkdirSync(cache, {recursive: true});
  fs.writeFileSync(path.join(cache, 'MyGame-sentinel'), 'MyGame absolute stale provenance');
  const destination = path.join(root, 'FreshStory');
  const result = spawnSync(path.join(root, 'bin/new-game'), ['FreshStory', destination, '--dep-path', process.cwd()], {encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.existsSync(path.join(destination, '.build-launchers')), false);
  assert.match(fs.readFileSync(path.join(destination, 'Sources/FreshStory/Packaged.swift'), 'utf8'), /PackagedGame/);
  assert.equal(fs.readFileSync(path.join(cache, 'MyGame-sentinel'), 'utf8'), 'MyGame absolute stale provenance');
});

import assert from 'node:assert/strict';
import test from 'node:test';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {loadGames, validateCatalog, resolveCatalogGame} from '../lib/game-catalog.mjs';
const value = () => ({version: 1, package: 'Story', games: [{name: 'Story', product: 'StoryLibrary', module: 'Story', symbol: 'game'}]});
test('product and module differ, and names use the existing folding rule', () => {
  const catalog = validateCatalog(value());
  assert.equal(resolveCatalogGame(catalog, 'STO-ry').product, 'StoryLibrary');
  assert.throws(() => resolveCatalogGame(catalog, 'unknown'), /Unknown game/);
});
test('rejects malformed catalogs, ambiguous names, unsafe modules and symbols', () => {
  for (const bad of [null, {}, {...value(), version: 2}, {...value(), package: ''}, {...value(), games: []}]) assert.throws(() => validateCatalog(bad));
  for (const patch of [{name: '../Story'}, {name: '/Story'}, {name: 'a/b'}, {name: 'a\\b'}, {name: '.'}, {name: '..'}, {name: ''}, {name: '   '}, {name: '!!!'}, {product: ''}, {module: undefined}, {module: 'Story; fatalError()'}, {symbol: 'other'}]) {
    const catalog = value(); Object.assign(catalog.games[0], patch); assert.throws(() => validateCatalog(catalog));
  }
  const catalog = value(); catalog.games.push({...catalog.games[0], name: 'sto-ry'}); assert.throws(() => validateCatalog(catalog), /Ambiguous/);
});
test('missing and malformed catalog files produce contextual errors', t => {
  const root = mkdtempSync(path.join(tmpdir(), 'gnusto-catalog-'));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  assert.throws(() => loadGames(root), /gnusto-games.json/);
  writeFileSync(path.join(root, 'gnusto-games.json'), '{');
  assert.throws(() => loadGames(root), /gnusto-games.json/);
});

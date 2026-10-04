import fs from 'node:fs';
import path from 'node:path';
export const foldGameName = value => String(value).toLowerCase().replace(/[^a-z0-9]/g, '');
export function validateCatalog(value) {
  if (!value || value.version !== 1 || typeof value.package !== 'string' || !value.package.trim() || !Array.isArray(value.games) || !value.games.length) throw new Error('Invalid version 1 game catalog');
  const seen = new Set();
  const games = value.games.map(game => {
    if (!game || typeof game.name !== 'string' || !game.name.trim() || /[/\\\x00-\x1f]/.test(game.name) || game.name === '.' || game.name === '..' || !foldGameName(game.name) || typeof game.product !== 'string' || !game.product.trim() || typeof game.module !== 'string' || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(game.module) || game.symbol !== 'game') throw new Error('Invalid game export in catalog');
    const folded = foldGameName(game.name);
    if (seen.has(folded)) throw new Error(`Ambiguous game name: ${game.name}`);
    seen.add(folded);
    return Object.freeze({name: game.name, product: game.product, module: game.module, symbol: game.symbol});
  });
  return Object.freeze({version: 1, package: value.package, games: Object.freeze(games)});
}
export function loadGames(packageRoot) {
  const file = path.join(packageRoot, 'gnusto-games.json');
  try { return validateCatalog(JSON.parse(fs.readFileSync(file, 'utf8'))); }
  catch (error) { throw new Error(`${file}: ${error.message}`, {cause: error}); }
}
export function resolveCatalogGame(catalog, words) {
  const game = catalog.games.find(game => foldGameName(game.name) === foldGameName(words));
  if (!game) throw new Error(`Unknown game: ${words}. Available games: ${catalog.games.map(game => game.name).join(', ')}`);
  return game;
}

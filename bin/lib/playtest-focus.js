//
// What `docs/games/<game>-playtest-focus.md` declares, read once.
//
// The focus file is the committed coverage split: `bin/playtest-preflight` passes
// it to a round as `focus`, and `playtest.js` chunks it across the blind seats.
//
// It also owns where a round's **deep starts** live and what they say —
// `routesDir`, `loadRoute`, `routeManifests`, `routeSeeds`, `seedFor` — for the same
// reason: `bin/playtest-preflight` decides whether a route can be handed out and
// `bin/playtest-routes` decides whether it can be replayed, and two judgements of
// one file is two answers to one question. ``PlaytestRoute`` in the engine is where
// the story of what these replaced is told.
//
// The focus file is what the module is named for and no longer all it holds: the
// same rule pulled in the game-doc naming, the product resolver and the shared
// check colours, and now `ledgerScan`, which parses
// `docs/games/<game>-playtest-ledger.md`. The ledger has the same shape of problem
// and the same reason to live here — `bin/playtest-preflight` and
// `.claude/workflows/playtest.dryrun.mjs` both have to decide whether a ledger can
// hand a round anything, and a parser with two implementations is a parser that
// disagrees with itself in the one run where it matters.

'use strict'

const { spawnSync } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const ROOT = path.resolve(__dirname, '..', '..')

// One read per file per process. Both parsers below want the whole focus file, and
// `bin/playtest-preflight` asks four times in one run — twice for the two halves of
// one split. Caching is not for the microseconds: two reads of one path can return
// two different states of it, and `focus` and `focusSighted` are the two halves of a
// single parse. A round whose halves came from different reads is a round nobody
// could reproduce.
const cache = new Map()
function read(relative) {
  const full = path.join(ROOT, relative)
  if (!cache.has(full)) cache.set(full, fs.readFileSync(full, 'utf8'))
  return cache.get(full)
}

/// The play-test scratch tree, which is also where a label's saves live — a
/// tester's own mid-session `save`, which is the only kind there is now.
const SCRATCH = '.context/playtest'

/// The table both front-door scripts print their checks in. Shared because an
/// operator reads them back to back — `bin/playtest-preflight` then
/// `bin/playtest-routes` — so the two formats are required to match and nothing
/// else would make them.
const GREEN = '\x1b[32m'
const RED = '\x1b[31m'
const DIM = '\x1b[2m'
const OFF = '\x1b[0m'

// A name as somebody typed it, reduced to what a product name could be. This is
// what lets `play-test Zork IV` find the `ZorkIV` product: the words are a phrase,
// the product is an identifier, and the only honest mapping between them drops
// everything that cannot appear in both.
const fold = (s) => String(s).toLowerCase().replace(/[^a-z0-9]/g, '')

// `docs/games/` is named for the game, but not by a rule a `toLowerCase()` can
// reproduce: the doc for `KindlyDeep` is `kindly-deep.md`. Assuming the naming made
// `bin/playtest-preflight KindlyDeep` derive `docPath: null` and `ledgerKeys: []` in
// silence, at which point `ground()` takes its "there is NO design doc" branch and
// the round loses the mechanics contract AND re-finds everything ever refuted. So
// match the directory rather than predict it, with the same `fold` that already
// lets `Zork IV` reach the `ZorkIV` product.
function gameDoc(game, suffix) {
  const dir = path.join(ROOT, 'docs/games')
  if (!fs.existsSync(dir)) return null
  const want = fold(game) + fold(suffix)
  const hit = fs.readdirSync(dir)
    .filter((f) => f.endsWith('.md'))
    .find((f) => fold(path.basename(f, '.md')) === want)
  return hit ? path.join('docs/games', hit) : null
}

// The split, and only the split — plus the half of it a blind seat may not have.
//
// Everything above the first `---` rule is the file's explanation of itself, for a
// person editing it, and must not travel: the focus string is pasted **verbatim**
// into a blind explorer's prompt, so anything in it that is not the split is a
// paragraph the firewall did not intend to hand over. The header of the Dungeon
// file alone would have added a thousand characters of harness talk to every blind
// seat.
//
// **The second rule is the sighted-only line, and it exists because closing one
// firewall hole opened another.** Regions used to be seated `regions[i % length]`,
// which with four regions and three copies ran 0, 1, 2 and handed the fourth to
// nobody — so the Dungeon operator put the solver's and wrong-footer's assignments
// in region four and relied on the bug to withhold them. `chunkRegions` fixed the
// seating, and the same text then reached a blind explorer: the walkthrough's type
// name, the nine cut indices, and last round's refuted list, three lines under a
// brief telling that tester it has no map. Nothing caught it, because the dry run's
// firewall check matches whole room names and none of that is a room name.
//
// A segment below the second rule is appended to the *sighted* charters' plan and
// is never chunked, never seated, and never pasted into a blind prompt.
function focusParts(focusPath) {
  const text = read(focusPath)
  // A *thematic break*, which in CommonMark is a rule with a blank line before it —
  // not a setext heading underline, which is the same three characters directly
  // under the heading text. Matching `^---$` alone means an author who underlines a
  // heading relocates every region after it out of the blind seats and into the
  // sighted addendum, silently, which is the region-nobody-was-seated-on bug
  // re-entering through a different door.
  const rule = /(?:^|\n)[ \t]*\n---[ \t]*(?=\n|$)/g
  const first = rule.exec(text)
  if (!first) return { blind: text.trim(), sighted: '' }
  const second = rule.exec(text)
  const blind = text.slice(first.index + first[0].length, second ? second.index : undefined)
  const sighted = second ? text.slice(second.index + second[0].length) : ''
  return { blind: blind.trim(), sighted: sighted.trim() }
}

/// Where a game's routes live, mirroring `PlaytestRoute.root(game:environment:)`.
///
/// `GNUSTO_PLAYTEST_ROUTES` replaces the `.playtest` base and the `<game>/routes/`
/// tail applies either way, so the keying that keeps a seven-game package's routes
/// apart is exercised rather than bypassed. Shared with `bin/playtest-routes`
/// because a second copy of a path is a second answer to where a route is.
///
/// Keyed by the game's **type name**, which is what the engine files routes under
/// (`PreparedGame.typeName`). For this package's games that is the product name.
function routesDir(game) {
  const override = process.env.GNUSTO_PLAYTEST_ROUTES
  const base = override && override.trim()
    ? path.resolve(override.replace(/^~/, os.homedir()))
    : '.playtest'
  return path.join(base, game, 'routes')
}

/// One route file, read and checked the way the engine checks it at `open`
/// (`PlaytestRoute.load`): a whole-number seed of zero or more, and a commands array
/// with at least one command in it.
///
/// The one parser, because `bin/playtest-preflight` decides whether a route can be
/// handed out and `bin/playtest-routes` decides whether it can be replayed, and two
/// judgements of one file is two answers to the same question.
///
/// - Returns: `{ name, seed, commands, landing, derivedFrom }`, or `{ name, error }`
///   for a file that cannot be used. Never both — a caller reads `error` first.
function loadRoute(name, dir) {
  let m
  try {
    m = JSON.parse(fs.readFileSync(path.join(dir, `${name}.json`), 'utf8'))
  } catch (e) {
    return { name, error: `${name}.json is missing or unreadable (${e.message})` }
  }
  if (!Number.isInteger(m.seed) || m.seed < 0) {
    return { name, error: `${name}.json declares no usable "seed"` }
  }
  const commands = Array.isArray(m.commands)
    ? m.commands.map((c) => String(c).trim()).filter((c) => c.length > 0)
    : []
  if (!commands.length) {
    return { name, error: `${name}.json declares no "commands" array with a command in it` }
  }
  return {
    name, commands, seed: m.seed, landing: m.landing || null, derivedFrom: m.derivedFrom,
  }
}

/// Every committed route of a game, in name order, each as ``loadRoute`` returns it.
///
/// A file that will not parse rides along carrying its `error` rather than being
/// skipped: `bin/playtest-preflight`'s `routes` row reports it, and a reader that
/// dropped it silently would let a round be dispatched against a deep start no
/// session can open.
/// One read per directory per process, for the reason `read()` is cached and not for
/// the microseconds: `bin/playtest-preflight` asks twice in a single-game run — once
/// for its `routes` row, once through `seedFor` for the round's pinned seed — and two
/// reads of one directory can return two states of it. A `cut` landing between them
/// would give a green row over routes the seed was never checked against, which is
/// precisely what the row exists to stop.
const routeCache = new Map()
function routeManifests(game) {
  // `resolve`, never `join`: under `GNUSTO_PLAYTEST_ROUTES` the directory is already
  // absolute, and joining an absolute path onto the package root produces a path
  // under it that holds nothing — which reads exactly like a game with no routes.
  const dir = path.resolve(ROOT, routesDir(game))
  if (!routeCache.has(dir)) {
    routeCache.set(dir, routeNames(dir).map((name) => loadRoute(name, dir)))
  }
  return routeCache.get(dir)
}

/// The route stems in a directory, sorted. Read the same way the engine reads them,
/// so a file that fails to parse is caught by whoever reads it and not dropped here.
function routeNames(dir) {
  return (fs.existsSync(dir) ? fs.readdirSync(dir) : [])
    .filter((f) => f.endsWith('.json')).map((f) => f.slice(0, -5)).sort()
}

/// The distinct seeds this game's readable routes declare, ascending.
///
/// One of them is the round's seed. More than one is a round that would turn half
/// its testers away at `open`, and none is a game with no deep starts yet — three
/// answers a caller has to tell apart, which is why this is a set and not a number.
function routeSeeds(game) {
  return [...new Set(routeManifests(game).filter((r) => !r.error).map((r) => r.seed))]
    .sort((a, b) => a - b)
}

/// The seed a round of this game must run at.
///
/// A finding without a seed is not reproducible, so a round pins one and every seat
/// uses it. This used to be scraped out of a walkthrough test — `grep` for
/// `<Game>Walkthrough`, then for a `static let seed` — which asked a Swift source
/// what the harness should do, and parsed one of this repo's two walkthroughs.
///
/// The committed routes answer it better, because they *constrain* it: `open`
/// refuses a session whose seed is not the route's, since a route replayed at
/// another seed lands somewhere else and says nothing about it.
///
/// - Returns: the seed the routes agree on; **`null` when they disagree**, which no
///   caller may paper over — picking one of two entrenches the split, and picking
///   the lowest does it silently; and 0 when there are no routes, which is
///   reproducible because it is pinned and is what a downstream game has on day one.
function seedFor(game) {
  const seeds = routeSeeds(game)
  return seeds.length > 1 ? null : (seeds[0] ?? 0)
}

// One manifest read per invocation. Every caller wants the same answer and each
// swiftpm launch takes the package lock for about a second — the very cost
// `bin/gnusto-mcp`'s mtime gate exists to stop paying.
let describedPackage
function describePackage() {
  if (describedPackage === undefined) {
    const r = spawnSync('swift', ['package', 'describe', '--type', 'json'],
      { encoding: 'utf8', cwd: ROOT })
    try { describedPackage = r.status === 0 ? JSON.parse(r.stdout) : null } catch { describedPackage = null }
  }
  return describedPackage
}

/// Every game this package builds, as the identifiers a product name can be.
function executableProducts() {
  return (describePackage()?.products || [])
    .filter((p) => p.type === 'executable' || (p.type && 'executable' in p.type))
    .map((p) => p.name)
}

/// The product somebody's words meant, or `null`.
///
/// Fold both sides so a phrase can find an identifier: `Zork IV` and `zork-iv`
/// both reach `ZorkIV`. Shared rather than copied because this is the contract a
/// person sees — which words find which game, and what they are told when none
/// does — and two front doors disagreeing about it is worse than either being
/// wrong.
function resolveGame(words) {
  const products = executableProducts()
  return {
    game: products.find((p) => fold(p) === fold(words)) || null,
    products,
  }
}

// `ledgerKeys` means **rejections**, and only rejections: `playtest.js` folds them
// into `seen`, and `seen.has(key)` drops a finding unreported. So the verdict column
// decides, and every other row in the file has to stay out.
//
// The first draft scraped every backticked `a::b` string in the whole markdown, and
// the cost was not cosmetic. On Dungeon's ledger that is 220 keys against 44 real
// refutations: it swallowed 61 `fixed` rows — which the ledger's own preamble says
// must come back, at raised severity, because a `fixed` key that reappears is a
// **regression** — and 48 still-open `confirmed` rows, telling testers that live
// defects were already rejected. It also swept up the prose placeholders, so
// `"a::b"` and `"<ownerFile>::<normalized offending text>"` led the list, and
// `playtest.js`'s 60-key prompt cap was spent on them.
//
// The columns are right there. The ledger's rows are `| key | class | verdict | note |`
// — a human reading record that is already machine-readable — so this reads the
// verdict rather than guessing from the shape of the key.
//
// Returns the usable keys, the number of refutations that could not become one,
// and the verdict — because a count of zero has two entirely different causes: a
// game nothing has been refuted about, and a file whose every refutation was
// written down in a form that cannot match. `bin/playtest-preflight`'s `ledger`
// row and `playtest.dryrun.mjs`'s ledger assertion are the two readers, and the
// verdict ships with the parse so the rule they enforce has one owner. Writing it
// out at both call sites is the drift this whole file exists to prevent.
function ledgerScan(p) {
  // **Read the header, never an index.** Five ledgers have put the verdict in three
  // different places — `| Key | Verdict | Category |`, `| key | verdict | class |
  // severity |`, and Fulminate's `| Key (abbreviated) | Tree | Verdict | Note |` —
  // and a fixed column is wrong for at least one of them whichever one you pick.
  // Reading `cells[2]` picked the *category* out of every Dungeon table, so no row
  // ever matched `refuted`; a fallback heuristic then let the whole of the one
  // three-column table through instead, and the round of 2026-08-29 was handed 55
  // keys of which the true useful count was zero.
  //
  // Both mistakes are silent, which is why this is parsed rather than assumed: a
  // round handed the wrong keys re-finds everything it should skip, and a round
  // handed a `fixed` key drops the regression this file exists to catch, unverified
  // and unreported.
  let verdictAt = null
  let wholeTableIsRefuted = false
  const keys = []
  let inert = 0
  for (const line of read(p).split('\n')) {
    if (!line.trimStart().startsWith('|')) {
      // A table ends at the first line that is not a row. Forgetting this carried
      // one table's column layout into the next one down the file.
      verdictAt = null
      wholeTableIsRefuted = false
      continue
    }
    const cells = line.split('|').slice(1, -1).map((c) => c.trim())
    if (cells.length < 3) continue
    const key = (cells[0].match(/^`([^`]+::[^`]+)`$/) || [])[1]

    if (!key) {
      // A header, a separator, or a table with no key column at all. Only the first
      // teaches us anything.
      const lower = cells.map((c) => c.toLowerCase())
      if (!/^key$/.test(lower[0]) && !/^key \(/.test(lower[0])) continue
      verdictAt = lower.findIndex((c) => c === 'verdict')
      if (verdictAt < 0) verdictAt = null
      // The older shape, where the row is a refutation by virtue of the table it is
      // in rather than by a word in it: its third column is the refutation's reason.
      wholeTableIsRefuted = lower.includes('refutation kind')
      continue
    }
    // The suffixed spellings are deliberate — `fixed (by #331)`,
    // `confirmed (needs-human)` — so match the leading word, not the whole cell.
    const refuted = wholeTableIsRefuted
      || (verdictAt !== null && /^refuted\b/.test(cells[verdictAt] || ''))
    if (!refuted) continue
    // A key the ledger stored abbreviated can never match one a round produces:
    // `normalize()` emits nothing but `[a-z0-9 ]`, so an ellipsis is inert by
    // construction. Dropping them is what makes the count preflight prints the
    // number of keys that can actually do something, and counting them is what
    // stops the drop from being silent.
    if (key.includes('\u2026')) { inert++; continue }
    keys.push(key)
  }
  const distinct = [...new Set(keys)]
  // A file that holds refutations and hands over none of them is broken. A file
  // that holds none at all is a game nothing has been refuted about yet, which is
  // a perfectly good state for a ledger to be in and must stay green.
  return { keys: distinct, inert, ok: distinct.length > 0 || inert === 0 }
}

module.exports = {
  ROOT,
  SCRATCH,
  GREEN,
  RED,
  DIM,
  OFF,
  fold,
  describePackage,
  executableProducts,
  resolveGame,
  gameDoc,
  focusParts,
  routesDir,
  routeNames,
  loadRoute,
  routeManifests,
  routeSeeds,
  seedFor,
  ledgerScan,
}

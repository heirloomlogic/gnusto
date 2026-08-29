//
// What `docs/games/<game>-playtest-focus.md` declares, read once.
//
// The focus file is the committed coverage split: `bin/playtest-preflight` passes
// it to a round as `focus`, and `playtest.js` chunks it across the blind seats. It
// also declares the round's *saved games* — which slot stands where, as a cut of
// the walkthrough route — because those two facts belong in one place. A region
// that says "restore `d-1` and push the buttons" and a slot table that says `d-1`
// is `route[0:113]` are the same sentence written twice if they live apart, and a
// round dies quietly when they disagree: every tester's `restore` answers
// `Restore failed.`, which reads as a finding about the game rather than about the
// harness.
//
// So there is one declaration and two readers. `bin/playtest-preflight` reads it to
// check the slots exist before dispatching anybody; `bin/playtest-slots` reads it
// to cut them. Neither has a list of its own.

'use strict'

const { spawnSync } = require('node:child_process')
const crypto = require('node:crypto')
const fs = require('node:fs')
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

/// The play-test scratch tree, which is also where a label's saves live.
const SCRATCH = '.context/playtest'

/// The table both front-door scripts print their checks in. Shared because an
/// operator reads them back to back — `bin/playtest-preflight` then
/// `bin/playtest-slots` — so the two formats are required to match and nothing
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

// The `Slots:` line in the header, which is the one place a round's saved games are
// named. It sits above the first rule on purpose: it is operator plumbing, and a
// tester handed the label and the route symbol is a tester handed the answer key.
//
//     Slots: `Dungeon-r1-slots`, cut from `DungeonWalkthroughTests.route`
//
const SLOT_LABEL = /^Slots:\s*`([A-Za-z0-9][A-Za-z0-9._-]*)`\s*,\s*cut from\s*`([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)`/m

// Anything at all that meant to be that line. A `Slots:` the strict pattern cannot
// read — bolded to `**Slots:**`, a backtick dropped — would otherwise return `null`,
// which this module cannot tell apart from a game that ships no saves: no `slots`
// row in preflight, `slots: null` in the round's arguments, `savesFrom` never
// passed, and every tester answering `Restore failed.` That is precisely the failure
// this file exists to end, so an unreadable declaration is loud and a missing one is
// silent.
const SLOT_LABEL_LOOSE = /^\s*\**Slots:\**/m

// Where each slot stands, taken from the regions' own prose rather than from a
// second table. The regions already have to say this — a tester is told "`d-1`
// (cut at `route[0:113]`)" so it knows how deep it is standing — and a table beside
// them would be a copy to keep in step. Parse the sentence instead.
//
// The array's own name, never the literal `route`: a second game whose walkthrough
// calls it `solution` declares that in the header, and a pattern that ignored the
// header would answer "no slots" rather than "I could not read yours".
const slotCut = (routeName) =>
  new RegExp(`\`([A-Za-z0-9][A-Za-z0-9._-]*)\`\\s*\\(cut at\\s*\`${routeName}\\[0:(\\d+)\\]\`\\)`, 'g')

// The same sentence read loosely, so a declaration that failed the strict pattern is
// counted rather than skipped. A dropped backtick used to cost one slot out of nine
// and leave preflight reporting `8/8` green.
const slotCutLoose = (routeName) => new RegExp(`\\(cut at[^)]*${routeName}\\[0:`, 'g')

/// What a focus file declares about the round's saved games.
///
/// - Returns: `{ label, routeType, routeName, slots: [{ name, cut }] }`, slots in
///   ascending cut order, or `null` when the file declares no `Slots:` line. A file
///   with a `Slots:` line and no `(cut at …)` mentions returns an empty `slots`,
///   which is a different thing from declaring none and is reported as such.
function slotPlan(focusPath) {
  const text = read(focusPath)
  const header = SLOT_LABEL.exec(text)
  if (!header) {
    if (!SLOT_LABEL_LOOSE.test(text)) return null
    throw new Error(
      `${focusPath} has a \`Slots:\` line this cannot read. It must be exactly:\n`
      + '    Slots: `<label>`, cut from `<TestType>.<arrayName>`\n'
      + '  with the backticks, unbolded, above the first rule.')
  }
  const routeName = header[3]
  // Only the regions, never the whole file. The header explains the format, and an
  // example of a declaration is a declaration to a scan that reads everything — so
  // documenting the syntax used to enter the plan as a phantom slot, or collide with
  // a real one and refuse to parse the file at all.
  const { blind } = focusParts(focusPath)
  const loose = [...blind.matchAll(slotCutLoose(routeName))].length
  const seen = new Map()
  for (const m of blind.matchAll(slotCut(routeName))) {
    const name = m[1]
    const cut = Number(m[2])
    // A slot named twice at two depths is the drift this whole module exists to
    // stop, and it is cheaper to refuse than to pick one.
    if (seen.has(name) && seen.get(name) !== cut) {
      throw new Error(
        `${focusPath} declares slot "${name}" at both route[0:${seen.get(name)}] and `
        + `route[0:${cut}]. One of them is stale.`)
    }
    seen.set(name, cut)
  }
  // The join the prose form otherwise lacks. A tester reads the sentence and this
  // reads the sentence, but only this one is parsed — so a malformed declaration is
  // a slot the round promises and does not ship, and it looked exactly like a round
  // that promised eight.
  if (loose !== seen.size) {
    throw new Error(
      `${focusPath} has ${loose} slot declarations and ${seen.size} that parse. `
      + 'Each must read exactly: `<name>` (cut at `'
      + `${routeName}[0:<n>]\`).`)
  }
  return {
    label: header[1],
    routeType: header[2],
    routeName,
    slots: [...seen].map(([name, cut]) => ({ name, cut })).sort((a, b) => a.cut - b.cut),
  }
}

/// The commands of a walkthrough route, read out of the committed test.
///
/// The route is a `static let <name>: [String] = [ … ]` literal in the suite that
/// pins it, and it is the single source of truth for what a slot's depth means:
/// indices drift between commits — `38e27b8` removed a `drop rope` and moved every
/// index after it — so a cut depth is only meaningful against the route as it
/// stands right now. Re-deriving it from the test on every cut is what keeps a
/// stale index from producing a plausible slot in the wrong room.
///
/// - Returns: `{ file, commands }`, or `null` when the declaration isn't found.
function routeCommands(routeType, routeName) {
  const hit = spawnSync(
    'grep',
    ['-rl', '--include=*.swift', `struct ${routeType}`, 'Tests'],
    { encoding: 'utf8', cwd: ROOT })
  const file = (hit.stdout || '').trim().split('\n').filter(Boolean)[0]
  if (!file) return null

  const lines = read(file).split('\n')
  const opens = new RegExp(`static\\s+let\\s+${routeName}\\s*:\\s*\\[String\\]\\s*=\\s*\\[`)
  const at = lines.findIndex((l) => opens.test(l))
  if (at < 0) return null

  const commands = []
  for (let i = at + 1; i < lines.length; i += 1) {
    // The literal's own closing bracket, alone on its line — the house style for
    // every route in this suite, and the only terminator that cannot be confused
    // with a bracket inside a comment.
    if (/^\s*\]\s*$/.test(lines[i])) return { file, commands }
    // Comments are the route's own narration and they hold no quoted strings, so
    // cutting at `//` is exact rather than approximate.
    for (const m of lines[i].split('//')[0].matchAll(/"((?:[^"\\]|\\.)*)"/g)) commands.push(m[1])
  }
  return null
}

// A finding without a seed is not reproducible, and a game with a pinned
// walkthrough has already chosen one. Read it rather than defaulting past it.
function seedFor(game) {
  const found = spawnSync(
    'grep', ['-rl', '--include=*.swift', `${game}Walkthrough`, 'Tests'],
    { encoding: 'utf8', cwd: ROOT })
    .stdout.trim().split('\n').filter(Boolean)
  // The walkthrough file first when there is one: several suites pin the same
  // seed, and the walkthrough is the one whose route the round is measured against.
  found.sort((a, b) => (b.includes('Walkthrough') ? 1 : 0) - (a.includes('Walkthrough') ? 1 : 0))
  for (const file of found) {
    // Any annotation, not just `Int`. Dungeon's is `static let seed: UInt64 = 52`,
    // and a regex that named the type read it as 0 — which is a different round.
    const m = read(file).match(/\bstatic\s+let\s+seed\b[^=\n]*=\s*([0-9]+)/)
    if (m) return Number(m[1])
  }
  return 0
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

/// Where `bin/playtest-replay --label <label> --save <slot>` puts its bytes, and
/// therefore where `--saves-from <label>` and the MCP `savesFrom` read them back.
const savesDir = (label) => path.join(SCRATCH, label, 'saves')

/// What a set of slots was cut from, in twelve hex characters.
///
/// **Existing is not the same as being current.** A slot is `route[0:N]` of a route
/// that moves: `38e27b8` removed a `drop rope` and shifted every index after it, so a
/// slot cut last month stands somewhere else today while its file sits there reading
/// green. That is the same failure the `slots` row was added for — a description and
/// the thing described drifting apart with nothing to notice — one level in.
///
/// So the cut records what it was a cut *of*: the route as it stands, the seed, and
/// the depths asked for. Change any of the three and the fingerprint changes, and
/// `bin/playtest-preflight` says to cut again rather than shipping yesterday's rooms.
const slotFingerprint = (plan, route, seed) =>
  crypto.createHash('sha256')
    .update(`${seed}\n${route.commands.join('\n')}\n`)
    .update(plan.slots.map((s) => `${s.name}:${s.cut}`).join(','))
    .digest('hex')
    .slice(0, 12)

/// The marker a cut leaves beside its bytes, and a reader for it.
const fingerprintFile = (label) => path.join(savesDir(label), '.cut-from')
const fingerprintOf = (label) => {
  try { return fs.readFileSync(path.join(ROOT, fingerprintFile(label)), 'utf8').trim() }
  catch { return null }
}

/// Each declared slot, and whether its bytes are on disk.
///
/// `.context/` is gitignored, so a fresh checkout has none of them however
/// carefully the focus file describes them. That is the failure this answers.
function slotStatus(plan) {
  return plan.slots.map((slot) => {
    const file = path.join(savesDir(plan.label), `${slot.name}.gnusto`)
    return { ...slot, file, exists: fs.existsSync(path.join(ROOT, file)) }
  })
}

module.exports = {
  ROOT,
  SCRATCH,
  slotFingerprint,
  fingerprintFile,
  fingerprintOf,
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
  slotPlan,
  routeCommands,
  seedFor,
  savesDir,
  slotStatus,
}

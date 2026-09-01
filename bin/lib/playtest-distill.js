//
// Shrinking a played command list down to a route worth committing.
//
// A round's session reached somewhere in sixty turns of which perhaps twelve
// mattered. Replaying it verbatim as a deep start replays the other forty-eight
// too — including the lantern that burned down while a tester tried fifty ways of
// working a lever. So a learned route is only usable once it has been distilled,
// and this file is the distillation: the arithmetic, with no judgement in it.
//
// **The judgement and the causality are deliberately separated.** An agent reads
// the round's transcripts and says *this state is worth being able to return to*,
// which is the half an agent is good at. It never says which of sixty commands
// mattered — `bin/playtest-replay` decides that, one replay at a time, because
// that is a thing a machine can know and an agent can only guess at from prose.
//
// ## What the predicate actually checks
//
// Room, score, the `look` answer and the `inventory` answer, with `moves` and
// `time` dropped — a shrunk route has fewer moves by construction, so gating on
// them would refuse every cut.
//
// It does **not** check timer state, actor positions, or anything else the
// tester's next fifty turns depend on. A route can preserve the landing and still
// have left the thief somewhere else. That is stated here rather than implied
// because the same argument one level out — that the `[status]` footer is the
// wrong test for where a deep start stands — is what the old slot machinery's
// header spent its length on, and it applies just as much in here.
//
// ## Why the yield is smaller than it looks like it should be
//
// A pinned seed means deleting any **turn-costing** command shifts the random
// stream for everything after it, so the predicate fails for reasons that have
// nothing to do with whether the deleted command was load-bearing. Measured on
// Dungeon's 719-command walkthrough (#359): 13,061 replays and fifteen minutes
// removed 22 commands, and 15 of those 22 were `score` — a meta intent that costs
// no turn and therefore moves no seed.
//
// Which is the whole reason ``freeRuns`` exists and runs first. A free command can
// be dropped without disturbing anything downstream of it, the engine already says
// which turns were free in its own status footer, and one replay confirms the whole
// batch. On that route it found 15 of the 22 commands that fifteen minutes of
// delta-debugging found.
//
// The caveat runs the other way for a *learned* route, which is what this file is
// actually for: a walkthrough is hand-tuned and near-minimal already, and a session
// with fifty turns idling at a lever has far more removable slack. ddmin converges
// faster when more is removable, because whole chunks succeed early.

'use strict'

const { LANDING_PROBE, LANDING_INVENTORY } = require('./playtest-focus')
const { answerTo, lastStatus } = require('./playtest-replay')

/// Every `[status]` footer's `turn=` field, in order.
///
/// The first is the opening block, which is not a command, so command `i` is
/// `turnCosts[i + 1]`. A run that recorded fewer footers than it was fed commands
/// stopped early, and the caller must not align against it.
function turnCosts(text) {
  return [...text.matchAll(/^\[status\].*\bturn=(free|cost)\b.*$/gm)].map((m) => m[1])
}

/// The landing a candidate produced, in the form the predicate compares.
///
/// Built on `lastStatus` rather than beside it. `bin/lib/playtest-replay.js`'s own
/// header says why a second footer parser is not allowed to exist here: the footer is
/// the harness's own line, a JS copy of it beside the engine's `StatusFooter` is
/// already two ways to disagree, and a third would live in whatever front door came
/// next. This is that front door.
///
/// - Returns: `{ room, moves, score, look, inventory, playable }`, or `null` for a
///   transcript with no footer in it at all — which is a replay that never ran, not a
///   landing that differs, and the caller has to tell those apart.
function landingSignature(text) {
  const fields = lastStatus(text)
  if (!fields) return null
  const look = answer(text, LANDING_PROBE)
  const inventory = answer(text, LANDING_INVENTORY)
  return {
    room: fields.room || '',
    // Carried but never compared. A shrunk route has fewer moves by construction, so
    // the predicate must not read it — the manifest records it because a person
    // choosing between two routes does.
    moves: fields.moves || '?',
    score: fields.score || '',
    look,
    inventory,
    // Whether the game was still taking commands at the end of it. A round learns
    // its routes from sessions that sometimes died, and a landing on a corpse has a
    // perfectly ordinary-looking `[status]` footer — same room, same score, and the
    // move counter simply stopped. What it does not have is two different answers:
    // an ended game replies to `look` and to `inventory` with the same line, because
    // neither was parsed as itself, and a live game never can. `readLanding` in
    // `bin/playtest-routes` is where the refusal is worded; this is the same fact for
    // the shrink's own oracle, which reads its transcripts directly.
    playable: !!look && look !== inventory,
  }
}

/// The reply to the last occurrence of one command, whitespace folded.
///
/// `answerTo` is the reader — the *last* occurrence, because a candidate may well type
/// `look` itself and the probe appended after it is the one that describes the landing.
/// Folded here because the shrink compares two of these for equality across runs, and
/// a wrap that differs by a newline is not a landing that differs.
const answer = (text, command) => (answerTo(text, command) || '').replace(/\s+/g, ' ').trim()

/// Two landings, compared as the shrink's predicate compares them.
const sameLanding = (a, b) => !!a && !!b
  && a.room === b.room && a.score === b.score
  && a.look === b.look && a.inventory === b.inventory

/// The indices of the commands that cost no turn, read off the run's own footers.
///
/// Measured rather than predicted: the engine prints `turn=free` for a meta intent
/// and for a line that failed to parse, and this reads that back rather than
/// keeping a JS copy of `Command.metaIntents` that would drift the day a verb moved
/// between the two tables.
///
/// **It is a candidate set, not a verdict.** `undo` and `restore` are free and
/// utterly load-bearing, so the caller drops the whole batch on one replay and keeps
/// it only if the landing survived. That check is what makes reading the footer safe.
///
/// - Returns: the 0-based indices, or `null` when the transcript recorded fewer
///   footers than there were commands — a truncated run, where alignment is a guess.
function freeRuns(text, count) {
  const costs = turnCosts(text)
  if (costs.length < count + 1) return null
  const free = []
  for (let i = 0; i < count; i += 1) if (costs[i + 1] === 'free') free.push(i)
  return free
}

/// Delta-debugging over contiguous segments: drop a run, replay, keep the cut if it
/// still lands.
///
/// Classic ddmin's complement pass and nothing else, which is exactly the shape
/// #364 asks for — *segments before individual lines*. Granularity starts at 2, so
/// the first candidates are halves and the largest cuts are tried first; that is
/// what makes a bounded run worth having, because whatever the bound stops, the
/// biggest wins are already behind it.
///
/// Chunks are tried **back to front**. A trailing run has nothing after it to
/// disturb, so it is both the likeliest to survive the predicate and the likeliest
/// to be a tester's wandering — the fifty turns at the lever are at the end of the
/// stretch that reached the target, never in front of it.
///
/// - Parameters:
///   - commands: the list to shrink.
///   - test: the predicate. One replay per call; `true` keeps the cut.
///   - budget: the most `test` calls this is allowed. **Named, printed and honest**
///     — a phase that silently truncated its own coverage would read as one that
///     covered everything, so `capped` comes back and the caller says so.
/// - Returns: `{ commands, replays, capped, dropped }`, where `dropped` is one row
///   per accepted cut, in the order they were taken.
function shrink(commands, test, budget) {
  let current = commands.slice()
  const dropped = []
  let replays = 0
  let capped = false
  let n = 2

  while (current.length > 1 && n <= current.length) {
    const size = Math.ceil(current.length / n)
    const bounds = []
    for (let from = 0; from < current.length; from += size) {
      bounds.push([from, Math.min(current.length, from + size)])
    }
    let cut = false
    for (const [from, to] of bounds.reverse()) {
      // Never shrink to nothing: a route with no commands is not a deep start, and
      // the empty list trivially "lands" wherever the game opens.
      if (to - from >= current.length) continue
      if (replays >= budget) { capped = true; break }
      replays += 1
      const candidate = [...current.slice(0, from), ...current.slice(to)]
      if (!test(candidate)) continue
      dropped.push({ at: from, commands: current.slice(from, to) })
      current = candidate
      // ddmin's own rule: a successful complement lowers the granularity by one, so
      // the next pass tries chunks of about the same size over a shorter list rather
      // than restarting at halves.
      n = Math.max(n - 1, 2)
      cut = true
      break
    }
    if (capped) break
    if (cut) continue
    if (n >= current.length) break
    n = Math.min(n * 2, current.length)
  }
  return { commands: current, replays, capped, dropped }
}

module.exports = { landingSignature, sameLanding, freeRuns, shrink }

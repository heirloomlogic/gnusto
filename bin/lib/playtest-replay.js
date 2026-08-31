//
// Driving `bin/playtest-replay` from a front-door script.
//
// Both `bin/playtest-slots` and `bin/playtest-routes` cut and verify by replaying a
// command list and reading the landing off the transcript, so the scaffold is
// written once here. The `[status]`-footer parser has an additional reason to live
// in one place: the footer is the harness's own line, and two JS copies of its
// parser plus the engine's `StatusFooter` is already three — a fourth way to
// disagree is not wanted.

'use strict'

const { spawnSync } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

// The replay script is the one thing that knows how to boot the game with a pinned
// seed and a transcript beside it. Cutting a route is replaying it and reading the
// landing off the transcript; nothing about that is reimplemented here.
function replay(args) {
  const r = spawnSync('bin/playtest-replay', args, { encoding: 'utf8' })
  return { status: r.status, out: `${r.stdout || ''}${r.stderr || ''}` }
}

// `--max-turns` refuses a list longer than 250 by default, which is a runaway guard
// and not a budget: a 719-command route is exactly the case it is not for. Same for
// the 60-second wall clock, which a seven-hundred-turn replay outgrows on a cold page
// cache. Both are raised from the work rather than from a constant, so a longer route
// needs no edit here.
const turnCap = (n) => String(n + 50)
const timeoutFor = (n) => String(Math.max(120, Math.ceil(n / 2)))

/// The last `[status]` footer in a transcript, as its fields.
///
/// The footer is the harness's own line, not the game's, so it is the one thing in a
/// transcript no game can re-voice — which is what makes reading it safe across seven
/// games that share nothing else.
function lastStatus(text) {
  const hits = [...text.matchAll(/^\[status\] (.+)$/gm)]
  if (!hits.length) return null
  const fields = {}
  for (const pair of hits[hits.length - 1][1].split('|')) {
    const [k, ...v] = pair.trim().split('=')
    fields[k.trim()] = v.join('=').trim()
  }
  return fields
}

/// The reply to one command, read out of a transcript by its prompt line.
function answerTo(text, command) {
  const needle = `\n> ${command}\n`
  const at = text.indexOf(needle)
  if (at < 0) return null
  const rest = text.slice(at + needle.length)
  const end = rest.search(/\n\[status\]/)
  return (end < 0 ? rest : rest.slice(0, end)).trim()
}

// One command list, one replay, one temp file cleaned up either way. The failure
// detail is the replay script's own last words, which is the only thing worth
// showing when a cut of seven hundred commands stops early. The caller's prefix
// names its temp files, so a temp listing says which front door left it behind.
function runReplay(prefix, name, commands, args) {
  const list = path.join(os.tmpdir(), `${prefix}-${process.pid}-${name}.txt`)
  fs.writeFileSync(list, `${commands.join('\n')}\n`)
  try {
    const r = replay(['--commands', list, ...args])
    return r.status === 0
      ? { ok: true, out: r.out }
      : { ok: false, detail: r.out.trim().split('\n').slice(-3).join(' / ') }
  } finally {
    fs.rmSync(list, { force: true })
  }
}

module.exports = { replay, turnCap, timeoutFor, lastStatus, answerTo, runReplay }

//
// Driving `bin/playtest-replay` from a front-door script.
//
// `bin/playtest-routes` cuts and verifies by replaying a command list and reading
// the landing off the transcript, and the scaffold for that lives here rather than
// in it. It had a second caller once — `bin/playtest-slots`, which cut a round's
// saved games — and the reason to keep it separate outlived that one: the
// `[status]` footer is the harness's own line, and a JS copy of its parser beside
// the engine's `StatusFooter` is already two ways to disagree about it. A third
// would live in whatever front door came next.

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
function statusFields(line) {
  const fields = {}
  for (const pair of line.split('|')) {
    const [k, ...v] = pair.trim().split('=')
    fields[k.trim()] = v.join('=').trim()
  }
  return fields
}

function lastStatus(text) {
  const hits = [...text.matchAll(/^\[status\] (.+)$/gm)]
  return hits.length ? statusFields(hits[hits.length - 1][1]) : null
}

const promptLine = (command) => `\n> ${command}\n`
const lastPromptIndex = (text, command) => text.lastIndexOf(promptLine(command))

/// The status immediately before the last occurrence of a command.
///
/// Landing probes are real game commands and may cost turns or change state. The
/// route ends before those observer commands, so callers read its status from the
/// transcript prefix while retaining this module's single footer parser.
function statusBefore(text, command) {
  const at = lastPromptIndex(text, command)
  return at < 0 ? null : lastStatus(text.slice(0, at))
}

/// The status produced by the last occurrence of a command.
///
/// Reads the first footer after that prompt, rather than the transcript's last one:
/// a landing trace can append another observer after `look`, and its footer belongs
/// to that later command.
function statusAfter(text, command) {
  const at = lastPromptIndex(text, command)
  if (at < 0) return null
  const hit = text.slice(at + promptLine(command).length).match(/^\[status\] (.+)$/m)
  return hit ? statusFields(hit[1]) : null
}

/// The reply to one command, read out of a transcript by its prompt line. The
/// *last* prompt of that name wins: a route replayed in one run may issue the same
/// command more than once (its own `inventory` before the landing probe appends
/// another), and the landing is the final one, never the first.
function answerTo(text, command) {
  const needle = promptLine(command)
  const at = lastPromptIndex(text, command)
  if (at < 0) return null
  const rest = text.slice(at + needle.length)
  const end = rest.search(/\n\[status\]/)
  return (end < 0 ? rest : rest.slice(0, end)).trim()
}

/// One command's response and the status immediately before it, with transcript
/// wrapping removed from the response. A route observer is meaningful only as both:
/// the answer says what the command saw, and the preceding footer says where its
/// fresh replay began.
function observationBefore(text, command) {
  const fields = statusBefore(text, command)
  const answer = answerTo(text, command)
  if (!fields || answer === null) return null
  return { fields, answer: answer.replace(/\s+/g, ' ').trim() }
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

module.exports = {
  replay, turnCap, timeoutFor, lastStatus, statusBefore, statusAfter, answerTo,
  observationBefore, runReplay,
}

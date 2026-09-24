// Exercises issue #448 item 4: `bin/playtest-measure` used to loop `sys.argv[1:]`
// with `status = 0` set outside the loop, so an empty argv (a shell glob like
// `probe-*` that matched nothing under nullglob) or an argv whose every entry
// names a probe it cannot measure exited 0 having measured nothing — a silent
// false green for whatever dispatched it.
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const repo = fileURLToPath(new URL('../..', import.meta.url))
const script = path.join(repo, 'bin/playtest-measure')

function run(args) {
  return spawnSync(script, args, { encoding: 'utf8', timeout: 10_000 })
}

function probe(t, { commands = 'look\nexamine lamp\n', transcript = '[status] room=Hall | moves=1 | turn=cost\n' } = {}) {
  const root = realpathSync(mkdtempSync(path.join(tmpdir(), 'gnusto-measure-')))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  mkdirSync(path.join(root, 'probe'))
  writeFileSync(path.join(root, 'probe/commands.txt'), commands)
  writeFileSync(path.join(root, 'probe/transcript.txt'), transcript)
  return path.join(root, 'probe')
}

test('no arguments prints usage and exits 2, not the old silent 0', () => {
  const result = run([])
  assert.equal(result.status, 2)
  assert.equal(result.stdout, '')
  assert.match(result.stderr, /^Usage: bin\/playtest-measure /)
})

test('a single argument that cannot be measured exits non-zero and says so twice', () => {
  const result = run(['/does/not/exist'])
  assert.equal(result.status, 1)
  assert.match(result.stderr, /holds no commands\.txt/)
  assert.match(result.stderr, /nothing measured — all 1 argument\(s\) failed/)
  assert.equal(result.stdout, '')
})

test('every argument failing gets one gap line each plus a distinct summary', () => {
  const result = run(['/does/not/exist/a', '/does/not/exist/b'])
  assert.equal(result.status, 1)
  assert.equal((result.stderr.match(/holds no commands\.txt/g) || []).length, 2)
  assert.match(result.stderr, /nothing measured — all 2 argument\(s\) failed/)
})

test('an unreadable artifact fails cleanly rather than with a traceback', (t) => {
  const dir = probe(t)
  chmodSync(path.join(dir, 'commands.txt'), 0o000)
  const result = run([dir])
  assert.equal(result.status, 1)
  assert.match(result.stderr, /unreadable/)
  assert.doesNotMatch(result.stderr, /Traceback/)
  assert.match(result.stderr, /nothing measured — all 1 argument\(s\) failed/)
})

test('a mix of a working probe and a missing one keeps its existing exit code and output', (t) => {
  const dir = probe(t)
  const result = run([dir, '/does/not/exist'])
  assert.equal(result.status, 1)
  assert.match(result.stderr, /holds no commands\.txt/)
  assert.doesNotMatch(result.stderr, /nothing measured/)
  assert.match(result.stdout, new RegExp(`=== ${dir.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')} ===`))
})

test('every argument measuring keeps existing output and exit code unchanged', (t) => {
  const dir = probe(t)
  const result = run([dir])
  assert.equal(result.status, 0)
  assert.equal(result.stderr, '')
  assert.match(result.stdout, /distinct rooms entered/)
})

// Issue #627 item 3. Every producer writes a `[status]` footer under the opening
// text, and it reads `turn=free` because the opening is not a turn. It is not a
// command either, so "free commands" must not count it.
test('free commands leaves out the opening footer', (t) => {
  const dir = probe(t, {
    commands: 'west\n// a note\neast\ninventory\n',
    transcript: [
      'Opening text.',
      '[status] room=Foyer | moves=0 | turn=free',
      '> west',
      '[status] room=Cloakroom | moves=1 | turn=cost',
      '> east',
      '[status] room=Foyer | moves=2 | turn=cost',
      '> inventory',
      '[status] room=Foyer | moves=2 | turn=free',
      '',
    ].join('\n'),
  })
  const result = run([dir])
  assert.equal(result.status, 0, result.stderr)
  assert.match(result.stdout, /^free commands\s+: 1$/m)
  assert.match(result.stdout, /^turns charged\s+: 2$/m)
  assert.match(result.stdout, /^distinct rooms entered\s+: 2$/m)
})

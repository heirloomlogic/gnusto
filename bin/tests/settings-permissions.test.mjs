// Issue #448 item 6: the engine's own `.claude/settings.json` allowlist omitted
// `bin/playtest-measure` and `bin/export-game`, even though the template this
// repo hands new games (`bin/templates/.claude/settings.json`) grants both and
// SKILL.md's measurement workflow uses the first. A session working in this
// checkout — the one every Builder and playtest round actually runs in — hit a
// permission prompt the template never would. This is a static config check
// rather than a spawned process, so it is cheap enough to be worth having even
// though nothing else in this directory asserts on `.claude/settings.json`
// directly.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const repo = fileURLToPath(new URL('../..', import.meta.url))

test('the engine settings allowlist grants bin/playtest-measure and bin/export-game', () => {
  const settings = JSON.parse(readFileSync(`${repo}/.claude/settings.json`, 'utf8'))
  const allow = settings.permissions?.allow ?? []
  assert.ok(allow.includes('Bash(bin/playtest-measure:*)'), allow.join('\n'))
  assert.ok(allow.includes('Bash(bin/export-game:*)'), allow.join('\n'))
})

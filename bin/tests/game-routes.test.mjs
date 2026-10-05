import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'

const require = createRequire(import.meta.url)
const { landingMismatch, routePrefix } = require('../lib/playtest-focus')
const { landingSignature } = require('../lib/playtest-distill')
const { observationBefore } = require('../lib/playtest-replay')

const declared = {
  room: 'Shaft Room',
  moves: '179',
  score: '210',
  inventory: 'You are carrying a brass lantern.',
}
const observed = {
  room: 'Shaft Room',
  moves: '179',
  score: '210',
  carrying: 'You are carrying a brass lantern.',
}

test('route prefix retains the complete declared landing for verification', (t) => {
  const root = realpathSync(mkdtempSync(path.join(tmpdir(), 'gnusto-route-')))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  mkdirSync(root, { recursive: true })
  writeFileSync(path.join(root, 'shaft.json'), JSON.stringify({
    seed: 52,
    commands: ['north'],
    landing: declared,
  }))

  const route = routePrefix('shaft', root)
  assert.equal(route.landing, declared.room)
  assert.deepEqual(route.landingRecord, declared)
  assert.deepEqual(route.routeCommands, ['north'])
})

test('matching room, moves, score and inventory verifies', () => {
  assert.equal(landingMismatch(declared, observed), null)
})

test('landing status is captured before the observer look and inventory turns', () => {
  const transcript = [
    'Opening.',
    '[status] room=West of House | moves=0 | score=0 | turn=free',
    '> north',
    'Forest',
    '[status] room=Forest | moves=7 | score=5 | turn=cost',
    '> look',
    'Forest\n\nA clearing.',
    '[status] room=Forest | moves=8 | score=5 | turn=cost',
    '> inventory',
    'You are carrying a brass lantern.',
    '[status] room=Forest | moves=9 | score=5 | turn=cost',
    '',
  ].join('\n')

  assert.deepEqual(landingSignature(transcript), {
    room: 'Forest',
    moves: '7',
    score: '5',
    look: 'Forest A clearing.',
    inventory: 'You are carrying a brass lantern.',
    playable: true,
  })
})

test('an inventory-only replay observes the same route endpoint before spending its turn', () => {
  const transcript = [
    'Opening.',
    '[status] room=West of House | moves=0 | score=0 | turn=free',
    '> north',
    'Forest',
    '[status] room=Forest | moves=7 | score=5 | turn=cost',
    '> inventory',
    'You are carrying a brass lantern.',
    '[status] room=Forest | moves=8 | score=5 | turn=cost',
    '',
  ].join('\n')

  assert.deepEqual(observationBefore(transcript, 'inventory'), {
    fields: { room: 'Forest', moves: '7', score: '5', turn: 'cost' },
    answer: 'You are carrying a brass lantern.',
  })
})

for (const field of ['room', 'moves', 'score', 'inventory']) {
  test(`a stale landing ${field} is rejected by name`, () => {
    const changed = field === 'inventory'
      ? { ...observed, carrying: 'You are carrying nothing.' }
      : { ...observed, [field]: field === 'room' ? 'Machine Room' : '999' }
    assert.match(landingMismatch(declared, changed), new RegExp(field))
  })
}

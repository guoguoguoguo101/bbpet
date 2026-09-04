import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_COLORS } from './types'
import { applyPoseItems, clampMoveSpeed, interpolatePose, keepVisualPeople, schoolHasRoom } from './sync'
import { MOVE_SPEED, SCHOOL_CROWD_CAP, type Presence } from './world'

function person(id: string, x: number, y: number, facing: 'l' | 'r' = 'r'): Presence {
  return {
    clientId: id,
    name: id,
    species: 'blob',
    colors: DEFAULT_COLORS.blob,
    homeId: `home:${id}`,
    schoolPlaceId: 'school:campus',
    placeId: 'school:campus',
    x,
    y,
    facing,
    pose: 'idle',
    lookX: 0,
    lookY: 0,
    dress: { gear: [], fx: [] },
  }
}

test('normal walking at 10Hz is not clipped', () => {
  const step = MOVE_SPEED * 0.1
  const next = clampMoveSpeed(0, 0, step, 0, 100)
  assert.equal(next.clipped, false)
  assert.equal(next.x, step)
})

test('teleport jumps are clamped toward the target', () => {
  const next = clampMoveSpeed(0, 0, 400, 0, 100)
  assert.equal(next.clipped, true)
  assert.ok(next.x < 80)
  assert.ok(next.x > 20)
})

test('pose patches never move the local player', () => {
  const people = [person('a', 10, 10), person('b', 20, 20)]
  const next = applyPoseItems(
    people,
    [
      { id: 'a', x: 99, y: 99, facing: 'l' },
      { id: 'b', x: 40, y: 50, facing: 'l' },
    ],
    'a',
  )
  assert.equal(next[0].x, 10)
  assert.equal(next[1].x, 40)
  assert.equal(next[1].facing, 'l')
})

test('chat-style snapshots keep the on-screen walk position', () => {
  const prev = [person('b', 80, 90, 'l')]
  const incoming = [person('b', 0, 0, 'r')]
  const next = keepVisualPeople(prev, incoming)
  assert.equal(next[0].x, 80)
  assert.equal(next[0].y, 90)
  assert.equal(next[0].facing, 'l')
})

test('new classmates still spawn at the snapshot point', () => {
  const next = keepVisualPeople([person('b', 80, 90)], [person('b', 80, 90), person('c', 12, 16)])
  assert.equal(next[1].clientId, 'c')
  assert.equal(next[1].x, 12)
})

test('school admits 100 people and then fills up', () => {
  assert.equal(schoolHasRoom(99, false), true)
  assert.equal(schoolHasRoom(SCHOOL_CROWD_CAP, false), false)
  assert.equal(schoolHasRoom(SCHOOL_CROWD_CAP, true), true)
})

test('remote pets ease toward the latest pose instead of snapping', () => {
  const mid = interpolatePose(0, 0, 10, 0, 0, 70, 140)
  assert.ok(mid.x > 4 && mid.x < 6)
  assert.ok(mid.t > 0.4 && mid.t < 0.6)
})

import test from 'node:test'
import assert from 'node:assert/strict'
import { actionSpec, flyerDir, flyerPath, flyerPoint, flyerSeat, FLYER_SIZE, slotOffset, yardMetrics } from './homeActions'

test('yard size is stable for a given crowd and only grows with people or chat', () => {
  const two = yardMetrics(2, false)
  const twoChat = yardMetrics(2, true)
  const three = yardMetrics(3, false)
  assert.equal(two.width, yardMetrics(2, false).width)
  assert.ok(twoChat.height > two.height)
  assert.ok(three.width >= two.width)
})

test('slots stay inside the yard', () => {
  const people = 5
  const yard = yardMetrics(people, false)
  for (let i = 0; i < people; i += 1) {
    const slot = slotOffset(i, people)
    assert.ok(slot.x >= 0 && slot.x + 72 <= yard.width)
    assert.ok(slot.y >= 0 && slot.y + 108 <= yard.height)
  }
})

test('kick lasts long enough to fly out and back', () => {
  const kick = actionSpec('kick')
  assert.equal(kick.flyer, true)
  assert.ok(kick.liftAt < kick.landAt)
  assert.ok(kick.landAt < kick.duration)
  assert.ok(kick.duration >= 2400)
})

test('flyer path starts and ends at the same seat', () => {
  const start = flyerPoint(0, 100, 200, 300, 180)
  const mid = flyerPoint(0.3, 100, 200, 300, 180)
  const end = flyerPoint(1, 100, 200, 300, 180)
  assert.deepEqual(start, { x: 100, y: 200 })
  assert.deepEqual(end, { x: 100, y: 200 })
  assert.notEqual(mid.x, 100)
})

test('kick direction prefers the target side', () => {
  assert.equal(flyerDir('x', 0, 1), 1)
  assert.equal(flyerDir('x', 2, 0), -1)
})

test('flyer path stays on the work area and flips when the wall is too close', () => {
  const wa = { x: 0, y: 0, width: 800, height: 600 }
  const open = flyerPath(200, 300, 1, wa)
  assert.ok(open.dest.x > open.start.x)
  const againstWall = flyerPath(760, 300, 1, wa)
  assert.equal(againstWall.dir, -1)
  assert.ok(againstWall.dest.x < againstWall.start.x)
  assert.ok(againstWall.start.x >= wa.x)
  assert.ok(againstWall.dest.x + FLYER_SIZE <= wa.x + wa.width)
})

test('flyer seat is centered on the slot', () => {
  const seat = flyerSeat(100, 200, 24, 40)
  assert.equal(seat.x, 100 + 24 + (72 - FLYER_SIZE) / 2)
  assert.equal(seat.y, 200 + 40 + 8)
})

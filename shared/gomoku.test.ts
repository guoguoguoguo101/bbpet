import assert from 'node:assert/strict'
import { test } from 'node:test'
import { SIZE, afterMove, emptyBoard, isFull, place, winLineAt, type Stone } from './gomoku'

function paint(cells: [number, number, 1 | 2][]) {
  let board = emptyBoard()
  for (const [x, y, stone] of cells) {
    const next = place(board, x, y, stone)
    assert.equal(next.ok, true)
    if (next.ok) board = next.board
  }
  return board
}

test('empty board is 15x15 zeros', () => {
  const board = emptyBoard()
  assert.equal(board.length, SIZE)
  assert.equal(board[0].length, SIZE)
  assert.equal(board[0][0], 0)
})

test('horizontal five wins', () => {
  const board = paint([
    [3, 7, 1],
    [4, 7, 1],
    [5, 7, 1],
    [6, 7, 1],
    [7, 7, 1],
  ])
  const line = winLineAt(board, 5, 7)
  assert.ok(line)
  assert.ok(line.length >= 5)
})

test('vertical five wins', () => {
  const board = paint([
    [8, 2, 2],
    [8, 3, 2],
    [8, 4, 2],
    [8, 5, 2],
    [8, 6, 2],
  ])
  assert.ok(winLineAt(board, 8, 4))
})

test('diagonal down-right five wins', () => {
  const board = paint([
    [1, 1, 1],
    [2, 2, 1],
    [3, 3, 1],
    [4, 4, 1],
    [5, 5, 1],
  ])
  assert.ok(winLineAt(board, 3, 3))
})

test('diagonal down-left five wins', () => {
  const board = paint([
    [10, 1, 2],
    [9, 2, 2],
    [8, 3, 2],
    [7, 4, 2],
    [6, 5, 2],
  ])
  assert.ok(winLineAt(board, 8, 3))
})

test('six in a row still wins', () => {
  const board = paint([
    [0, 0, 1],
    [1, 0, 1],
    [2, 0, 1],
    [3, 0, 1],
    [4, 0, 1],
    [5, 0, 1],
  ])
  const line = winLineAt(board, 2, 0)
  assert.ok(line)
  assert.ok(line.length >= 5)
})

test('four in a row does not win', () => {
  const board = paint([
    [0, 14, 1],
    [1, 14, 1],
    [2, 14, 1],
    [3, 14, 1],
  ])
  assert.equal(winLineAt(board, 2, 14), null)
})

test('occupied and out of bounds fail', () => {
  const once = place(emptyBoard(), 4, 4, 1)
  assert.equal(once.ok, true)
  if (!once.ok) return
  const twice = place(once.board, 4, 4, 2)
  assert.equal(twice.ok, false)
  const oob = place(emptyBoard(), 15, 0, 1)
  assert.equal(oob.ok, false)
})

test('afterMove reports draw on full board without five', () => {
  const board = emptyBoard()
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      board[y][x] = (((x + y * 2) % 4) < 2 ? 1 : 2) as Stone
    }
  }
  board[0][0] = 0
  const result = afterMove(board, 0, 0, 1)
  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.equal(result.draw, true)
  assert.equal(result.winLine, null)
  assert.equal(isFull(result.board), true)
})

test('empty and single stone have no winner', () => {
  assert.equal(winLineAt(emptyBoard(), 0, 0), null)
  const one = place(emptyBoard(), 7, 7, 1)
  assert.equal(one.ok, true)
  if (one.ok) assert.equal(winLineAt(one.board, 7, 7), null)
})

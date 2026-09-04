import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_COLORS } from '../shared/types'
import type { GamePlayer, GameView } from '../shared/world'
import { DISCONNECT_MS, INVITE_MS, TURN_MS, createGomokuTable } from './gomokuTable'

const alice: GamePlayer = { clientId: 'a', name: 'Alice', species: 'cat', colors: DEFAULT_COLORS.cat }
const bob: GamePlayer = { clientId: 'b', name: 'Bob', species: 'dog', colors: DEFAULT_COLORS.dog }
const carol: GamePlayer = { clientId: 'c', name: 'Carol', species: 'blob', colors: DEFAULT_COLORS.blob }

function fakeClock() {
  let now = 1_000_000
  const timers: { id: number; at: number; fn: () => void }[] = []
  let seq = 1
  return {
    now: () => now,
    setTimeout(fn: () => void, ms: number) {
      const id = seq++
      timers.push({ id, at: now + ms, fn })
      return id
    },
    clearTimeout(id: unknown) {
      const i = timers.findIndex((item) => item.id === id)
      if (i >= 0) timers.splice(i, 1)
    },
    advance(ms: number) {
      now += ms
      for (;;) {
        const due = timers.filter((item) => item.at <= now).sort((a, b) => a.at - b.at)
        if (due.length === 0) break
        for (const item of due) {
          const i = timers.indexOf(item)
          if (i >= 0) timers.splice(i, 1)
          item.fn()
        }
      }
    },
  }
}

function setup(friends = new Set(['a|b']), online = new Set(['a', 'b'])) {
  const clock = fakeClock()
  const games: Record<string, GameView[]> = { a: [], b: [], c: [] }
  const errors: Record<string, string[]> = { a: [], b: [], c: [] }
  const notices: Record<string, string[]> = { a: [], b: [], c: [] }
  const players: Record<string, GamePlayer> = { a: alice, b: bob, c: carol }
  let n = 0
  const table = createGomokuTable({
    clock,
    randomId: () => `g${++n}`,
    world: {
      isFriend: (x, y) => friends.has(`${x}|${y}`) || friends.has(`${y}|${x}`),
      isOnline: (id) => online.has(id),
      player: (id) => players[id] ?? null,
    },
    sink: {
      sendGame: (id, game) => {
        games[id] ??= []
        games[id].push(game)
      },
      sendError: (id, message) => {
        errors[id] ??= []
        errors[id].push(message)
      },
      sendNotice: (id, text) => {
        notices[id] ??= []
        notices[id].push(text)
      },
    },
  })
  const last = (id: string) => games[id]?.[games[id].length - 1]
  return { clock, table, games, errors, notices, last, online }
}

test('rejects self, stranger, and offline invites', () => {
  const { table, errors, games } = setup()
  table.invite('a', 'a')
  table.invite('a', 'c')
  const offline = setup(new Set(['a|b']), new Set(['a']))
  offline.table.invite('a', 'b')
  assert.deepEqual(errors.a, ['不能和自己下', '先加好友再下棋'])
  assert.deepEqual(offline.errors.a, ['对方不在线'])
  assert.equal(games.a.length, 0)
})

test('invite then accept starts black to move', () => {
  const { clock, table, last } = setup()
  table.invite('a', 'b')
  assert.equal(last('a')?.status, 'pending')
  assert.equal(last('a')?.you, 'black')
  assert.equal(last('b')?.you, 'white')
  assert.equal(table.isBusy('a'), true)
  table.respond('b', 'g1', true)
  const playing = last('a')
  assert.equal(playing?.status, 'playing')
  assert.equal(playing?.turn, 1)
  assert.equal(playing?.deadlineAt, clock.now() + TURN_MS)
  assert.equal(playing?.board[0]?.length, 15)
})

test('decline and invite timeout notify inviter', () => {
  const declined = setup()
  declined.table.invite('a', 'b')
  declined.table.respond('b', 'g1', false)
  assert.equal(declined.last('a')?.result?.reason, 'declined')
  assert.deepEqual(declined.notices.a, ['对方拒绝了五子棋邀请'])

  const expired = setup()
  expired.table.invite('a', 'b')
  expired.clock.advance(INVITE_MS)
  assert.equal(expired.last('a')?.result?.reason, 'expired')
  assert.deepEqual(expired.notices.a, ['五子棋邀请过期了'])
})

test('rejects occupied and out-of-turn moves', () => {
  const { table, last, errors } = setup()
  table.invite('a', 'b')
  table.respond('b', 'g1', true)
  table.move('a', 'g1', 7, 7)
  table.move('b', 'g1', 7, 7)
  table.move('a', 'g1', 8, 8)
  assert.equal(last('a')?.board[7][7], 1)
  assert.equal(last('a')?.turn, 2)
  assert.ok(errors.b.includes('这步不行'))
  assert.ok(errors.a.includes('这步不行'))
})

test('five in a row ends the game', () => {
  const { table, last } = setup()
  table.invite('a', 'b')
  table.respond('b', 'g1', true)
  const black = [0, 1, 2, 3, 4]
  const white = [0, 1, 2, 3]
  for (let i = 0; i < 4; i++) {
    table.move('a', 'g1', black[i], 7)
    table.move('b', 'g1', white[i], 8)
  }
  table.move('a', 'g1', 4, 7)
  assert.equal(last('a')?.status, 'ended')
  assert.equal(last('a')?.result?.reason, 'five')
  assert.equal(last('a')?.result?.winnerId, 'a')
  assert.ok((last('a')?.winLine?.length ?? 0) >= 5)
})

test('resign timeout busy disconnect and pending drop', () => {
  const resign = setup()
  resign.table.invite('a', 'b')
  resign.table.respond('b', 'g1', true)
  resign.table.resign('a', 'g1')
  assert.equal(resign.last('b')?.result?.reason, 'resign')
  assert.equal(resign.last('b')?.result?.winnerId, 'b')

  const timeout = setup()
  timeout.table.invite('a', 'b')
  timeout.table.respond('b', 'g1', true)
  timeout.clock.advance(TURN_MS)
  assert.equal(timeout.last('a')?.result?.reason, 'timeout')
  assert.equal(timeout.last('a')?.result?.winnerId, 'b')

  const busy = setup()
  busy.table.invite('a', 'b')
  busy.table.invite('a', 'b')
  assert.ok(busy.errors.a.includes('已经在下棋了'))

  const drop = setup()
  drop.table.invite('a', 'b')
  drop.table.respond('b', 'g1', true)
  drop.table.onDisconnect('b')
  drop.clock.advance(1000)
  drop.table.move('a', 'g1', 7, 7)
  drop.clock.advance(DISCONNECT_MS - 1000)
  assert.equal(drop.last('a')?.result?.reason, 'disconnect')
  assert.equal(drop.last('a')?.result?.winnerId, 'a')

  const rejoin = setup()
  rejoin.table.invite('a', 'b')
  rejoin.table.respond('b', 'g1', true)
  rejoin.table.onDisconnect('b')
  rejoin.table.onReconnect('b')
  rejoin.clock.advance(1000)
  assert.equal(rejoin.table.gameFor('a')?.status, 'playing')

  const pendingDrop = setup()
  pendingDrop.table.invite('a', 'b')
  pendingDrop.table.onDisconnect('b')
  assert.equal(pendingDrop.last('a')?.result?.reason, 'expired')
  assert.equal(pendingDrop.last('a')?.result?.winnerId, null)
})

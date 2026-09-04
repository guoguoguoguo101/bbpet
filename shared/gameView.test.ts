import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_COLORS } from './types'
import { canInviteFriend, isGameBusy, isIncomingInvite, type GameView } from './world'

const player = {
  clientId: 'a',
  name: 'A',
  species: 'cat' as const,
  colors: DEFAULT_COLORS.cat,
}

function game(partial: Partial<GameView>): GameView {
  return {
    id: 'g1',
    status: 'pending',
    black: player,
    white: { ...player, clientId: 'b', name: 'B' },
    board: [],
    turn: 1,
    deadlineAt: 0,
    lastMove: null,
    winLine: null,
    result: null,
    you: 'black',
    ...partial,
  }
}

test('busy covers pending and playing only', () => {
  assert.equal(isGameBusy(null), false)
  assert.equal(isGameBusy(game({ status: 'pending' })), true)
  assert.equal(isGameBusy(game({ status: 'playing' })), true)
  assert.equal(isGameBusy(game({ status: 'ended' })), false)
})

test('incoming invite is pending white', () => {
  assert.equal(isIncomingInvite(game({ status: 'pending', you: 'white' })), true)
  assert.equal(isIncomingInvite(game({ status: 'pending', you: 'black' })), false)
  assert.equal(isIncomingInvite(game({ status: 'playing', you: 'white' })), false)
})

test('can invite online friend when neither is in a game', () => {
  const card = { clientId: 'b', online: true, inGame: false }
  assert.equal(canInviteFriend(null, 'a', card), true)
  assert.equal(canInviteFriend(game({ status: 'playing' }), 'a', card), false)
  assert.equal(canInviteFriend(null, 'a', { ...card, online: false }), false)
  assert.equal(canInviteFriend(null, 'a', { ...card, inGame: true }), false)
  assert.equal(canInviteFriend(null, 'a', { ...card, clientId: 'a' }), false)
})

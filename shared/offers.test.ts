import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_COLORS } from './types'
import {
  collectOffers,
  GOMOKU_INVITE_MS,
  isOfferAlive,
  offerProgress,
  offerSeconds,
  offersFromGame,
} from './offers'
import type { GameView } from './world'

const black = {
  clientId: 'a',
  name: '阿豆',
  species: 'cat' as const,
  colors: DEFAULT_COLORS.cat,
}

const white = {
  clientId: 'b',
  name: '米米',
  species: 'rabbit' as const,
  colors: DEFAULT_COLORS.rabbit,
}

function game(partial: Partial<GameView>): GameView {
  return {
    id: 'g1',
    status: 'pending',
    black,
    white,
    board: [],
    turn: 1,
    deadlineAt: 1_000_000,
    lastMove: null,
    winLine: null,
    result: null,
    you: 'black',
    ...partial,
  }
}

test('pending game makes an outgoing wait card for black', () => {
  const [offer] = offersFromGame(game({ you: 'black' }))
  assert.equal(offer.role, 'outgoing')
  assert.equal(offer.kind, 'gomoku')
  assert.equal(offer.title, '在等 米米')
  assert.equal(offer.actions.length, 0)
  assert.equal(offer.durationMs, GOMOKU_INVITE_MS)
})

test('pending game makes an incoming action card for white', () => {
  const [offer] = offersFromGame(game({ you: 'white' }))
  assert.equal(offer.role, 'incoming')
  assert.equal(offer.title, '阿豆 来找你玩')
  assert.deepEqual(
    offer.actions.map((item) => item.label),
    ['好呀', '先不要'],
  )
  assert.equal(offer.actions[0].message.type, 'gameRespond')
  if (offer.actions[0].message.type === 'gameRespond') {
    assert.equal(offer.actions[0].message.accept, true)
    assert.equal(offer.actions[1].message.type === 'gameRespond' && offer.actions[1].message.accept, false)
  }
})

test('playing and ended games are not offers', () => {
  assert.deepEqual(offersFromGame(game({ status: 'playing' })), [])
  assert.deepEqual(offersFromGame(game({ status: 'ended' })), [])
  assert.deepEqual(offersFromGame(null), [])
})

test('progress shrinks toward the deadline then dies', () => {
  const [offer] = offersFromGame(game({ deadlineAt: 60_000 }))
  assert.equal(offerProgress(offer, 0), 1)
  assert.equal(offerProgress(offer, 30_000), 0.5)
  assert.equal(offerSeconds(offer, 30_000), 30)
  assert.equal(offerProgress(offer, 60_000), 0)
  assert.equal(isOfferAlive(offer, 59_999), true)
  assert.equal(isOfferAlive(offer, 60_000), false)
})

test('collectOffers fans in game invites', () => {
  const live = collectOffers({ game: game({ you: 'white' }) })
  assert.equal(live.length, 1)
  assert.equal(live[0].kind, 'gomoku')
  assert.deepEqual(collectOffers({ game: null }), [])
})

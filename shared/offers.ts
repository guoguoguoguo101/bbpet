import type { ClientMsg, GameView } from './world'

/** Known invite kinds. Add a row here when a new social invite lands. */
export type OfferKind = 'gomoku' | 'visit' | 'rps'

export type OfferRole = 'incoming' | 'outgoing'
export type OfferTone = 'primary' | 'ghost'

export interface OfferAction {
  id: string
  label: string
  tone: OfferTone
  message: ClientMsg
}

export interface Offer {
  id: string
  kind: OfferKind
  role: OfferRole
  title: string
  body: string
  stamp: string
  deadlineAt: number | null
  durationMs: number | null
  actions: OfferAction[]
}

export const OFFER_TTL = {
  gomoku: 60_000,
  visit: 60_000,
  rps: 30_000,
} as const

export const GOMOKU_INVITE_MS = OFFER_TTL.gomoku

export function offerProgress(offer: Offer, now: number) {
  if (!offer.deadlineAt || !offer.durationMs || offer.durationMs <= 0) return 1
  return Math.max(0, Math.min(1, (offer.deadlineAt - now) / offer.durationMs))
}

export function offerSeconds(offer: Offer, now: number) {
  if (!offer.deadlineAt) return 0
  return Math.max(0, Math.ceil((offer.deadlineAt - now) / 1000))
}

export function isOfferAlive(offer: Offer, now: number) {
  return !offer.deadlineAt || now < offer.deadlineAt
}

export function offersFromGame(game: GameView | null | undefined): Offer[] {
  if (!game || game.status !== 'pending') return []
  const incoming = game.you === 'white'
  const id = `gomoku:${game.id}:${incoming ? 'in' : 'out'}`
  if (incoming) {
    return [
      {
        id,
        kind: 'gomoku',
        role: 'incoming',
        title: `${game.black.name} 来找你玩`,
        body: '一起下五子棋呀',
        stamp: '五子棋',
        deadlineAt: game.deadlineAt,
        durationMs: GOMOKU_INVITE_MS,
        actions: [
          {
            id: 'accept',
            label: '好呀',
            tone: 'primary',
            message: { type: 'gameRespond', gameId: game.id, accept: true },
          },
          {
            id: 'decline',
            label: '先不要',
            tone: 'ghost',
            message: { type: 'gameRespond', gameId: game.id, accept: false },
          },
        ],
      },
    ]
  }
  return [
    {
      id,
      kind: 'gomoku',
      role: 'outgoing',
      title: `在等 ${game.white.name}`,
      body: '五子棋邀请已送出',
      stamp: '等待中',
      deadlineAt: game.deadlineAt,
      durationMs: GOMOKU_INVITE_MS,
      actions: [],
    },
  ]
}

/** Fan-in for every live invite. Add adapters here; the pet toast stays unchanged. */
export function collectOffers(input: { game?: GameView | null }): Offer[] {
  return [...offersFromGame(input.game)]
}

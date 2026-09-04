import { useEffect, useState } from 'react'
import {
  collectOffers,
  isOfferAlive,
  offerProgress,
  offerSeconds,
  type Offer,
} from '../../shared/offers'
import type { GameView } from '../../shared/world'

interface OfferStackProps {
  game: GameView | null
}

function OfferGlyph({ kind }: { kind: Offer['kind'] }) {
  if (kind === 'visit') return <span className="offer-glyph">⌂</span>
  if (kind === 'rps') return <span className="offer-glyph">✌</span>
  return (
    <div className="offer-stones" aria-hidden>
      <i className="offer-stone black" />
      <i className="offer-stone white" />
    </div>
  )
}

function OfferCard({ offer, now }: { offer: Offer; now: number }) {
  const seconds = offerSeconds(offer, now)
  const progress = offerProgress(offer, now)
  const timed = Boolean(offer.deadlineAt && offer.durationMs)
  return (
    <article className={`offer-card role-${offer.role} kind-${offer.kind}`}>
      <span className="offer-stamp">{offer.stamp}</span>
      <OfferGlyph kind={offer.kind} />
      <strong className="offer-title">{offer.title}</strong>
      <p className="offer-body">{offer.body}</p>
      {timed && (
        <div className="offer-meter" title={`还剩 ${seconds} 秒`}>
          <i style={{ width: `${Math.round(progress * 1000) / 10}%` }} />
          <span>{seconds}s</span>
        </div>
      )}
      {offer.actions.length > 0 && (
        <div className="offer-actions">
          {offer.actions.map((action) => (
            <button
              key={action.id}
              type="button"
              className={action.tone === 'primary' ? 'primary' : 'ghost'}
              onPointerDown={(event) => event.stopPropagation()}
              onClick={(event) => {
                event.stopPropagation()
                window.bbpet.roomSend(action.message)
              }}
            >
              {action.label}
            </button>
          ))}
        </div>
      )}
    </article>
  )
}

export function OfferStack({ game }: OfferStackProps) {
  const [now, setNow] = useState(() => Date.now())
  const offers = collectOffers({ game }).filter((offer) => isOfferAlive(offer, now))

  useEffect(() => {
    if (game?.status !== 'pending') return
    const id = window.setInterval(() => setNow(Date.now()), 200)
    return () => window.clearInterval(id)
  }, [game?.id, game?.status])

  if (!offers.length) return null

  return (
    <div className="offer-stack" onContextMenu={(event) => event.stopPropagation()}>
      {offers.map((offer) => (
        <OfferCard key={offer.id} offer={offer} now={now} />
      ))}
    </div>
  )
}

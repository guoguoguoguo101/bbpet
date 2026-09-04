import { useEffect, useRef, useState } from 'react'
import type { HomeEmote, Presence } from '../../shared/world'
import { actionSpec, flyerDir, slotOffset } from '../../shared/homeActions'

export function useEmotePlayback(
  emote: HomeEmote | null,
  guests: Presence[],
  dresses: Record<string, { gear: string[] }>,
  onKickLift: (payload: {
    id: string
    guest: Presence
    slotX: number
    slotY: number
    dir: 1 | -1
    duration: number
    gears: string[]
  }) => void,
) {
  const [playing, setPlaying] = useState<HomeEmote | null>(null)
  const [airborneId, setAirborneId] = useState<string | null>(null)
  const lastId = useRef('')
  const guestsRef = useRef(guests)
  const dressesRef = useRef(dresses)
  const liftRef = useRef(onKickLift)
  guestsRef.current = guests
  dressesRef.current = dresses
  liftRef.current = onKickLift

  useEffect(() => {
    if (!emote || emote.id === lastId.current) return
    lastId.current = emote.id
    setPlaying(emote)
    const spec = actionSpec(emote.kind)
    const timers: number[] = []
    if (spec.flyer && emote.targetId) {
      const people = guestsRef.current
      const fromIndex = people.findIndex((item) => item.clientId === emote.fromId)
      const toIndex = people.findIndex((item) => item.clientId === emote.targetId)
      const guest = people[toIndex]
      if (guest) {
        const slot = slotOffset(toIndex, people.length)
        timers.push(
          window.setTimeout(() => {
            setAirborneId(guest.clientId)
            liftRef.current({
              id: emote.id,
              guest,
              slotX: slot.x,
              slotY: slot.y,
              dir: flyerDir(emote.id, fromIndex, toIndex),
              duration: spec.landAt - spec.liftAt,
              gears: dressesRef.current[guest.clientId]?.gear ?? guest.dress?.gear ?? [],
            })
          }, spec.liftAt),
        )
        timers.push(window.setTimeout(() => setAirborneId(null), spec.landAt))
      }
    }
    timers.push(window.setTimeout(() => setPlaying((current) => (current?.id === emote.id ? null : current)), spec.duration))
    return () => {
      timers.forEach((id) => window.clearTimeout(id))
      if (lastId.current === emote.id) lastId.current = ''
      setAirborneId(null)
    }
  }, [emote?.id])

  return { playing, airborneId }
}

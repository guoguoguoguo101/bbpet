import { useEffect, useRef, useState } from 'react'
import type { AppState } from '../../shared/types'
import { homeOwnerId, type Presence, type RoomView } from '../../shared/world'
import { PixelPet } from './PixelPet'

interface GatheringProps {
  state: AppState
  room: RoomView
}

export function Gathering({ state, room }: GatheringProps) {
  const you = room.you
  const [draft, setDraft] = useState('')
  const [bubbles, setBubbles] = useState<Record<string, { text: string; until: number }>>({})
  const lastChatIdRef = useRef('')

  useEffect(() => {
    const line = room.lastChat
    if (!line || line.id === lastChatIdRef.current) return
    lastChatIdRef.current = line.id
    setBubbles((current) => ({ ...current, [line.clientId]: { text: line.text, until: Date.now() + 5000 } }))
  }, [room.lastChat])

  useEffect(() => {
    const timer = window.setInterval(() => {
      setBubbles((current) => {
        const next: Record<string, { text: string; until: number }> = {}
        let changed = false
        for (const [id, bubble] of Object.entries(current)) {
          if (bubble.until > Date.now()) next[id] = bubble
          else changed = true
        }
        return changed ? next : current
      })
    }, 400)
    return () => window.clearInterval(timer)
  }, [])

  if (!you) return null

  const guests: Presence[] = [you, ...room.people]
  const ownerId = homeOwnerId(you.placeId)
  const owner =
    ownerId === state.clientId
      ? null
      : guests.find((item) => item.clientId === ownerId) || room.friends.find((item) => item.clientId === ownerId)
  const title = ownerId === state.clientId ? '自己家' : `${owner?.name || '好友'}的家`
  const log = room.board.slice(-3)

  const send = () => {
    const text = draft.trim()
    if (!text) return
    window.bbpet.roomSend({ type: 'chat', text })
    setDraft('')
  }

  return (
    <div className="gather">
      <div className="gather-pets">
        {guests.map((guest) => {
          const bubble = bubbles[guest.clientId]
          const talking = Boolean(bubble)
          return (
            <div key={guest.clientId} className={`gather-slot pet-wrap${talking ? ' talking' : ''}`}>
              {bubble && <div className="gather-bubble">{bubble.text}</div>}
              <PixelPet species={guest.species} colors={guest.colors} pose={talking ? 'talk' : 'idle'} />
              <div className="name-plate">
                {guest.name}
                {guest.clientId === state.clientId ? '（我）' : ''}
              </div>
            </div>
          )
        })}
      </div>
      <div className="gather-ui">
        <div className="gather-head">
          <strong>{title}</strong>
          <span>{guests.length} 人</span>
          <button type="button" className="ghost" onClick={() => window.bbpet.leaveHome()}>
            离开
          </button>
        </div>
        <div className="gather-log">
          {ownerId && ownerId !== state.clientId && !guests.some((item) => item.clientId === ownerId) && (
            <p>主人还在别处，回家后就会出现在你桌面上。</p>
          )}
          {log.length === 0 && <p>附近还很安静，打个招呼吧。</p>}
          {log.map((line) => (
            <p key={line.id}>
              {line.name}：{line.text}
            </p>
          ))}
        </div>
        <form
          className="gather-chat"
          onSubmit={(event) => {
            event.preventDefault()
            send()
          }}
        >
          <input
            value={draft}
            maxLength={80}
            autoComplete="off"
            spellCheck={false}
            placeholder="附近的人都能看见"
            onChange={(event) => setDraft(event.target.value)}
          />
          <button type="submit" disabled={!draft.trim()}>
            发送
          </button>
        </form>
      </div>
    </div>
  )
}

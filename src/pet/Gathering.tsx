import { useEffect, useRef, useState } from 'react'
import type { AppState, PetPose } from '../../shared/types'
import {
  DIRECTED_EMOTES,
  EMOTE_LABELS,
  EMPTY_DRESS,
  homeOwnerId,
  type EmoteKind,
  type PetDress,
  type Presence,
  type RoomView,
} from '../../shared/world'
import { labelForAction, poseForAction, roleInAction, SLOT_H, SLOT_W, YARD_PAD_TOP, YARD_PAD_X, yardMetrics } from '../../shared/homeActions'
import { lineForPose } from '../../shared/weatherLines'
import { useEmotePlayback } from './useEmotePlayback'
import { PixelPet } from './PixelPet'
import { WeatherDress } from './WeatherDress'

interface GatheringProps {
  state: AppState
  room: RoomView
  selfPose: PetPose
  selfDress: PetDress
  selfLook: { x: number; y: number }
  idleLine: string
}

const COOLDOWN_MS = 5000

function poseCaption(pose: PetPose) {
  if (pose === 'sleep') return 'Zzz'
  if (pose === 'drink') return '咕嘟'
  if (pose === 'wake') return '伸懒腰'
  if (pose === 'type') return '嗒嗒'
  if (pose === 'phone') return '刷'
  if (pose === 'snack') return '偷吃'
  if (pose === 'peek') return '张望'
  if (pose === 'game') return '再来一把'
  if (pose === 'coffee') return '续命'
  if (pose === 'toilet') return '嘘嘘'
  return ''
}

function guestTalk(pose: PetPose, clientId: string, look: { x: number; y: number }) {
  if (pose === 'idle' && look.x > 0) return lineForPose('look-right', clientId)
  if (pose === 'idle' && look.x < 0) return lineForPose('look-left', clientId)
  return lineForPose(pose, clientId)
}

export function Gathering({ state, room, selfPose, selfDress, selfLook, idleLine }: GatheringProps) {
  const you = room.you
  const [draft, setDraft] = useState('')
  const [bubbles, setBubbles] = useState<Record<string, { text: string; until: number }>>({})
  const [cooling, setCooling] = useState(false)
  const [chatting, setChatting] = useState(false)
  const [menuFor, setMenuFor] = useState<string | null>(null)
  const [peekLook, setPeekLook] = useState(-1)
  const lastChatIdRef = useRef('')
  const coolTimer = useRef(0)
  const logRef = useRef<HTMLDivElement>(null)
  const guests: Presence[] = you ? [you, ...room.homePeople] : []
  const yard = yardMetrics(Math.max(1, guests.length), chatting)

  const { playing, airborneId } = useEmotePlayback(room.lastEmote, guests, room.dresses, (payload) => {
    window.bbpet.playFlyer({
      id: payload.id,
      species: payload.guest.species,
      colors: payload.guest.colors,
      gears: payload.gears,
      pose: 'peek',
      slotX: payload.slotX,
      slotY: payload.slotY,
      dir: payload.dir,
      duration: payload.duration,
    })
  })

  useEffect(() => () => window.bbpet.hideFlyer(), [])

  useEffect(() => {
    const line = room.lastHomeChat
    if (!line || line.id === lastChatIdRef.current) return
    lastChatIdRef.current = line.id
    setBubbles((current) => ({ ...current, [line.clientId]: { text: line.text, until: Date.now() + 5000 } }))
  }, [room.lastHomeChat?.id])

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
    return () => {
      window.clearInterval(timer)
      window.clearTimeout(coolTimer.current)
    }
  }, [])

  useEffect(() => {
    if (!you) return
    const peeking = guests.some((guest) => {
      const resting = guest.clientId === state.clientId ? selfPose : room.poses[guest.clientId] || guest.pose || 'idle'
      return poseForAction(playing, guest.clientId, resting) === 'peek'
    })
    if (!peeking) return
    let tick = 0
    setPeekLook(-1)
    const id = window.setInterval(() => {
      tick += 1
      setPeekLook(tick % 2 === 0 ? -1 : 1)
    }, 380)
    return () => window.clearInterval(id)
  }, [you, guests, room.poses, selfPose, playing, state.clientId])

  useEffect(() => {
    if (!chatting) return
    logRef.current?.scrollTo(0, logRef.current.scrollHeight)
  }, [chatting, room.homeBoard.length])

  useEffect(() => {
    window.bbpet.reportPetLayout({ width: yard.width, height: yard.height })
  }, [yard.width, yard.height])

  useEffect(() => {
    if (!menuFor) return
    const onDown = (event: PointerEvent) => {
      if (event.target instanceof HTMLElement && event.target.closest('.gather-react, .gather-slot.menu-open')) return
      setMenuFor(null)
    }
    window.addEventListener('pointerdown', onDown, true)
    return () => window.removeEventListener('pointerdown', onDown, true)
  }, [menuFor])

  if (!you) return null

  const ownerId = homeOwnerId(you.homeId)
  const owner =
    ownerId === state.clientId
      ? null
      : guests.find((item) => item.clientId === ownerId) || room.friends.find((item) => item.clientId === ownerId)
  const visiting = ownerId !== state.clientId
  const title = visiting ? `${owner?.name || '好友'}家` : '自家'

  const sendChat = () => {
    const text = draft.trim()
    if (!text) return
    window.bbpet.roomSend({ type: 'chat', text, placeId: you.homeId })
    setDraft('')
  }

  const sendEmote = (kind: EmoteKind, targetId: string) => {
    if (cooling) return
    window.bbpet.roomSend({ type: 'emote', kind, targetId, placeId: you.homeId })
    setCooling(true)
    setMenuFor(null)
    window.clearTimeout(coolTimer.current)
    coolTimer.current = window.setTimeout(() => setCooling(false), COOLDOWN_MS)
  }

  return (
    <div className="gather" style={{ width: yard.width, height: yard.height }}>
      <div className="gather-pets">
        {guests.map((guest, index) => {
          const mine = guest.clientId === state.clientId
          const bubble = bubbles[guest.clientId]
          const resting = mine ? selfPose : room.poses[guest.clientId] || guest.pose || 'idle'
          const role = roleInAction(playing, guest.clientId)
          const acted = Boolean(role)
          const pose = poseForAction(playing, guest.clientId, resting)
          const talking = Boolean(bubble) && !acted
          const dress = mine ? selfDress : room.dresses[guest.clientId] || guest.dress || EMPTY_DRESS
          const down = pose === 'drink' || pose === 'type' || pose === 'phone' || pose === 'snack' || pose === 'game' || pose === 'coffee' || pose === 'toilet'
          const look = mine ? selfLook : room.looks?.[guest.clientId] || { x: guest.lookX || 0, y: guest.lookY || 0 }
          const poseTalk = mine ? idleLine : guestTalk(pose, guest.clientId, look)
          const caption = playing && acted ? labelForAction(playing, guest.clientId) : bubble?.text || poseTalk || poseCaption(pose)
          const lookX = pose === 'peek' ? peekLook : pose === 'sleep' || down ? 0 : look.x
          const lookY = pose === 'sleep' || pose === 'peek' ? 0 : down ? 1 : look.y
          const fromIndex = playing ? guests.findIndex((item) => item.clientId === playing.fromId) : -1
          const toIndex = playing?.targetId ? guests.findIndex((item) => item.clientId === playing.targetId) : -1
          const towardRight = fromIndex >= 0 && toIndex >= 0 && toIndex > fromIndex
          const openMenu = menuFor === guest.clientId && !mine
          const hidden = airborneId === guest.clientId
          const col = index % yard.cols
          const row = Math.floor(index / yard.cols)
          const slotClass = [
            'gather-slot',
            'pet-wrap',
            talking && 'talking',
            mine && 'mine',
            hidden && 'airborne',
            openMenu && 'menu-open',
            pose === 'drink' && 'drinking',
            pose === 'sleep' && 'sleeping',
            pose === 'wake' && 'waking',
            pose === 'type' && 'typing',
            pose === 'phone' && 'phoning',
            pose === 'snack' && 'snacking',
            pose === 'peek' && 'peeking',
            pose === 'game' && 'gaming',
            pose === 'coffee' && 'coffeeting',
            pose === 'toilet' && 'toileting',
            pose === 'wave' && 'waving',
            dress.fx.includes('wind') && 'weather-wind',
            dress.fx.includes('storm') && 'weather-storm',
            playing && role,
            playing && role && `emote-${playing.kind}`,
            playing && role === 'from' && towardRight && 'lean-right',
            playing && role === 'from' && !towardRight && toIndex >= 0 && 'lean-left',
            playing && playing.kind !== 'kick' && role === 'to' && towardRight && !hidden && 'lean-left',
            playing && playing.kind !== 'kick' && role === 'to' && !towardRight && fromIndex >= 0 && !hidden && 'lean-right',
          ]
            .filter(Boolean)
            .join(' ')

          return (
            <div
              key={guest.clientId}
              className={slotClass}
              style={{ left: YARD_PAD_X + col * SLOT_W, top: YARD_PAD_TOP + row * SLOT_H, width: SLOT_W, height: SLOT_H }}
              title={mine ? undefined : '右键选动作'}
              onContextMenu={(event) => {
                if (mine) return
                event.preventDefault()
                event.stopPropagation()
                setMenuFor((current) => (current === guest.clientId ? null : guest.clientId))
              }}
            >
              {(dress.gear.length > 0 || dress.fx.length > 0) && <WeatherDress weather={dress} />}
              {caption && !hidden && <div className={acted ? 'gather-emote' : 'gather-bubble'}>{caption}</div>}
              <PixelPet
                species={guest.species}
                colors={guest.colors}
                pose={talking ? 'talk' : pose}
                lookX={lookX}
                lookY={lookY}
                gears={dress.gear}
              />
              <div className="name-plate">{guest.name}</div>
              {openMenu && (
                <div className="gather-react">
                  {DIRECTED_EMOTES.map((kind) => (
                    <button
                      key={kind}
                      type="button"
                      className="ghost"
                      disabled={cooling}
                      onClick={() => sendEmote(kind, guest.clientId)}
                    >
                      {EMOTE_LABELS[kind]}
                    </button>
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {chatting && (
        <div ref={logRef} className="gather-log gather-ui" onWheel={(event) => event.stopPropagation()}>
          {room.homeBoard.length === 0 ? (
            <div className="gather-log-empty">还没有说过话</div>
          ) : (
            room.homeBoard.slice(-24).map((line) => (
              <div key={line.id} className="gather-log-line">
                <b>{line.name}</b>
                <span>{line.text}</span>
              </div>
            ))
          )}
        </div>
      )}

      <div className={`gather-bar gather-ui${chatting ? ' is-chat' : ''}`}>
        {chatting ? (
          <form
            className="gather-chat"
            onSubmit={(event) => {
              event.preventDefault()
              sendChat()
            }}
          >
            <input
              value={draft}
              maxLength={80}
              autoComplete="off"
              spellCheck={false}
              autoFocus
              placeholder="回车发送"
              title="回车发送"
              onChange={(event) => setDraft(event.target.value)}
            />
            <button
              type="button"
              className="ghost"
              onClick={() => {
                setChatting(false)
                setDraft('')
              }}
            >
              收
            </button>
          </form>
        ) : (
          <>
            <strong>{title}</strong>
            <span>{guests.length}人</span>
            <button type="button" className="ghost" onClick={() => setChatting(true)}>
              聊
            </button>
          </>
        )}
      </div>
    </div>
  )
}

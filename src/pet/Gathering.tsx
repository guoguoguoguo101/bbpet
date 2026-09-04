import { useEffect, useRef, useState } from 'react'
import type { AppState, PetPose } from '../../shared/types'
import {
  DIRECTED_EMOTES,
  EMOTE_LABELS,
  EMPTY_DRESS,
  homeOwnerId,
  type EmoteKind,
  type HomeEmote,
  type PetDress,
  type Presence,
  type RoomView,
} from '../../shared/world'
import { collectPetShape } from '../lib/petShape'
import { PixelPet } from './PixelPet'
import { WeatherDress } from './WeatherDress'
import { lineForPose } from '../../shared/weatherLines'

interface GatheringProps {
  state: AppState
  room: RoomView
  selfPose: PetPose
  selfDress: PetDress
  idleLine: string
}

const EMOTE_MS = 1600
const COOLDOWN_MS = 5000

function emotePose(emote: HomeEmote, clientId: string, resting: PetPose): PetPose | null {
  if (emote.fromId !== clientId && emote.targetId !== clientId) return null
  const asTarget = emote.targetId === clientId
  if (emote.kind === 'wave') return 'wave'
  if (emote.kind === 'hug') return 'talk'
  if (emote.kind === 'pour') return 'drink'
  if (emote.kind === 'wake') return asTarget ? (resting === 'sleep' ? 'wake' : 'wave') : 'wave'
  if (emote.kind === 'kick') return asTarget ? 'peek' : 'wake'
  return null
}

function emoteLabel(emote: HomeEmote, clientId: string) {
  const asTarget = emote.targetId === clientId
  if (emote.kind === 'hug') return '抱抱'
  if (emote.kind === 'pour') return asTarget ? '咕嘟' : '倒水'
  if (emote.kind === 'wake') return asTarget ? '伸懒腰' : '拍醒'
  if (emote.kind === 'kick') return asTarget ? '哎呀' : '飞踢'
  return '挥手'
}

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

export function Gathering({ state, room, selfPose, selfDress, idleLine }: GatheringProps) {
  const you = room.you
  const [draft, setDraft] = useState('')
  const [bubbles, setBubbles] = useState<Record<string, { text: string; until: number }>>({})
  const [playing, setPlaying] = useState<HomeEmote | null>(null)
  const [cooling, setCooling] = useState(false)
  const [chatting, setChatting] = useState(false)
  const [menuFor, setMenuFor] = useState<string | null>(null)
  const [peekLook, setPeekLook] = useState(-1)
  const lastChatIdRef = useRef('')
  const lastEmoteIdRef = useRef('')
  const coolTimer = useRef(0)
  const emoteTimer = useRef(0)
  const logRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const line = room.lastHomeChat
    if (!line || line.id === lastChatIdRef.current) return
    lastChatIdRef.current = line.id
    setBubbles((current) => ({ ...current, [line.clientId]: { text: line.text, until: Date.now() + 5000 } }))
  }, [room.lastHomeChat?.id])

  useEffect(() => {
    const emote = room.lastEmote
    if (!emote) return
    if (emote.id === lastEmoteIdRef.current) return
    lastEmoteIdRef.current = emote.id
    setPlaying(emote)
    window.clearTimeout(emoteTimer.current)
    emoteTimer.current = window.setTimeout(() => {
      setPlaying((current) => (current?.id === emote.id ? null : current))
    }, EMOTE_MS)
  }, [room.lastEmote?.id])

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
      window.clearTimeout(emoteTimer.current)
    }
  }, [])

  useEffect(() => {
    if (!you) return
    const people = [you, ...room.homePeople]
    const peeking = people.some((guest) => {
      const resting = guest.clientId === state.clientId ? selfPose : room.poses[guest.clientId] || guest.pose || 'idle'
      return (playing ? emotePose(playing, guest.clientId, resting) : resting) === 'peek'
    })
    if (!peeking) return
    let tick = 0
    setPeekLook(-1)
    const id = window.setInterval(() => {
      tick += 1
      setPeekLook(tick % 2 === 0 ? -1 : 1)
    }, 380)
    return () => window.clearInterval(id)
  }, [you, room.homePeople, room.poses, selfPose, playing, state.clientId])

  useEffect(() => {
    if (!chatting) return
    logRef.current?.scrollTo(0, logRef.current.scrollHeight)
  }, [chatting, room.homeBoard.length])

  useEffect(() => {
    const root = document.querySelector('.pet-wrap') as HTMLElement | null
    if (!root) return
    const report = () => {
      const box = root.getBoundingClientRect()
      window.bbpet.reportPetLayout({
        width: Math.max(64, Math.ceil(box.width)),
        height: Math.max(86, Math.ceil(box.height)),
      })
      const rects = collectPetShape(root, state.pet.species)
      if (rects.length) window.bbpet.setWindowShape(rects)
    }
    report()
    const id = window.requestAnimationFrame(report)
    const later = window.setTimeout(report, 40)
    return () => {
      window.cancelAnimationFrame(id)
      window.clearTimeout(later)
    }
  }, [chatting, menuFor, room.homeBoard.length, room.homePeople.length, state.pet.species])

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

  const guests: Presence[] = [you, ...room.homePeople]
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
    <div className="gather">
      <div className="gather-pets">
        {guests.map((guest) => {
          const mine = guest.clientId === state.clientId
          const bubble = bubbles[guest.clientId]
          const resting = mine ? selfPose : room.poses[guest.clientId] || guest.pose || 'idle'
          const acted = playing ? emotePose(playing, guest.clientId, resting) : null
          const pose = acted || resting
          const talking = Boolean(bubble) && !acted
          const poseTalk = mine ? idleLine : lineForPose(pose, guest.clientId)
          const caption = playing && acted ? emoteLabel(playing, guest.clientId) : bubble?.text || poseTalk || poseCaption(pose)
          const dress = mine ? selfDress : room.dresses[guest.clientId] || guest.dress || EMPTY_DRESS
          const down = pose === 'drink' || pose === 'type' || pose === 'phone' || pose === 'snack' || pose === 'game' || pose === 'coffee' || pose === 'toilet'
          const lookX = pose === 'peek' ? peekLook : 0
          const lookY = pose === 'sleep' || pose === 'peek' ? 0 : down ? 1 : 0
          const fromIndex = playing ? guests.findIndex((item) => item.clientId === playing.fromId) : -1
          const toIndex = playing?.targetId ? guests.findIndex((item) => item.clientId === playing.targetId) : -1
          const towardRight = fromIndex >= 0 && toIndex >= 0 && toIndex > fromIndex
          const role =
            playing && guest.clientId === playing.fromId ? 'from' : playing && guest.clientId === playing.targetId ? 'to' : ''
          const openMenu = menuFor === guest.clientId && !mine
          const slotClass = [
            'gather-slot',
            'pet-wrap',
            talking && 'talking',
            mine && 'mine',
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
            playing && role && towardRight && role === 'from' && 'lean-right',
            playing && role && towardRight && role === 'to' && 'lean-left',
            playing && role && !towardRight && role === 'from' && toIndex >= 0 && 'lean-left',
            playing && role && !towardRight && role === 'to' && fromIndex >= 0 && 'lean-right',
          ]
            .filter(Boolean)
            .join(' ')

          return (
            <div
              key={guest.clientId}
              className={slotClass}
              title={mine ? undefined : '右键选动作'}
              onContextMenu={(event) => {
                if (mine) return
                event.preventDefault()
                event.stopPropagation()
                setMenuFor((current) => (current === guest.clientId ? null : guest.clientId))
              }}
            >
              {(dress.gear.length > 0 || dress.fx.length > 0) && <WeatherDress weather={dress} />}
              {caption && <div className={acted ? 'gather-emote' : 'gather-bubble'}>{caption}</div>}
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
        <div
          ref={logRef}
          className="gather-log gather-ui"
          onWheel={(event) => event.stopPropagation()}
        >
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

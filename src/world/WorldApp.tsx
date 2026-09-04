import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { AppState } from '../../shared/types'
import {
  MOVE_SPEED,
  NEARBY_RANGE,
  PET_SIZE,
  PLACES,
  TILE,
  canInviteFriend,
  clampMove,
  dist,
  isIncomingInvite,
  isSchoolPlace,
  mapSize,
  triggerAt,
  type ChatLine,
  type Facing,
  type FriendCard,
  type GameView,
  type PlaceId,
  type Presence,
  type RoomView,
} from '../../shared/world'
import { PixelPet } from '../pet/PixelPet'
import { drawPlace } from './paint'

interface Bubble {
  text: string
  until: number
}

const ZOOM_MIN = 1
const ZOOM_MAX = 4

function cameraFor(
  scale: number,
  meX: number,
  meY: number,
  stageW: number,
  stageH: number,
  mapW: number,
  mapH: number,
) {
  const drawnW = mapW * scale
  const drawnH = mapH * scale
  let left = Math.round(stageW / 2 - (meX + PET_SIZE / 2) * scale)
  let top = Math.round(stageH / 2 - (meY + PET_SIZE / 2) * scale)
  if (drawnW <= stageW) left = Math.round((stageW - drawnW) / 2)
  else left = Math.min(0, Math.max(Math.round(stageW - drawnW), left))
  if (drawnH <= stageH) top = Math.round((stageH - drawnH) / 2)
  else top = Math.min(0, Math.max(Math.round(stageH - drawnH), top))
  return { scale, left, top }
}

export function WorldApp() {
  const [state, setState] = useState<AppState | null>(null)
  const [status, setStatus] = useState('正在走进校门...')
  const [placeId, setPlaceId] = useState<PlaceId>('school:campus')
  const [me, setMe] = useState({ x: 0, y: 0, facing: 'r' as Facing })
  const [others, setOthers] = useState<Presence[]>([])
  const [board, setBoard] = useState<ChatLine[]>([])
  const [bubbles, setBubbles] = useState<Record<string, Bubble>>({})
  const [draft, setDraft] = useState('')
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [moving, setMoving] = useState(false)
  const [fitScale, setFitScale] = useState(1)
  const [zoom, setZoom] = useState(1.8)
  const [stageSize, setStageSize] = useState({ w: 1, h: 1 })
  const [friendIds, setFriendIds] = useState<string[]>([])
  const [friends, setFriends] = useState<FriendCard[]>([])
  const [game, setGame] = useState<GameView | null>(null)
  const [now, setNow] = useState(() => Date.now())
  const [movingOthers, setMovingOthers] = useState<Record<string, number>>({})
  const lastOthersRef = useRef<Record<string, { x: number; y: number }>>({})
  const [inspect, setInspect] = useState<{ clientId: string; name: string; x: number; y: number } | null>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const stageRef = useRef<HTMLDivElement>(null)
  const keysRef = useRef({ w: false, a: false, s: false, d: false })
  const meRef = useRef(me)
  const placeRef = useRef(placeId)
  const lastSendRef = useRef(0)
  const ignoreDoorRef = useRef(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const rootRef = useRef<HTMLDivElement>(null)
  const chattingRef = useRef(false)
  const lastChatIdRef = useRef('')

  meRef.current = me
  placeRef.current = placeId

  useEffect(() => {
    document.documentElement.classList.add('world-host')
    document.body.classList.add('world-host')
    return () => {
      document.documentElement.classList.remove('world-host')
      document.body.classList.remove('world-host')
    }
  }, [])

  useEffect(() => {
    void window.bbpet.getState().then((next) => setState(next))
    return window.bbpet.onStateChanged(setState)
  }, [])

  useEffect(() => {
    const apply = (room: RoomView) => {
      setError(room.error)
      setNotice(room.notice)
      setFriendIds(room.friends.map((item) => item.clientId))
      setFriends(room.friends)
      setGame(room.game)
      if (!room.you) {
        setStatus(room.connecting ? '正在连学校...' : '正在走进校门...')
        return
      }
      const schoolId = room.you.schoolPlaceId
      if (!schoolId) {
        setStatus('正在走进校门...')
        return
      }
      const jumped =
        schoolId !== placeRef.current ||
        Math.hypot(room.you.x - meRef.current.x, room.you.y - meRef.current.y) > 64
      if (jumped) {
        ignoreDoorRef.current = performance.now() + 700
        meRef.current = { x: room.you.x, y: room.you.y, facing: room.you.facing }
        setMe(meRef.current)
      }
      setPlaceId(schoolId)
      const moved: Record<string, number> = {}
      for (const person of room.people) {
        const prev = lastOthersRef.current[person.clientId]
        if (prev && (Math.abs(prev.x - person.x) > 0.4 || Math.abs(prev.y - person.y) > 0.4)) {
          moved[person.clientId] = Date.now() + 220
        }
        lastOthersRef.current[person.clientId] = { x: person.x, y: person.y }
      }
      if (Object.keys(moved).length) setMovingOthers((current) => ({ ...current, ...moved }))
      setOthers(room.people)
      setBoard(room.board)
      setStatus(PLACES[schoolId].title)
      if (room.lastChat && room.lastChat.id !== lastChatIdRef.current) {
        lastChatIdRef.current = room.lastChat.id
        const line = room.lastChat
        setBubbles((current) => ({ ...current, [line.clientId]: { text: line.text, until: Date.now() + 5000 } }))
      }
    }
    void window.bbpet.roomState().then(apply)
    return window.bbpet.onRoomState(apply)
  }, [])

  useEffect(() => {
    if (!isIncomingInvite(game)) return
    const id = window.setInterval(() => setNow(Date.now()), 200)
    return () => window.clearInterval(id)
  }, [game?.id, game?.status, game?.you])

  useEffect(() => {
    const moveKey = (event: KeyboardEvent) => {
      if (event.code === 'KeyW' || event.code === 'ArrowUp' || event.key.toLowerCase() === 'w') return 'w'
      if (event.code === 'KeyA' || event.code === 'ArrowLeft' || event.key.toLowerCase() === 'a') return 'a'
      if (event.code === 'KeyS' || event.code === 'ArrowDown' || event.key.toLowerCase() === 's') return 's'
      if (event.code === 'KeyD' || event.code === 'ArrowRight' || event.key.toLowerCase() === 'd') return 'd'
      return null
    }
    const typing = () => chattingRef.current && Boolean(inputRef.current?.value)
    const onDown = (event: KeyboardEvent) => {
      const key = moveKey(event)
      if (key) {
        if (typing()) return
        chattingRef.current = false
        inputRef.current?.blur()
        rootRef.current?.focus()
        keysRef.current[key] = true
        event.preventDefault()
        return
      }
      if (event.key === 'Enter') {
        if (chattingRef.current) return
        event.preventDefault()
        chattingRef.current = true
        inputRef.current?.focus()
        return
      }
      if (event.key === 'Escape') {
        if (inspect) {
          setInspect(null)
          return
        }
        if (chattingRef.current) {
          chattingRef.current = false
          inputRef.current?.blur()
          rootRef.current?.focus()
          return
        }
        window.bbpet.closeWorld()
      }
    }
    const onUp = (event: KeyboardEvent) => {
      const key = moveKey(event)
      if (key) keysRef.current[key] = false
    }
    const onBlur = () => {
      window.setTimeout(() => {
        if (document.hasFocus()) return
        keysRef.current = { w: false, a: false, s: false, d: false }
      }, 50)
    }
    window.addEventListener('keydown', onDown, true)
    window.addEventListener('keyup', onUp, true)
    window.addEventListener('blur', onBlur)
    const focusGame = () => rootRef.current?.focus()
    const timers = [window.setTimeout(focusGame, 50), window.setTimeout(focusGame, 250)]
    return () => {
      timers.forEach((id) => window.clearTimeout(id))
      window.removeEventListener('keydown', onDown, true)
      window.removeEventListener('keyup', onUp, true)
      window.removeEventListener('blur', onBlur)
    }
  }, [inspect])

  useEffect(() => {
    if (!isSchoolPlace(placeId)) return
    const id = window.requestAnimationFrame(() => rootRef.current?.focus())
    return () => window.cancelAnimationFrame(id)
  }, [placeId])

  useEffect(() => {
    let frame = 0
    let last = performance.now()
    const tick = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000)
      last = now
      const keys = keysRef.current
      const dx = (keys.d ? 1 : 0) - (keys.a ? 1 : 0)
      const dy = (keys.s ? 1 : 0) - (keys.w ? 1 : 0)
      const walking = dx !== 0 || dy !== 0
      const currentPlace = placeRef.current
      if (document.hidden || !isSchoolPlace(currentPlace)) {
        frame = window.requestAnimationFrame(tick)
        return
      }
      setMoving(walking)
      if (walking) {
        const place = PLACES[currentPlace]
        const len = Math.hypot(dx, dy) || 1
        const nextX = meRef.current.x + (dx / len) * MOVE_SPEED * dt
        const nextY = meRef.current.y + (dy / len) * MOVE_SPEED * dt
        const clamped = clampMove(place, meRef.current.x, meRef.current.y, nextX, nextY)
        const facing: Facing = dx < 0 ? 'l' : dx > 0 ? 'r' : meRef.current.facing
        meRef.current = { ...clamped, facing }
        setMe(meRef.current)
        if (now - lastSendRef.current > 80) {
          lastSendRef.current = now
          window.bbpet.roomSend({ type: 'move', x: clamped.x, y: clamped.y, facing })
        }
        if (now > ignoreDoorRef.current) {
          const trigger = triggerAt(place, clamped.x, clamped.y)
          if (trigger?.kind === 'exit') window.bbpet.closeWorld()
          else if (trigger?.kind === 'campus') {
            ignoreDoorRef.current = now + 800
            window.bbpet.roomSend({ type: 'enterPlace', placeId: 'school:campus' })
          } else if (trigger?.kind === 'classroom') {
            ignoreDoorRef.current = now + 800
            window.bbpet.roomSend({ type: 'enterPlace', placeId: trigger.placeId })
          }
        }
      }
      setMovingOthers((current) => {
        const next: Record<string, number> = {}
        let changed = false
        const stamp = Date.now()
        for (const [id, until] of Object.entries(current)) {
          if (until > stamp) next[id] = until
          else changed = true
        }
        return changed ? next : current
      })
      setBubbles((current) => {
        const next: Record<string, Bubble> = {}
        let changed = false
        for (const [id, bubble] of Object.entries(current)) {
          if (bubble.until > Date.now()) next[id] = bubble
          else changed = true
        }
        return changed ? next : current
      })
      frame = window.requestAnimationFrame(tick)
    }
    frame = window.requestAnimationFrame(tick)
    return () => window.cancelAnimationFrame(frame)
  }, [])

  useEffect(() => {
    if (!state || !isSchoolPlace(placeId)) return
    const canvas = canvasRef.current
    const ctx = canvas?.getContext('2d')
    if (!canvas || !ctx) return
    const place = PLACES[placeId]
    const { cols, rows } = mapSize(place)
    canvas.width = cols * TILE
    canvas.height = rows * TILE
    drawPlace(ctx, place)
  }, [placeId, state])

  useLayoutEffect(() => {
    if (!state || !isSchoolPlace(placeId)) return
    const stage = stageRef.current
    if (!stage) return
    const fit = () => {
      if (!isSchoolPlace(placeRef.current)) return
      const place = PLACES[placeRef.current]
      const { cols, rows } = mapSize(place)
      const mapW = cols * TILE
      const mapH = rows * TILE
      const w = stage.clientWidth
      const h = stage.clientHeight
      setStageSize({ w, h })
      setFitScale(Math.max(0.5, Math.min(w / mapW, h / mapH)))
    }
    fit()
    const observer = new ResizeObserver(fit)
    observer.observe(stage)
    return () => observer.disconnect()
  }, [placeId, state])

  useEffect(() => {
    const onWheel = (event: WheelEvent) => {
      if (chattingRef.current) return
      if (event.target instanceof HTMLElement && event.target.closest('input, .world-hud, .world-inspect, .world-bar')) {
        return
      }
      event.preventDefault()
      const factor = event.deltaY > 0 ? 0.9 : 1.12
      setZoom((current) => {
        const next = current * factor
        return Math.round(Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, next)) * 20) / 20
      })
    }
    window.addEventListener('wheel', onWheel, { passive: false })
    return () => window.removeEventListener('wheel', onWheel)
  }, [])

  const sendChat = () => {
    const text = draft.trim()
    if (!text) return
    window.bbpet.roomSend({ type: 'chat', text, placeId })
    setDraft('')
  }

  if (!state) return <div className="world-boot">桌宠正在背书包...</div>
  if (!isSchoolPlace(placeId)) {
    return <div className="world-boot">正在走进校门...</div>
  }

  const place = PLACES[placeId]
  const { cols, rows } = mapSize(place)
  const mapW = cols * TILE
  const mapH = rows * TILE
  const view = cameraFor(fitScale * zoom, me.x, me.y, stageSize.w, stageSize.h, mapW, mapH)
  const actors = [
    {
      clientId: state.clientId,
      name: state.pet.name,
      species: state.pet.species,
      colors: state.pet.colors,
      x: me.x,
      y: me.y,
      facing: me.facing,
      self: true,
    },
    ...others.map((item) => ({ ...item, self: false })),
  ].sort((a, b) => a.y - b.y)

  const visibleBoard = board.slice(-7)
  const nearbyHint = place.kind === 'classroom' ? '黑板只有本班听得见' : '走近才看得到气泡'
  const hint = error || notice || `WASD 移动 · 点同学加好友${friendIds.length ? ` · 好友 ${friendIds.length}` : ''} · ${nearbyHint}`
  const incoming = isIncomingInvite(game)
  const inviteSeconds = game ? Math.max(0, Math.ceil((game.deadlineAt - now) / 1000)) : 0
  const inspectFriend = inspect ? friends.find((card) => card.clientId === inspect.clientId) : undefined

  return (
    <div
      ref={rootRef}
      className="world-root"
      tabIndex={0}
      onMouseDown={(event) => {
        if (event.target === inputRef.current) {
          chattingRef.current = true
          return
        }
        const el = event.target instanceof HTMLElement ? event.target : null
        if (el?.closest('.world-inspect, .world-hud, .world-bar')) return
        const onActor = el?.closest('.world-actor.other')
        if (!onActor) setInspect(null)
        chattingRef.current = false
        inputRef.current?.blur()
        rootRef.current?.focus()
      }}
    >
      <header className="world-bar">
        <strong>{status}</strong>
        <span>{others.length + 1} 人在这里</span>
        <span className="world-zoom">{Math.round(zoom * 100)}%</span>
        <div className="world-bar-actions">
          {incoming && game && (
            <>
              <span className="world-invite">
                {game.black.name} 邀请你下五子棋 {inviteSeconds}秒
              </span>
              <button
                type="button"
                onClick={() => window.bbpet.roomSend({ type: 'gameRespond', gameId: game.id, accept: true })}
              >
                接受
              </button>
              <button
                type="button"
                className="ghost"
                onClick={() => window.bbpet.roomSend({ type: 'gameRespond', gameId: game.id, accept: false })}
              >
                拒绝
              </button>
            </>
          )}
          <button type="button" className="ghost" onClick={() => window.bbpet.closeWorld()}>
            收起
          </button>
        </div>
      </header>
      <div className="world-stage" ref={stageRef}>
        <div
          className="world-map"
          style={{
            left: view.left,
            top: view.top,
            width: mapW,
            height: mapH,
            transform: `scale(${view.scale})`,
            transformOrigin: 'top left',
          }}
        >
          <canvas ref={canvasRef} className="world-tiles" />
          {place.kind === 'classroom' && (
            <div className="blackboard">
              {visibleBoard.length === 0 && <p className="chalk-empty">黑板还是空的，回车写一句。</p>}
              {visibleBoard.map((line) => (
                <p key={line.id} className="chalk-line">
                  {line.name}：{line.text}
                </p>
              ))}
            </div>
          )}
          {actors.map((actor) => {
            const bubble = bubbles[actor.clientId]
            const showNear =
              place.kind === 'classroom' ||
              actor.self ||
              (bubble && dist(actor.x, actor.y, me.x, me.y) <= NEARBY_RANGE)
            return (
              <div
                key={actor.clientId}
                className={`world-actor${actor.self ? ' self' : ' other'}${(moving && actor.self) || movingOthers[actor.clientId] ? ' walking' : ''}${inspect?.clientId === actor.clientId ? ' picked' : ''}`}
                style={{ left: actor.x, top: actor.y, width: PET_SIZE, height: PET_SIZE }}
                onMouseDown={(event) => {
                  if (actor.self) return
                  event.stopPropagation()
                  setInspect({ clientId: actor.clientId, name: actor.name, x: actor.x, y: actor.y })
                }}
              >
                {bubble && showNear && <div className="world-bubble">{bubble.text}</div>}
                <PixelPet
                  species={actor.species}
                  colors={actor.colors}
                  pose={bubble ? 'talk' : 'idle'}
                  pixelSize={2}
                  flip={actor.facing === 'l'}
                />
                <span className="world-name">{actor.name}</span>
              </div>
            )
          })}
        </div>
        {inspect && (
          <div
            className="world-inspect"
            onMouseDown={(event) => event.stopPropagation()}
            style={{
              left: Math.max(8, inspect.x * view.scale + view.left + 36),
              top: Math.max(8, inspect.y * view.scale + view.top),
            }}
          >
            <strong>{inspect.name}</strong>
            {friendIds.includes(inspect.clientId) ? (
              <>
                {inspectFriend && canInviteFriend(game, state.clientId, inspectFriend) && (
                  <button
                    type="button"
                    onMouseDown={(event) => {
                      event.stopPropagation()
                      window.bbpet.roomSend({ type: 'inviteGame', targetId: inspect.clientId })
                      setInspect(null)
                    }}
                  >
                    五子棋
                  </button>
                )}
                <button
                  type="button"
                  onMouseDown={(event) => {
                    event.stopPropagation()
                    window.bbpet.goHome(inspect.clientId)
                    setInspect(null)
                  }}
                >
                  去他家
                </button>
              </>
            ) : (
              <button
                type="button"
                onMouseDown={(event) => {
                  event.preventDefault()
                  event.stopPropagation()
                  window.bbpet.roomSend({ type: 'friendRequest', targetId: inspect.clientId })
                  setFriendIds((ids) => (ids.includes(inspect.clientId) ? ids : [...ids, inspect.clientId]))
                }}
              >
                加好友
              </button>
            )}
            <button
              type="button"
              className="ghost"
              onMouseDown={(event) => {
                event.stopPropagation()
                setInspect(null)
              }}
            >
              取消
            </button>
          </div>
        )}
      </div>
      <form
        className="world-hud"
        onSubmit={(event) => {
          event.preventDefault()
          sendChat()
        }}
      >
        <p className="world-hint">{hint}</p>
        <div className="world-input">
          <input
            ref={inputRef}
            tabIndex={-1}
            value={draft}
            maxLength={80}
            autoComplete="off"
            spellCheck={false}
            placeholder={place.kind === 'classroom' ? '点这里或按 Enter 写黑板' : '点这里或按 Enter 说话'}
            onFocus={() => {
              chattingRef.current = true
            }}
            onBlur={() => {
              chattingRef.current = false
            }}
            onChange={(event) => setDraft(event.target.value)}
          />
          <button type="submit" disabled={!draft.trim()}>
            发送
          </button>
        </div>
      </form>
    </div>
  )
}

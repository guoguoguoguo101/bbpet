import { useEffect, useRef, useState } from 'react'
import type { AppState, PanelKind, PetPose } from '../shared/types'
import { emptyRoomView, isHomePlace, type RoomView } from '../shared/world'
import { isPetSolid } from './lib/hitTest'
import { collectPetShape } from './lib/petShape'
import { Gathering } from './pet/Gathering'
import { PixelPet } from './pet/PixelPet'
import { BubbleApp } from './ui/BubbleApp'
import { PanelApp } from './ui/PanelApp'
import { WorldApp } from './world/WorldApp'

function currentHash() {
  return window.location.hash.replace('#', '')
}

export function App() {
  const [hash, setHash] = useState(currentHash)

  useEffect(() => {
    const sync = () => setHash(currentHash())
    window.addEventListener('hashchange', sync)
    const off = window.bbpet.onSetPanel((kind) => setHash(kind))
    return () => {
      window.removeEventListener('hashchange', sync)
      off()
    }
  }, [])

  if (hash === 'bubble') return <BubbleApp />
  if (hash === 'world') return <WorldApp />
  if (hash === 'hub' || hash === 'chat' || hash === 'settings' || hash === 'wizard' || hash === 'friends') {
    return <PanelApp kind={hash as PanelKind} />
  }
  return <PetApp />
}

function PetApp() {
  const [state, setState] = useState<AppState | null>(null)
  const [room, setRoom] = useState<RoomView>(emptyRoomView())
  const [pose, setPose] = useState<PetPose>('idle')
  const [chatOpen, setChatOpen] = useState(false)
  const [talkingPush, setTalkingPush] = useState(false)
  const dragging = useRef(false)
  const pressOrigin = useRef<{ x: number; y: number } | null>(null)
  const lastIgnore = useRef<boolean | null>(null)
  const wrapRef = useRef<HTMLDivElement>(null)
  const gathering = Boolean(room.you && isHomePlace(room.you.placeId))

  useEffect(() => {
    document.documentElement.classList.add('pet-host')
    document.body.classList.add('pet-host')
    return () => {
      document.documentElement.classList.remove('pet-host')
      document.body.classList.remove('pet-host')
    }
  }, [])

  useEffect(() => {
    void window.bbpet.getState().then((next) => {
      setState(next)
      if (!next.onboarded) window.bbpet.openPanel('wizard')
    })
    void window.bbpet.roomState().then(setRoom)
    const offState = window.bbpet.onStateChanged(setState)
    const offRoom = window.bbpet.onRoomState(setRoom)
    return () => {
      offState()
      offRoom()
    }
  }, [])

  useEffect(() => {
    const offPush = window.bbpet.onPush(() => {
      setTalkingPush(true)
      setPose('talk')
    })
    const offChat = window.bbpet.onOpenChat(() => {
      setChatOpen(true)
      window.bbpet.openPanel('chat')
    })
    const offSettings = window.bbpet.onOpenSettings(() => window.bbpet.openPanel('settings'))
    const offClosed = window.bbpet.onPanelClosed(() => setChatOpen(false))
    const offBubble = window.bbpet.onBubbleClosed(() => {
      setTalkingPush(false)
      if (!chatOpen) setPose('idle')
    })
    return () => {
      offPush()
      offChat()
      offSettings()
      offClosed()
      offBubble()
    }
  }, [chatOpen])

  useEffect(() => {
    if (chatOpen || talkingPush) {
      setPose('talk')
      return
    }
    const blink = window.setInterval(() => {
      setPose('blink')
      window.setTimeout(() => setPose('idle'), 160)
    }, 3200)
    return () => window.clearInterval(blink)
  }, [chatOpen, talkingPush])

  const setIgnore = (ignore: boolean) => {
    if (lastIgnore.current === ignore) return
    lastIgnore.current = ignore
    window.bbpet.setIgnoreMouse(ignore)
  }

  useEffect(() => {
    const onDown = (event: PointerEvent) => {
      if (event.button !== 0 || !isPetSolid(event.clientX, event.clientY)) return
      if (event.target instanceof HTMLElement && event.target.closest('.gather-ui')) return
      pressOrigin.current = { x: event.screenX, y: event.screenY }
      setIgnore(false)
    }

    const syncHit = (event: PointerEvent) => {
      if (pressOrigin.current && !dragging.current) {
        const moved = Math.abs(event.screenX - pressOrigin.current.x) + Math.abs(event.screenY - pressOrigin.current.y) > 6
        if (moved) {
          dragging.current = true
          setIgnore(false)
          window.bbpet.dragStart()
        }
      }
      if (dragging.current) {
        setIgnore(false)
        return
      }
      setIgnore(!isPetSolid(event.clientX, event.clientY))
    }

    const onUp = (event: PointerEvent) => {
      const origin = pressOrigin.current
      const wasPressing = Boolean(origin)
      const moved = origin ? Math.abs(event.screenX - origin.x) + Math.abs(event.screenY - origin.y) > 6 : false
      const wasDragging = dragging.current
      dragging.current = false
      pressOrigin.current = null
      if (wasDragging) window.bbpet.dragEnd()
      setIgnore(!isPetSolid(event.clientX, event.clientY))
      const onChat = event.target instanceof HTMLElement && event.target.closest('.gather-ui')
      if (onChat) return
      if (wasPressing && !moved && event.button === 0 && isPetSolid(event.clientX, event.clientY)) {
        window.bbpet.openPanel('hub')
      }
    }

    window.addEventListener('pointermove', syncHit, { capture: true, passive: true })
    window.addEventListener('pointerdown', onDown, { capture: true })
    window.addEventListener('pointerup', onUp, { capture: true })
    window.addEventListener('pointercancel', onUp, { capture: true })
    window.addEventListener('blur', () => setIgnore(true))
    setIgnore(true)
    return () => {
      window.removeEventListener('pointermove', syncHit, true)
      window.removeEventListener('pointerdown', onDown, true)
      window.removeEventListener('pointerup', onUp, true)
      window.removeEventListener('pointercancel', onUp, true)
    }
  }, [])

  useEffect(() => {
    if (!state) return
    const report = () => {
      const root = wrapRef.current
      if (!root) return
      const box = root.getBoundingClientRect()
      window.bbpet.reportPetLayout({
        width: Math.max(80, Math.ceil(box.width)),
        height: Math.max(108, Math.ceil(box.height)),
      })
      const rects = collectPetShape(root, state.pet.species)
      if (rects.length) window.bbpet.setWindowShape(rects)
    }
    const id = window.requestAnimationFrame(report)
    const later = window.setTimeout(report, 160)
    return () => {
      window.cancelAnimationFrame(id)
      window.clearTimeout(later)
    }
  }, [state?.pet.species, state?.pet.name, gathering, room.people.length, room.lastChat?.id, room.board.length])

  const talking = pose === 'talk'

  if (!state) return <div className="boot">桌宠正在起床...</div>

  return (
    <div className="stage stage-pet">
      <div
        ref={wrapRef}
        className={`pet-wrap ${talking ? 'talking' : ''}${gathering ? ' gathering' : ''}`}
        onContextMenu={(event) => {
          event.preventDefault()
          if (!isPetSolid(event.clientX, event.clientY)) return
          window.bbpet.popupPetMenu()
        }}
      >
        {gathering ? (
          <Gathering state={state} room={room} />
        ) : (
          <>
            <PixelPet species={state.pet.species} colors={state.pet.colors} pose={pose} />
            <div className="name-plate">{state.pet.name}</div>
          </>
        )}
      </div>
    </div>
  )
}

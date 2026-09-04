import { useEffect, useRef, useState } from 'react'
import type { AppState, PanelKind, PetPose, WeatherInfo } from '../shared/types'
import { emptyRoomView, isHomeGathering, EMPTY_DRESS, type RoomView } from '../shared/world'
import { isPetSolid } from './lib/hitTest'
import { collectPetShape } from './lib/petShape'
import { findDemoAction, isSlackPose, SLACK_POSES } from '../shared/demoActions'
import { lineForPose } from '../shared/weatherLines'
import { Gathering } from './pet/Gathering'
import { PixelPet } from './pet/PixelPet'
import { WeatherDress } from './pet/WeatherDress'
import { BubbleApp } from './ui/BubbleApp'
import { PanelApp } from './ui/PanelApp'
import { GomokuApp } from './game/GomokuApp'
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
  if (hash === 'game') return <GomokuApp />
  if (hash === 'hub' || hash === 'chat' || hash === 'settings' || hash === 'wizard' || hash === 'friends') {
    return <PanelApp kind={hash as PanelKind} />
  }
  return <PetApp />
}

function PetApp() {
  const [state, setState] = useState<AppState | null>(null)
  const [room, setRoom] = useState<RoomView>(emptyRoomView())
  const [pose, setPose] = useState<PetPose>('idle')
  const poseRef = useRef<PetPose>('idle')
  const [awakeToken, setAwakeToken] = useState(0)
  const [look, setLook] = useState({ x: 0, y: 0 })
  const [userTyping, setUserTyping] = useState(false)
  const [weather, setWeather] = useState<WeatherInfo | null>(null)
  const [weatherShow, setWeatherShow] = useState<WeatherInfo | null>(null)
  const [chatOpen, setChatOpen] = useState(false)
  const [talkingPush, setTalkingPush] = useState(false)
  const [demoing, setDemoing] = useState(false)
  const [demoEmote, setDemoEmote] = useState('')
  const [demoLook, setDemoLook] = useState<{ x: number; y: number } | null>(null)
  const [idleLine, setIdleLine] = useState('')
  const [peekLook, setPeekLook] = useState(-1)
  const demoLock = useRef(false)
  const weatherShowTimer = useRef(0)
  const dragging = useRef(false)
  const pressOrigin = useRef<{ x: number; y: number } | null>(null)
  const lastIgnore = useRef<boolean | null>(null)
  const wrapRef = useRef<HTMLDivElement>(null)
  const gathering = Boolean(state && isHomeGathering(room.you, room.homePeople, state.clientId))
  poseRef.current = pose

  const startWeatherShow = (next: WeatherInfo) => {
    setWeather(next)
    if (demoLock.current) return
    setWeatherShow(next)
    window.clearTimeout(weatherShowTimer.current)
    weatherShowTimer.current = window.setTimeout(() => {
      setWeatherShow(null)
      setAwakeToken((n) => n + 1)
    }, 30000)
  }

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
    void window.bbpet.fetchWeather().then(startWeatherShow).catch(() => undefined)
    const offState = window.bbpet.onStateChanged(setState)
    const offRoom = window.bbpet.onRoomState(setRoom)
    const offPlay = window.bbpet.onPetPlay((play) => {
      if (demoLock.current) return
      setLook({ x: play.lookX, y: play.lookY })
      setUserTyping(play.typing)
    })
    const offWeather = window.bbpet.onWeather((next) => {
      startWeatherShow(next)
    })
    return () => {
      window.clearTimeout(weatherShowTimer.current)
      offState()
      offRoom()
      offPlay()
      offWeather()
    }
  }, [])

  useEffect(() => {
    const stopDemo = () => {
      demoLock.current = false
      setDemoing(false)
      setDemoEmote('')
      setDemoLook(null)
      setWeatherShow(null)
      setPose('idle')
      setAwakeToken((n) => n + 1)
    }

    const offDemo = window.bbpet.onPlayDemo?.((id) => {
      if (id === 'off') {
        stopDemo()
        return
      }
      const action = findDemoAction(id)
      if (!action) return
      demoLock.current = true
      window.clearTimeout(weatherShowTimer.current)
      setWeatherShow(null)
      setDemoing(true)
      setChatOpen(false)
      setTalkingPush(false)
      setUserTyping(false)
      setPose(action.pose)
      setWeather(action.weather)
      setDemoEmote(action.emote ?? '')
      setDemoLook(action.look ?? { x: 0, y: 0 })
    })
    return () => offDemo?.()
  }, [])

  useEffect(() => {
    const offPush = window.bbpet.onPush(() => {
      if (demoLock.current) return
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
      if (demoLock.current) return
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
    if (demoing) return
    if (gathering) {
      if (userTyping) {
        setPose('type')
        return
      }
      if (poseRef.current === 'type') setPose('idle')
      const timers: number[] = []
      const later = (fn: () => void, ms: number) => {
        const id = window.setTimeout(fn, ms)
        timers.push(id)
        return id
      }
      const blinkLoop = () => {
        later(() => {
          if (poseRef.current === 'idle') {
            setPose('blink')
            later(() => {
              if (poseRef.current === 'blink') setPose('idle')
            }, 160)
          }
          blinkLoop()
        }, 2600 + Math.floor(Math.random() * 1400))
      }
      const drinkLoop = () => {
        later(() => {
          if (poseRef.current === 'idle' || poseRef.current === 'blink') {
            setPose('drink')
            later(() => {
              if (poseRef.current === 'drink') setPose('idle')
            }, 2800)
          }
          drinkLoop()
        }, 150000 + Math.floor(Math.random() * 150000))
      }
      const nap = () => {
        later(() => {
          if (poseRef.current === 'talk' || poseRef.current === 'type') return
          setPose('sleep')
          later(() => {
            if (poseRef.current !== 'sleep') return
            setPose('wake')
            later(() => {
              if (poseRef.current === 'wake') setPose('idle')
              nap()
            }, 1600)
          }, 12000 + Math.floor(Math.random() * 8000))
        }, 55000 + Math.floor(Math.random() * 20000))
      }
      const slackLoop = () => {
        later(() => {
          if (poseRef.current === 'idle' || poseRef.current === 'blink') {
            const next = SLACK_POSES[Math.floor(Math.random() * SLACK_POSES.length)]
            setPose(next)
            later(() => {
              if (isSlackPose(poseRef.current)) setPose('idle')
            }, 3400 + Math.floor(Math.random() * 1600))
          }
          slackLoop()
        }, 14000 + Math.floor(Math.random() * 16000))
      }
      blinkLoop()
      drinkLoop()
      nap()
      slackLoop()
      if (weatherShow?.gear.includes('juice')) {
        const sip = () => {
          if (poseRef.current === 'idle' || poseRef.current === 'blink') {
            setPose('drink')
            later(() => {
              if (poseRef.current === 'drink') setPose('idle')
            }, 2800)
          }
        }
        sip()
        const juiceId = window.setInterval(sip, 10000)
        timers.push(juiceId)
      }
      return () => timers.forEach((id) => window.clearTimeout(id))
    }
    if (chatOpen || talkingPush) {
      setPose('talk')
      return
    }
    if (userTyping) {
      if (poseRef.current === 'sleep') {
        setPose('wake')
        const id = window.setTimeout(() => setPose('type'), 380)
        return () => window.clearTimeout(id)
      }
      setPose('type')
      return
    }

    if (weatherShow) {
      const sipJuice = weatherShow.gear.includes('juice')
      if (!sipJuice) {
        setPose('idle')
        return
      }
      const timers: number[] = []
      const sip = () => {
        setPose('drink')
        timers.push(
          window.setTimeout(() => {
            if (poseRef.current === 'drink') setPose('idle')
          }, 2800),
        )
      }
      sip()
      timers.push(window.setInterval(sip, 10000))
      return () => {
        timers.forEach((id) => {
          window.clearTimeout(id)
          window.clearInterval(id)
        })
      }
    }

    setPose('idle')
    const timers: number[] = []
    const later = (fn: () => void, ms: number) => {
      const id = window.setTimeout(fn, ms)
      timers.push(id)
      return id
    }

    const blinkLoop = () => {
      later(() => {
        if (poseRef.current === 'idle') {
          setPose('blink')
          later(() => {
            if (poseRef.current === 'blink') setPose('idle')
          }, 160)
        }
        blinkLoop()
      }, 2600 + Math.floor(Math.random() * 1400))
    }

    const drinkLoop = () => {
      later(() => {
        if (poseRef.current === 'idle' || poseRef.current === 'blink') {
          setPose('drink')
          later(() => {
            if (poseRef.current === 'drink') setPose('idle')
          }, 2800)
        }
        drinkLoop()
      }, 150000 + Math.floor(Math.random() * 150000))
    }

    const nap = () => {
      later(() => {
        if (poseRef.current === 'talk' || poseRef.current === 'type') return
        setPose('sleep')
        later(() => {
          if (poseRef.current !== 'sleep') return
          setPose('wake')
          later(() => {
            if (poseRef.current === 'wake') setPose('idle')
            nap()
          }, 1600)
        }, 12000 + Math.floor(Math.random() * 8000))
      }, 55000 + Math.floor(Math.random() * 20000))
    }

    const slackLoop = () => {
      later(() => {
        if (poseRef.current === 'idle' || poseRef.current === 'blink') {
          const next = SLACK_POSES[Math.floor(Math.random() * SLACK_POSES.length)]
          setPose(next)
          later(() => {
            if (isSlackPose(poseRef.current)) setPose('idle')
          }, 3400 + Math.floor(Math.random() * 1600))
        }
        slackLoop()
      }, 14000 + Math.floor(Math.random() * 16000))
    }

    blinkLoop()
    drinkLoop()
    nap()
    slackLoop()
    return () => timers.forEach((id) => window.clearTimeout(id))
  }, [chatOpen, talkingPush, gathering, awakeToken, userTyping, demoing, weatherShow])

  useEffect(() => {
    if (!gathering || demoing) return
    if (pose === 'blink') return
    window.bbpet.roomSend({ type: 'pose', pose, placeId: room.you?.homeId })
  }, [pose, gathering, demoing, room.you?.homeId])

  useEffect(() => {
    if (!gathering || demoing) return
    const dress = weatherShow ? { gear: weatherShow.gear, fx: weatherShow.fx } : EMPTY_DRESS
    window.bbpet.roomSend({ type: 'dress', dress, placeId: room.you?.homeId })
  }, [gathering, demoing, weatherShow, room.you?.homeId])

  useEffect(() => {
    if (demoing) {
      setIdleLine('')
      return
    }
    if (pose === 'idle' || pose === 'blink' || pose === 'talk') {
      setIdleLine('')
      return
    }
    if (pose === 'drink' && weatherShow?.gear.includes('juice')) {
      setIdleLine('')
      return
    }
    setIdleLine(lineForPose(pose))
  }, [pose, demoing, weatherShow?.gear.join()])

  useEffect(() => {
    const emote = room.lastEmote
    if (!emote || !state || emote.targetId !== state.clientId) return
    if (emote.kind === 'pour') {
      setPose('drink')
      const id = window.setTimeout(() => {
        if (poseRef.current === 'drink') setPose('idle')
      }, 2800)
      return () => window.clearTimeout(id)
    }
    if (emote.kind === 'wake' || emote.kind === 'kick' || emote.kind === 'hug') {
      if (poseRef.current === 'sleep') {
        setPose('wake')
        const id = window.setTimeout(() => {
          if (poseRef.current === 'wake') setPose('idle')
        }, 1600)
        return () => window.clearTimeout(id)
      }
    }
  }, [room.lastEmote?.id, state?.clientId])

  useEffect(() => {
    if (pose !== 'peek') return
    let tick = 0
    setPeekLook(-1)
    const id = window.setInterval(() => {
      tick += 1
      setPeekLook(tick % 2 === 0 ? -1 : 1)
    }, 380)
    return () => window.clearInterval(id)
  }, [pose])

  const setIgnore = (ignore: boolean) => {
    if (lastIgnore.current === ignore) return
    lastIgnore.current = ignore
    window.bbpet.setIgnoreMouse(ignore)
  }

  useEffect(() => {
    const onDown = (event: PointerEvent) => {
      if (event.button !== 0 || !isPetSolid(event.clientX, event.clientY)) return
      if (event.target instanceof HTMLElement && event.target.closest('.gather-ui, .gather-dock, .gather-react')) return
      dragging.current = true
      pressOrigin.current = { x: event.screenX, y: event.screenY }
      setAwakeToken((n) => n + 1)
      setIgnore(false)
      window.bbpet.dragStart()
    }

    const syncHit = (event: PointerEvent) => {
      if (dragging.current) {
        setIgnore(false)
        return
      }
      setIgnore(!isPetSolid(event.clientX, event.clientY))
    }

    const onUp = (event: PointerEvent) => {
      const origin = pressOrigin.current
      const moved = origin ? Math.abs(event.screenX - origin.x) + Math.abs(event.screenY - origin.y) > 6 : false
      const wasDragging = dragging.current
      dragging.current = false
      pressOrigin.current = null
      if (wasDragging) window.bbpet.dragEnd()
      setIgnore(!isPetSolid(event.clientX, event.clientY))
      if (event.target instanceof HTMLElement && event.target.closest('.gather-ui, .gather-slot, .gather-dock, .gather-react')) return
      if (wasDragging && !moved && event.button === 0 && isPetSolid(event.clientX, event.clientY)) {
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
        width: Math.max(64, Math.ceil(box.width)),
        height: Math.max(86, Math.ceil(box.height)),
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
  }, [state?.pet.species, state?.pet.name, gathering, gathering ? '' : pose, weatherShow?.fx.join(), weatherShow?.gear.join(), weather?.fx.join(), weather?.gear.join(), room.homePeople.length, demoing])

  const dressWeather = demoing ? weather : weatherShow
  const talking = pose === 'talk'
  const glanceSource = demoLook ?? look
  const down = pose === 'drink' || pose === 'type' || pose === 'phone' || pose === 'snack' || pose === 'game' || pose === 'coffee' || pose === 'toilet'
  const glanceX = pose === 'sleep' ? 0 : pose === 'peek' ? peekLook : down ? 0 : glanceSource.x
  const glanceY = pose === 'sleep' ? 0 : pose === 'peek' ? 0 : down ? 1 : glanceSource.y
  const wrapClass = [
    'pet-wrap',
    talking && 'talking',
    gathering && 'gathering',
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
    dressWeather?.fx.includes('wind') && 'weather-wind',
    dressWeather?.fx.includes('storm') && 'weather-storm',
    dressWeather?.fx.includes('stars') && 'night-sky',
  ]
    .filter(Boolean)
    .join(' ')

  if (!state) return <div className="boot">桌宠正在起床...</div>

  return (
    <div className="stage stage-pet">
      <div
        ref={wrapRef}
        className={wrapClass}
        onContextMenu={(event) => {
          event.preventDefault()
          if (event.target instanceof HTMLElement && event.target.closest('.gather-slot:not(.mine), .gather-react')) return
          if (!isPetSolid(event.clientX, event.clientY)) return
          setAwakeToken((n) => n + 1)
          window.bbpet.popupPetMenu()
        }}
      >
        {gathering && !demoing ? (
          <Gathering
            state={state}
            room={room}
            selfPose={pose}
            selfDress={weatherShow ? { gear: weatherShow.gear, fx: weatherShow.fx } : EMPTY_DRESS}
            idleLine={idleLine}
          />
        ) : (
          <>
            {dressWeather && <WeatherDress weather={dressWeather} />}
            {(demoEmote || idleLine) && (
              <span className="pet-emote">
                {demoEmote || idleLine}
              </span>
            )}
            <PixelPet
              species={state.pet.species}
              colors={state.pet.colors}
              pose={pose}
              lookX={glanceX}
              lookY={glanceY}
              gears={dressWeather?.gear ?? []}
            />
            {!demoing && <div className="name-plate">{state.pet.name}</div>}
          </>
        )}
      </div>
    </div>
  )
}

import { useEffect, useState } from 'react'
import { CITIES } from '../../shared/cities'
import type { AppState, PanelKind, PetProfile, WorldStatus } from '../../shared/types'
import { emptyRoomView, type RoomView } from '../../shared/world'
import { ChatPanel } from './ChatPanel'
import { FriendsPanel } from './FriendsPanel'
import { HubPanel } from './HubPanel'
import { Settings } from './Settings'
import { Wizard } from './Wizard'

export function PanelApp({ kind }: { kind: PanelKind }) {
  const [state, setState] = useState<AppState | null>(null)
  const [busy, setBusy] = useState(false)
  const [world, setWorld] = useState<WorldStatus>({
    present: false,
    visible: false,
    connected: false,
    inHome: false,
    placeTitle: '',
  })
  const [room, setRoom] = useState<RoomView>(emptyRoomView())

  useEffect(() => {
    void window.bbpet.getState().then(setState)
    void window.bbpet.worldStatus().then(setWorld)
    void window.bbpet.roomState().then(setRoom)
    const offState = window.bbpet.onStateChanged(setState)
    const offWorld = window.bbpet.onWorldStatus(setWorld)
    const offRoom = window.bbpet.onRoomState(setRoom)
    return () => {
      offState()
      offWorld()
      offRoom()
    }
  }, [kind])

  if (!state) return <div className="boot">桌宠正在起床...</div>

  const close = () => window.bbpet.closePanel()

  if (kind === 'hub') {
    return (
      <div className="stage stage-dock">
        <HubPanel
          state={state}
          inSchool={world.present}
          inHome={world.inHome}
          incoming={room.incoming.length}
          onChat={() => window.bbpet.openPanel('chat')}
          onSchool={() => {
            close()
            window.bbpet.openWorld()
          }}
          onHome={() => window.bbpet.goHome()}
          onFriends={() => window.bbpet.openPanel('friends')}
          onSettings={() => window.bbpet.openPanel('settings')}
          onClose={close}
        />
      </div>
    )
  }

  if (kind === 'friends') {
    return (
      <div className="stage stage-dock">
        <FriendsPanel
          room={room}
          myId={state.clientId}
          onVisit={(ownerId) => window.bbpet.goHome(ownerId)}
          onClose={close}
        />
      </div>
    )
  }

  if (kind === 'chat') {
    return (
      <div className="stage stage-dock">
        <ChatPanel
          name={state.pet.name}
          history={state.chatHistory}
          busy={busy}
          onSend={(text) => {
            setBusy(true)
            void window.bbpet
              .chat(text)
              .then((result) => setState((current) => (current ? { ...current, chatHistory: result.history } : current)))
              .finally(() => setBusy(false))
          }}
          onClose={close}
        />
      </div>
    )
  }

  if (kind === 'settings') {
    return (
      <div className="stage stage-dock">
        <Settings
          pet={state.pet}
          settings={state.settings}
          onSavePet={async (pet) => setState(await window.bbpet.savePet(pet))}
          onSaveSettings={async (settings) => setState(await window.bbpet.saveSettings(settings))}
          onClose={close}
        />
      </div>
    )
  }

  const finishWizard = async (pet: PetProfile, cityId: string) => {
    const city = CITIES.find((item) => item.id === cityId) ?? CITIES[0]
    await window.bbpet.savePet(pet)
    await window.bbpet.saveSettings({
      ...state.settings,
      cityId: city.id,
      cityName: city.name,
      latitude: city.latitude,
      longitude: city.longitude,
    })
    close()
  }

  return (
    <div className="stage stage-dock">
      <Wizard
        initial={state.pet}
        cityId={state.settings.cityId}
        onCityChange={(nextCity) => {
          const city = CITIES.find((item) => item.id === nextCity) ?? CITIES[0]
          setState({
            ...state,
            settings: {
              ...state.settings,
              cityId: city.id,
              cityName: city.name,
              latitude: city.latitude,
              longitude: city.longitude,
            },
          })
        }}
        onDone={(pet) => void finishWizard(pet, state.settings.cityId)}
      />
    </div>
  )
}

import WebSocket from 'ws'
import type { PetPose, PetProfile } from '../shared/types'
import {
  emptyRoomView,
  homePlaceId,
  isHomePlace,
  isSchoolPlace,
  type ClientMsg,
  type HomePlaceId,
  type PetDress,
  type PlaceId,
  type PoseItem,
  type Presence,
  type RoomView,
  type SchoolPlaceId,
  type ServerMsg,
  type WorldSnapshot,
} from '../shared/world'
import { applyPoseItems } from '../shared/sync'

export class RoomClient {
  private ws: WebSocket | null = null
  private view: RoomView = emptyRoomView()
  private url = ''
  private clientId = ''
  private pet: PetProfile | null = null
  private wanted = false
  private ready = false
  private pending: ClientMsg[] = []
  private homeTarget: HomePlaceId | null = null
  private schoolTarget: SchoolPlaceId | null = null
  private retryTimer: NodeJS.Timeout | null = null
  private noticeTimer: NodeJS.Timeout | null = null
  onChange: (view: RoomView) => void = () => {}
  onPoses: (payload: { placeId: PlaceId; t: number; items: PoseItem[] }) => void = () => {}

  get(): RoomView {
    return this.view
  }

  enter(placeId: PlaceId) {
    if (placeId === 'away') this.homeTarget = homePlaceId(this.clientId)
    else if (isHomePlace(placeId)) this.homeTarget = placeId
    else if (isSchoolPlace(placeId)) this.schoolTarget = placeId
    this.send({ type: 'enterPlace', placeId })
  }

  send(msg: ClientMsg) {
    if (msg.type === 'enterPlace') {
      if (msg.placeId === 'away') this.homeTarget = homePlaceId(this.clientId)
      else if (isHomePlace(msg.placeId)) this.homeTarget = msg.placeId
      else if (isSchoolPlace(msg.placeId)) this.schoolTarget = msg.placeId
    }
    if (!this.ready && msg.type !== 'hello') {
      this.pending.push(msg)
      return
    }
    if (msg.type === 'move' && this.view.you) {
      this.view = {
        ...this.view,
        you: { ...this.view.you, x: msg.x, y: msg.y, facing: msg.facing },
      }
    }
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(msg))
  }

  async ensure(url: string, clientId: string, pet: PetProfile) {
    this.wanted = true
    if (!this.homeTarget) this.homeTarget = homePlaceId(clientId)
    const sameConn = this.ws && this.view.connected && this.url === url && this.clientId === clientId
    if (sameConn) {
      const petChanged =
        this.pet &&
        (this.pet.name !== pet.name || this.pet.species !== pet.species || JSON.stringify(this.pet.colors) !== JSON.stringify(pet.colors))
      this.pet = pet
      if (petChanged) this.send({ type: 'hello', clientId, pet })
      return this.view
    }
    this.url = url
    this.clientId = clientId
    this.pet = pet
    await this.connect()
    return this.view
  }

  disconnect() {
    this.wanted = false
    if (this.retryTimer) clearTimeout(this.retryTimer)
    this.retryTimer = null
    this.ws?.close()
    this.ws = null
    this.ready = false
    this.pending = []
    this.view = emptyRoomView()
    this.emit()
  }

  private patchPoses(placeId: PlaceId, t: number, items: PoseItem[]) {
    this.view = {
      ...this.view,
      people: applyPoseItems(this.view.people, items, this.clientId),
    }
    this.onPoses({ placeId, t, items })
  }

  private emit() {
    this.onChange(this.view)
  }

  private flush() {
    const queued = this.pending
    this.pending = []
    for (const msg of queued) this.send(msg)
  }

  private applyBucket(snapshot: WorldSnapshot, kind: 'home' | 'school') {
    if (kind === 'home') {
      this.view = {
        ...this.view,
        homePeople: snapshot.people,
        homeBoard: snapshot.board,
        friends: snapshot.friends,
        incoming: snapshot.incoming,
        poses: {
          ...this.view.poses,
          ...posesFrom(this.view.you, snapshot.people),
        },
        looks: {
          ...this.view.looks,
          ...looksFrom(this.view.you, snapshot.people),
        },
        dresses: {
          ...this.view.dresses,
          ...dressesFrom(this.view.you, snapshot.people),
        },
      }
      return
    }
    this.view = {
      ...this.view,
      people: snapshot.people,
      board: snapshot.board,
      friends: snapshot.friends,
      incoming: snapshot.incoming,
    }
  }

  private connect(): Promise<void> {
    return new Promise((resolve) => {
      if (this.retryTimer) {
        clearTimeout(this.retryTimer)
        this.retryTimer = null
      }
      this.ready = false
      this.view = { ...emptyRoomView(), connecting: true, error: '' }
      this.emit()
      const ws = new WebSocket(this.url)
      this.ws = ws
      let settled = false
      const done = () => {
        if (settled) return
        settled = true
        resolve()
      }
      const failTimer = setTimeout(() => {
        if (!this.view.connected) {
          this.view = {
            ...this.view,
            connecting: false,
            error: '连不上房主。先在设置里打开「我来当校长」，或本机运行 npm run room。',
          }
          this.emit()
        }
        done()
      }, 5000)

      ws.on('open', () => {
        if (this.pet) ws.send(JSON.stringify({ type: 'hello', clientId: this.clientId, pet: this.pet }))
      })
      ws.on('message', (raw) => {
        this.handle(String(raw))
        if (this.view.connected) {
          clearTimeout(failTimer)
          done()
        }
      })
      ws.on('close', () => {
        clearTimeout(failTimer)
        this.ready = false
        if (this.ws === ws) this.ws = null
        this.view = { ...this.view, connected: false, connecting: false, error: this.view.error || '和学校断开了' }
        this.emit()
        done()
        if (this.wanted) {
          this.retryTimer = setTimeout(() => {
            if (this.wanted) void this.connect()
          }, 1600)
        }
      })
      ws.on('error', () => {
        this.view = {
          ...this.view,
          error: '连不上房主。先在设置里打开「我来当校长」，或本机运行 npm run room。',
        }
        this.emit()
      })
    })
  }

  private handle(raw: string) {
    let msg: ServerMsg
    try {
      msg = JSON.parse(raw) as ServerMsg
    } catch {
      return
    }
    if (msg.type === 'error') {
      this.view = { ...this.view, error: msg.message }
      this.emit()
      return
    }
    if (msg.type === 'notice') {
      this.view = { ...this.view, notice: msg.text, error: '' }
      this.emit()
      if (this.noticeTimer) clearTimeout(this.noticeTimer)
      const text = msg.text
      this.noticeTimer = setTimeout(() => {
        if (this.view.notice === text) {
          this.view = { ...this.view, notice: '' }
          this.emit()
        }
      }, 4200)
      return
    }
    if (msg.type === 'welcome') {
      this.ready = true
      this.view = {
        ...this.view,
        connected: true,
        connecting: false,
        error: '',
        you: msg.you,
        homePeople: msg.home.people,
        homeBoard: msg.home.board,
        people: msg.school?.people ?? [],
        board: msg.school?.board ?? [],
        friends: msg.home.friends,
        incoming: msg.home.incoming,
        lastChat: null,
        lastHomeChat: null,
        poses: posesFrom(msg.you, msg.home.people),
        looks: looksFrom(msg.you, msg.home.people),
        dresses: dressesFrom(msg.you, msg.home.people),
        lastEmote: null,
        game: msg.game ?? null,
      }
      this.emit()
      this.flush()
      if (this.homeTarget && this.homeTarget !== msg.you.homeId) this.send({ type: 'enterPlace', placeId: this.homeTarget })
      if (this.schoolTarget && this.schoolTarget !== msg.you.schoolPlaceId) {
        this.send({ type: 'enterPlace', placeId: this.schoolTarget })
      }
      return
    }
    if (msg.type === 'gameState') {
      this.view = { ...this.view, game: msg.game, error: '' }
      this.emit()
      return
    }
    if (msg.type === 'snapshot') {
      this.view = { ...this.view, you: msg.you, error: '' }
      if (isHomePlace(msg.snapshot.placeId)) this.homeTarget = msg.you.homeId
      this.applyBucket(msg.snapshot, isHomePlace(msg.snapshot.placeId) ? 'home' : 'school')
      this.emit()
      return
    }
    if (msg.type === 'join') {
      const person = msg.person
      if (isHomePlace(msg.placeId) && this.view.you?.homeId === msg.placeId) {
        this.view = {
          ...this.view,
          homePeople: [...this.view.homePeople.filter((item) => item.clientId !== person.clientId), person],
          poses: { ...this.view.poses, [person.clientId]: person.pose || 'idle' },
          looks: { ...this.view.looks, [person.clientId]: lookOf(person) },
          dresses: { ...this.view.dresses, [person.clientId]: person.dress || { gear: [], fx: [] } },
        }
      }
      if (isSchoolPlace(msg.placeId) && this.view.you?.schoolPlaceId === msg.placeId) {
        this.view = {
          ...this.view,
          people: [...this.view.people.filter((item) => item.clientId !== person.clientId), person],
        }
      }
      this.emit()
      return
    }
    if (msg.type === 'leave') {
      if (isHomePlace(msg.placeId)) {
        const poses = { ...this.view.poses }
        const looks = { ...this.view.looks }
        const dresses = { ...this.view.dresses }
        delete poses[msg.clientId]
        delete looks[msg.clientId]
        delete dresses[msg.clientId]
        this.view = {
          ...this.view,
          homePeople: this.view.homePeople.filter((item) => item.clientId !== msg.clientId),
          poses,
          looks,
          dresses,
        }
      }
      if (isSchoolPlace(msg.placeId)) {
        this.view = { ...this.view, people: this.view.people.filter((item) => item.clientId !== msg.clientId) }
      }
      this.emit()
      return
    }
    if (msg.type === 'move') {
      this.patchPoses(this.view.you?.schoolPlaceId ?? 'school:campus', Date.now(), [
        { id: msg.clientId, x: msg.x, y: msg.y, facing: msg.facing },
      ])
      return
    }
    if (msg.type === 'poses') {
      this.patchPoses(msg.placeId, msg.t, msg.items)
      return
    }
    if (msg.type === 'chat') {
      if (isHomePlace(msg.line.placeId)) {
        const homeBoard = msg.line.kind === 'board' ? [...this.view.homeBoard, msg.line].slice(-80) : this.view.homeBoard
        this.view = { ...this.view, homeBoard, lastHomeChat: msg.line.action ? this.view.lastHomeChat : msg.line }
      } else {
        const board = msg.line.kind === 'board' ? [...this.view.board, msg.line].slice(-80) : this.view.board
        this.view = { ...this.view, board, lastChat: msg.line }
      }
      this.emit()
      return
    }
    if (msg.type === 'friends') {
      this.view = { ...this.view, friends: msg.friends, incoming: msg.incoming }
      this.emit()
      return
    }
    if (msg.type === 'pose') {
      const poses = { ...this.view.poses, [msg.clientId]: msg.pose }
      const looks = { ...this.view.looks, [msg.clientId]: { x: msg.lookX || 0, y: msg.lookY || 0 } }
      const you = this.view.you?.clientId === msg.clientId && this.view.you ? { ...this.view.you, pose: msg.pose, lookX: msg.lookX || 0, lookY: msg.lookY || 0 } : this.view.you
      this.view = {
        ...this.view,
        you,
        poses,
        looks,
        homePeople: this.view.homePeople.map((item) =>
          item.clientId === msg.clientId ? { ...item, pose: msg.pose, lookX: msg.lookX || 0, lookY: msg.lookY || 0 } : item,
        ),
        people: this.view.people.map((item) =>
          item.clientId === msg.clientId ? { ...item, pose: msg.pose, lookX: msg.lookX || 0, lookY: msg.lookY || 0 } : item,
        ),
      }
      this.emit()
      return
    }
    if (msg.type === 'dress') {
      const dresses = { ...this.view.dresses, [msg.clientId]: msg.dress }
      const you = this.view.you?.clientId === msg.clientId && this.view.you ? { ...this.view.you, dress: msg.dress } : this.view.you
      this.view = {
        ...this.view,
        you,
        dresses,
        homePeople: this.view.homePeople.map((item) => (item.clientId === msg.clientId ? { ...item, dress: msg.dress } : item)),
        people: this.view.people.map((item) => (item.clientId === msg.clientId ? { ...item, dress: msg.dress } : item)),
      }
      this.emit()
      return
    }
    if (msg.type === 'emote') {
      this.view = { ...this.view, lastEmote: msg.emote }
      this.emit()
    }
  }
}

function posesFrom(you: Presence | null, people: Presence[]) {
  const poses: Record<string, PetPose> = {}
  if (you) poses[you.clientId] = you.pose || 'idle'
  for (const person of people) poses[person.clientId] = person.pose || 'idle'
  return poses
}

function lookOf(person: Pick<Presence, 'lookX' | 'lookY'>) {
  return { x: person.lookX || 0, y: person.lookY || 0 }
}

function looksFrom(you: Presence | null, people: Presence[]) {
  const looks: Record<string, { x: number; y: number }> = {}
  if (you) looks[you.clientId] = lookOf(you)
  for (const person of people) looks[person.clientId] = lookOf(person)
  return looks
}

function dressesFrom(you: Presence | null, people: Presence[]) {
  const dresses: Record<string, PetDress> = {}
  if (you) dresses[you.clientId] = you.dress || { gear: [], fx: [] }
  for (const person of people) dresses[person.clientId] = person.dress || { gear: [], fx: [] }
  return dresses
}

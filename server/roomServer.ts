import { createServer, type Server } from 'node:http'
import { join } from 'node:path'
import { WebSocket, WebSocketServer } from 'ws'
import { DEFAULT_COLORS } from '../shared/types'
import {
  BOARD_LIMIT,
  DIRECTED_EMOTES,
  PLACES,
  chatKindFor,
  clampMove,
  defaultSpawn,
  displayPlace,
  homeOwnerId,
  homePlaceId,
  inPlace,
  isEmoteKind,
  isHomePlace,
  isPlaceId,
  isSchoolPlace,
  isSyncPose,
  sanitizeChat,
  sanitizeDress,
  spawnAfterEnter,
  type ChatLine,
  type ClientMsg,
  type EmoteKind,
  type FriendCard,
  type HomeEmote,
  type PetDress,
  type PlaceId,
  type Presence,
  type ServerMsg,
} from '../shared/world'
import { createFriendsStore } from './friendsStore'

interface Client {
  ws: WebSocket
  presence: Presence
  lastChatAt: number
  chatBurst: number
  lastPoseAt: number
  lastEmoteAt: number
  lastDressAt: number
}

export function startRoomServer(port: number, options?: { friendsFile?: string }): Promise<Server> {
  const httpServer = createServer((_req, res) => {
    res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' })
    res.end('BbPet school is open\n')
  })
  const wss = new WebSocketServer({ server: httpServer })
  const clients = new Map<WebSocket, Client>()
  const byId = new Map<string, Client>()
  const boards = new Map<PlaceId, ChatLine[]>()
  const friends = createFriendsStore(options?.friendsFile || join(process.cwd(), 'bbpet-friends.json'))

  const send = (ws: WebSocket, msg: ServerMsg) => {
    if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg))
  }

  const cardFor = (id: string): FriendCard => {
    const online = byId.get(id)
    const rec = friends.get(id)
    return {
      clientId: id,
      name: online?.presence.name || rec?.name || '桌宠',
      species: online?.presence.species || rec?.species || 'blob',
      colors: online?.presence.colors || rec?.colors || DEFAULT_COLORS.blob,
      online: Boolean(online),
      placeId: online ? displayPlace(online.presence) : null,
      homeId: online?.presence.homeId ?? null,
      schoolPlaceId: online?.presence.schoolPlaceId ?? null,
    }
  }

  const packFriends = (id: string) => {
    const rec = friends.get(id)
    return {
      friends: (rec?.friends ?? []).map(cardFor),
      incoming: (rec?.incoming ?? []).map(cardFor),
    }
  }

  const sendFriends = (id: string) => {
    const client = byId.get(id)
    if (!client) return
    send(client.ws, { type: 'friends', ...packFriends(id) })
  }

  const notifyFriendLists = (id: string) => {
    sendFriends(id)
    const rec = friends.get(id)
    if (!rec) return
    for (const otherId of rec.friends) sendFriends(otherId)
    for (const otherId of rec.incoming) sendFriends(otherId)
  }

  const peopleIn = (placeId: PlaceId, exceptId?: string) => {
    if (placeId === 'away') return []
    return [...byId.values()]
      .filter((item) => inPlace(item.presence, placeId) && item.presence.clientId !== exceptId)
      .map((item) => item.presence)
  }

  const boardOf = (placeId: PlaceId) => boards.get(placeId) ?? []

  const snapshot = (placeId: PlaceId, clientId: string) => ({
    placeId,
    people: peopleIn(placeId, clientId),
    board: placeId === 'away' ? [] : boardOf(placeId),
    ...packFriends(clientId),
  })

  const broadcast = (placeId: PlaceId, msg: ServerMsg, except?: WebSocket) => {
    if (placeId === 'away') return
    for (const [socket, client] of clients) {
      if (inPlace(client.presence, placeId) && socket !== except) send(socket, msg)
    }
  }

  const resolvePlace = (client: Client, placeId?: PlaceId) => {
    let target: PlaceId | null = placeId && isPlaceId(placeId) && placeId !== 'away' ? placeId : null
    if (!target) target = client.presence.schoolPlaceId ?? client.presence.homeId
    if (!inPlace(client.presence, target)) return null
    return target
  }

  const emitEmote = (client: Client, kind: EmoteKind, placeId: PlaceId, targetId?: string) => {
    const emote: HomeEmote = {
      id: `${Date.now()}-${client.presence.clientId}-${kind}`,
      fromId: client.presence.clientId,
      targetId,
      kind,
      ts: Date.now(),
      placeId,
    }
    const payload: ServerMsg = { type: 'emote', emote }
    send(client.ws, payload)
    broadcast(placeId, payload, client.ws)
    return emote
  }

  const sendHome = (guest: Client, reason: string) => {
    const own = homePlaceId(guest.presence.clientId)
    if (guest.presence.homeId === own) return
    const from = guest.presence.homeId
    broadcast(from, { type: 'leave', clientId: guest.presence.clientId, placeId: from }, guest.ws)
    guest.presence.homeId = own
    guest.presence.placeId = displayPlace(guest.presence)
    guest.presence.pose = 'idle'
    send(guest.ws, { type: 'snapshot', you: guest.presence, snapshot: snapshot(own, guest.presence.clientId) })
    send(guest.ws, { type: 'notice', text: reason })
    broadcast(own, { type: 'join', person: guest.presence, placeId: own }, guest.ws)
    notifyFriendLists(guest.presence.clientId)
  }

  const bounceVisitors = (homeId: PlaceId) => {
    const owner = homeOwnerId(homeId)
    if (!owner) return
    for (const guest of [...byId.values()]) {
      if (guest.presence.clientId === owner) continue
      if (guest.presence.homeId !== homeId) continue
      sendHome(guest, '主人不在家了，先回自己家吧')
    }
  }

  const hostIsHome = (ownerId: string) => {
    const host = byId.get(ownerId)
    return Boolean(host && host.presence.homeId === homePlaceId(ownerId))
  }

  const drop = (ws: WebSocket) => {
    const client = clients.get(ws)
    if (!client) return
    clients.delete(ws)
    if (byId.get(client.presence.clientId) === client) byId.delete(client.presence.clientId)
    broadcast(client.presence.homeId, { type: 'leave', clientId: client.presence.clientId, placeId: client.presence.homeId })
    if (client.presence.schoolPlaceId) {
      broadcast(client.presence.schoolPlaceId, {
        type: 'leave',
        clientId: client.presence.clientId,
        placeId: client.presence.schoolPlaceId,
      })
    }
    notifyFriendLists(client.presence.clientId)
    bounceVisitors(homePlaceId(client.presence.clientId))
  }

  wss.on('connection', (ws) => {
    ws.on('message', (raw) => {
      let msg: ClientMsg
      try {
        msg = JSON.parse(String(raw)) as ClientMsg
      } catch {
        send(ws, { type: 'error', message: '报文看不懂' })
        return
      }

      if (msg.type === 'hello') {
        const pet = msg.pet
        if (!msg.clientId || !pet?.name || !pet.species || !pet.colors) {
          send(ws, { type: 'error', message: '形象不完整' })
          return
        }
        const existing = clients.get(ws)
        if (existing && existing.presence.clientId === msg.clientId) {
          existing.presence.name = String(pet.name).slice(0, 12)
          existing.presence.species = pet.species
          existing.presence.colors = pet.colors
          friends.upsert(msg.clientId, existing.presence)
          notifyFriendLists(msg.clientId)
          return
        }
        const old = byId.get(msg.clientId)
        if (old && old.ws !== ws) {
          old.ws.close()
          drop(old.ws)
        }
        const homeId = homePlaceId(msg.clientId)
        const spawn = defaultSpawn('school:campus')
        const presence: Presence = {
          clientId: msg.clientId,
          name: String(pet.name).slice(0, 12),
          species: pet.species,
          colors: pet.colors,
          homeId,
          schoolPlaceId: null,
          placeId: homeId,
          x: spawn.x,
          y: spawn.y,
          facing: 'r',
          pose: 'idle',
          dress: { gear: [], fx: [] },
        }
        friends.upsert(msg.clientId, presence)
        console.log(`[hello] ${presence.name} ${msg.clientId.slice(0, 8)} 上线`)
        const client: Client = { ws, presence, lastChatAt: 0, chatBurst: 0, lastPoseAt: 0, lastEmoteAt: 0, lastDressAt: 0 }
        clients.set(ws, client)
        byId.set(msg.clientId, client)
        send(ws, {
          type: 'welcome',
          you: presence,
          home: snapshot(homeId, presence.clientId),
          school: null,
        })
        broadcast(homeId, { type: 'join', person: presence, placeId: homeId }, ws)
        notifyFriendLists(msg.clientId)
        if (peopleIn(homeId).length >= 2) emitEmote(client, 'wave', homeId)
        return
      }

      const client = clients.get(ws)
      if (!client) {
        send(ws, { type: 'error', message: '先打个招呼' })
        return
      }

      if (msg.type === 'enterPlace') {
        if (!isPlaceId(msg.placeId)) return
        const to = msg.placeId === 'away' ? homePlaceId(client.presence.clientId) : msg.placeId

        if (isHomePlace(to)) {
          const owner = homeOwnerId(to)
          if (owner !== client.presence.clientId && !friends.isFriend(client.presence.clientId, owner || '')) {
            send(ws, { type: 'error', message: '还不是好友，先加好友再串门' })
            return
          }
          if (owner && owner !== client.presence.clientId && !hostIsHome(owner)) {
            send(ws, { type: 'notice', text: '好友不在家，现在去不了' })
            return
          }
          if (to === client.presence.homeId) return
          const from = client.presence.homeId
          const leavingOwn = from === homePlaceId(client.presence.clientId)
          broadcast(from, { type: 'leave', clientId: client.presence.clientId, placeId: from }, ws)
          client.presence.homeId = to
          client.presence.placeId = displayPlace(client.presence)
          client.presence.pose = 'idle'
          send(ws, { type: 'snapshot', you: client.presence, snapshot: snapshot(to, client.presence.clientId) })
          broadcast(to, { type: 'join', person: client.presence, placeId: to }, ws)
          notifyFriendLists(client.presence.clientId)
          if (leavingOwn) bounceVisitors(from)
          if (peopleIn(to).length >= 2) emitEmote(client, 'wave', to)
          return
        }

        if (isSchoolPlace(to)) {
          if (to === client.presence.schoolPlaceId) return
          const from = client.presence.schoolPlaceId
          const spawn = spawnAfterEnter(from ?? client.presence.homeId, to)
          if (from) broadcast(from, { type: 'leave', clientId: client.presence.clientId, placeId: from }, ws)
          client.presence.schoolPlaceId = to
          client.presence.placeId = to
          client.presence.x = spawn.x
          client.presence.y = spawn.y
          send(ws, { type: 'snapshot', you: client.presence, snapshot: snapshot(to, client.presence.clientId) })
          broadcast(to, { type: 'join', person: client.presence, placeId: to }, ws)
          notifyFriendLists(client.presence.clientId)
        }
        return
      }

      if (msg.type === 'move') {
        const school = client.presence.schoolPlaceId
        if (!school) return
        const place = PLACES[school]
        const next = clampMove(place, client.presence.x, client.presence.y, Number(msg.x) || 0, Number(msg.y) || 0)
        client.presence.x = next.x
        client.presence.y = next.y
        client.presence.facing = msg.facing === 'l' ? 'l' : 'r'
        broadcast(
          school,
          {
            type: 'move',
            clientId: client.presence.clientId,
            x: next.x,
            y: next.y,
            facing: client.presence.facing,
          },
          ws,
        )
        return
      }

      if (msg.type === 'chat') {
        let target: PlaceId | null = msg.placeId && isPlaceId(msg.placeId) && msg.placeId !== 'away' ? msg.placeId : null
        if (!target) target = client.presence.schoolPlaceId ?? client.presence.homeId
        if (!inPlace(client.presence, target)) return
        const now = Date.now()
        if (now - client.lastChatAt < 400) return
        if (now - client.lastChatAt < 3000) client.chatBurst += 1
        else client.chatBurst = 1
        client.lastChatAt = now
        if (client.chatBurst > 8) return
        const text = sanitizeChat(msg.text)
        if (!text) return
        const line: ChatLine = {
          id: `${now}-${client.presence.clientId}`,
          clientId: client.presence.clientId,
          name: client.presence.name,
          text,
          ts: now,
          kind: chatKindFor(target),
          placeId: target,
        }
        if (line.kind === 'board') {
          const board = [...boardOf(line.placeId), line].slice(-BOARD_LIMIT)
          boards.set(line.placeId, board)
        }
        send(ws, { type: 'chat', line })
        broadcast(target, { type: 'chat', line }, ws)
        return
      }

      if (msg.type === 'pose') {
        if (!isSyncPose(msg.pose)) return
        const place = resolvePlace(client, msg.placeId)
        if (!place) return
        const now = Date.now()
        if (now - client.lastPoseAt < 400) return
        client.lastPoseAt = now
        client.presence.pose = msg.pose
        const payload: ServerMsg = {
          type: 'pose',
          clientId: client.presence.clientId,
          pose: msg.pose,
          placeId: place,
        }
        send(ws, payload)
        broadcast(place, payload, ws)
        return
      }

      if (msg.type === 'dress') {
        const place = resolvePlace(client, msg.placeId)
        if (!place) return
        const now = Date.now()
        if (now - client.lastDressAt < 400) return
        client.lastDressAt = now
        const dress: PetDress = sanitizeDress(msg.dress)
        client.presence.dress = dress
        const payload: ServerMsg = {
          type: 'dress',
          clientId: client.presence.clientId,
          dress,
          placeId: place,
        }
        send(ws, payload)
        broadcast(place, payload, ws)
        return
      }

      if (msg.type === 'emote') {
        if (!isEmoteKind(msg.kind)) return
        const place = resolvePlace(client, msg.placeId)
        if (!place) return
        const now = Date.now()
        if (now - client.lastEmoteAt < 5000) {
          send(ws, { type: 'error', message: '动作还在冷却' })
          return
        }
        const directed = DIRECTED_EMOTES.includes(msg.kind)
        const targetId = directed ? String(msg.targetId || '') : undefined
        if (directed) {
          if (!targetId || targetId === client.presence.clientId) {
            send(ws, { type: 'error', message: '先点客厅里的人' })
            return
          }
          const other = byId.get(targetId)
          if (!other || !inPlace(other.presence, place)) {
            send(ws, { type: 'error', message: '对方不在这间客厅' })
            return
          }
        }
        client.lastEmoteAt = now
        if (msg.kind === 'wave') client.presence.pose = 'wave'
        if (msg.kind === 'wake' && targetId) {
          const other = byId.get(targetId)
          if (other?.presence.pose === 'sleep') other.presence.pose = 'wake'
        }
        emitEmote(client, msg.kind, place, targetId)
        return
      }

      if (msg.type === 'friendRequest') {
        const targetId = String(msg.targetId || '')
        if (!targetId) {
          console.log(`[friend] ${client.presence.name} 点了加好友，但没带上对方 id`)
          send(ws, { type: 'error', message: '没选到同学' })
          return
        }
        const result = friends.request(client.presence.clientId, targetId)
        const otherName = byId.get(targetId)?.presence.name || friends.get(targetId)?.name || targetId.slice(0, 8)
        console.log(`[friend] ${client.presence.name} -> ${otherName} (${result})`)
        if (result === 'same') {
          send(ws, { type: 'error', message: '不能加自己' })
          return
        }
        if (result === 'already') {
          send(ws, { type: 'notice', text: '你们已经是好友了' })
          sendFriends(client.presence.clientId)
          return
        }
        notifyFriendLists(client.presence.clientId)
        notifyFriendLists(targetId)
        send(ws, { type: 'notice', text: `已添加 ${otherName}` })
        const other = byId.get(targetId)
        if (other) send(other.ws, { type: 'notice', text: `${client.presence.name} 加你为好友了` })
        return
      }

      if (msg.type === 'friendAccept') {
        const targetId = String(msg.targetId || '')
        if (!friends.accept(client.presence.clientId, targetId)) {
          send(ws, { type: 'error', message: '没有这条申请' })
          return
        }
        send(ws, { type: 'notice', text: '你们成为好友了' })
        const other = byId.get(targetId)
        if (other) send(other.ws, { type: 'notice', text: `${client.presence.name} 同意了好友申请` })
        notifyFriendLists(client.presence.clientId)
        notifyFriendLists(targetId)
        return
      }

      if (msg.type === 'friendDecline') {
        const targetId = String(msg.targetId || '')
        friends.decline(client.presence.clientId, targetId)
        sendFriends(client.presence.clientId)
      }
    })

    ws.on('close', () => drop(ws))
    ws.on('error', () => drop(ws))
  })

  return new Promise((resolve, reject) => {
    httpServer.once('error', reject)
    httpServer.listen(port, '0.0.0.0', () => resolve(httpServer))
  })
}

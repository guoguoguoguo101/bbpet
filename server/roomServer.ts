import { createServer, type Server } from 'node:http'
import { join } from 'node:path'
import { WebSocket, WebSocketServer } from 'ws'
import { DEFAULT_COLORS } from '../shared/types'
import {
  BOARD_LIMIT,
  DIRECTED_EMOTES,
  PLACES,
  POSE_TICK_MS,
  SCHOOL_CROWD_CAP,
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
  clampLook,
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
  type SchoolPlaceId,
  type ServerMsg,
} from '../shared/world'
import { createFriendsStore } from './friendsStore'
import { createGomokuTable } from './gomokuTable'
import { actionStory } from '../shared/homeActions'
import { clampMoveSpeed, roundPose, schoolHasRoom } from '../shared/sync'

interface Client {
  ws: WebSocket
  presence: Presence
  lastChatAt: number
  chatBurst: number
  lastPoseAt: number
  lastEmoteAt: number
  lastDressAt: number
  lastMoveAt: number
}

export function startRoomServer(port: number, options?: { friendsFile?: string }): Promise<Server> {
  const httpServer = createServer((_req, res) => {
    res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' })
    res.end('BbPet school is open\n')
  })
  const wss = new WebSocketServer({ server: httpServer })
  const clients = new Map<WebSocket, Client>()
  const byId = new Map<string, Client>()
  const occupants = new Map<PlaceId, Set<Client>>()
  const dirtyMoves = new Set<Client>()
  const boards = new Map<PlaceId, ChatLine[]>()
  const friends = createFriendsStore(options?.friendsFile || join(process.cwd(), 'bbpet-friends.json'))

  const send = (ws: WebSocket, msg: ServerMsg) => {
    if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg))
  }

  const games = createGomokuTable({
    world: {
      isFriend: (a, b) => friends.isFriend(a, b),
      isOnline: (id) => byId.has(id),
      player: (id) => {
        const client = byId.get(id)
        if (!client) return null
        const p = client.presence
        return { clientId: p.clientId, name: p.name, species: p.species, colors: p.colors }
      },
    },
    sink: {
      sendGame: (id, game) => {
        const client = byId.get(id)
        if (client) send(client.ws, { type: 'gameState', game })
        // Defer so end() can forget() before friend cards read isBusy.
        // Notify once per snapshot (black send) to avoid duplicate fan-out.
        if (id !== game.black.clientId) return
        queueMicrotask(() => {
          notifyFriendLists(game.black.clientId)
          notifyFriendLists(game.white.clientId)
        })
      },
      sendError: (id, message) => {
        const client = byId.get(id)
        if (client) send(client.ws, { type: 'error', message })
      },
      sendNotice: (id, text) => {
        const client = byId.get(id)
        if (client) send(client.ws, { type: 'notice', text })
      },
    },
  })

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
      inGame: games.isBusy(id),
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

  const occupy = (placeId: PlaceId | null | undefined, client: Client) => {
    if (!placeId || placeId === 'away') return
    let set = occupants.get(placeId)
    if (!set) {
      set = new Set()
      occupants.set(placeId, set)
    }
    set.add(client)
  }

  const vacate = (placeId: PlaceId | null | undefined, client: Client) => {
    if (!placeId || placeId === 'away') return
    const set = occupants.get(placeId)
    if (!set) return
    set.delete(client)
    if (!set.size) occupants.delete(placeId)
  }

  const schoolCrowd = () => {
    let count = 0
    for (const id of Object.keys(PLACES) as SchoolPlaceId[]) count += occupants.get(id)?.size ?? 0
    return count
  }

  const peopleIn = (placeId: PlaceId, exceptId?: string) => {
    if (placeId === 'away') return []
    const set = occupants.get(placeId)
    if (!set) return []
    const people: Presence[] = []
    for (const item of set) {
      if (item.presence.clientId !== exceptId) people.push(item.presence)
    }
    return people
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
    const set = occupants.get(placeId)
    if (!set) return
    for (const client of set) {
      if (client.ws !== except) send(client.ws, msg)
    }
  }

  const flushPoses = () => {
    if (!dirtyMoves.size) return
    const batches = new Map<SchoolPlaceId, { id: string; x: number; y: number; facing: 'l' | 'r' }[]>()
    for (const client of dirtyMoves) {
      const school = client.presence.schoolPlaceId
      if (!school) continue
      const items = batches.get(school) ?? []
      items.push({
        id: client.presence.clientId,
        x: client.presence.x,
        y: client.presence.y,
        facing: client.presence.facing,
      })
      batches.set(school, items)
    }
    dirtyMoves.clear()
    const t = Date.now()
    for (const [placeId, items] of batches) {
      if (!items.length) continue
      broadcast(placeId, { type: 'poses', placeId, t, items })
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
    if (isHomePlace(placeId)) {
      const other = targetId ? byId.get(targetId) : undefined
      const line: ChatLine = {
        id: `${emote.id}-story`,
        clientId: client.presence.clientId,
        name: client.presence.name,
        text: sanitizeChat(actionStory(kind, client.presence.name, other?.presence.name)),
        ts: emote.ts,
        kind: 'board',
        placeId,
        action: kind,
      }
      if (line.text) {
        boards.set(placeId, [...boardOf(placeId), line].slice(-BOARD_LIMIT))
        const chat: ServerMsg = { type: 'chat', line }
        send(client.ws, chat)
        broadcast(placeId, chat, client.ws)
      }
    }
    return emote
  }

  const sendHome = (guest: Client, reason: string) => {
    const own = homePlaceId(guest.presence.clientId)
    if (guest.presence.homeId === own) return
    const from = guest.presence.homeId
    broadcast(from, { type: 'leave', clientId: guest.presence.clientId, placeId: from }, guest.ws)
    vacate(from, guest)
    guest.presence.homeId = own
    occupy(own, guest)
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
    dirtyMoves.delete(client)
    games.onDisconnect(client.presence.clientId)
    broadcast(client.presence.homeId, { type: 'leave', clientId: client.presence.clientId, placeId: client.presence.homeId })
    vacate(client.presence.homeId, client)
    if (client.presence.schoolPlaceId) {
      broadcast(client.presence.schoolPlaceId, {
        type: 'leave',
        clientId: client.presence.clientId,
        placeId: client.presence.schoolPlaceId,
      })
      vacate(client.presence.schoolPlaceId, client)
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
          lookX: 0,
          lookY: 0,
          dress: { gear: [], fx: [] },
        }
        friends.upsert(msg.clientId, presence)
        console.log(`[hello] ${presence.name} ${msg.clientId.slice(0, 8)} 上线`)
        const client: Client = { ws, presence, lastChatAt: 0, chatBurst: 0, lastPoseAt: 0, lastEmoteAt: 0, lastDressAt: 0, lastMoveAt: 0 }
        clients.set(ws, client)
        byId.set(msg.clientId, client)
        occupy(homeId, client)
        games.onReconnect(msg.clientId)
        send(ws, {
          type: 'welcome',
          you: presence,
          home: snapshot(homeId, presence.clientId),
          school: null,
          game: games.gameFor(presence.clientId),
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
          vacate(from, client)
          client.presence.homeId = to
          occupy(to, client)
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
          if (!schoolHasRoom(schoolCrowd(), Boolean(client.presence.schoolPlaceId))) {
            send(ws, { type: 'notice', text: `学校已经有 ${SCHOOL_CROWD_CAP} 人了，先等一等` })
            return
          }
          const from = client.presence.schoolPlaceId
          const spawn = spawnAfterEnter(from ?? client.presence.homeId, to)
          if (from) broadcast(from, { type: 'leave', clientId: client.presence.clientId, placeId: from }, ws)
          vacate(from, client)
          client.presence.schoolPlaceId = to
          occupy(to, client)
          client.presence.placeId = to
          const pos = roundPose(spawn.x, spawn.y)
          client.presence.x = pos.x
          client.presence.y = pos.y
          dirtyMoves.delete(client)
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
        const now = Date.now()
        const dt = client.lastMoveAt ? Math.min(250, now - client.lastMoveAt) : POSE_TICK_MS
        const wanted = roundPose(Number(msg.x) || 0, Number(msg.y) || 0)
        const stepped = clampMoveSpeed(client.presence.x, client.presence.y, wanted.x, wanted.y, dt)
        const next = clampMove(place, client.presence.x, client.presence.y, stepped.x, stepped.y)
        const pos = roundPose(next.x, next.y)
        client.presence.x = pos.x
        client.presence.y = pos.y
        client.presence.facing = msg.facing === 'l' ? 'l' : 'r'
        client.lastMoveAt = now
        dirtyMoves.add(client)
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
        const lookX = clampLook(msg.lookX)
        const lookY = clampLook(msg.lookY)
        const same =
          client.presence.pose === msg.pose &&
          (client.presence.lookX || 0) === lookX &&
          (client.presence.lookY || 0) === lookY
        const now = Date.now()
        if (same && now - client.lastPoseAt < 400) return
        client.lastPoseAt = now
        client.presence.pose = msg.pose
        client.presence.lookX = lookX
        client.presence.lookY = lookY
        const payload: ServerMsg = {
          type: 'pose',
          clientId: client.presence.clientId,
          pose: msg.pose,
          lookX,
          lookY,
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
        const dress: PetDress = sanitizeDress(msg.dress)
        const same =
          JSON.stringify(client.presence.dress) === JSON.stringify(dress)
        if (same && now - client.lastDressAt < 400) return
        client.lastDressAt = now
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
        return
      }

      if (msg.type === 'inviteGame') {
        games.invite(client.presence.clientId, String(msg.targetId || ''))
        return
      }
      if (msg.type === 'gameRespond') {
        games.respond(client.presence.clientId, String(msg.gameId || ''), Boolean(msg.accept))
        return
      }
      if (msg.type === 'gameMove') {
        games.move(client.presence.clientId, String(msg.gameId || ''), Number(msg.x), Number(msg.y))
        return
      }
      if (msg.type === 'gameResign') {
        games.resign(client.presence.clientId, String(msg.gameId || ''))
        return
      }
    })

    ws.on('close', () => drop(ws))
    ws.on('error', () => drop(ws))
  })

  const poseTimer = setInterval(flushPoses, POSE_TICK_MS)
  httpServer.on('close', () => clearInterval(poseTimer))

  return new Promise((resolve, reject) => {
    httpServer.once('error', reject)
    httpServer.listen(port, '0.0.0.0', () => resolve(httpServer))
  })
}

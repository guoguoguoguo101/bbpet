import { createServer, type Server } from 'node:http'
import { join } from 'node:path'
import { WebSocket, WebSocketServer } from 'ws'
import { DEFAULT_COLORS } from '../shared/types'
import {
  BOARD_LIMIT,
  PLACES,
  chatKindFor,
  clampMove,
  defaultSpawn,
  homeOwnerId,
  isHomePlace,
  isPlaceId,
  isSchoolPlace,
  sanitizeChat,
  spawnAfterEnter,
  type ChatLine,
  type ClientMsg,
  type FriendCard,
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
      placeId: online?.presence.placeId ?? null,
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
      .filter((item) => item.presence.placeId === placeId && item.presence.clientId !== exceptId)
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
      if (client.presence.placeId === placeId && socket !== except) send(socket, msg)
    }
  }

  const drop = (ws: WebSocket) => {
    const client = clients.get(ws)
    if (!client) return
    clients.delete(ws)
    if (byId.get(client.presence.clientId) === client) byId.delete(client.presence.clientId)
    broadcast(client.presence.placeId, { type: 'leave', clientId: client.presence.clientId })
    notifyFriendLists(client.presence.clientId)
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
        const spawn = defaultSpawn('away')
        const presence: Presence = {
          clientId: msg.clientId,
          name: String(pet.name).slice(0, 12),
          species: pet.species,
          colors: pet.colors,
          placeId: 'away',
          x: spawn.x,
          y: spawn.y,
          facing: 'r',
        }
        friends.upsert(msg.clientId, presence)
        const client: Client = { ws, presence, lastChatAt: 0, chatBurst: 0 }
        clients.set(ws, client)
        byId.set(msg.clientId, client)
        send(ws, { type: 'welcome', you: presence, snapshot: snapshot(presence.placeId, presence.clientId) })
        notifyFriendLists(msg.clientId)
        return
      }

      const client = clients.get(ws)
      if (!client) {
        send(ws, { type: 'error', message: '先打个招呼' })
        return
      }

      if (msg.type === 'enterPlace') {
        if (!isPlaceId(msg.placeId) || msg.placeId === client.presence.placeId) return
        const to = msg.placeId
        if (isHomePlace(to)) {
          const owner = homeOwnerId(to)
          if (owner !== client.presence.clientId && !friends.isFriend(client.presence.clientId, owner || '')) {
            send(ws, { type: 'error', message: '还不是好友，先加好友再串门' })
            return
          }
        }
        const from = client.presence.placeId
        const spawn = spawnAfterEnter(from, to)
        broadcast(from, { type: 'leave', clientId: client.presence.clientId }, ws)
        client.presence.placeId = to
        client.presence.x = spawn.x
        client.presence.y = spawn.y
        send(ws, { type: 'snapshot', you: client.presence, snapshot: snapshot(to, client.presence.clientId) })
        broadcast(to, { type: 'join', person: client.presence }, ws)
        notifyFriendLists(client.presence.clientId)
        if (isHomePlace(to)) {
          const owner = homeOwnerId(to)
          if (owner && owner !== client.presence.clientId) {
            const host = byId.get(owner)
            if (host && host.presence.placeId !== to) {
              send(host.ws, { type: 'notice', text: `${client.presence.name} 来你家了，点枢纽「回家」就能看见` })
            }
          }
        }
        return
      }

      if (msg.type === 'move') {
        if (!isSchoolPlace(client.presence.placeId)) return
        const place = PLACES[client.presence.placeId]
        const next = clampMove(place, client.presence.x, client.presence.y, Number(msg.x) || 0, Number(msg.y) || 0)
        client.presence.x = next.x
        client.presence.y = next.y
        client.presence.facing = msg.facing === 'l' ? 'l' : 'r'
        broadcast(
          client.presence.placeId,
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
        if (client.presence.placeId === 'away') return
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
          kind: chatKindFor(client.presence.placeId),
          placeId: client.presence.placeId,
        }
        if (line.kind === 'board') {
          const board = [...boardOf(line.placeId), line].slice(-BOARD_LIMIT)
          boards.set(line.placeId, board)
        }
        send(ws, { type: 'chat', line })
        broadcast(client.presence.placeId, { type: 'chat', line }, ws)
        return
      }

      if (msg.type === 'friendRequest') {
        const targetId = String(msg.targetId || '')
        const result = friends.request(client.presence.clientId, targetId)
        if (result === 'same') {
          send(ws, { type: 'error', message: '不能加自己' })
          return
        }
        if (result === 'already') {
          send(ws, { type: 'notice', text: '你们已经是好友了' })
          sendFriends(client.presence.clientId)
          return
        }
        if (result === 'accepted') {
          send(ws, { type: 'notice', text: '你们成为好友了' })
          const other = byId.get(targetId)
          if (other) send(other.ws, { type: 'notice', text: `${client.presence.name} 同意了好友申请` })
          notifyFriendLists(client.presence.clientId)
          notifyFriendLists(targetId)
          return
        }
        send(ws, { type: 'notice', text: '好友申请已送出' })
        sendFriends(client.presence.clientId)
        const other = byId.get(targetId)
        if (other) {
          send(other.ws, { type: 'notice', text: `${client.presence.name} 想加你为好友` })
          sendFriends(targetId)
        }
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

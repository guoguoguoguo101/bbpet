import { afterMove, emptyBoard, type Stone } from '../shared/gomoku'
import type { GameEndReason, GamePlayer, GameResult, GameStatus, GameView } from '../shared/world'

export const INVITE_MS = 60_000
export const TURN_MS = 30_000
export const DISCONNECT_MS = 30_000

export interface GomokuClock {
  now(): number
  setTimeout(fn: () => void, ms: number): unknown
  clearTimeout(id: unknown): void
}

export interface GomokuWorld {
  isFriend(a: string, b: string): boolean
  isOnline(id: string): boolean
  player(id: string): GamePlayer | null
}

export interface GomokuSink {
  sendGame(clientId: string, game: GameView): void
  sendError(clientId: string, message: string): void
  sendNotice(clientId: string, text: string): void
}

interface Session {
  id: string
  status: GameStatus
  black: GamePlayer
  white: GamePlayer
  board: Stone[][]
  turn: 1 | 2
  deadlineAt: number
  lastMove: { x: number; y: number } | null
  winLine: { x: number; y: number }[] | null
  result: GameResult | null
  turnTimer: unknown
  inviteTimer: unknown
  disconnectTimers: Map<string, unknown>
}

const realClock: GomokuClock = {
  now: () => Date.now(),
  setTimeout: (fn, ms) => setTimeout(fn, ms),
  clearTimeout: (id) => clearTimeout(id as ReturnType<typeof setTimeout>),
}

export function createGomokuTable(opts: {
  world: GomokuWorld
  sink: GomokuSink
  clock?: GomokuClock
  randomId?: () => string
}) {
  const clock = opts.clock ?? realClock
  const randomId = opts.randomId ?? (() => crypto.randomUUID())
  const sessions = new Map<string, Session>()
  const busy = new Map<string, string>()

  const viewFor = (session: Session, viewerId: string): GameView => ({
    id: session.id,
    status: session.status,
    black: session.black,
    white: session.white,
    board: session.board.map((row) => row.slice()),
    turn: session.turn,
    deadlineAt: session.deadlineAt,
    lastMove: session.lastMove ? { ...session.lastMove } : null,
    winLine: session.winLine ? session.winLine.map((p) => ({ ...p })) : null,
    result: session.result ? { ...session.result } : null,
    you: viewerId === session.black.clientId ? 'black' : 'white',
  })

  const push = (session: Session) => {
    opts.sink.sendGame(session.black.clientId, viewFor(session, session.black.clientId))
    opts.sink.sendGame(session.white.clientId, viewFor(session, session.white.clientId))
  }

  const clearTimers = (session: Session) => {
    if (session.turnTimer) clock.clearTimeout(session.turnTimer)
    if (session.inviteTimer) clock.clearTimeout(session.inviteTimer)
    for (const id of session.disconnectTimers.values()) clock.clearTimeout(id)
    session.turnTimer = null
    session.inviteTimer = null
    session.disconnectTimers.clear()
  }

  const forget = (session: Session) => {
    clearTimers(session)
    sessions.delete(session.id)
    if (busy.get(session.black.clientId) === session.id) busy.delete(session.black.clientId)
    if (busy.get(session.white.clientId) === session.id) busy.delete(session.white.clientId)
  }

  const end = (session: Session, winnerId: string | null, reason: GameEndReason) => {
    if (session.status === 'ended') return
    session.status = 'ended'
    session.result = { winnerId, reason }
    push(session)
    forget(session)
  }

  const armTurn = (session: Session) => {
    if (session.turnTimer) clock.clearTimeout(session.turnTimer)
    session.deadlineAt = clock.now() + TURN_MS
    const turn = session.turn
    const id = session.id
    session.turnTimer = clock.setTimeout(() => {
      const current = sessions.get(id)
      if (!current || current.status !== 'playing' || current.turn !== turn) return
      const loser = current.turn === 1 ? current.black.clientId : current.white.clientId
      const winner = loser === current.black.clientId ? current.white.clientId : current.black.clientId
      end(current, winner, 'timeout')
    }, TURN_MS)
  }

  const find = (clientId: string, gameId: string) => {
    const session = sessions.get(gameId)
    if (!session || (session.black.clientId !== clientId && session.white.clientId !== clientId)) {
      opts.sink.sendError(clientId, '不是你的对局')
      return null
    }
    return session
  }

  const invite = (fromId: string, targetId: string) => {
    if (!targetId || fromId === targetId) {
      opts.sink.sendError(fromId, '不能和自己下')
      return
    }
    if (!opts.world.isFriend(fromId, targetId)) {
      opts.sink.sendError(fromId, '先加好友再下棋')
      return
    }
    if (!opts.world.isOnline(targetId)) {
      opts.sink.sendError(fromId, '对方不在线')
      return
    }
    if (busy.has(fromId) || busy.has(targetId)) {
      opts.sink.sendError(fromId, '已经在下棋了')
      return
    }
    const black = opts.world.player(fromId)
    const white = opts.world.player(targetId)
    if (!black || !white) {
      opts.sink.sendError(fromId, '对方不在线')
      return
    }
    const session: Session = {
      id: randomId(),
      status: 'pending',
      black,
      white,
      board: emptyBoard(),
      turn: 1,
      deadlineAt: clock.now() + INVITE_MS,
      lastMove: null,
      winLine: null,
      result: null,
      turnTimer: null,
      inviteTimer: null,
      disconnectTimers: new Map(),
    }
    sessions.set(session.id, session)
    busy.set(fromId, session.id)
    busy.set(targetId, session.id)
    session.inviteTimer = clock.setTimeout(() => {
      const current = sessions.get(session.id)
      if (!current || current.status !== 'pending') return
      opts.sink.sendNotice(current.black.clientId, '五子棋邀请过期了')
      end(current, null, 'expired')
    }, INVITE_MS)
    push(session)
  }

  const respond = (fromId: string, gameId: string, accept: boolean) => {
    const session = find(fromId, gameId)
    if (!session) return
    if (session.status !== 'pending' || session.white.clientId !== fromId) {
      opts.sink.sendError(fromId, '这步不行')
      return
    }
    if (!accept) {
      opts.sink.sendNotice(session.black.clientId, '对方拒绝了五子棋邀请')
      end(session, null, 'declined')
      return
    }
    if (session.inviteTimer) clock.clearTimeout(session.inviteTimer)
    session.inviteTimer = null
    session.status = 'playing'
    session.board = emptyBoard()
    session.turn = 1
    armTurn(session)
    push(session)
  }

  const move = (fromId: string, gameId: string, x: number, y: number) => {
    const session = find(fromId, gameId)
    if (!session) return
    const stone = session.black.clientId === fromId ? 1 : 2
    if (session.status !== 'playing' || session.turn !== stone) {
      opts.sink.sendError(fromId, '这步不行')
      return
    }
    const result = afterMove(session.board, x, y, stone)
    if (!result.ok) {
      opts.sink.sendError(fromId, '这步不行')
      return
    }
    session.board = result.board
    session.lastMove = { x, y }
    if (result.winLine) {
      session.winLine = result.winLine
      end(session, fromId, 'five')
      return
    }
    if (result.draw) {
      end(session, null, 'draw')
      return
    }
    session.turn = stone === 1 ? 2 : 1
    armTurn(session)
    push(session)
  }

  const resign = (fromId: string, gameId: string) => {
    const session = find(fromId, gameId)
    if (!session) return
    if (session.status !== 'playing') {
      opts.sink.sendError(fromId, '这步不行')
      return
    }
    const winner = fromId === session.black.clientId ? session.white.clientId : session.black.clientId
    end(session, winner, 'resign')
  }

  const onDisconnect = (clientId: string) => {
    const gameId = busy.get(clientId)
    if (!gameId) return
    const session = sessions.get(gameId)
    if (!session) return
    if (session.status === 'pending') {
      opts.sink.sendNotice(session.black.clientId, '五子棋邀请过期了')
      end(session, null, 'expired')
      return
    }
    if (session.status !== 'playing') return
    const existing = session.disconnectTimers.get(clientId)
    if (existing) clock.clearTimeout(existing)
    session.disconnectTimers.set(
      clientId,
      clock.setTimeout(() => {
        const current = sessions.get(session.id)
        if (!current || current.status !== 'playing') return
        const winner = clientId === current.black.clientId ? current.white.clientId : current.black.clientId
        end(current, winner, 'disconnect')
      }, DISCONNECT_MS),
    )
  }

  const onReconnect = (clientId: string) => {
    const gameId = busy.get(clientId)
    if (!gameId) return
    const session = sessions.get(gameId)
    if (!session) return
    const timer = session.disconnectTimers.get(clientId)
    if (timer) clock.clearTimeout(timer)
    session.disconnectTimers.delete(clientId)
  }

  return {
    invite,
    respond,
    move,
    resign,
    onDisconnect,
    onReconnect,
    gameFor: (clientId: string) => {
      const gameId = busy.get(clientId)
      if (!gameId) return null
      const session = sessions.get(gameId)
      return session ? viewFor(session, clientId) : null
    },
    isBusy: (clientId: string) => busy.has(clientId),
  }
}

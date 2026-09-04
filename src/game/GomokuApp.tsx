import { useEffect, useState, type MouseEvent } from 'react'
import type { AppState } from '../../shared/types'
import { emptyRoomView, type GameResult, type GameView, type RoomView } from '../../shared/world'

const CELL = 28
const PAD = 22
const POINTS = 15
const BOARD = PAD * 2 + CELL * 14
const STONE = 22

function myTurn(game: GameView) {
  return (game.you === 'black' && game.turn === 1) || (game.you === 'white' && game.turn === 2)
}

function resultCopy(result: GameResult, clientId: string) {
  const mine = result.winnerId === clientId
  if (result.reason === 'five') return mine ? '五连胜' : '对方五连'
  if (result.reason === 'draw') return '满盘平局'
  if (result.reason === 'resign') return mine ? '对方认输' : '你认输了'
  if (result.reason === 'timeout') return mine ? '对方超时' : '你超时了'
  if (result.reason === 'disconnect') return mine ? '对方断线' : '你断线了'
  return ''
}

export function GomokuApp() {
  const [state, setState] = useState<AppState | null>(null)
  const [room, setRoom] = useState<RoomView>(emptyRoomView())
  const [now, setNow] = useState(() => Date.now())
  const game = room.game

  useEffect(() => {
    document.documentElement.classList.add('game-host')
    document.body.classList.add('game-host')
    return () => {
      document.documentElement.classList.remove('game-host')
      document.body.classList.remove('game-host')
    }
  }, [])

  useEffect(() => {
    void window.bbpet.getState().then(setState)
    void window.bbpet.roomState().then(setRoom)
    const offState = window.bbpet.onStateChanged(setState)
    const offRoom = window.bbpet.onRoomState(setRoom)
    return () => {
      offState()
      offRoom()
    }
  }, [])

  useEffect(() => {
    if (game?.status !== 'playing') return
    const id = window.setInterval(() => setNow(Date.now()), 200)
    return () => window.clearInterval(id)
  }, [game?.id, game?.status])

  const seconds = game ? Math.max(0, Math.ceil((game.deadlineAt - now) / 1000)) : 0
  const canMove = Boolean(game && game.status === 'playing' && myTurn(game) && seconds > 0)
  const waitingConfirm = Boolean(game && game.status === 'playing' && seconds === 0)

  const onBoardClick = (event: MouseEvent<HTMLDivElement>) => {
    if (!game || !canMove) return
    const x = Math.round((event.nativeEvent.offsetX - PAD) / CELL)
    const y = Math.round((event.nativeEvent.offsetY - PAD) / CELL)
    if (x < 0 || y < 0 || x >= POINTS || y >= POINTS) return
    window.bbpet.roomSend({ type: 'gameMove', gameId: game.id, x, y })
  }

  const resign = () => {
    if (!game || game.status !== 'playing') return
    window.bbpet.roomSend({ type: 'gameResign', gameId: game.id })
  }

  const opponent = game ? (game.you === 'black' ? game.white.name : game.black.name) : ''
  const winCells = new Set((game?.winLine ?? []).map((p) => `${p.x},${p.y}`))

  return (
    <div className="game-root">
      <header className="game-bar">
        {game ? (
          <>
            <strong>{opponent}</strong>
            <span>{game.you === 'black' ? '你执黑' : '你执白'}</span>
            {game.status === 'playing' && <span>{myTurn(game) ? '轮到你' : '等待对方'}</span>}
            {game.status === 'playing' && !waitingConfirm && <span>{seconds}s</span>}
            {waitingConfirm && <span>等待校长确认...</span>}
            {game.status === 'ended' && game.result && state && <span>{resultCopy(game.result, state.clientId)}</span>}
            <div className="game-bar-actions">
              {game.status === 'playing' ? (
                <button type="button" className="ghost" onClick={resign}>
                  认输
                </button>
              ) : (
                <button type="button" className="ghost" onClick={() => window.bbpet.closeGame()}>
                  关闭
                </button>
              )}
            </div>
          </>
        ) : (
          <>
            <strong>对局已中断</strong>
            <div className="game-bar-actions">
              <button type="button" className="ghost" onClick={() => window.bbpet.closeGame()}>
                关闭
              </button>
            </div>
          </>
        )}
      </header>
      {!game ? (
        <div className="game-empty">
          <p>对局已中断</p>
          <button type="button" className="ghost" onClick={() => window.bbpet.closeGame()}>
            关闭
          </button>
        </div>
      ) : (
        <>
          <div
            className="game-board"
            style={{ width: BOARD, height: BOARD, cursor: canMove ? 'pointer' : 'default' }}
            onClick={onBoardClick}
          >
            <svg className="game-lines" width={BOARD} height={BOARD} aria-hidden>
              {Array.from({ length: POINTS }, (_, i) => {
                const p = PAD + i * CELL
                const end = PAD + CELL * 14
                return (
                  <g key={i}>
                    <line x1={PAD} y1={p} x2={end} y2={p} stroke="#3d2c29" strokeWidth="1" />
                    <line x1={p} y1={PAD} x2={p} y2={end} stroke="#3d2c29" strokeWidth="1" />
                  </g>
                )
              })}
            </svg>
            {game.board.flatMap((row, y) =>
              row.map((stone, x) => {
                if (!stone) return null
                const last = game.lastMove && game.lastMove.x === x && game.lastMove.y === y
                const win = winCells.has(`${x},${y}`)
                return (
                  <span
                    key={`${x},${y}`}
                    className={['game-stone', stone === 1 ? 'black' : 'white', last && 'last', win && 'win']
                      .filter(Boolean)
                      .join(' ')}
                    style={{ left: PAD + x * CELL, top: PAD + y * CELL, width: STONE, height: STONE }}
                  />
                )
              }),
            )}
          </div>
          {game.status === 'playing' && <p className="game-hint">关闭窗口 = 认输</p>}
          {game.status === 'ended' && game.result && state && (
            <p className="game-hint">{resultCopy(game.result, state.clientId)}</p>
          )}
        </>
      )}
    </div>
  )
}

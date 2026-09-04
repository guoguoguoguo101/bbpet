export const SIZE = 15
export type Stone = 0 | 1 | 2
export type Point = { x: number; y: number }
export type PlaceFail = 'oob' | 'occupied'

export function emptyBoard(): Stone[][] {
  return Array.from({ length: SIZE }, () => Array<Stone>(SIZE).fill(0))
}

export function inBounds(x: number, y: number) {
  return Number.isInteger(x) && Number.isInteger(y) && x >= 0 && x < SIZE && y >= 0 && y < SIZE
}

export function place(
  board: Stone[][],
  x: number,
  y: number,
  stone: 1 | 2,
): { ok: true; board: Stone[][] } | { ok: false; reason: PlaceFail } {
  if (!inBounds(x, y)) return { ok: false, reason: 'oob' }
  if (board[y][x] !== 0) return { ok: false, reason: 'occupied' }
  const next = board.map((row) => row.slice())
  next[y][x] = stone
  return { ok: true, board: next }
}

const DIRS: Point[] = [
  { x: 1, y: 0 },
  { x: 0, y: 1 },
  { x: 1, y: 1 },
  { x: 1, y: -1 },
]

function ray(board: Stone[][], x: number, y: number, dx: number, dy: number): Point[] {
  const stone = board[y][x]
  const out: Point[] = []
  let cx = x + dx
  let cy = y + dy
  while (inBounds(cx, cy) && board[cy][cx] === stone) {
    out.push({ x: cx, y: cy })
    cx += dx
    cy += dy
  }
  return out
}

export function winLineAt(board: Stone[][], x: number, y: number): Point[] | null {
  if (!inBounds(x, y) || board[y][x] === 0) return null
  for (const dir of DIRS) {
    const fwd = ray(board, x, y, dir.x, dir.y)
    const back = ray(board, x, y, -dir.x, -dir.y)
    const line = [...back.reverse(), { x, y }, ...fwd]
    if (line.length >= 5) return line
  }
  return null
}

export function isFull(board: Stone[][]) {
  for (const row of board) {
    for (const cell of row) if (cell === 0) return false
  }
  return true
}

export function afterMove(board: Stone[][], x: number, y: number, stone: 1 | 2) {
  const placed = place(board, x, y, stone)
  if (!placed.ok) return placed
  const line = winLineAt(placed.board, x, y)
  return {
    ok: true as const,
    board: placed.board,
    winLine: line,
    draw: !line && isFull(placed.board),
  }
}

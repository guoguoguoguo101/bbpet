import { useEffect, useMemo, useRef } from 'react'
import type { PetColors, PetPose, Species } from '../../shared/types'
import { getFrame, type PixelCode } from './templates'

const ROLE_KEY: Record<Exclude<PixelCode, '.'>, keyof PetColors> = {
  '#': 'outline',
  B: 'body',
  D: 'shadow',
  L: 'light',
  A: 'accent',
  E: 'eye',
  P: 'pupil',
  C: 'blush',
}

const GEAR_FILL: Record<string, string> = {
  G: '#111111',
  R: '#e21830',
  H: '#ff4d3a',
  T: '#fff4d6',
}

function paintCell(grid: string[][], x: number, y: number, code: string) {
  if (!grid[y] || x < 0 || x > 15 || y < 0 || y > 15) return
  grid[y][x] = code
}

interface PixelPetProps {
  species: Species
  colors: PetColors
  pose: PetPose
  pixelSize?: number
  flip?: boolean
  lookX?: number
  lookY?: number
  gears?: string[]
}

function shiftPupils(frame: string[], dx: number, dy: number) {
  if (!dx && !dy) return frame
  const grid = frame.map((row) => row.split(''))
  const pupils: Array<[number, number]> = []
  grid.forEach((row, y) => {
    row.forEach((cell, x) => {
      if (cell === 'P') pupils.push([x, y])
    })
  })
  for (const [x, y] of pupils) grid[y][x] = 'E'
  for (const [x, y] of pupils) {
    const nx = Math.min(15, Math.max(0, x + dx))
    const ny = Math.min(15, Math.max(0, y + dy))
    const target = grid[ny]?.[nx]
    if (target === 'E' || target === 'P' || target === 'B' || target === 'L') grid[ny][nx] = 'P'
    else grid[y][x] = 'P'
  }
  return grid.map((row) => row.join(''))
}

function applyGear(frame: string[], gears: string[]) {
  if (!gears.length) return frame
  const grid = frame.map((row) => row.split(''))

  if (gears.includes('shades')) {
    const eyes: Array<[number, number]> = []
    grid.forEach((row, y) => {
      row.forEach((cell, x) => {
        if (cell === 'E' || cell === 'P') eyes.push([x, y])
      })
    })
    for (const [ex, ey] of eyes) {
      for (let y = ey - 1; y <= ey + 1; y++) {
        for (let x = ex - 1; x <= ex + 1; x++) {
          paintCell(grid, x, y, 'G')
        }
      }
    }
    if (eyes.length) {
      const xs = eyes.map(([x]) => x)
      const ys = eyes.map(([, y]) => y)
      const minX = Math.min(...xs)
      const maxX = Math.max(...xs)
      const midY = Math.round((Math.min(...ys) + Math.max(...ys)) / 2)
      for (let x = minX; x <= maxX; x++) paintCell(grid, x, midY, 'G')
      for (let x = minX - 1; x <= maxX + 1; x++) {
        paintCell(grid, x, Math.min(...ys) - 1, 'G')
      }
    }
  }

  if (gears.includes('beanie')) {
    for (let x = 2; x <= 13; x++) {
      paintCell(grid, x, 1, 'H')
      paintCell(grid, x, 2, 'H')
    }
    for (let x = 4; x <= 11; x++) paintCell(grid, x, 0, 'H')
    paintCell(grid, 6, 0, 'T')
    paintCell(grid, 7, 0, 'T')
    paintCell(grid, 8, 0, 'T')
    paintCell(grid, 9, 0, 'T')
  }

  if (gears.includes('scarf')) {
    for (let y = 8; y <= 10; y++) {
      for (let x = 2; x <= 13; x++) {
        const cell = grid[y]?.[x]
        if (!cell || cell === '.') continue
        if (y === 8 && x > 5 && x < 10) continue
        paintCell(grid, x, y, 'R')
      }
    }
    for (let y = 9; y <= 10; y++) {
      for (let x = 3; x <= 12; x++) {
        if (grid[y]?.[x] && grid[y][x] !== '.') paintCell(grid, x, y, 'R')
      }
    }
    for (let y = 10; y <= 14; y++) {
      paintCell(grid, 12, y, 'R')
      paintCell(grid, 13, y, 'R')
    }
    paintCell(grid, 11, 13, 'R')
    paintCell(grid, 11, 14, 'R')
  }

  return grid.map((row) => row.join(''))
}

export function PixelPet({
  species,
  colors,
  pose,
  pixelSize = 4,
  flip = false,
  lookX = 0,
  lookY = 0,
  gears = [],
}: PixelPetProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const frame = useMemo(() => {
    const geared = applyGear(getFrame(species, pose), gears)
    if (pose === 'sleep') return geared
    return shiftPupils(geared, lookX, lookY)
  }, [species, pose, lookX, lookY, gears])
  const width = 16 * pixelSize
  const height = 16 * pixelSize

  useEffect(() => {
    const canvas = canvasRef.current
    const ctx = canvas?.getContext('2d', { alpha: true, willReadFrequently: true })
    if (!canvas || !ctx) return
    ctx.imageSmoothingEnabled = false
    ctx.clearRect(0, 0, width, height)
    ctx.globalCompositeOperation = 'source-over'
    frame.forEach((row, y) => {
      ;[...row].forEach((cell, x) => {
        if (cell === '.') return
        if (GEAR_FILL[cell]) {
          ctx.fillStyle = GEAR_FILL[cell]
          ctx.fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize)
          return
        }
        const role = ROLE_KEY[cell as Exclude<PixelCode, '.'>]
        let fill = colors[role] ?? colors.body
        if (gears.includes('raincoat') && (role === 'body' || role === 'light' || role === 'shadow')) {
          fill = role === 'light' ? '#FFF3B0' : role === 'shadow' ? '#C47B17' : '#F4D35E'
        }
        ctx.fillStyle = fill
        ctx.fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize)
      })
    })
  }, [colors, frame, gears, height, pixelSize, width])

  return (
    <canvas
      ref={canvasRef}
      className={`pixel-pet${flip ? ' flip' : ''}`}
      data-species={species}
      width={width}
      height={height}
    />
  )
}

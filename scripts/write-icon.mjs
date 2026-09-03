import { deflateSync } from 'node:zlib'
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, '..')

function crc32(buf) {
  let c = ~0
  for (const byte of buf) {
    c ^= byte
    for (let i = 0; i < 8; i++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1))
  }
  return ~c >>> 0
}

function chunk(type, data) {
  const len = Buffer.alloc(4)
  len.writeUInt32BE(data.length)
  const td = Buffer.concat([Buffer.from(type), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(td))
  return Buffer.concat([len, td, crc])
}

function encodePng(width, height, rgba) {
  const raw = Buffer.alloc((width * 4 + 1) * height)
  for (let y = 0; y < height; y++) {
    raw[(width * 4 + 1) * y] = 0
    rgba.copy(raw, (width * 4 + 1) * y + 1, y * width * 4, (y + 1) * width * 4)
  }
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(width, 0)
  ihdr.writeUInt32BE(height, 4)
  ihdr[8] = 8
  ihdr[9] = 6
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

const GRID = [
  '................',
  '....######......',
  '...#BBBBBB#.....',
  '..#BBBBBBBB#....',
  '.#BBBBBBBBBB#...',
  '.#BEEBBBBEEB#...',
  '.#BEPBBBBPEB#...',
  '.#BBBBBBBBBB#...',
  '.#BBCBAAABCB#...',
  '.#BBB....BBB#...',
  '.#BBLLLLLLBB#...',
  '..#DBLLLLBD#....',
  '...#BBBBBB#.....',
  '....#D##D#......',
  '................',
  '................',
]

const PALETTE = {
  '.': [0, 0, 0, 0],
  '#': [61, 44, 41, 255],
  B: [255, 194, 212, 255],
  D: [244, 154, 179, 255],
  L: [255, 230, 240, 255],
  A: [255, 143, 171, 255],
  E: [255, 248, 240, 255],
  P: [43, 33, 30, 255],
  C: [255, 158, 187, 255],
}

function drawGrid(scale) {
  const size = 16 * scale
  const rgba = Buffer.alloc(size * size * 4)
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const color = PALETTE[GRID[y][x]] ?? PALETTE['.']
      for (let dy = 0; dy < scale; dy++) {
        for (let dx = 0; dx < scale; dx++) {
          const i = ((y * scale + dy) * size + (x * scale + dx)) * 4
          rgba[i] = color[0]
          rgba[i + 1] = color[1]
          rgba[i + 2] = color[2]
          rgba[i + 3] = color[3]
        }
      }
    }
  }
  return { size, rgba }
}

function padToSquare(rgba, src, dest, fill = [255, 230, 240, 255]) {
  const out = Buffer.alloc(dest * dest * 4)
  const offset = Math.floor((dest - src) / 2)
  for (let y = 0; y < dest; y++) {
    for (let x = 0; x < dest; x++) {
      const i = (y * dest + x) * 4
      const inside = x >= offset && x < offset + src && y >= offset && y < offset + src
      if (inside) {
        const s = ((y - offset) * src + (x - offset)) * 4
        out[i] = rgba[s]
        out[i + 1] = rgba[s + 1]
        out[i + 2] = rgba[s + 2]
        out[i + 3] = rgba[s + 3]
      } else {
        out[i] = fill[0]
        out[i + 1] = fill[1]
        out[i + 2] = fill[2]
        out[i + 3] = fill[3]
      }
    }
  }
  return out
}

mkdirSync(join(root, 'build'), { recursive: true })
const big = drawGrid(14)
writeFileSync(join(root, 'build', 'icon.png'), encodePng(256, 256, padToSquare(big.rgba, big.size, 256)))
const tray = drawGrid(2)
writeFileSync(join(root, 'build', 'tray.png'), encodePng(tray.size, tray.size, tray.rgba))
console.log('wrote build/icon.png and build/tray.png')

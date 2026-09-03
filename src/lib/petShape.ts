import type { Species } from '../../shared/types'
import { getFrame } from '../pet/templates'

export interface ShapeRect {
  x: number
  y: number
  w: number
  h: number
}

const POSES: Array<'idle' | 'blink' | 'talk'> = ['idle', 'blink', 'talk']

export function solidRectsFromPet(species: Species, pixelSize: number, originX: number, originY: number): ShapeRect[] {
  const grid = Array.from({ length: 16 }, () => Array.from({ length: 16 }, () => false))
  for (const pose of POSES) {
    getFrame(species, pose).forEach((row, y) => {
      ;[...row].forEach((cell, x) => {
        if (cell !== '.') grid[y][x] = true
      })
    })
  }

  const rects: ShapeRect[] = []
  for (let y = 0; y < 16; y++) {
    let x = 0
    while (x < 16) {
      if (!grid[y][x]) {
        x += 1
        continue
      }
      let x2 = x + 1
      while (x2 < 16 && grid[y][x2]) x2 += 1
      rects.push({
        x: Math.round(originX + x * pixelSize),
        y: Math.round(originY + y * pixelSize),
        w: (x2 - x) * pixelSize,
        h: pixelSize,
      })
      x = x2
    }
  }
  return rects
}

function boxRect(node: HTMLElement): ShapeRect {
  const box = node.getBoundingClientRect()
  return {
    x: Math.floor(box.left),
    y: Math.floor(box.top),
    w: Math.max(1, Math.ceil(box.width)),
    h: Math.max(1, Math.ceil(box.height)),
  }
}

export function collectPetShape(root: HTMLElement, fallbackSpecies: Species, pixelSize = 5): ShapeRect[] {
  const rects: ShapeRect[] = []
  for (const canvas of root.querySelectorAll<HTMLCanvasElement>('canvas.pixel-pet')) {
    const species = (canvas.dataset.species as Species) || fallbackSpecies
    const box = canvas.getBoundingClientRect()
    rects.push(...solidRectsFromPet(species, pixelSize, box.left, box.top))
  }
  for (const node of root.querySelectorAll<HTMLElement>('.name-plate, .gather-ui, .gather-bubble')) {
    rects.push(boxRect(node))
  }
  return rects.filter((rect) => rect.w > 0 && rect.h > 0)
}

import { useEffect, useRef } from 'react'
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

interface PixelPetProps {
  species: Species
  colors: PetColors
  pose: PetPose
  pixelSize?: number
  flip?: boolean
}

export function PixelPet({ species, colors, pose, pixelSize = 5, flip = false }: PixelPetProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const frame = getFrame(species, pose)
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
      [...row].forEach((cell, x) => {
        if (cell === '.') return
        const role = ROLE_KEY[cell as Exclude<PixelCode, '.'>]
        ctx.fillStyle = colors[role] ?? colors.body
        ctx.fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize)
      })
    })
  }, [colors, frame, height, pixelSize, width])

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

import { DEFAULT_COLORS, type PetColors, type Species } from '../../shared/types'

function clamp(value: number) {
  return Math.max(0, Math.min(255, Math.round(value)))
}

function hexToRgb(hex: string) {
  const raw = hex.replace('#', '')
  return {
    r: parseInt(raw.slice(0, 2), 16),
    g: parseInt(raw.slice(2, 4), 16),
    b: parseInt(raw.slice(4, 6), 16),
  }
}

function rgbToHex(r: number, g: number, b: number) {
  return `#${[r, g, b].map((value) => clamp(value).toString(16).padStart(2, '0')).join('')}`
}

function mix(hex: string, toward: string, amount: number) {
  const a = hexToRgb(hex)
  const b = hexToRgb(toward)
  return rgbToHex(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount)
}

function luminance(hex: string) {
  const { r, g, b } = hexToRgb(hex)
  return (r * 299 + g * 587 + b * 114) / 1000
}

export function paletteFromPrimary(primary: string, accent?: string, species: Species = 'blob'): PetColors {
  const fallback = DEFAULT_COLORS[species]
  const body = primary || fallback.body
  return {
    outline: mix(body, '#1A1210', 0.62),
    body,
    shadow: mix(body, '#2A1814', 0.28),
    light: mix(body, '#FFF8F2', 0.45),
    accent: accent || mix(body, '#E76F51', 0.35),
    eye: '#FFF8F0',
    pupil: '#2B211E',
    blush: mix(body, '#FF8FAB', 0.4),
  }
}

export async function extractPalette(file: File, species: Species): Promise<PetColors> {
  const source = await createImageBitmap(file)
  const canvas = document.createElement('canvas')
  const size = 48
  canvas.width = size
  canvas.height = size
  const ctx = canvas.getContext('2d')
  if (!ctx) return DEFAULT_COLORS[species]
  ctx.drawImage(source, 0, 0, size, size)
  const { data } = ctx.getImageData(0, 0, size, size)

  const buckets = new Map<string, { count: number; r: number; g: number; b: number }>()
  for (let i = 0; i < data.length; i += 4) {
    const a = data[i + 3]
    if (a < 140) continue
    const r = data[i]
    const g = data[i + 1]
    const b = data[i + 2]
    const max = Math.max(r, g, b)
    const min = Math.min(r, g, b)
    if (max < 40 || min > 230) continue
    if (max - min < 18 && max > 180) continue
    const key = `${Math.round(r / 24)}-${Math.round(g / 24)}-${Math.round(b / 24)}`
    const current = buckets.get(key) ?? { count: 0, r: 0, g: 0, b: 0 }
    current.count += 1
    current.r += r
    current.g += g
    current.b += b
    buckets.set(key, current)
  }

  const ranked = [...buckets.values()].sort((a, b) => b.count - a.count)
  if (ranked.length === 0) return DEFAULT_COLORS[species]
  const main = ranked[0]
  const primary = rgbToHex(main.r / main.count, main.g / main.count, main.b / main.count)
  const second = ranked.find((item) => {
    const hex = rgbToHex(item.r / item.count, item.g / item.count, item.b / item.count)
    return Math.abs(luminance(hex) - luminance(primary)) > 28
  })
  const accent = second
    ? rgbToHex(second.r / second.count, second.g / second.count, second.b / second.count)
    : undefined
  return paletteFromPrimary(primary, accent, species)
}

export async function fileToDataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(file)
  })
}

const silhouetteCache = new WeakMap<HTMLCanvasElement, { inside: Uint8Array; width: number; height: number }>()

function canvasPixelAt(canvas: HTMLCanvasElement, clientX: number, clientY: number) {
  const rect = canvas.getBoundingClientRect()
  if (clientX < rect.left || clientX >= rect.right || clientY < rect.top || clientY >= rect.bottom) {
    return null
  }
  const ctx = canvas.getContext('2d', { willReadFrequently: true })
  if (!ctx) return null
  const x = Math.floor((clientX - rect.left) * (canvas.width / rect.width))
  const y = Math.floor((clientY - rect.top) * (canvas.height / rect.height))
  if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height) return null
  return { ctx, x, y, width: canvas.width, height: canvas.height }
}

function buildInsideMask(data: Uint8ClampedArray, width: number, height: number) {
  const opaque = (px: number, py: number) => data[(py * width + px) * 4 + 3] > 16
  const outside = new Uint8Array(width * height)
  const stack: number[] = []
  const visit = (px: number, py: number) => {
    if (px < 0 || py < 0 || px >= width || py >= height) return
    const i = py * width + px
    if (outside[i] || opaque(px, py)) return
    outside[i] = 1
    stack.push(i)
  }
  for (let px = 0; px < width; px += 1) {
    visit(px, 0)
    visit(px, height - 1)
  }
  for (let py = 0; py < height; py += 1) {
    visit(0, py)
    visit(width - 1, py)
  }
  while (stack.length) {
    const i = stack.pop()!
    const px = i % width
    const py = (i / width) | 0
    visit(px - 1, py)
    visit(px + 1, py)
    visit(px, py - 1)
    visit(px, py + 1)
  }
  const inside = new Uint8Array(width * height)
  for (let i = 0; i < inside.length; i += 1) inside[i] = outside[i] ? 0 : 1
  return inside
}

function isInsidePetSilhouette(canvas: HTMLCanvasElement, clientX: number, clientY: number) {
  const at = canvasPixelAt(canvas, clientX, clientY)
  if (!at) return false
  const { ctx, x, y, width, height } = at
  const data = ctx.getImageData(0, 0, width, height).data
  let painted = false
  for (let i = 3; i < data.length; i += 4) {
    if (data[i] > 16) {
      painted = true
      break
    }
  }
  let mask = silhouetteCache.get(canvas)
  if (painted) {
    mask = { inside: buildInsideMask(data, width, height), width, height }
    silhouetteCache.set(canvas, mask)
  } else if (!mask || mask.width !== width || mask.height !== height) {
    return false
  }
  return mask.inside[y * width + x] === 1
}

export function isPetSolid(clientX: number, clientY: number) {
  const stack = document.elementsFromPoint(clientX, clientY)
  for (const node of stack) {
    if (!(node instanceof HTMLElement)) continue
    if (node.closest('.panel, .context-menu, .name-plate, .bubble-link, button, input, select, label, .gather-ui, .gather-dock, .gather-react, .gather-slot, .gather-bar, .gather-log, .offer-stack, .offer-card')) return true
    if (node instanceof HTMLCanvasElement && node.classList.contains('pixel-pet')) {
      return isInsidePetSilhouette(node, clientX, clientY)
    }
  }
  return false
}

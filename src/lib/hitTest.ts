function canvasAlphaAt(canvas: HTMLCanvasElement, clientX: number, clientY: number) {
  const rect = canvas.getBoundingClientRect()
  if (clientX < rect.left || clientX >= rect.right || clientY < rect.top || clientY >= rect.bottom) {
    return 0
  }
  const ctx = canvas.getContext('2d', { willReadFrequently: true })
  if (!ctx) return 0
  const x = Math.floor((clientX - rect.left) * (canvas.width / rect.width))
  const y = Math.floor((clientY - rect.top) * (canvas.height / rect.height))
  if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height) return 0
  return ctx.getImageData(x, y, 1, 1).data[3]
}

export function isPetSolid(clientX: number, clientY: number) {
  const stack = document.elementsFromPoint(clientX, clientY)
  for (const node of stack) {
    if (!(node instanceof HTMLElement)) continue
    if (node.closest('.panel, .context-menu, .name-plate, .bubble-link, button, input, select, label, .gather-ui, .gather-dock, .gather-react, .gather-slot, .gather-bar, .gather-log')) return true
    if (node instanceof HTMLCanvasElement && node.classList.contains('pixel-pet')) {
      return canvasAlphaAt(node, clientX, clientY) > 16
    }
  }
  return false
}

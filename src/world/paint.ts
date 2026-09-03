import {
  TILE,
  mapSize,
  tileAccent,
  tileColor,
  type PlaceDef,
} from '../../shared/world'

export function drawPlace(ctx: CanvasRenderingContext2D, place: PlaceDef) {
  const { cols, rows } = mapSize(place)
  ctx.imageSmoothingEnabled = false
  for (let ty = 0; ty < rows; ty += 1) {
    for (let tx = 0; tx < cols; tx += 1) {
      const code = place.tiles[ty][tx]
      const x = tx * TILE
      const y = ty * TILE
      ctx.fillStyle = tileColor(code, place.kind)
      ctx.fillRect(x, y, TILE, TILE)
      ctx.strokeStyle = tileAccent(code)
      ctx.lineWidth = 2
      ctx.strokeRect(x + 1, y + 1, TILE - 2, TILE - 2)
      if (place.kind === 'campus' && code === 'f' && ty === 2) {
        ctx.fillStyle = '#8ecae6'
        ctx.fillRect(x + 8, y + 8, TILE - 16, TILE - 16)
        ctx.strokeStyle = '#3d2c29'
        ctx.strokeRect(x + 8, y + 8, TILE - 16, TILE - 16)
      }
    }
  }
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.font = '12px "Microsoft YaHei", sans-serif'
  for (const label of place.labels) {
    const x = label.tx * TILE + TILE / 2
    const y = label.ty * TILE + TILE / 2
    const width = label.text.length > 2 ? 52 : 40
    ctx.fillStyle = '#3d2c29'
    ctx.fillRect(x - width / 2, y - 9, width, 18)
    ctx.fillStyle = '#fff8f2'
    ctx.fillText(label.text, x, y + 1)
  }
  if (place.kind === 'campus') {
    ctx.fillStyle = '#3d2c29'
    ctx.fillRect(cols * TILE / 2 - 70, 13 * TILE + 4, 140, 22)
    ctx.fillStyle = '#c8f5e4'
    ctx.fillText('校门口 · 往上走进教室', cols * TILE / 2, 13 * TILE + 16)
  }
}

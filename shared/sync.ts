import { MOVE_SPEED, POSE_TICK_MS, SCHOOL_CROWD_CAP, type Facing, type PoseItem, type Presence } from './world'

export function roundPose(x: number, y: number) {
  return { x: Math.round(x * 10) / 10, y: Math.round(y * 10) / 10 }
}

export function schoolHasRoom(count: number, alreadyInside: boolean, cap = SCHOOL_CROWD_CAP) {
  return alreadyInside || count < cap
}

export function clampMoveSpeed(fromX: number, fromY: number, toX: number, toY: number, dtMs: number) {
  const slack = 18
  const max = MOVE_SPEED * (Math.max(16, dtMs) / 1000) + slack
  const dx = toX - fromX
  const dy = toY - fromY
  const dist = Math.hypot(dx, dy)
  if (dist <= max || dist === 0) return { x: toX, y: toY, clipped: false }
  const scale = max / dist
  return { x: fromX + dx * scale, y: fromY + dy * scale, clipped: true }
}

export function applyPoseItems(people: Presence[], items: PoseItem[], selfId: string) {
  if (!items.length) return people
  const byId = new Map<string, PoseItem>()
  for (const item of items) {
    if (item.id !== selfId) byId.set(item.id, item)
  }
  if (!byId.size) return people
  let changed = false
  const next = people.map((person) => {
    const item = byId.get(person.clientId)
    if (!item) return person
    if (person.x === item.x && person.y === item.y && person.facing === item.facing) return person
    changed = true
    return { ...person, x: item.x, y: item.y, facing: item.facing }
  })
  return changed ? next : people
}

export function keepVisualPeople(prev: Presence[], incoming: Presence[]) {
  if (!prev.length) return incoming
  const prevBy = new Map(prev.map((person) => [person.clientId, person]))
  return incoming.map((person) => {
    const old = prevBy.get(person.clientId)
    if (!old) return person
    return { ...person, x: old.x, y: old.y, facing: old.facing }
  })
}

export function interpolatePose(
  fromX: number,
  fromY: number,
  toX: number,
  toY: number,
  fromAt: number,
  now: number,
  dur = POSE_TICK_MS + 40,
) {
  const t = dur <= 0 ? 1 : Math.min(1, Math.max(0, (now - fromAt) / dur))
  return {
    x: fromX + (toX - fromX) * t,
    y: fromY + (toY - fromY) * t,
    t,
  }
}

export function poseFacing(from: Facing, to: Facing, t: number): Facing {
  return t >= 0.35 ? to : from
}

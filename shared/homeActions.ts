import type { PetColors, PetPose, Species } from './types'
import type { EmoteKind, HomeEmote } from './world'

export const SLOT_W = 72
export const SLOT_H = 108
export const YARD_PAD_X = 24
export const YARD_PAD_TOP = 40
export const MENU_RESERVE = 80
export const BAR_H = 32
export const LOG_H = 76
export const MAX_COLS = 4
export const FLYER_SIZE = 96
export const FLYER_OUT = 220
export const FLYER_LIFT = 48

export interface FlyerPlay {
  id: string
  species: Species
  colors: PetColors
  gears?: string[]
  pose?: PetPose
  slotX: number
  slotY: number
  dir: 1 | -1
  duration: number
}

export interface WorkArea {
  x: number
  y: number
  width: number
  height: number
}

export interface ActionSpec {
  duration: number
  liftAt: number
  landAt: number
  flyer: boolean
  actorPose: PetPose
  targetPose: PetPose
  actorLabel: string
  targetLabel: string
}

export const HOME_ACTIONS: Record<EmoteKind, ActionSpec> = {
  wave: {
    duration: 1600,
    liftAt: 0,
    landAt: 1600,
    flyer: false,
    actorPose: 'wave',
    targetPose: 'wave',
    actorLabel: '挥手',
    targetLabel: '挥手',
  },
  hug: {
    duration: 1800,
    liftAt: 0,
    landAt: 1800,
    flyer: false,
    actorPose: 'talk',
    targetPose: 'talk',
    actorLabel: '抱抱',
    targetLabel: '抱抱',
  },
  pour: {
    duration: 1800,
    liftAt: 0,
    landAt: 1800,
    flyer: false,
    actorPose: 'drink',
    targetPose: 'drink',
    actorLabel: '倒水',
    targetLabel: '咕嘟',
  },
  wake: {
    duration: 1800,
    liftAt: 0,
    landAt: 1800,
    flyer: false,
    actorPose: 'wave',
    targetPose: 'wake',
    actorLabel: '拍醒',
    targetLabel: '伸懒腰',
  },
  kick: {
    duration: 2800,
    liftAt: 280,
    landAt: 2520,
    flyer: true,
    actorPose: 'wake',
    targetPose: 'peek',
    actorLabel: '飞踢',
    targetLabel: '转圈飞走',
  },
}

export function actionSpec(kind: EmoteKind): ActionSpec {
  return HOME_ACTIONS[kind]
}

export function roleInAction(emote: HomeEmote | null, clientId: string): 'from' | 'to' | '' {
  if (!emote) return ''
  if (emote.fromId === clientId) return 'from'
  if (emote.targetId === clientId) return 'to'
  return ''
}

export function poseForAction(emote: HomeEmote | null, clientId: string, resting: PetPose): PetPose {
  const role = roleInAction(emote, clientId)
  if (!emote || !role) return resting
  const spec = actionSpec(emote.kind)
  if (role === 'to' && emote.kind === 'wake' && resting !== 'sleep') return 'wave'
  return role === 'from' ? spec.actorPose : spec.targetPose
}

export function labelForAction(emote: HomeEmote | null, clientId: string): string {
  const role = roleInAction(emote, clientId)
  if (!emote || !role) return ''
  const spec = actionSpec(emote.kind)
  return role === 'from' ? spec.actorLabel : spec.targetLabel
}

export function yardMetrics(people: number, chatting: boolean) {
  const n = Math.max(1, people)
  const cols = Math.min(n, MAX_COLS)
  const rows = Math.ceil(n / cols)
  return {
    cols,
    rows,
    width: YARD_PAD_X + cols * SLOT_W + MENU_RESERVE,
    height: YARD_PAD_TOP + rows * SLOT_H + BAR_H + (chatting ? LOG_H : 0),
  }
}

export function slotOffset(index: number, people: number) {
  const { cols } = yardMetrics(people, false)
  const col = Math.max(0, index) % cols
  const row = Math.floor(Math.max(0, index) / cols)
  return {
    x: YARD_PAD_X + col * SLOT_W,
    y: YARD_PAD_TOP + row * SLOT_H,
  }
}

export function flyerDir(emoteId: string, fromIndex: number, toIndex: number): 1 | -1 {
  if (fromIndex >= 0 && toIndex >= 0 && fromIndex !== toIndex) {
    return toIndex > fromIndex ? 1 : -1
  }
  let hash = 0
  for (const ch of emoteId) hash = (hash + ch.charCodeAt(0)) % 2
  return hash === 0 ? 1 : -1
}

export function flyerPoint(t: number, startX: number, startY: number, outX: number, outY: number) {
  const clamp = Math.min(1, Math.max(0, t))
  const ease = (u: number) => (u < 0.5 ? 2 * u * u : 1 - (-2 * u + 2) ** 2 / 2)
  if (clamp < 0.1) return { x: startX, y: startY }
  if (clamp < 0.5) {
    const u = ease((clamp - 0.1) / 0.4)
    return {
      x: startX + (outX - startX) * u,
      y: startY + (outY - startY) * u - 72 * Math.sin(u * Math.PI),
    }
  }
  if (clamp < 0.9) {
    const u = ease((clamp - 0.5) / 0.4)
    return {
      x: outX + (startX - outX) * u,
      y: outY + (startY - outY) * u - 72 * Math.sin((1 - u) * Math.PI),
    }
  }
  return { x: startX, y: startY }
}

export function clampPoint(x: number, y: number, size: number, wa: WorkArea) {
  return {
    x: Math.min(Math.max(wa.x, x), Math.max(wa.x, wa.x + wa.width - size)),
    y: Math.min(Math.max(wa.y, y), Math.max(wa.y, wa.y + wa.height - size)),
  }
}

export function flyerSeat(petX: number, petY: number, slotX: number, slotY: number) {
  return {
    x: petX + slotX + (SLOT_W - FLYER_SIZE) / 2,
    y: petY + slotY + 8,
  }
}

export function flyerPath(startX: number, startY: number, dir: 1 | -1, wa: WorkArea) {
  const start = clampPoint(startX, startY, FLYER_SIZE, wa)
  let d: 1 | -1 = dir
  let dest = clampPoint(start.x + d * FLYER_OUT, start.y - FLYER_LIFT, FLYER_SIZE, wa)
  if (Math.abs(dest.x - start.x) < FLYER_SIZE) {
    d = d === 1 ? -1 : 1
    dest = clampPoint(start.x + d * FLYER_OUT, start.y - FLYER_LIFT, FLYER_SIZE, wa)
  }
  return { start, dest, dir: d }
}

import type { Stone } from './gomoku'
import type { PetColors, PetPose, PetProfile, Species, WeatherFx, WeatherGear } from './types'

export const TILE = 32
export const PET_SIZE = 32
export const DEFAULT_ROOM_PORT = 18765
export const DEFAULT_ROOM_URL = `ws://127.0.0.1:${DEFAULT_ROOM_PORT}`
export const BOARD_LIMIT = 80
export const NEARBY_RANGE = 140
export const MOVE_SPEED = 110
export const POSE_TICK_MS = 100
export const MOVE_SEND_MS = 100
export const SCHOOL_CROWD_CAP = 100

export type Facing = 'l' | 'r'
export type PlaceKind = 'campus' | 'classroom'
export type ChatKind = 'board' | 'nearby'
export type SchoolPlaceId = 'school:campus' | 'school:class-1' | 'school:class-2' | 'school:class-3' | 'school:class-4'
export type HomePlaceId = `home:${string}`
export type PlaceId = SchoolPlaceId | HomePlaceId | 'away'

export type EmoteKind = 'wave' | 'hug' | 'pour' | 'wake' | 'kick'

export const EMOTE_KINDS: EmoteKind[] = ['wave', 'hug', 'pour', 'wake', 'kick']
export const DIRECTED_EMOTES: EmoteKind[] = ['hug', 'pour', 'wake', 'kick']
export const SYNC_POSES: PetPose[] = [
  'idle',
  'talk',
  'drink',
  'sleep',
  'wake',
  'type',
  'phone',
  'snack',
  'peek',
  'game',
  'wave',
  'coffee',
  'toilet',
]

export const EMOTE_LABELS: Record<EmoteKind, string> = {
  wave: '挥手',
  hug: '抱抱',
  pour: '倒水',
  wake: '拍醒',
  kick: '飞踢',
}

export function isEmoteKind(value: string): value is EmoteKind {
  return (EMOTE_KINDS as string[]).includes(value)
}

export function isSyncPose(value: string): value is PetPose {
  return (SYNC_POSES as string[]).includes(value)
}

export function clampLook(value: unknown) {
  const n = Number(value)
  if (!Number.isFinite(n) || n === 0) return 0
  return n < 0 ? -1 : 1
}

export interface PetDress {
  gear: WeatherGear[]
  fx: WeatherFx[]
}

export const EMPTY_DRESS: PetDress = { gear: [], fx: [] }

const GEAR_OK: WeatherGear[] = ['shades', 'raincoat', 'scarf', 'beanie', 'umbrella', 'snowman', 'juice']
const FX_OK: WeatherFx[] = ['rain', 'snow', 'sun', 'fog', 'storm', 'wind', 'stars', 'cloud']

export function sanitizeDress(raw: unknown): PetDress {
  const value = raw && typeof raw === 'object' ? (raw as PetDress) : EMPTY_DRESS
  return {
    gear: Array.isArray(value.gear) ? value.gear.filter((item): item is WeatherGear => (GEAR_OK as string[]).includes(item)).slice(0, 8) : [],
    fx: Array.isArray(value.fx) ? value.fx.filter((item): item is WeatherFx => (FX_OK as string[]).includes(item)).slice(0, 8) : [],
  }
}

export interface Presence {
  clientId: string
  name: string
  species: Species
  colors: PetColors
  homeId: HomePlaceId
  schoolPlaceId: SchoolPlaceId | null
  placeId: PlaceId
  x: number
  y: number
  facing: Facing
  pose: PetPose
  lookX: number
  lookY: number
  dress: PetDress
}

export interface HomeEmote {
  id: string
  fromId: string
  targetId?: string
  kind: EmoteKind
  ts: number
  placeId: PlaceId
}

export interface ChatLine {
  id: string
  clientId: string
  name: string
  text: string
  ts: number
  kind: ChatKind
  placeId: PlaceId
}

export interface PoseItem {
  id: string
  x: number
  y: number
  facing: Facing
}

export interface PlaceDef {
  id: SchoolPlaceId
  title: string
  kind: PlaceKind
  tiles: string[]
  labels: { text: string; tx: number; ty: number }[]
}

export interface FriendCard {
  clientId: string
  name: string
  species: Species
  colors: PetColors
  online: boolean
  placeId: PlaceId | null
  homeId: HomePlaceId | null
  schoolPlaceId: SchoolPlaceId | null
  inGame: boolean
}

export interface RoomView {
  connected: boolean
  connecting: boolean
  error: string
  you: Presence | null
  people: Presence[]
  board: ChatLine[]
  homePeople: Presence[]
  homeBoard: ChatLine[]
  friends: FriendCard[]
  incoming: FriendCard[]
  notice: string
  lastChat: ChatLine | null
  lastHomeChat: ChatLine | null
  poses: Record<string, PetPose>
  looks: Record<string, { x: number; y: number }>
  dresses: Record<string, PetDress>
  lastEmote: HomeEmote | null
  game: GameView | null
}

export type GameStatus = 'pending' | 'playing' | 'ended'
export type GameEndReason = 'five' | 'draw' | 'resign' | 'timeout' | 'disconnect' | 'expired' | 'declined'
export type GameRole = 'black' | 'white'

export interface GamePlayer {
  clientId: string
  name: string
  species: Species
  colors: PetColors
}

export interface GameResult {
  winnerId: string | null
  reason: GameEndReason
}

export interface GameView {
  id: string
  status: GameStatus
  black: GamePlayer
  white: GamePlayer
  board: Stone[][]
  turn: 1 | 2
  deadlineAt: number
  lastMove: { x: number; y: number } | null
  winLine: { x: number; y: number }[] | null
  result: GameResult | null
  you: GameRole
}

export function isGameBusy(game: GameView | null | undefined) {
  return Boolean(game && (game.status === 'pending' || game.status === 'playing'))
}

export function isIncomingInvite(game: GameView | null | undefined) {
  return Boolean(game && game.status === 'pending' && game.you === 'white')
}

export function canInviteFriend(
  game: GameView | null | undefined,
  myId: string,
  card: Pick<FriendCard, 'clientId' | 'online' | 'inGame'>,
) {
  return card.clientId !== myId && card.online && !card.inGame && !isGameBusy(game)
}

export type ClientMsg =
  | { type: 'hello'; clientId: string; pet: PetProfile }
  | { type: 'enterPlace'; placeId: PlaceId }
  | { type: 'move'; x: number; y: number; facing: Facing }
  | { type: 'chat'; text: string; placeId?: PlaceId }
  | { type: 'friendRequest'; targetId: string }
  | { type: 'friendAccept'; targetId: string }
  | { type: 'friendDecline'; targetId: string }
  | { type: 'pose'; pose: PetPose; lookX?: number; lookY?: number; placeId?: PlaceId }
  | { type: 'dress'; dress: PetDress; placeId?: PlaceId }
  | { type: 'emote'; kind: EmoteKind; targetId?: string; placeId?: PlaceId }
  | { type: 'inviteGame'; targetId: string }
  | { type: 'gameRespond'; gameId: string; accept: boolean }
  | { type: 'gameMove'; gameId: string; x: number; y: number }
  | { type: 'gameResign'; gameId: string }

export type ServerMsg =
  | { type: 'welcome'; you: Presence; home: WorldSnapshot; school: WorldSnapshot | null; game?: GameView | null }
  | { type: 'gameState'; game: GameView }
  | { type: 'snapshot'; you: Presence; snapshot: WorldSnapshot }
  | { type: 'join'; person: Presence; placeId: PlaceId }
  | { type: 'leave'; clientId: string; placeId: PlaceId }
  | { type: 'move'; clientId: string; x: number; y: number; facing: Facing }
  | { type: 'poses'; placeId: PlaceId; t: number; items: PoseItem[] }
  | { type: 'chat'; line: ChatLine }
  | { type: 'friends'; friends: FriendCard[]; incoming: FriendCard[] }
  | { type: 'notice'; text: string }
  | { type: 'error'; message: string }
  | { type: 'pose'; clientId: string; pose: PetPose; lookX?: number; lookY?: number; placeId: PlaceId }
  | { type: 'dress'; clientId: string; dress: PetDress; placeId: PlaceId }
  | { type: 'emote'; emote: HomeEmote }

export interface WorldSnapshot {
  placeId: PlaceId
  people: Presence[]
  board: ChatLine[]
  friends: FriendCard[]
  incoming: FriendCard[]
}

const CAMPUS: string[] = [
  '#########################',
  '#rrrrr#rrrrr#rrrrr#rrrrr#',
  '#fffff#fffff#fffff#fffff#',
  '#fffff#fffff#fffff#fffff#',
  '###a#####b#####c#####d###',
  '#ppppppppppppppppppppppp#',
  '#.......................#',
  '#.......................#',
  '#.......................#',
  '#.......................#',
  '#.......................#',
  '#.......................#',
  '#...........x...........#',
  '#########################',
]

const CLASSROOM: string[] = [
  '####################',
  '#kkkkkkkkkkkkkkkkkk#',
  '#..................#',
  '#..................#',
  '#..ss....ss....ss..#',
  '#..................#',
  '#..ss....ss....ss..#',
  '#..................#',
  '#..................#',
  '#........g.........#',
  '#..................#',
  '####################',
]

export const PLACES: Record<SchoolPlaceId, PlaceDef> = {
  'school:campus': {
    id: 'school:campus',
    title: '学校操场',
    kind: 'campus',
    tiles: CAMPUS,
    labels: [
      { text: '一班', tx: 3, ty: 2 },
      { text: '二班', tx: 9, ty: 2 },
      { text: '三班', tx: 15, ty: 2 },
      { text: '活动室', tx: 21, ty: 2 },
    ],
  },
  'school:class-1': {
    id: 'school:class-1',
    title: '一班教室',
    kind: 'classroom',
    tiles: CLASSROOM,
    labels: [{ text: '一班黑板', tx: 7, ty: 1 }],
  },
  'school:class-2': {
    id: 'school:class-2',
    title: '二班教室',
    kind: 'classroom',
    tiles: CLASSROOM,
    labels: [{ text: '二班黑板', tx: 7, ty: 1 }],
  },
  'school:class-3': {
    id: 'school:class-3',
    title: '三班教室',
    kind: 'classroom',
    tiles: CLASSROOM,
    labels: [{ text: '三班黑板', tx: 7, ty: 1 }],
  },
  'school:class-4': {
    id: 'school:class-4',
    title: '活动室',
    kind: 'classroom',
    tiles: CLASSROOM,
    labels: [{ text: '活动室黑板', tx: 6, ty: 1 }],
  },
}

const DOOR_TO_CLASS: Record<string, SchoolPlaceId> = {
  a: 'school:class-1',
  b: 'school:class-2',
  c: 'school:class-3',
  d: 'school:class-4',
}

export function isSchoolPlace(value: string): value is SchoolPlaceId {
  return value in PLACES
}

export function isHomePlace(value: string): value is HomePlaceId {
  return value.startsWith('home:') && value.length > 5
}

export function isPlaceId(value: string): value is PlaceId {
  return value === 'away' || isSchoolPlace(value) || isHomePlace(value)
}

export function isFriendAtHome(card: Pick<FriendCard, 'online' | 'clientId' | 'homeId'>) {
  return Boolean(card.online && card.homeId === homePlaceId(card.clientId))
}

export function homeOwnerId(placeId: PlaceId) {
  return isHomePlace(placeId) ? placeId.slice(5) : null
}

export function homePlaceId(ownerId: string): HomePlaceId {
  return `home:${ownerId}`
}

export function placeTitle(placeId: PlaceId) {
  if (placeId === 'away') return '桌面'
  if (isHomePlace(placeId)) return '房间'
  return PLACES[placeId].title
}

export function inPlace(person: Pick<Presence, 'homeId' | 'schoolPlaceId'>, placeId: PlaceId) {
  if (isHomePlace(placeId)) return person.homeId === placeId
  if (isSchoolPlace(placeId)) return person.schoolPlaceId === placeId
  return false
}

export function displayPlace(person: Pick<Presence, 'homeId' | 'schoolPlaceId'>): PlaceId {
  return person.schoolPlaceId ?? person.homeId
}

export function isHomeGathering(you: Presence | null, homePeople: Presence[], myId: string) {
  if (!you) return false
  if (homeOwnerId(you.homeId) !== myId) return true
  return homePeople.length > 0
}

export function emptyRoomView(): RoomView {
  return {
    connected: false,
    connecting: false,
    error: '',
    you: null,
    people: [],
    board: [],
    homePeople: [],
    homeBoard: [],
    friends: [],
    incoming: [],
    notice: '',
    lastChat: null,
    lastHomeChat: null,
    poses: {},
    looks: {},
    dresses: {},
    lastEmote: null,
    game: null,
  }
}

export function mapSize(place: PlaceDef) {
  return { cols: place.tiles[0].length, rows: place.tiles.length }
}

export function tileAt(place: PlaceDef, tx: number, ty: number) {
  const row = place.tiles[ty]
  if (!row || tx < 0 || tx >= row.length) return '#'
  return row[tx] ?? '#'
}

export function pixelToTile(x: number, y: number) {
  return { tx: Math.floor(x / TILE), ty: Math.floor(y / TILE) }
}

function findTile(place: PlaceDef, code: string) {
  for (let ty = 0; ty < place.tiles.length; ty += 1) {
    const tx = place.tiles[ty].indexOf(code)
    if (tx >= 0) return { tx, ty }
  }
  return { tx: 1, ty: 1 }
}

export function spawnOnTile(place: PlaceDef, code: string, dy = -8) {
  const { tx, ty } = findTile(place, code)
  return { x: tx * TILE + (TILE - PET_SIZE) / 2, y: ty * TILE + dy }
}

export function defaultSpawn(placeId: PlaceId) {
  if (!isSchoolPlace(placeId)) return { x: 0, y: 0 }
  const place = PLACES[placeId]
  if (place.kind === 'campus') return spawnOnTile(place, 'x', -TILE - 4)
  return spawnOnTile(place, 'g', -TILE - 4)
}

export function spawnAfterEnter(from: PlaceId, to: PlaceId) {
  if (!isSchoolPlace(to)) return { x: 0, y: 0 }
  if (to === 'school:campus' && isSchoolPlace(from) && from !== 'school:campus') {
    const door = Object.entries(DOOR_TO_CLASS).find(([, id]) => id === from)?.[0] ?? 'a'
    return spawnOnTile(PLACES[to], door, TILE - 6)
  }
  return defaultSpawn(to)
}

export function isSolid(code: string) {
  return code === '#' || code === 's' || code === 'k' || code === 'r'
}

export function feetBox(x: number, y: number) {
  return { x: x + 8, y: y + 20, w: 16, h: 10 }
}

export function canWalk(place: PlaceDef, x: number, y: number) {
  const box = feetBox(x, y)
  const points = [
    [box.x, box.y],
    [box.x + box.w, box.y],
    [box.x, box.y + box.h],
    [box.x + box.w, box.y + box.h],
  ]
  return points.every(([px, py]) => !isSolid(tileAt(place, Math.floor(px / TILE), Math.floor(py / TILE))))
}

export function clampMove(place: PlaceDef, fromX: number, fromY: number, toX: number, toY: number) {
  if (canWalk(place, toX, toY)) return { x: toX, y: toY }
  if (canWalk(place, toX, fromY)) return { x: toX, y: fromY }
  if (canWalk(place, fromX, toY)) return { x: fromX, y: toY }
  return { x: fromX, y: fromY }
}

export function triggerAt(place: PlaceDef, x: number, y: number) {
  const box = feetBox(x, y)
  const cx = box.x + box.w / 2
  const cy = box.y + box.h / 2
  const code = tileAt(place, Math.floor(cx / TILE), Math.floor(cy / TILE))
  if (code === 'x') return { kind: 'exit' as const }
  if (code === 'g') return { kind: 'campus' as const }
  const classroom = DOOR_TO_CLASS[code]
  if (classroom) return { kind: 'classroom' as const, placeId: classroom }
  return null
}

export function tileColor(code: string, kind: PlaceKind) {
  if (code === '#') return kind === 'campus' ? '#c45c4a' : '#8b5e3c'
  if (code === 'r') return '#d64545'
  if (code === 'f') return '#f0d2a8'
  if (code === 'p') return '#e6d3a0'
  if (code === 'k') return '#24382c'
  if (code === 's') return '#8b5e3c'
  if (code === 'a' || code === 'b' || code === 'c' || code === 'd' || code === 'g') return '#ffb347'
  if (code === 'x') return '#7ee0c6'
  if (kind === 'classroom') return '#e2b989'
  return code === '.' && (kind === 'campus') ? '#6ec15a' : '#8fbc6b'
}

export function tileAccent(code: string) {
  if (code === 'k') return '#4a7a5c'
  if (code === 'r') return '#8e1f1f'
  if (code === '#') return '#3d2c29'
  if (code === 's' || code === 'f') return '#b07d4f'
  if (code === 'p') return '#c4a574'
  if (code === '.') return '#4a9a45'
  if (code === 'x') return '#2f6f5e'
  return '#3d2c29'
}

export function chatKindFor(placeId: PlaceId): ChatKind {
  if (isHomePlace(placeId)) return 'board'
  if (!isSchoolPlace(placeId)) return 'nearby'
  return PLACES[placeId].kind === 'classroom' ? 'board' : 'nearby'
}

export function dist(ax: number, ay: number, bx: number, by: number) {
  const dx = ax - bx
  const dy = ay - by
  return Math.hypot(dx, dy)
}

export function sanitizeChat(text: string) {
  return text.replace(/\s+/g, ' ').trim().slice(0, 80)
}

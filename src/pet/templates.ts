import type { PetPose, Species } from '../../shared/types'

export const PIXEL_LEGEND = {
  '.': 'empty',
  '#': 'outline',
  B: 'body',
  D: 'shadow',
  L: 'light',
  A: 'accent',
  E: 'eye',
  P: 'pupil',
  C: 'blush',
} as const

export type PixelCode = keyof typeof PIXEL_LEGEND

const CAT_IDLE = [
  '................',
  '.#.#........#.#.',
  '#A#A########A#A#',
  '#BBBBBBBBBBBBBB#',
  '#BEEBBBBBBBBEEB#',
  '#BEPBBBBBBBBEPE#',
  '#BBBBBBBBBBBBBB#',
  '#BBCBBBBBBCBBBB#',
  '#BBBB.AAAA.BBBB#',
  '#BBBBB....BBBBB#',
  '.#BBBBBBBBBBBB#.',
  '.#BBLLLLLLLLBB#.',
  '.#DBLLLLLLLLBD#.',
  '.#BBBBBBBBBBBB#.',
  '..#BBB#..#BBB#..',
  '...###....###...',
]

const CAT_BLINK = [
  '................',
  '.#.#........#.#.',
  '#A#A########A#A#',
  '#BBBBBBBBBBBBBB#',
  '#B##BBBBBBBB##B#',
  '#B##BBBBBBBB##B#',
  '#BBBBBBBBBBBBBB#',
  '#BBCBBBBBBCBBBB#',
  '#BBBB.AAAA.BBBB#',
  '#BBBBB....BBBBB#',
  '.#BBBBBBBBBBBB#.',
  '.#BBLLLLLLLLBB#.',
  '.#DBLLLLLLLLBD#.',
  '.#BBBBBBBBBBBB#.',
  '..#BBB#..#BBB#..',
  '...###....###...',
]

const CAT_TALK = [
  '................',
  '.#.#........#.#.',
  '#A#A########A#A#',
  '#BBBBBBBBBBBBBB#',
  '#BEEBBBBBBBBEEB#',
  '#BEPBBBBBBBBEPE#',
  '#BBBBBBBBBBBBBB#',
  '#BBCBBBBBBCBBBB#',
  '#BBBB.AAAA.BBBB#',
  '#BBBBB.AA.BBBBB#',
  '.#BBBB....BBBB#.',
  '.#BBLLLLLLLLBB#.',
  '.#DBLLLLLLLLBD#.',
  '.#BBBBBBBBBBBB#.',
  '..#BBB#..#BBB#..',
  '...###....###...',
]

const DOG_IDLE = [
  '................',
  '##..........##..',
  '#D#........#D#..',
  '.#BB######BB#...',
  '.#BBBBBBBBBB#...',
  '.#BEEBBBBEEB#...',
  '.#BEPBBBBPEB#...',
  '.#BBBBBBBBBB#...',
  '.#BBCBAAABCBB#...',
  '.#BBB....BBB#...',
  '.#BBBBBBBBBB#...',
  '#BBLLLLLLLLBB#..',
  '#DBLLLLLLLLBD#..',
  '.#BBBBBBBBBB#...',
  '..#BBB##BBB#....',
  '...###..###.....',
]

const DOG_BLINK = [
  '................',
  '##..........##..',
  '#D#........#D#..',
  '.#BB######BB#...',
  '.#BBBBBBBBBB#...',
  '.#B##BBBB##B#...',
  '.#B##BBBB##B#...',
  '.#BBBBBBBBBB#...',
  '.#BBCBAAABCBB#...',
  '.#BBB....BBB#...',
  '.#BBBBBBBBBB#...',
  '#BBLLLLLLLLBB#..',
  '#DBLLLLLLLLBD#..',
  '.#BBBBBBBBBB#...',
  '..#BBB##BBB#....',
  '...###..###.....',
]

const DOG_TALK = [
  '................',
  '##..........##..',
  '#D#........#D#..',
  '.#BB######BB#...',
  '.#BBBBBBBBBB#...',
  '.#BEEBBBBEEB#...',
  '.#BEPBBBBPEB#...',
  '.#BBBBBBBBBB#...',
  '.#BBCBAAABCBB#...',
  '.#BBB.AA.BBB#...',
  '.#BBBB..BBBB#...',
  '#BBLLLLLLLLBB#..',
  '#DBLLLLLLLLBD#..',
  '.#BBBBBBBBBB#...',
  '..#BBB##BBB#....',
  '...###..###.....',
]

const RABBIT_IDLE = [
  '..#......#......',
  '.#A#....#A#.....',
  '.#B#....#B#.....',
  '.#B######B#.....',
  '.#BBBBBBBB#.....',
  '.#BEEBBEEB#.....',
  '.#BEPBBPEB#.....',
  '.#BBBBBBBB#.....',
  '.#BCBAAAABC#....',
  '.#BBB....B#.....',
  '.#BBBBBBBB#.....',
  '#BBLLLLLLBB#....',
  '#DBLLLLLLBD#....',
  '.#BBBBBBBB#.....',
  '..#BB##BB#......',
  '...##..##.......',
]

const RABBIT_BLINK = [
  '..#......#......',
  '.#A#....#A#.....',
  '.#B#....#B#.....',
  '.#B######B#.....',
  '.#BBBBBBBB#.....',
  '.#B##BB##B#.....',
  '.#B##BB##B#.....',
  '.#BBBBBBBB#.....',
  '.#BCBAAAABC#....',
  '.#BBB....B#.....',
  '.#BBBBBBBB#.....',
  '#BBLLLLLLBB#....',
  '#DBLLLLLLBD#....',
  '.#BBBBBBBB#.....',
  '..#BB##BB#......',
  '...##..##.......',
]

const RABBIT_TALK = [
  '..#......#......',
  '.#A#....#A#.....',
  '.#B#....#B#.....',
  '.#B######B#.....',
  '.#BBBBBBBB#.....',
  '.#BEEBBEEB#.....',
  '.#BEPBBPEB#.....',
  '.#BBBBBBBB#.....',
  '.#BCBAAAABC#....',
  '.#BBB.AA.B#.....',
  '.#BBBB..BB#.....',
  '#BBLLLLLLBB#....',
  '#DBLLLLLLBD#....',
  '.#BBBBBBBB#.....',
  '..#BB##BB#......',
  '...##..##.......',
]

const BIRD_IDLE = [
  '................',
  '....######......',
  '...#BBBBBB#.....',
  '..#BBBBBBBB#....',
  '..#BEEBBBEE#....',
  '..#BEPBBPEP#....',
  '..#BBBBAAAA#....',
  '..#BBCBBBAA#....',
  '...#BBBBBB#.....',
  '...#BLLLLB#.....',
  '..#DBLLLLBD#....',
  '..#BBBBBBBB#....',
  '...#D#..#D#.....',
  '....#....#......',
  '................',
  '................',
]

const BIRD_BLINK = [
  '................',
  '....######......',
  '...#BBBBBB#.....',
  '..#BBBBBBBB#....',
  '..#B##BBB###....',
  '..#B##BBB###....',
  '..#BBBBAAAA#....',
  '..#BBCBBBAA#....',
  '...#BBBBBB#.....',
  '...#BLLLLB#.....',
  '..#DBLLLLBD#....',
  '..#BBBBBBBB#....',
  '...#D#..#D#.....',
  '....#....#......',
  '................',
  '................',
]

const BIRD_TALK = [
  '................',
  '....######......',
  '...#BBBBBB#.....',
  '..#BBBBBBBB#....',
  '..#BEEBBBEE#....',
  '..#BEPBBPEP#....',
  '..#BBBB.AAA#....',
  '..#BBCBB.AA#....',
  '...#BBBBBB#.....',
  '...#BLLLLB#.....',
  '..#DBLLLLBD#....',
  '..#BBBBBBBB#....',
  '...#D#..#D#.....',
  '....#....#......',
  '................',
  '................',
]

const HAMSTER_IDLE = [
  '................',
  '...##########...',
  '..#BBBBBBBBBB#..',
  '.#BBBBBBBBBBBB#.',
  '.#BEEBBBBBEEBB#.',
  '.#BEPBBBBBPEBB#.',
  '.#BBBBBBBBBBBB#.',
  '.#BBCBAAAABCBB#.',
  '.#BBBB....BBBB#.',
  '.#BBLLLLLLLLBB#.',
  '.#DBLLLLLLLLBD#.',
  '..#BBBBBBBBBB#..',
  '..#BBB#..#BBB#..',
  '...###....###...',
  '................',
  '................',
]

const HAMSTER_BLINK = [
  '................',
  '...##########...',
  '..#BBBBBBBBBB#..',
  '.#BBBBBBBBBBBB#.',
  '.#B##BBBBB##BB#.',
  '.#B##BBBBB##BB#.',
  '.#BBBBBBBBBBBB#.',
  '.#BBCBAAAABCBB#.',
  '.#BBBB....BBBB#.',
  '.#BBLLLLLLLLBB#.',
  '.#DBLLLLLLLLBD#.',
  '..#BBBBBBBBBB#..',
  '..#BBB#..#BBB#..',
  '...###....###...',
  '................',
  '................',
]

const HAMSTER_TALK = [
  '................',
  '...##########...',
  '..#BBBBBBBBBB#..',
  '.#BBBBBBBBBBBB#.',
  '.#BEEBBBBBEEBB#.',
  '.#BEPBBBBBPEBB#.',
  '.#BBBBBBBBBBBB#.',
  '.#BBCBAAAABCBB#.',
  '.#BBBB.AA.BBBB#.',
  '.#BBLLLLLLLLBB#.',
  '.#DBLLLLLLLLBD#.',
  '..#BBBBBBBBBB#..',
  '..#BBB#..#BBB#..',
  '...###....###...',
  '................',
  '................',
]

const BLOB_IDLE = [
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

const BLOB_BLINK = [
  '................',
  '....######......',
  '...#BBBBBB#.....',
  '..#BBBBBBBB#....',
  '.#BBBBBBBBBB#...',
  '.#B##BBBB##B#...',
  '.#B##BBBB##B#...',
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

const BLOB_TALK = [
  '................',
  '....######......',
  '...#BBBBBB#.....',
  '..#BBBBBBBB#....',
  '.#BBBBBBBBBB#...',
  '.#BEEBBBBEEB#...',
  '.#BEPBBBBPEB#...',
  '.#BBBBBBBBBB#...',
  '.#BBCBAAABCB#...',
  '.#BBB.AA.BBB#...',
  '.#BBLL..LLBB#...',
  '..#DBLLLLBD#....',
  '...#BBBBBB#.....',
  '....#D##D#......',
  '................',
  '................',
]

function padRow(row: string) {
  return (row + '................').slice(0, 16)
}

function normalize(rows: string[]) {
  return rows.map(padRow)
}

function overlay(base: string[], stamps: Array<[number, number, string]>) {
  const grid = normalize(base).map((row) => row.split(''))
  for (const [x, y, ch] of stamps) {
    if (!grid[y] || grid[y][x] === undefined) continue
    grid[y][x] = ch
  }
  return grid.map((row) => row.join(''))
}

const BOWL: Array<[number, number, string]> = [
  [10, 12, '#'],
  [11, 12, '#'],
  [12, 12, '#'],
  [9, 13, '#'],
  [10, 13, 'A'],
  [11, 13, 'A'],
  [12, 13, 'A'],
  [13, 13, '#'],
  [10, 14, '#'],
  [11, 14, '#'],
  [12, 14, '#'],
]

const ZZZ: Array<[number, number, string]> = [
  [13, 0, 'A'],
  [14, 0, 'A'],
  [15, 0, 'A'],
  [14, 1, 'A'],
  [13, 2, 'A'],
  [14, 2, 'A'],
  [15, 2, 'A'],
]

const STRETCH: Array<[number, number, string]> = [
  [0, 1, '#'],
  [1, 0, '#'],
  [1, 1, 'B'],
  [2, 1, '#'],
  [13, 1, '#'],
  [14, 0, '#'],
  [14, 1, 'B'],
  [15, 1, '#'],
]

const KEYBOARD: Array<[number, number, string]> = [
  [5, 12, 'D'],
  [6, 12, 'B'],
  [7, 12, 'D'],
  [2, 14, '#'],
  [3, 14, 'L'],
  [4, 14, '#'],
  [5, 14, 'L'],
  [6, 14, '#'],
  [7, 14, 'L'],
  [8, 14, '#'],
  [9, 14, 'L'],
  [10, 14, '#'],
  [11, 14, 'L'],
  [12, 14, '#'],
  [3, 15, '#'],
  [4, 15, '#'],
  [5, 15, '#'],
  [6, 15, '#'],
  [7, 15, '#'],
  [8, 15, '#'],
  [9, 15, '#'],
  [10, 15, '#'],
  [11, 15, '#'],
]

const PHONE: Array<[number, number, string]> = [
  [11, 8, '#'],
  [12, 8, '#'],
  [13, 8, '#'],
  [11, 9, '#'],
  [12, 9, 'L'],
  [13, 9, '#'],
  [11, 10, '#'],
  [12, 10, 'A'],
  [13, 10, '#'],
  [11, 11, '#'],
  [12, 11, 'L'],
  [13, 11, '#'],
  [11, 12, '#'],
  [12, 12, 'A'],
  [13, 12, '#'],
  [11, 13, '#'],
  [12, 13, '#'],
  [13, 13, '#'],
]

const SNACK: Array<[number, number, string]> = [
  [2, 12, '#'],
  [3, 12, 'A'],
  [4, 12, '#'],
  [1, 13, '#'],
  [2, 13, 'A'],
  [3, 13, 'A'],
  [4, 13, 'A'],
  [5, 13, '#'],
  [2, 14, '#'],
  [3, 14, 'A'],
  [4, 14, '#'],
]

const GAMEPAD: Array<[number, number, string]> = [
  [3, 13, '#'],
  [4, 13, 'D'],
  [5, 13, 'L'],
  [6, 13, 'L'],
  [7, 13, 'L'],
  [8, 13, 'D'],
  [9, 13, '#'],
  [3, 14, '#'],
  [4, 14, 'A'],
  [5, 14, '#'],
  [6, 14, '#'],
  [7, 14, '#'],
  [8, 14, 'A'],
  [9, 14, '#'],
]

const SWEAT: Array<[number, number, string]> = [
  [1, 2, 'L'],
  [0, 3, 'L'],
  [1, 4, 'L'],
]

const WAVE: Array<[number, number, string]> = [
  [13, 1, '#'],
  [14, 0, '#'],
  [15, 1, '#'],
  [13, 2, '#'],
  [14, 2, 'A'],
  [15, 2, '#'],
  [14, 3, 'B'],
  [13, 3, '#'],
  [15, 3, '#'],
  [14, 4, '#'],
]

const COFFEE: Array<[number, number, string]> = [
  [12, 6, 'L'],
  [13, 7, 'L'],
  [12, 8, 'L'],
  [10, 11, '#'],
  [11, 11, '#'],
  [12, 11, '#'],
  [9, 12, '#'],
  [10, 12, 'D'],
  [11, 12, 'D'],
  [12, 12, 'D'],
  [13, 12, '#'],
  [14, 12, '#'],
  [9, 13, '#'],
  [10, 13, 'D'],
  [11, 13, 'A'],
  [12, 13, 'D'],
  [13, 13, '#'],
  [14, 13, '#'],
  [10, 14, '#'],
  [11, 14, '#'],
  [12, 14, '#'],
  [13, 14, '#'],
]

const TOILET: Array<[number, number, string]> = [
  [12, 5, 'L'],
  [13, 6, 'L'],
  [12, 7, 'L'],
  [1, 11, '#'],
  [2, 11, 'L'],
  [3, 11, '#'],
  [0, 12, '#'],
  [1, 12, 'L'],
  [2, 12, 'L'],
  [3, 12, 'L'],
  [4, 12, '#'],
  [1, 13, '#'],
  [2, 13, 'A'],
  [3, 13, '#'],
  [2, 14, '#'],
]

function speciesPoses(idle: string[], blink: string[], talk: string[]): Record<PetPose, string[]> {
  return {
    idle: normalize(idle),
    blink: normalize(blink),
    talk: normalize(talk),
    drink: overlay(blink, BOWL),
    sleep: overlay(blink, ZZZ),
    wake: overlay(idle, STRETCH),
    type: overlay(idle, KEYBOARD),
    phone: overlay(idle, PHONE),
    snack: overlay(idle, SNACK),
    peek: overlay(idle, SWEAT),
    game: overlay(idle, GAMEPAD),
    wave: overlay(idle, WAVE),
    coffee: overlay(idle, COFFEE),
    toilet: overlay(blink, TOILET),
  }
}

const FRAMES: Record<Species, Record<PetPose, string[]>> = {
  cat: speciesPoses(CAT_IDLE, CAT_BLINK, CAT_TALK),
  dog: speciesPoses(DOG_IDLE, DOG_BLINK, DOG_TALK),
  rabbit: speciesPoses(RABBIT_IDLE, RABBIT_BLINK, RABBIT_TALK),
  bird: speciesPoses(BIRD_IDLE, BIRD_BLINK, BIRD_TALK),
  hamster: speciesPoses(HAMSTER_IDLE, HAMSTER_BLINK, HAMSTER_TALK),
  blob: speciesPoses(BLOB_IDLE, BLOB_BLINK, BLOB_TALK),
}

export function getFrame(species: Species, pose: PetPose) {
  return FRAMES[species][pose]
}

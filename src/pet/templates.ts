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

const FRAMES: Record<Species, Record<PetPose, string[]>> = {
  cat: { idle: normalize(CAT_IDLE), blink: normalize(CAT_BLINK), talk: normalize(CAT_TALK) },
  dog: { idle: normalize(DOG_IDLE), blink: normalize(DOG_BLINK), talk: normalize(DOG_TALK) },
  rabbit: { idle: normalize(RABBIT_IDLE), blink: normalize(RABBIT_BLINK), talk: normalize(RABBIT_TALK) },
  bird: { idle: normalize(BIRD_IDLE), blink: normalize(BIRD_BLINK), talk: normalize(BIRD_TALK) },
  hamster: { idle: normalize(HAMSTER_IDLE), blink: normalize(HAMSTER_BLINK), talk: normalize(HAMSTER_TALK) },
  blob: { idle: normalize(BLOB_IDLE), blink: normalize(BLOB_BLINK), talk: normalize(BLOB_TALK) },
}

export function getFrame(species: Species, pose: PetPose) {
  return FRAMES[species][pose]
}

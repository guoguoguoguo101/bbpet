import type { PetPose, WeatherInfo } from './types'
import { POSE_LINES, WEATHER_LINES } from './weatherLines'

export type DemoGroup = 'pose' | 'weather' | 'slack'

export const SLACK_POSES = ['phone', 'snack', 'peek', 'game', 'coffee', 'toilet'] as const

export function isSlackPose(pose: PetPose) {
  return (SLACK_POSES as readonly PetPose[]).includes(pose)
}

export interface DemoAction {
  id: string
  group: DemoGroup
  label: string
  pose: PetPose
  emote?: string
  look?: { x: number; y: number }
  lines: string[]
  weather: WeatherInfo
}

function wx(partial: Partial<WeatherInfo> & Pick<WeatherInfo, 'description' | 'emoji' | 'temperature' | 'code'>): WeatherInfo {
  return {
    cityName: '演示',
    isDay: true,
    wind: 6,
    gear: [],
    fx: [],
    dressLine: '',
    ...partial,
  }
}

export const CLEAR_WEATHER = wx({
  description: '多云',
  emoji: '⛅',
  temperature: 22,
  code: 2,
})

export const DEMO_ACTIONS: DemoAction[] = [
  { id: 'idle', group: 'pose', label: '发呆', pose: 'idle', lines: POSE_LINES.idle, weather: CLEAR_WEATHER },
  { id: 'look-right', group: 'pose', label: '看右边', pose: 'idle', look: { x: 1, y: 0 }, lines: POSE_LINES['look-right'], weather: CLEAR_WEATHER },
  { id: 'look-left', group: 'pose', label: '看左边', pose: 'idle', look: { x: -1, y: 0 }, lines: POSE_LINES['look-left'], weather: CLEAR_WEATHER },
  { id: 'blink', group: 'pose', label: '眨眼', pose: 'blink', lines: POSE_LINES.blink, weather: CLEAR_WEATHER },
  { id: 'talk', group: 'pose', label: '说话', pose: 'talk', emote: '喵', lines: POSE_LINES.talk, weather: CLEAR_WEATHER },
  { id: 'drink', group: 'pose', label: '喝水', pose: 'drink', emote: '咕嘟', lines: POSE_LINES.drink, weather: CLEAR_WEATHER },
  { id: 'sleep', group: 'pose', label: '睡觉', pose: 'sleep', emote: 'Zzz', lines: POSE_LINES.sleep, weather: CLEAR_WEATHER },
  { id: 'wake', group: 'pose', label: '伸懒腰', pose: 'wake', emote: '伸懒腰', lines: POSE_LINES.wake, weather: CLEAR_WEATHER },
  { id: 'type', group: 'pose', label: '打字', pose: 'type', emote: '嗒嗒', lines: POSE_LINES.type, weather: CLEAR_WEATHER },
  { id: 'phone', group: 'slack', label: '刷手机', pose: 'phone', lines: POSE_LINES.phone, weather: CLEAR_WEATHER },
  { id: 'snack', group: 'slack', label: '偷吃', pose: 'snack', lines: POSE_LINES.snack, weather: CLEAR_WEATHER },
  { id: 'peek', group: 'slack', label: '张望', pose: 'peek', lines: POSE_LINES.peek, weather: CLEAR_WEATHER },
  { id: 'game', group: 'slack', label: '打游戏', pose: 'game', lines: POSE_LINES.game, weather: CLEAR_WEATHER },
  { id: 'coffee', group: 'slack', label: '喝咖啡', pose: 'coffee', lines: POSE_LINES.coffee, weather: CLEAR_WEATHER },
  { id: 'toilet', group: 'slack', label: '上厕所', pose: 'toilet', lines: POSE_LINES.toilet, weather: CLEAR_WEATHER },
    {
    id: 'wx-sun',
    group: 'weather',
    label: '晴天',
    pose: 'drink',
    weather: wx({
      description: '晴朗',
      emoji: '☀️',
      temperature: 24,
      code: 0,
      gear: ['shades', 'juice'],
      fx: ['sun'],
      dressLine: WEATHER_LINES.sun[0],
    }),
    lines: WEATHER_LINES.sun,
  },
  {
    id: 'wx-hot',
    group: 'weather',
    label: '炎热',
    pose: 'drink',
    weather: wx({
      description: '晴朗',
      emoji: '🥵',
      temperature: 33,
      code: 0,
      gear: ['shades', 'juice'],
      fx: ['sun'],
      dressLine: WEATHER_LINES.sunHot[0],
    }),
    lines: WEATHER_LINES.sunHot,
  },
  {
    id: 'wx-drizzle',
    group: 'weather',
    label: '毛毛雨 · 伞',
    pose: 'idle',
    weather: wx({
      description: '小毛毛雨',
      emoji: '🌦️',
      temperature: 18,
      code: 51,
      gear: ['umbrella'],
      fx: ['rain'],
      dressLine: WEATHER_LINES.drizzle[0],
    }),
    lines: WEATHER_LINES.drizzle,
  },
  {
    id: 'wx-rain',
    group: 'weather',
    label: '下雨 · 雨衣',
    pose: 'idle',
    weather: wx({
      description: '中雨',
      emoji: '🌧️',
      temperature: 16,
      code: 63,
      gear: ['raincoat', 'umbrella'],
      fx: ['rain'],
      dressLine: WEATHER_LINES.rain[0],
    }),
    lines: WEATHER_LINES.rain,
  },
  {
    id: 'wx-storm',
    group: 'weather',
    label: '雷暴 · 发抖',
    pose: 'idle',
    weather: wx({
      description: '雷阵雨',
      emoji: '⛈️',
      temperature: 19,
      code: 95,
      gear: ['raincoat', 'umbrella'],
      fx: ['rain', 'storm'],
      dressLine: WEATHER_LINES.storm[0],
    }),
    lines: WEATHER_LINES.storm,
  },
  {
    id: 'wx-snow',
    group: 'weather',
    label: '下雪 · 雪人',
    pose: 'idle',
    weather: wx({
      description: '中雪',
      emoji: '🌨️',
      temperature: -2,
      code: 73,
      gear: ['beanie', 'scarf', 'snowman'],
      fx: ['snow'],
      dressLine: WEATHER_LINES.snow[0],
    }),
    lines: WEATHER_LINES.snow,
  },
  {
    id: 'wx-cold',
    group: 'weather',
    label: '寒冷 · 围巾帽',
    pose: 'idle',
    weather: wx({
      description: '阴天',
      emoji: '☁️',
      temperature: 2,
      code: 3,
      gear: ['scarf', 'beanie'],
      dressLine: WEATHER_LINES.cold[0],
    }),
    lines: WEATHER_LINES.cold,
  },
  {
    id: 'wx-fog',
    group: 'weather',
    label: '有雾',
    pose: 'idle',
    weather: wx({
      description: '有雾',
      emoji: '🌫️',
      temperature: 12,
      code: 45,
      fx: ['fog'],
      dressLine: WEATHER_LINES.fog[0],
    }),
    lines: WEATHER_LINES.fog,
  },
  {
    id: 'wx-night',
    group: 'weather',
    label: '晚上 · 星星',
    pose: 'idle',
    weather: wx({
      description: '晴朗',
      emoji: '🌙',
      temperature: 17,
      code: 0,
      isDay: false,
      fx: ['stars'],
      dressLine: WEATHER_LINES.night[0],
    }),
    lines: WEATHER_LINES.night,
  },
  {
    id: 'wx-wind',
    group: 'weather',
    label: '大风 · 站稳',
    pose: 'idle',
    weather: wx({
      description: '多云',
      emoji: '💨',
      temperature: 21,
      code: 2,
      wind: 34,
      fx: ['wind'],
      dressLine: WEATHER_LINES.wind[0],
    }),
    lines: WEATHER_LINES.wind,
  },
  {
    id: 'wx-partly',
    group: 'weather',
    label: '多云',
    pose: 'idle',
    weather: wx({
      description: '多云',
      emoji: '⛅',
      temperature: 22,
      code: 2,
      fx: ['cloud', 'sun'],
      dressLine: WEATHER_LINES.partly[0],
    }),
    lines: WEATHER_LINES.partly,
  },
  {
    id: 'wx-cloud',
    group: 'weather',
    label: '阴天',
    pose: 'idle',
    weather: wx({
      description: '阴天',
      emoji: '☁️',
      temperature: 20,
      code: 3,
      fx: ['cloud'],
      dressLine: WEATHER_LINES.overcast[0],
    }),
    lines: WEATHER_LINES.overcast,
  },
]

export function findDemoAction(id: string) {
  return DEMO_ACTIONS.find((item) => item.id === id)
}

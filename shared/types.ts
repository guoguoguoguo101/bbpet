export type Species = 'cat' | 'dog' | 'rabbit' | 'bird' | 'hamster' | 'blob'
export type PetPose =
  | 'idle'
  | 'blink'
  | 'talk'
  | 'drink'
  | 'sleep'
  | 'wake'
  | 'type'
  | 'phone'
  | 'snack'
  | 'peek'
  | 'game'
  | 'wave'
  | 'coffee'
  | 'toilet'
export type WindowMode = 'pet' | 'bubble'
export type PanelKind = 'hub' | 'chat' | 'settings' | 'wizard' | 'friends'

export interface PetColors {
  outline: string
  body: string
  shadow: string
  light: string
  accent: string
  eye: string
  pupil: string
  blush: string
}

export interface PetProfile {
  name: string
  species: Species
  colors: PetColors
  photoDataUrl?: string
}

export interface LlmSettings {
  apiBaseUrl: string
  apiKey: string
  model: string
  fallbackModel: string
}

export interface AppSettings extends LlmSettings {
  cityId: string
  cityName: string
  latitude: number
  longitude: number
  pushIntervalMin: number
  roomUrl: string
  hostRoom: boolean
  worldWidth: number
  worldHeight: number
}

export interface WorldStatus {
  present: boolean
  visible: boolean
  connected: boolean
  inHome: boolean
  placeTitle: string
}

export interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
}

export interface AppState {
  onboarded: boolean
  clientId: string
  pet: PetProfile
  settings: AppSettings
  chatHistory: ChatMessage[]
}

export interface WeatherInfo {
  cityName: string
  temperature: number
  description: string
  emoji: string
  code: number
  isDay: boolean
  wind: number
  gear: WeatherGear[]
  fx: WeatherFx[]
  dressLine: string
}

export type WeatherGear = 'shades' | 'raincoat' | 'scarf' | 'beanie' | 'umbrella' | 'snowman' | 'juice'
export type WeatherFx = 'rain' | 'snow' | 'sun' | 'fog' | 'storm' | 'wind' | 'stars' | 'cloud'

export interface NewsItem {
  title: string
  source: string
  url?: string
}

export interface PushBubble {
  kind: string
  text: string
  url?: string
}

export interface ChatResult {
  reply: string
  usedFallback: boolean
  placeholder: boolean
}

export const SPECIES_LABELS: Record<Species, string> = {
  cat: '小猫',
  dog: '小狗',
  rabbit: '兔子',
  bird: '小鸟',
  hamster: '仓鼠',
  blob: '软萌团',
}

export const DEFAULT_COLORS: Record<Species, PetColors> = {
  cat: {
    outline: '#3D2C29',
    body: '#F4A261',
    shadow: '#E0762F',
    light: '#FFE0B8',
    accent: '#E76F51',
    eye: '#FFF8F0',
    pupil: '#2B211E',
    blush: '#FFB4C8',
  },
  dog: {
    outline: '#3D2C29',
    body: '#D4A373',
    shadow: '#B07D4F',
    light: '#F5E1C8',
    accent: '#8B5E3C',
    eye: '#FFF8F0',
    pupil: '#2B211E',
    blush: '#FFB4C8',
  },
  rabbit: {
    outline: '#3D2C29',
    body: '#F3D6D8',
    shadow: '#E2B3B8',
    light: '#FFF4F5',
    accent: '#E8919A',
    eye: '#FFF8F0',
    pupil: '#2B211E',
    blush: '#FFB4C8',
  },
  bird: {
    outline: '#3D2C29',
    body: '#8ED8C4',
    shadow: '#5FB89F',
    light: '#E4FFF6',
    accent: '#F4A261',
    eye: '#FFF8F0',
    pupil: '#2B211E',
    blush: '#FFB4C8',
  },
  hamster: {
    outline: '#3D2C29',
    body: '#F2C6A0',
    shadow: '#D59A6A',
    light: '#FFE9D2',
    accent: '#E76F51',
    eye: '#FFF8F0',
    pupil: '#2B211E',
    blush: '#FFB4C8',
  },
  blob: {
    outline: '#3D2C29',
    body: '#FFC2D4',
    shadow: '#F49AB3',
    light: '#FFE6F0',
    accent: '#FF8FAB',
    eye: '#FFF8F0',
    pupil: '#2B211E',
    blush: '#FF9EBB',
  },
}

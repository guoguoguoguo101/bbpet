import { randomUUID } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { app } from 'electron'
import { CITIES, DEFAULT_CITY } from '../shared/cities'
import { DEFAULT_COLORS, type AppSettings, type AppState, type PetProfile } from '../shared/types'
import { DEFAULT_ROOM_URL } from '../shared/world'

const DEFAULT_PET: PetProfile = {
  name: '豆豆',
  species: 'blob',
  colors: DEFAULT_COLORS.blob,
}

export function defaultSettings(env: NodeJS.ProcessEnv = process.env): AppSettings {
  const city = CITIES.find((item) => item.id === env.BBPET_CITY) ?? DEFAULT_CITY
  return {
    apiBaseUrl: env.LLM_BASE_URL || 'https://openrouter.ai/api/v1',
    apiKey: env.OPENROUTER_API_KEY || env.LLM_API_KEY || '',
    model: env.LLM_MODEL || 'minimax/minimax-m3:free',
    fallbackModel: env.LLM_FALLBACK_MODEL || 'minimax/minimax-m2.7:free',
    cityId: city.id,
    cityName: city.name,
    latitude: city.latitude,
    longitude: city.longitude,
    pushIntervalMin: Number(env.BBPET_PUSH_INTERVAL || 30) || 30,
    roomUrl: env.BBPET_ROOM_URL || DEFAULT_ROOM_URL,
    hostRoom: env.BBPET_HOST_ROOM === '1',
    worldWidth: 820,
    worldHeight: 560,
  }
}

export function createDefaultState(env: NodeJS.ProcessEnv = process.env): AppState {
  return {
    onboarded: false,
    clientId: randomUUID(),
    pet: DEFAULT_PET,
    settings: defaultSettings(env),
    chatHistory: [],
  }
}

export class JsonStore {
  private file: string
  private state: AppState

  constructor(file = join(app.getPath('userData'), 'bbpet-state.json')) {
    this.file = file
    this.state = this.read()
    this.hydrateEmptyFromEnv()
    if (!this.state.clientId) this.state.clientId = randomUUID()
    this.write()
  }

  get(): AppState {
    return this.state
  }

  savePet(pet: PetProfile) {
    this.state.pet = pet
    this.state.onboarded = true
    this.write()
  }

  saveSettings(settings: AppSettings) {
    this.state.settings = settings
    this.write()
  }

  saveWorldSize(width: number, height: number) {
    this.state.settings.worldWidth = width
    this.state.settings.worldHeight = height
    this.write()
  }

  saveChat(history: AppState['chatHistory']) {
    this.state.chatHistory = history.slice(-12)
    this.write()
  }

  markOnboarded() {
    this.state.onboarded = true
    this.write()
  }

  private hydrateEmptyFromEnv() {
    const envDefaults = defaultSettings()
    const current = this.state.settings
    if (!current.apiKey && envDefaults.apiKey) current.apiKey = envDefaults.apiKey
    if (!current.apiBaseUrl) current.apiBaseUrl = envDefaults.apiBaseUrl
    if (!current.model) current.model = envDefaults.model
    if (!current.fallbackModel) current.fallbackModel = envDefaults.fallbackModel
    if (!current.roomUrl) current.roomUrl = envDefaults.roomUrl
    if (typeof current.hostRoom !== 'boolean') current.hostRoom = envDefaults.hostRoom
    if (!current.worldWidth) current.worldWidth = envDefaults.worldWidth
    if (!current.worldHeight) current.worldHeight = envDefaults.worldHeight
    if (current.worldWidth === 560 && current.worldHeight === 420) {
      current.worldWidth = envDefaults.worldWidth
      current.worldHeight = envDefaults.worldHeight
    }
  }

  private read(): AppState {
    try {
      if (!existsSync(this.file)) return createDefaultState()
      const parsed = JSON.parse(readFileSync(this.file, 'utf8')) as Partial<AppState>
      const base = createDefaultState()
      return {
        ...base,
        ...parsed,
        clientId: parsed.clientId || base.clientId,
        pet: { ...base.pet, ...parsed.pet },
        settings: { ...base.settings, ...parsed.settings },
        chatHistory: parsed.chatHistory ?? [],
      }
    } catch {
      return createDefaultState()
    }
  }

  private write() {
    mkdirSync(dirname(this.file), { recursive: true })
    writeFileSync(this.file, JSON.stringify(this.state, null, 2), 'utf8')
  }
}

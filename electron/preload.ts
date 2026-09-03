import type { AppSettings, AppState, ChatResult, NewsItem, PanelKind, PetProfile, PushBubble, WeatherInfo, WindowMode, WorldStatus } from '../shared/types'
import type { ClientMsg, RoomView } from '../shared/world'

export interface BbPetApi {
  getState: () => Promise<AppState>
  savePet: (pet: PetProfile) => Promise<AppState>
  saveSettings: (settings: AppSettings) => Promise<AppState>
  markOnboarded: () => Promise<AppState>
  chat: (content: string) => Promise<ChatResult & { history: AppState['chatHistory'] }>
  fetchWeather: () => Promise<WeatherInfo>
  fetchNews: () => Promise<NewsItem>
  roomHostInfo: () => Promise<{ hosting: boolean; error: string; urls: string[] }>
  worldStatus: () => Promise<WorldStatus>
  roomState: () => Promise<RoomView>
  roomSend: (msg: ClientMsg) => void
  goHome: (ownerId?: string) => void
  leaveHome: () => void
  setIgnoreMouse: (ignore: boolean) => void
  setWindowShape: (rects: { x: number; y: number; w: number; h: number }[]) => void
  resizeWindow: (mode: WindowMode) => void
  reportPetLayout: (size: { width: number; height: number }) => void
  dragStart: () => void
  dragEnd: () => void
  popupPetMenu: () => void
  openPanel: (kind: PanelKind) => void
  closePanel: () => void
  openWorld: () => void
  closeWorld: () => void
  leaveWorld: () => void
  openUrl: (url: string) => void
  reportBubbleSize: (width: number, height: number) => void
  quit: () => void
  onPlayDemo: (handler: (id: string) => void) => () => void
  onPush: (handler: (payload: PushBubble) => void) => () => void
  onShowBubble: (handler: (payload: PushBubble) => void) => () => void
  onBubbleClosed: (handler: () => void) => () => void
  onOpenChat: (handler: () => void) => () => void
  onOpenSettings: (handler: () => void) => () => void
  onStateChanged: (handler: (state: AppState) => void) => () => void
  onSetPanel: (handler: (kind: PanelKind) => void) => () => void
  onPanelClosed: (handler: () => void) => () => void
  onWorldStatus: (handler: (status: WorldStatus) => void) => () => void
  onRoomState: (handler: (view: RoomView) => void) => () => void
  onPetPlay: (handler: (play: { lookX: number; lookY: number; typing: boolean }) => void) => () => void
  onWeather: (handler: (weather: WeatherInfo) => void) => () => void
}

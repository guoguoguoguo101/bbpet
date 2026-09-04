import { app, BrowserWindow, Menu, nativeImage, screen, shell, Tray, ipcMain, type MenuItemConstructorOptions } from 'electron'
import { execFile, spawn, type ChildProcess } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import type { Server } from 'node:http'
import { networkInterfaces } from 'node:os'
import { join } from 'node:path'
import { DEMO_ACTIONS, findDemoAction } from '../shared/demoActions'
import { SPECIES_LABELS, type AppSettings, type PanelKind, type PetProfile, type PushBubble, type WindowMode } from '../shared/types'
import { pickLine } from '../shared/weatherLines'
import { DEFAULT_ROOM_PORT, DEFAULT_ROOM_URL, homePlaceId, isHomeGathering, placeTitle, type ClientMsg } from '../shared/world'
import { startRoomServer } from '../server/roomServer'
import { loadDotEnv } from './env'
import { RoomClient } from './roomClient'
import { fetchNews } from './services/news'
import { chatWithLlm } from './services/llm'
import { fetchWeather } from './services/weather'
import { JsonStore } from './store'

declare const __dirname: string

if (process.platform === 'win32') {
  app.commandLine.appendSwitch('enable-transparent-visuals')
  app.commandLine.appendSwitch('disable-renderer-backgrounding')
  app.commandLine.appendSwitch('disable-backgrounding-occluded-windows')
  app.commandLine.appendSwitch('disable-features', 'CalculateNativeWinOcclusion')
}

loadDotEnv()

let win: BrowserWindow | null = null
let panelWin: BrowserWindow | null = null
let bubbleWin: BrowserWindow | null = null
let worldWin: BrowserWindow | null = null
let gameWin: BrowserWindow | null = null
let lastGameStatus: string | null = null
let menuAnchor: BrowserWindow | null = null
let tray: Tray | null = null
let store: JsonStore
let pushTimer: NodeJS.Timeout | null = null
let weatherTimer: NodeJS.Timeout | null = null
let lastWeather: Awaited<ReturnType<typeof fetchWeather>> | null = null
let pushToggle = 0
let quitting = false
let allowPanelBlurClose = false
let panelKind: PanelKind | null = null
let panelClosedAt = 0
let roomServer: Server | null = null
let roomHostError = ''
let leaveWorldNext = false
let worldResizeTimer: NodeJS.Timeout | null = null
let petSenseTimer: NodeJS.Timeout | null = null

function pinOnTop(target: BrowserWindow | null | undefined) {
  if (!target || target.isDestroyed()) return
  target.setAlwaysOnTop(true, 'screen-saver')
  if (target.isVisible()) target.moveTop()
}

function pinDeskPet() {
  pinOnTop(win)
  pinOnTop(panelWin)
  pinOnTop(bubbleWin)
}

function keepPinned(target: BrowserWindow) {
  target.on('always-on-top-changed', (_event, isAlwaysOnTop) => {
    if (quitting || isAlwaysOnTop || !target.isVisible()) return
    pinOnTop(target)
  })
}
let keyWatch: ChildProcess | null = null
let typingUntil = 0
let lastPetPlay = ''
const roomClient = new RoomClient()

const PET_SIZE = { width: 64, height: 86 }
const WORLD_DEFAULT = { width: 820, height: 560 }
const WORLD_MIN = { width: 520, height: 380 }
const PANEL_SIZES: Record<PanelKind, { width: number; height: number }> = {
  hub: { width: 300, height: 430 },
  chat: { width: 320, height: 420 },
  settings: { width: 340, height: 640 },
  wizard: { width: 340, height: 520 },
  friends: { width: 300, height: 480 },
}
let petLayout = { width: PET_SIZE.width, height: PET_SIZE.height }

let dragging = false
let dragOffsetX = 0
let dragOffsetY = 0
let dragTimer: NodeJS.Timeout | null = null
let dragStartedAt = 0
let ignoreMouse = true
let placedOnce = false

function createTrayIcon() {
  const size = 16
  const buf = Buffer.alloc(size * size * 4)
  const paint = (x: number, y: number, r: number, g: number, b: number, a = 255) => {
    if (x < 0 || y < 0 || x >= size || y >= size) return
    const i = (y * size + x) * 4
    buf[i] = b
    buf[i + 1] = g
    buf[i + 2] = r
    buf[i + 3] = a
  }
  for (let y = 3; y <= 12; y++) {
    for (let x = 3; x <= 12; x++) {
      const dx = x - 7.5
      const dy = y - 8
      if (dx * dx + dy * dy <= 26) paint(x, y, 255, 194, 212)
    }
  }
  paint(4, 4, 255, 194, 212)
  paint(11, 4, 255, 194, 212)
  paint(6, 8, 43, 33, 30)
  paint(9, 8, 43, 33, 30)
  paint(7, 10, 231, 111, 81)
  paint(8, 10, 231, 111, 81)
  return nativeImage.createFromBitmap(buf, { width: size, height: size })
}

function applyIgnoreMouse(ignore: boolean) {
  if (dragging) {
    win?.setIgnoreMouseEvents(false)
    return
  }
  ignoreMouse = ignore
  win?.setIgnoreMouseEvents(ignore, { forward: true })
  if (ignore && win) refreshTransparent(win)
}

function startDrag() {
  if (!win) return
  const cursor = screen.getCursorScreenPoint()
  const [x, y] = win.getPosition()
  dragging = true
  dragStartedAt = Date.now()
  dragOffsetX = cursor.x - x
  dragOffsetY = cursor.y - y
  win.setIgnoreMouseEvents(false)
  if (dragTimer) clearInterval(dragTimer)
  dragTimer = setInterval(() => {
    if (!dragging || !win) return
    const point = screen.getCursorScreenPoint()
    win.setPosition(Math.round(point.x - dragOffsetX), Math.round(point.y - dragOffsetY), false)
    placePanel()
    placeBubble()
  }, 16)
}

function endDrag() {
  dragging = false
  dragStartedAt = 0
  if (dragTimer) {
    clearInterval(dragTimer)
    dragTimer = null
  }
  applyIgnoreMouse(true)
  if (win) refreshTransparent(win)
}

function placeWindow(_mode?: WindowMode) {
  if (!win) return
  const size = petLayout
  const wa = screen.getPrimaryDisplay().workArea
  if (!placedOnce) {
    const offsetX = Number(process.env.BBPET_OFFSET_X || 0) || 0
    const x = wa.x + wa.width - size.width - 8 - offsetX
    const y = wa.y + wa.height - size.height - 6
    win.setBounds({ x, y, width: size.width, height: size.height })
    placedOnce = true
    return
  }
  const prev = win.getBounds()
  const x = Math.min(Math.max(wa.x + 4, prev.x + prev.width - size.width), wa.x + wa.width - size.width - 8)
  const y = Math.min(Math.max(wa.y + 4, prev.y + prev.height - size.height), wa.y + wa.height - size.height - 6)
  win.setBounds({ x, y, width: size.width, height: size.height })
}

let bubblePayload: PushBubble | null = null
let bubbleTimer: NodeJS.Timeout | null = null
let bubbleSize = { width: 200, height: 72 }

function hideBubble() {
  if (bubbleTimer) {
    clearTimeout(bubbleTimer)
    bubbleTimer = null
  }
  bubblePayload = null
  bubbleWin?.hide()
  sendUi('bubble-closed')
}

function placeBubble() {
  if (!win || !bubbleWin || !bubblePayload) return
  const pet = win.getBounds()
  const wa = screen.getPrimaryDisplay().workArea
  let x = pet.x + pet.width - bubbleSize.width
  let y = pet.y - bubbleSize.height - 4
  if (y < wa.y + 4) y = pet.y + pet.height + 4
  x = Math.min(Math.max(wa.x + 4, x), wa.x + wa.width - bubbleSize.width - 4)
  bubbleWin.setBounds({ x, y, width: bubbleSize.width, height: bubbleSize.height })
}

function ensureBubbleWindow() {
  if (bubbleWin) return
  bubbleWin = new BrowserWindow({
    width: bubbleSize.width,
    height: bubbleSize.height,
    show: false,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    hasShadow: false,
    thickFrame: false,
    fullscreenable: false,
    focusable: true,
    roundedCorners: false,
    title: ' ',
    backgroundColor: '#00000000',
    webPreferences: {
      preload: join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  })
  bubbleWin.setMenuBarVisibility(false)
  bubbleWin.setTitle(' ')
  bubbleWin.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })
  keepPinned(bubbleWin)
  pinOnTop(bubbleWin)
  bubbleWin.on('close', (event) => {
    if (quitting) return
    event.preventDefault()
    hideBubble()
  })
}

function showBubble(payload: PushBubble) {
  ensureBubbleWindow()
  if (!bubbleWin) return
  bubblePayload = payload
  if (bubbleTimer) clearTimeout(bubbleTimer)
  const reveal = () => {
    if (!bubbleWin || bubblePayload !== payload) return
    bubbleWin.webContents.send('show-bubble', payload)
  }
  const current = bubbleWin.webContents.getURL()
  if (current.includes('#bubble')) {
    reveal()
  } else {
    bubbleWin.webContents.once('did-finish-load', reveal)
    loadPage(bubbleWin, 'bubble')
  }
  bubbleTimer = setTimeout(() => hideBubble(), payload.url ? 16000 : 8000)
}

function openExternalQuiet(url: string) {
  hideBubble()
  win?.setAlwaysOnTop(false)
  panelWin?.setAlwaysOnTop(false)
  void shell.openExternal(url).finally(() => {
    setTimeout(() => pinDeskPet(), 600)
  })
}

function loadPage(target: BrowserWindow, hash = '') {
  const devUrl = process.env.VITE_DEV_SERVER_URL
  if (devUrl) {
    void target.loadURL(hash ? `${devUrl}#${hash}` : devUrl)
    return
  }
  void target.loadFile(join(__dirname, '../dist/index.html'), { hash })
}

function placePanel(force = false) {
  if (!win || !panelWin || !panelKind) return
  if (!force && !panelWin.isVisible()) return
  const pet = win.getBounds()
  const size = PANEL_SIZES[panelKind]
  const wa = screen.getPrimaryDisplay().workArea
  let x = pet.x + pet.width + 8
  if (x + size.width > wa.x + wa.width - 4) x = pet.x - size.width - 8
  let y = pet.y + pet.height - size.height
  y = Math.min(Math.max(wa.y + 4, y), wa.y + wa.height - size.height - 4)
  x = Math.min(Math.max(wa.x + 4, x), wa.x + wa.width - size.width - 4)
  panelWin.setBounds({ x, y, width: size.width, height: size.height })
}

function worldSize() {
  const { worldWidth, worldHeight } = store.get().settings
  return {
    width: Math.max(WORLD_MIN.width, worldWidth || WORLD_DEFAULT.width),
    height: Math.max(WORLD_MIN.height, worldHeight || WORLD_DEFAULT.height),
  }
}

function worldStatus() {
  const view = roomClient.get()
  const schoolId = view.you?.schoolPlaceId
  const homeId = view.you?.homeId
  const alive = Boolean(worldWin && !worldWin.isDestroyed())
  return {
    present: Boolean(schoolId),
    visible: alive && Boolean(worldWin?.isVisible()),
    connected: view.connected,
    inHome: Boolean(homeId),
    placeTitle: schoolId ? placeTitle(schoolId) : homeId ? placeTitle(homeId) : '',
  }
}

function broadcastWorldStatus() {
  const payload = worldStatus()
  win?.webContents.send('world-status', payload)
  panelWin?.webContents.send('world-status', payload)
}

function hideWorld() {
  if (!worldWin || worldWin.isDestroyed()) return
  worldWin.hide()
  broadcastWorldStatus()
}

function leaveWorld() {
  hideWorld()
}

function ensureWorldWindow() {
  if (worldWin && !worldWin.isDestroyed()) return
  worldWin = new BrowserWindow({
    ...worldSize(),
    minWidth: WORLD_MIN.width,
    minHeight: WORLD_MIN.height,
    show: false,
    frame: false,
    transparent: false,
    alwaysOnTop: false,
    skipTaskbar: false,
    resizable: true,
    thickFrame: true,
    backgroundColor: '#1c1410',
    title: 'BbPet 学校',
    focusable: true,
    webPreferences: {
      preload: join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  })
  worldWin.setMenuBarVisibility(false)
  worldWin.on('close', (event) => {
    if (quitting || leaveWorldNext) return
    event.preventDefault()
    hideWorld()
  })
  worldWin.on('closed', () => {
    worldWin = null
    broadcastWorldStatus()
  })
  worldWin.on('resized', () => {
    if (!worldWin || worldWin.isDestroyed()) return
    const [width, height] = worldWin.getSize()
    if (worldResizeTimer) clearTimeout(worldResizeTimer)
    worldResizeTimer = setTimeout(() => store.saveWorldSize(width, height), 300)
  })
}

async function ensureRoom() {
  const state = store.get()
  const url = state.settings.roomUrl.trim() || DEFAULT_ROOM_URL
  await roomClient.ensure(url, state.clientId, state.pet)
}

async function goHome(ownerId?: string) {
  hidePanel()
  await ensureRoom()
  roomClient.enter(homePlaceId(ownerId || store.get().clientId))
}

function leaveHome() {
  roomClient.enter(homePlaceId(store.get().clientId))
}

async function showFriends() {
  showPanel('friends')
  await ensureRoom()
}

function bindRoomClient() {
  let lastNotice = ''
  let lastGathering: boolean | null = null
  let lastSchoolPlace: string | null = null
  roomClient.onChange = () => {
    const view = roomClient.get()
    win?.webContents.send('room-state', view)
    panelWin?.webContents.send('room-state', view)
    worldWin?.webContents.send('room-state', view)
    gameWin?.webContents.send('room-state', view)
    const status = view.game?.status ?? null
    if (status === 'playing' && lastGameStatus !== 'playing') void showGame()
    lastGameStatus = status
    broadcastWorldStatus()
    if (view.notice && view.notice !== lastNotice) {
      lastNotice = view.notice
      const payload = { kind: 'info', text: view.notice }
      sendUi('push-bubble', payload)
      showBubble(payload)
    }
    if (!view.notice) lastNotice = ''
    const gathering = isHomeGathering(view.you, view.homePeople, store.get().clientId)
    if (lastGathering !== gathering) {
      lastGathering = gathering
      if (win && !win.isDestroyed()) win.setFocusable(gathering)
    }
    const schoolId = view.you?.schoolPlaceId ?? null
    if (schoolId && schoolId !== lastSchoolPlace) {
      lastSchoolPlace = schoolId
      if (worldWin && !worldWin.isDestroyed() && worldWin.isVisible()) {
        worldWin.focus()
        worldWin.webContents.focus()
      }
    } else if (!schoolId) {
      lastSchoolPlace = null
    }
    if (gathering) {
      const n = Math.max(1, 1 + view.homePeople.length)
      const cols = Math.min(n, 5)
      const rows = Math.ceil(n / 5)
      const minW = Math.max(148, cols * 64 + 58)
      const minH = Math.max(148, rows * 90 + 48)
      if (petLayout.width < minW || petLayout.height < minH) {
        petLayout = { width: Math.max(petLayout.width, minW), height: Math.max(petLayout.height, minH) }
        placeWindow()
      }
      return
    }
    if (petLayout.width !== PET_SIZE.width || petLayout.height !== PET_SIZE.height) {
      petLayout = { width: PET_SIZE.width, height: PET_SIZE.height }
      placeWindow()
    }
  }
}

async function showWorld() {
  if (!win) return
  hidePanel()
  await ensureRoom()
  if (!roomClient.get().you?.schoolPlaceId) roomClient.enter('school:campus')
  ensureWorldWindow()
  if (!worldWin) return
  const loaded = worldWin.webContents.getURL().includes('#world')
  if (loaded) {
    worldWin.show()
    worldWin.focus()
    worldWin.webContents.focus()
    broadcastWorldStatus()
    return
  }
  loadPage(worldWin, 'world')
  worldWin.show()
  worldWin.focus()
  worldWin.webContents.focus()
  broadcastWorldStatus()
}

function ensureGameWindow() {
  if (gameWin && !gameWin.isDestroyed()) return
  gameWin = new BrowserWindow({
    width: 560,
    height: 640,
    show: false,
    frame: false,
    transparent: false,
    alwaysOnTop: false,
    skipTaskbar: false,
    resizable: false,
    backgroundColor: '#1c1410',
    title: 'BbPet 五子棋',
    focusable: true,
    webPreferences: {
      preload: join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  })
  gameWin.setMenuBarVisibility(false)
  gameWin.on('close', () => {
    const game = roomClient.get().game
    if (game?.status === 'playing') {
      roomClient.send({ type: 'gameResign', gameId: game.id })
    }
  })
  gameWin.on('closed', () => {
    gameWin = null
  })
}

function destroyGameWindow() {
  if (!gameWin || gameWin.isDestroyed()) {
    gameWin = null
    return
  }
  gameWin.close()
}

async function showGame() {
  ensureGameWindow()
  if (!gameWin) return
  const sendState = () => {
    if (!gameWin || gameWin.isDestroyed()) return
    gameWin.webContents.send('room-state', roomClient.get())
    gameWin.webContents.send('state-changed', store.get())
  }
  const loaded = gameWin.webContents.getURL().includes('#game')
  if (loaded) {
    gameWin.show()
    gameWin.focus()
    gameWin.webContents.focus()
    sendState()
    return
  }
  gameWin.webContents.once('did-finish-load', sendState)
  loadPage(gameWin, 'game')
  gameWin.show()
  gameWin.focus()
  gameWin.webContents.focus()
}

function lanRoomUrls(port: number) {
  const urls = [`ws://127.0.0.1:${port}`]
  for (const list of Object.values(networkInterfaces())) {
    for (const item of list ?? []) {
      if (item.internal || item.family !== 'IPv4') continue
      urls.push(`ws://${item.address}:${port}`)
    }
  }
  return urls
}

async function syncRoomHost() {
  const want = store.get().settings.hostRoom
  if (want && !roomServer) {
    try {
      roomServer = await startRoomServer(DEFAULT_ROOM_PORT, {
        friendsFile: join(app.getPath('userData'), 'bbpet-friends.json'),
      })
      roomHostError = ''
    } catch (error) {
      roomServer = null
      roomHostError = error instanceof Error ? error.message : '校长室没开起来，端口可能被占用'
    }
    return
  }
  if (!want && roomServer) {
    await new Promise<void>((resolve) => roomServer?.close(() => resolve()))
    roomServer = null
    roomHostError = ''
  }
}

function hidePanel() {
  allowPanelBlurClose = false
  panelKind = null
  panelClosedAt = Date.now()
  panelWin?.hide()
  sendUi('panel-closed')
}

function revealPanel(kind: PanelKind) {
  if (!panelWin || panelKind !== kind) return
  panelWin.webContents.send('set-panel', kind)
  panelWin.show()
  panelWin.focus()
  pinOnTop(panelWin)
  setTimeout(() => {
    if (panelKind !== kind || !panelWin?.isVisible()) return
    allowPanelBlurClose = true
    panelWin.focus()
  }, 500)
}

function showPanel(kind: PanelKind) {
  if (!win) return
  closePetMenu(true)
  if (panelWin?.isVisible() && panelKind === kind) {
    hidePanel()
    return
  }
  ensurePanelWindow()
  if (!panelWin) return
  panelKind = kind
  allowPanelBlurClose = false
  const size = PANEL_SIZES[kind]
  panelWin.setSize(size.width, size.height)
  placePanel(true)
  const url = panelWin.webContents.getURL()
  if (url.includes('#') || url.includes('5173') || url.includes('index.html')) {
    revealPanel(kind)
    return
  }
  panelWin.webContents.once('did-finish-load', () => revealPanel(kind))
  loadPage(panelWin, kind)
}

function ensurePanelWindow() {
  if (panelWin) return
  panelWin = new BrowserWindow({
    ...PANEL_SIZES.chat,
    show: false,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    hasShadow: false,
    thickFrame: false,
    fullscreenable: false,
    backgroundColor: '#00000000',
    webPreferences: {
      preload: join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  })
  panelWin.setMenuBarVisibility(false)
  panelWin.setTitle(' ')
  panelWin.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })
  keepPinned(panelWin)
  pinOnTop(panelWin)
  panelWin.on('blur', () => {
    if (!allowPanelBlurClose || panelKind === 'wizard') return
    hidePanel()
  })
  panelWin.on('close', (event) => {
    if (quitting) return
    event.preventDefault()
    hidePanel()
  })
}

function broadcastState() {
  const state = store.get()
  win?.webContents.send('state-changed', state)
  panelWin?.webContents.send('state-changed', state)
  worldWin?.webContents.send('state-changed', state)
  gameWin?.webContents.send('state-changed', state)
}

function nativeHwnd(target: BrowserWindow) {
  const buf = target.getNativeWindowHandle()
  return buf.length >= 8 ? buf.readBigUInt64LE(0).toString() : buf.readUInt32LE(0).toString()
}

type ShapeRect = { x: number; y: number; w: number; h: number }
let lastShape: ShapeRect[] = []

function clearWindowShape() {
  if (!win || win.isDestroyed() || process.platform !== 'win32') return
  lastShape = []
  const source = join(__dirname, 'apply-shape.ps1')
  if (!existsSync(source)) return
  try {
    const script = join(app.getPath('temp'), 'bbpet-apply-shape.ps1')
    writeFileSync(script, readFileSync(source, 'utf8'))
    execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script, '-Hwnd', nativeHwnd(win), '-Clear'],
      { windowsHide: true },
    )
  } catch {
    // keep a rectangular hit target
  }
}

function applyWindowShape(_rects: ShapeRect[]) {
  // Cropping the HWND broke left-click and drag; keep the full window.
}

function refreshTransparent(target: BrowserWindow) {
  if (target.isDestroyed()) return
  target.setBackgroundColor('#00000000')
  target.setHasShadow(false)
  try {
    target.webContents.invalidate()
  } catch {
    // older Electron
  }
}

function setupTransparentGuards(target: BrowserWindow) {
  target.webContents.setBackgroundThrottling(false)
  refreshTransparent(target)
  clearWindowShape()
  if (process.platform !== 'win32') return
  target.on('blur', () => {
    applyIgnoreMouse(true)
    refreshTransparent(target)
  })
}

let petMenu: Menu | null = null
let petMenuOpenedAt = 0

function closePetMenu(force = false) {
  if (!force && Date.now() - petMenuOpenedAt < 180) return
  const menu = petMenu
  petMenu = null
  try {
    menu?.closePopup()
  } catch {
    // already closed
  }
  if (menuAnchor && !menuAnchor.isDestroyed()) menuAnchor.hide()
}

function getMenuAnchor() {
  if (menuAnchor && !menuAnchor.isDestroyed()) return menuAnchor
  menuAnchor = new BrowserWindow({
    width: 4,
    height: 4,
    show: false,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    focusable: true,
    hasShadow: false,
    thickFrame: false,
    fullscreenable: false,
    backgroundColor: '#00000000',
  })
  menuAnchor.setMenuBarVisibility(false)
  menuAnchor.on('blur', () => closePetMenu())
  return menuAnchor
}

function playDemoAction(id: string) {
  if (id === 'off') {
    hideBubble()
    sendUi('play-demo', id)
    return
  }
  sendUi('play-demo', id)
  const action = findDemoAction(id)
  const line = action?.lines?.length ? pickLine(action.lines) : ''
  if (!line) return
  const payload = { kind: 'weather', text: line }
  sendUi('push-bubble', payload)
  showBubble(payload)
}

function testActionMenu(): MenuItemConstructorOptions {
  const items = (group: 'pose' | 'weather' | 'slack') =>
    DEMO_ACTIONS.filter((item) => item.group === group).map((item) => ({
      label: item.group === 'weather' ? `${item.weather.emoji} ${item.label}` : item.label,
      click: () => playDemoAction(item.id),
    }))
  return {
    label: '测试动作',
    submenu: [
      { label: '待机动作', submenu: items('pose') },
      { label: '摸鱼', submenu: items('slack') },
      { label: '天气装扮', submenu: items('weather') },
      { type: 'separator' },
      { label: '恢复正常', click: () => playDemoAction('off') },
    ],
  }
}

function popupPetMenu() {
  closePetMenu(true)
  petMenuOpenedAt = Date.now()
  const point = screen.getCursorScreenPoint()
  const anchor = getMenuAnchor()
  anchor.setBounds({ x: point.x, y: point.y, width: 4, height: 4 })
  anchor.setAlwaysOnTop(true, 'screen-saver')
  anchor.show()
  anchor.focus()
  petMenu = Menu.buildFromTemplate([
    { label: '今天去哪', click: () => showPanel('hub') },
    { label: '去上学', click: () => void showWorld() },
    { label: '回家', click: () => void goHome() },
    { label: '好友', click: () => void showFriends() },
    { label: '聊一聊', click: () => showPanel('chat') },
    { label: '现在看看天气', click: () => void pushOnce('weather') },
    { label: '现在看看新闻', click: () => void pushOnce('news') },
    { label: '设置', click: () => showPanel('settings') },
    { type: 'separator' },
    testActionMenu(),
    { type: 'separator' },
    { label: '退出', click: () => app.quit() },
  ])
  petMenu.popup({
    window: anchor,
    x: 0,
    y: 0,
    callback: () => {
      petMenu = null
      if (!anchor.isDestroyed()) anchor.hide()
      applyIgnoreMouse(true)
      if (win) refreshTransparent(win)
    },
  })
}

function noteTyping() {
  typingUntil = Date.now() + 520
}

function stopPetSense() {
  if (petSenseTimer) {
    clearInterval(petSenseTimer)
    petSenseTimer = null
  }
  if (keyWatch) {
    keyWatch.kill()
    keyWatch = null
  }
  lastPetPlay = ''
}

function startPetSense() {
  stopPetSense()
  if (process.platform === 'win32') {
    const script = join(__dirname, 'watch-keys.ps1')
    if (existsSync(script)) {
      keyWatch = spawn(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script],
        { windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] },
      )
      keyWatch.stdout?.setEncoding('utf8')
      keyWatch.stdout?.on('data', (chunk: string) => {
        const text = String(chunk)
        if (text.includes('T1')) noteTyping()
        if (text.includes('L0') && dragging && Date.now() - dragStartedAt > 80) endDrag()
      })
    }
  }
  petSenseTimer = setInterval(() => {
    if (!win || win.isDestroyed() || win.webContents.isDestroyed()) return
    const cursor = screen.getCursorScreenPoint()
    const bounds = win.getBounds()
    const dx = cursor.x - (bounds.x + Math.round(bounds.width / 2))
    const dy = cursor.y - (bounds.y + Math.round(bounds.height * 0.32))
    const payload = {
      lookX: dx < -42 ? -1 : dx > 42 ? 1 : 0,
      lookY: dy < -28 ? -1 : dy > 36 ? 1 : 0,
      typing: Date.now() < typingUntil,
    }
    const raw = `${payload.lookX},${payload.lookY},${payload.typing ? 1 : 0}`
    if (raw === lastPetPlay) return
    lastPetPlay = raw
    win.webContents.send('pet-play', payload)
  }, 90)
}

function createWindow() {
  win = new BrowserWindow({
    ...PET_SIZE,
    show: false,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    hasShadow: false,
    thickFrame: false,
    fullscreenable: false,
    focusable: false,
    roundedCorners: false,
    title: ' ',
    backgroundColor: '#00ffffff',
    paintWhenInitiallyHidden: true,
    webPreferences: {
      preload: join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  })

  win.setMenuBarVisibility(false)
  win.setTitle(' ')
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })
  keepPinned(win)
  pinOnTop(win)
  setupTransparentGuards(win)
  placeWindow('pet')
  win.setIgnoreMouseEvents(true, { forward: true })

  loadPage(win)

  win.once('ready-to-show', () => {
    if (!win) return
    win.setBackgroundColor('#00000000')
    setTimeout(() => {
      if (!win) return
      win.setBackgroundColor('#00000000')
      win.showInactive()
      pinOnTop(win)
      clearWindowShape()
      setTimeout(() => {
        void refreshWeather(true).catch(() => undefined)
      }, 2500)
    }, 120)
  })
  startPetSense()
}

function createTray() {
  tray = new Tray(createTrayIcon())
  tray.setToolTip('BbPet 桌宠')
  const menu = Menu.buildFromTemplate([
    { label: '显示 / 隐藏', click: () => toggleWindow() },
    { label: '今天去哪', click: () => showPanel('hub') },
    { label: '去上学', click: () => void showWorld() },
    { label: '回家', click: () => void goHome() },
    { label: '好友', click: () => void showFriends() },
    { label: '聊一聊', click: () => showPanel('chat') },
    { label: '现在看看天气', click: () => void pushOnce('weather') },
    { label: '现在看看新闻', click: () => void pushOnce('news') },
    { label: '设置', click: () => showPanel('settings') },
    { type: 'separator' },
    testActionMenu(),
    { type: 'separator' },
    { label: '退出', click: () => app.quit() },
  ])
  tray.setContextMenu(menu)
  tray.on('click', () => toggleWindow())
}

function toggleWindow() {
  if (!win) return
  if (win.isVisible()) {
    hidePanel()
    hideBubble()
    win.hide()
  } else {
    win.showInactive()
    pinOnTop(win)
  }
}

function sendUi(channel: string, payload?: unknown) {
  win?.webContents.send(channel, payload)
}

async function refreshWeather(withBubble = false) {
  const { settings } = store.get()
  const weather = await fetchWeather(settings.cityName, settings.latitude, settings.longitude)
  lastWeather = weather
  sendUi('weather', weather)
  if (withBubble) {
    const weatherPayload = {
      kind: 'weather',
      text: weather.dressLine,
    }
    sendUi('push-bubble', weatherPayload)
    showBubble(weatherPayload)
  }
  return weather
}

async function pushOnce(kind: 'auto' | 'weather' | 'news') {
  if (!win) return
  const { pet } = store.get()
  try {
    const useWeather = kind === 'weather' || (kind === 'auto' && pushToggle % 2 === 0)
    pushToggle += 1
    if (useWeather) {
      await refreshWeather(true)
    } else {
      const news = await fetchNews()
      const newsPayload = {
        kind: 'news',
        text: `${pet.name}：[${news.source}] ${news.title}`,
        url: news.url,
      }
      sendUi('push-bubble', newsPayload)
      showBubble(newsPayload)
    }
  } catch {
    const infoPayload = {
      kind: 'info',
      text: `${pet.name}：外网有点安静，我稍后再探探天气和新闻。`,
    }
    sendUi('push-bubble', infoPayload)
    showBubble(infoPayload)
  }
}

function restartPushTimer() {
  if (pushTimer) clearInterval(pushTimer)
  if (weatherTimer) clearInterval(weatherTimer)
  const minutes = Math.max(5, store.get().settings.pushIntervalMin || 30)
  pushTimer = setInterval(() => void pushOnce('auto'), minutes * 60 * 1000)
  weatherTimer = setInterval(() => void refreshWeather(true).catch(() => undefined), 20 * 60 * 1000)
}

function registerIpc() {
  ipcMain.handle('get-state', () => store.get())

  ipcMain.handle('save-pet', (_event, pet: PetProfile) => {
    store.savePet(pet)
    broadcastState()
    if (roomClient.get().connected) {
      const state = store.get()
      void roomClient.ensure(state.settings.roomUrl.trim() || DEFAULT_ROOM_URL, state.clientId, state.pet)
    }
    return store.get()
  })

  ipcMain.handle('save-settings', async (_event, settings: AppSettings) => {
    store.saveSettings(settings)
    restartPushTimer()
    void refreshWeather(false).catch(() => undefined)
    await syncRoomHost()
    if (roomClient.get().connected || roomClient.get().connecting) {
      const state = store.get()
      await roomClient.ensure(state.settings.roomUrl.trim() || DEFAULT_ROOM_URL, state.clientId, state.pet)
    }
    broadcastState()
    return store.get()
  })

  ipcMain.handle('mark-onboarded', () => {
    store.markOnboarded()
    return store.get()
  })

  ipcMain.handle('chat', async (_event, content: string) => {
    const state = store.get()
    const history = [...state.chatHistory, { role: 'user' as const, content }]
    const result = await chatWithLlm(
      state.settings,
      history,
      state.pet.name,
      SPECIES_LABELS[state.pet.species],
    )
    const next = [...history, { role: 'assistant' as const, content: result.reply }]
    store.saveChat(next)
    broadcastState()
    return { ...result, history: store.get().chatHistory }
  })

  ipcMain.handle('fetch-weather', async () => lastWeather || refreshWeather(false))

  ipcMain.handle('fetch-news', async () => fetchNews())

  ipcMain.handle('room-host-info', () => ({
    hosting: Boolean(roomServer),
    error: roomHostError,
    urls: lanRoomUrls(DEFAULT_ROOM_PORT),
  }))

  ipcMain.handle('world-status', () => worldStatus())
  ipcMain.handle('room-state', () => roomClient.get())

  ipcMain.on('room-send', (_event, msg: ClientMsg) => {
    if (!msg || typeof msg.type !== 'string') return
    roomClient.send(msg)
  })
  ipcMain.on('go-home', (_event, ownerId?: string) => {
    void goHome(typeof ownerId === 'string' && ownerId ? ownerId : undefined)
  })
  ipcMain.on('leave-home', () => leaveHome())
  ipcMain.on('pet-layout', (_event, size: { width: number; height: number }) => {
    if (!size || typeof size.width !== 'number' || typeof size.height !== 'number') return
    const gathering = isHomeGathering(roomClient.get().you, roomClient.get().homePeople, store.get().clientId)
    const next = {
      width: Math.max(gathering ? 148 : 80, Math.min(800, Math.round(size.width))),
      height: Math.max(gathering ? 148 : 108, Math.min(560, Math.round(size.height))),
    }
    if (next.width === petLayout.width && next.height === petLayout.height) return
    petLayout = next
    placeWindow()
  })

  ipcMain.on('set-ignore-mouse', (_event, ignore: boolean) => {
    applyIgnoreMouse(ignore)
  })

  ipcMain.on('set-window-shape', (_event, rects: ShapeRect[]) => {
    if (!Array.isArray(rects) || rects.length === 0) return
    applyWindowShape(rects)
  })

  ipcMain.on('resize-window', (_event, mode: WindowMode) => {
    placeWindow(mode)
  })

  ipcMain.on('drag-start', () => startDrag())
  ipcMain.on('drag-end', () => endDrag())

  ipcMain.on('pet-menu', () => popupPetMenu())

  ipcMain.on('open-panel', (_event, kind: PanelKind) => {
    if (kind === 'friends') void ensureRoom()
    showPanel(kind)
  })
  ipcMain.on('close-panel', () => hidePanel())
  ipcMain.on('open-world', () => void showWorld())
  ipcMain.on('close-world', () => hideWorld())
  ipcMain.on('close-game', () => destroyGameWindow())
  ipcMain.on('leave-world', () => leaveWorld())
  ipcMain.on('open-url', (_event, url: string) => {
    if (!/^https?:\/\//i.test(url)) return
    openExternalQuiet(url)
  })
  ipcMain.on('show-line', (_event, text: string) => {
    if (typeof text !== 'string') return
    const line = text.replace(/\s+/g, ' ').trim().slice(0, 80)
    if (!line) return
    showBubble({ kind: 'info', text: line })
  })
  ipcMain.on('bubble-size', (_event, size: { width: number; height: number }) => {
    if (!bubbleWin || !bubblePayload) return
    const width = Math.ceil(size.width)
    const height = Math.ceil(size.height)
    if (width < 40 || height < 28) return
    bubbleSize = {
      width: Math.min(320, width),
      height: Math.min(240, height),
    }
    bubbleWin.setBackgroundColor('#00000000')
    bubbleWin.setSize(bubbleSize.width, bubbleSize.height)
    placeBubble()
    bubbleWin.showInactive()
    pinOnTop(bubbleWin)
  })
  ipcMain.on('quit-app', () => app.quit())
}

app.whenReady().then(() => {
  store = new JsonStore()
  bindRoomClient()
  registerIpc()
  app.on('web-contents-created', (_event, contents) => {
    contents.on('before-input-event', (_inputEvent, input) => {
      if (input.type === 'keyDown' && input.key && input.key.length <= 2) noteTyping()
    })
  })
  const start = () => {
    createWindow()
    createTray()
    restartPushTimer()
    screen.on('display-metrics-changed', () => pinDeskPet())
    void syncRoomHost().then(() => void ensureRoom())
  }
  if (process.platform === 'win32') setTimeout(start, 160)
  else start()
})

app.on('before-quit', () => {
  quitting = true
  if (weatherTimer) clearInterval(weatherTimer)
  stopPetSense()
  roomClient.disconnect()
  roomServer?.close()
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

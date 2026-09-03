import { app, BrowserWindow, Menu, nativeImage, screen, shell, Tray, ipcMain } from 'electron'
import { execFile } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import type { Server } from 'node:http'
import { networkInterfaces } from 'node:os'
import { join } from 'node:path'
import { SPECIES_LABELS, type AppSettings, type PanelKind, type PetProfile, type PushBubble, type WindowMode } from '../shared/types'
import { DEFAULT_ROOM_PORT, DEFAULT_ROOM_URL, homePlaceId, isHomeGathering, placeTitle, type ClientMsg } from '../shared/world'
import { startRoomServer } from '../server/roomServer'
import { loadDotEnv } from './env'
import { RoomClient } from './roomClient'
import { fetchNews } from './services/news'
import { chatWithLlm } from './services/llm'
import { fetchWeather, formatWeatherLine } from './services/weather'
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
let menuAnchor: BrowserWindow | null = null
let tray: Tray | null = null
let store: JsonStore
let pushTimer: NodeJS.Timeout | null = null
let pushToggle = 0
let quitting = false
let allowPanelBlurClose = false
let panelKind: PanelKind | null = null
let panelClosedAt = 0
let roomServer: Server | null = null
let roomHostError = ''
let leaveWorldNext = false
let worldResizeTimer: NodeJS.Timeout | null = null
const roomClient = new RoomClient()

const PET_SIZE = { width: 80, height: 108 }
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
    const x = wa.x + wa.width - size.width - 8
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
    setTimeout(() => {
      win?.setAlwaysOnTop(true)
      panelWin?.setAlwaysOnTop(true)
    }, 600)
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

function isLocalRoom(url: string) {
  return !url || /127\.0\.0\.1|localhost/i.test(url)
}

async function ensureRoom() {
  if (!roomServer && isLocalRoom(store.get().settings.roomUrl)) {
    try {
      roomServer = await startRoomServer(DEFAULT_ROOM_PORT, {
        friendsFile: join(app.getPath('userData'), 'bbpet-friends.json'),
      })
      roomHostError = ''
    } catch {
      roomHostError = ''
    }
  }
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
  roomClient.onChange = () => {
    const view = roomClient.get()
    win?.webContents.send('room-state', view)
    panelWin?.webContents.send('room-state', view)
    worldWin?.webContents.send('room-state', view)
    broadcastWorldStatus()
    if (view.notice && view.notice !== lastNotice) {
      lastNotice = view.notice
      const payload = { kind: 'info', text: view.notice }
      sendUi('push-bubble', payload)
      showBubble(payload)
    }
    if (!view.notice) lastNotice = ''
    const gathering = isHomeGathering(view.you, view.homePeople, store.get().clientId)
    if (win && !win.isDestroyed()) win.setFocusable(gathering)
    if (gathering) {
      const n = Math.max(1, 1 + view.homePeople.length)
      const cols = Math.min(n, 5)
      const rows = Math.ceil(n / 5)
      const next = { width: Math.max(240, cols * 80), height: rows * 108 + 76 }
      if (next.width !== petLayout.width || next.height !== petLayout.height) {
        petLayout = next
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
}

function nativeHwnd(target: BrowserWindow) {
  const buf = target.getNativeWindowHandle()
  return buf.length >= 8 ? buf.readBigUInt64LE(0).toString() : buf.readUInt32LE(0).toString()
}

type ShapeRect = { x: number; y: number; w: number; h: number }
let lastShape: ShapeRect[] = []
let shapeBusy = false
let shapeTimer: NodeJS.Timeout | null = null

function scaleShape(target: BrowserWindow, rects: ShapeRect[]) {
  const scale = screen.getDisplayMatching(target.getBounds()).scaleFactor || 1
  return rects.map((rect) => ({
    x: Math.round(rect.x * scale),
    y: Math.round(rect.y * scale),
    w: Math.max(1, Math.round(rect.w * scale)),
    h: Math.max(1, Math.round(rect.h * scale)),
  }))
}

function applyWindowShape(rects: ShapeRect[]) {
  if (!win || win.isDestroyed() || process.platform !== 'win32' || rects.length === 0) return
  lastShape = rects
  if (shapeBusy) {
    if (shapeTimer) clearTimeout(shapeTimer)
    shapeTimer = setTimeout(() => applyWindowShape(lastShape), 120)
    return
  }
  const source = join(__dirname, 'apply-shape.ps1')
  if (!existsSync(source)) return
  shapeBusy = true
  try {
    const script = join(app.getPath('temp'), 'bbpet-apply-shape.ps1')
    const rectFile = join(app.getPath('temp'), 'bbpet-shape.txt')
    writeFileSync(script, readFileSync(source, 'utf8'))
    writeFileSync(rectFile, scaleShape(win, rects).map((rect) => `${rect.x},${rect.y},${rect.w},${rect.h}`).join(';'))
    execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script, '-Hwnd', nativeHwnd(win), '-RectFile', rectFile],
      { windowsHide: true },
      () => {
        shapeBusy = false
      },
    )
  } catch {
    shapeBusy = false
  }
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
      if (lastShape.length) applyWindowShape(lastShape)
      setTimeout(() => void pushOnce('auto'), 4000)
    }, 120)
  })
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
  }
}

function sendUi(channel: string, payload?: unknown) {
  win?.webContents.send(channel, payload)
}

async function pushOnce(kind: 'auto' | 'weather' | 'news') {
  if (!win) return
  const { settings, pet } = store.get()
  try {
    const useWeather = kind === 'weather' || (kind === 'auto' && pushToggle % 2 === 0)
    pushToggle += 1
    if (useWeather) {
      const weather = await fetchWeather(settings.cityName, settings.latitude, settings.longitude)
      const weatherPayload = {
        kind: 'weather',
        text: `${pet.name}：${formatWeatherLine(weather)}，记得出门看一眼天。`,
      }
      sendUi('push-bubble', weatherPayload)
      showBubble(weatherPayload)
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
  const minutes = Math.max(5, store.get().settings.pushIntervalMin || 30)
  pushTimer = setInterval(() => void pushOnce('auto'), minutes * 60 * 1000)
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

  ipcMain.handle('fetch-weather', async () => {
    const { settings } = store.get()
    return fetchWeather(settings.cityName, settings.latitude, settings.longitude)
  })

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
    const next = {
      width: Math.max(80, Math.min(800, Math.round(size.width))),
      height: Math.max(108, Math.min(560, Math.round(size.height))),
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
  ipcMain.on('leave-world', () => leaveWorld())
  ipcMain.on('open-url', (_event, url: string) => {
    if (!/^https?:\/\//i.test(url)) return
    openExternalQuiet(url)
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
  })
  ipcMain.on('quit-app', () => app.quit())
}

app.whenReady().then(() => {
  store = new JsonStore()
  bindRoomClient()
  registerIpc()
  const start = () => {
    createWindow()
    createTray()
    restartPushTimer()
    void syncRoomHost().then(() => void ensureRoom())
  }
  if (process.platform === 'win32') setTimeout(start, 160)
  else start()
})

app.on('before-quit', () => {
  quitting = true
  roomClient.disconnect()
  roomServer?.close()
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

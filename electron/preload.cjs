const { contextBridge, ipcRenderer } = require('electron')

const api = {
  getState: () => ipcRenderer.invoke('get-state'),
  savePet: (pet) => ipcRenderer.invoke('save-pet', pet),
  saveSettings: (settings) => ipcRenderer.invoke('save-settings', settings),
  markOnboarded: () => ipcRenderer.invoke('mark-onboarded'),
  chat: (content) => ipcRenderer.invoke('chat', content),
  fetchWeather: () => ipcRenderer.invoke('fetch-weather'),
  fetchNews: () => ipcRenderer.invoke('fetch-news'),
  roomHostInfo: () => ipcRenderer.invoke('room-host-info'),
  worldStatus: () => ipcRenderer.invoke('world-status'),
  roomState: () => ipcRenderer.invoke('room-state'),
  roomSend: (msg) => ipcRenderer.send('room-send', msg),
  goHome: (ownerId) => ipcRenderer.send('go-home', ownerId),
  leaveHome: () => ipcRenderer.send('leave-home'),
  setIgnoreMouse: (ignore) => ipcRenderer.send('set-ignore-mouse', ignore),
  setWindowShape: (rects) => ipcRenderer.send('set-window-shape', rects),
  resizeWindow: (mode) => ipcRenderer.send('resize-window', mode),
  reportPetLayout: (size) => ipcRenderer.send('pet-layout', size),
  dragStart: () => ipcRenderer.send('drag-start'),
  dragEnd: () => ipcRenderer.send('drag-end'),
  popupPetMenu: () => ipcRenderer.send('pet-menu'),
  openPanel: (kind) => ipcRenderer.send('open-panel', kind),
  closePanel: () => ipcRenderer.send('close-panel'),
  openWorld: () => ipcRenderer.send('open-world'),
  closeWorld: () => ipcRenderer.send('close-world'),
  closeGame: () => ipcRenderer.send('close-game'),
  leaveWorld: () => ipcRenderer.send('leave-world'),
  openUrl: (url) => ipcRenderer.send('open-url', url),
  reportBubbleSize: (width, height) => ipcRenderer.send('bubble-size', { width, height }),
  showLine: (text) => ipcRenderer.send('show-line', text),
  quit: () => ipcRenderer.send('quit-app'),
  onPlayDemo: (handler) => {
    const listener = (_event, id) => handler(id)
    ipcRenderer.on('play-demo', listener)
    return () => ipcRenderer.removeListener('play-demo', listener)
  },
  onPush: (handler) => {
    const listener = (_event, payload) => handler(payload)
    ipcRenderer.on('push-bubble', listener)
    return () => ipcRenderer.removeListener('push-bubble', listener)
  },
  onShowBubble: (handler) => {
    const listener = (_event, payload) => handler(payload)
    ipcRenderer.on('show-bubble', listener)
    return () => ipcRenderer.removeListener('show-bubble', listener)
  },
  onBubbleClosed: (handler) => {
    const listener = () => handler()
    ipcRenderer.on('bubble-closed', listener)
    return () => ipcRenderer.removeListener('bubble-closed', listener)
  },
  onOpenChat: (handler) => {
    const listener = () => handler()
    ipcRenderer.on('open-chat', listener)
    return () => ipcRenderer.removeListener('open-chat', listener)
  },
  onOpenSettings: (handler) => {
    const listener = () => handler()
    ipcRenderer.on('open-settings', listener)
    return () => ipcRenderer.removeListener('open-settings', listener)
  },
  onStateChanged: (handler) => {
    const listener = (_event, state) => handler(state)
    ipcRenderer.on('state-changed', listener)
    return () => ipcRenderer.removeListener('state-changed', listener)
  },
  onSetPanel: (handler) => {
    const listener = (_event, kind) => handler(kind)
    ipcRenderer.on('set-panel', listener)
    return () => ipcRenderer.removeListener('set-panel', listener)
  },
  onPanelClosed: (handler) => {
    const listener = () => handler()
    ipcRenderer.on('panel-closed', listener)
    return () => ipcRenderer.removeListener('panel-closed', listener)
  },
  onWorldStatus: (handler) => {
    const listener = (_event, payload) => handler(payload)
    ipcRenderer.on('world-status', listener)
    return () => ipcRenderer.removeListener('world-status', listener)
  },
  onRoomState: (handler) => {
    const listener = (_event, payload) => handler(payload)
    ipcRenderer.on('room-state', listener)
    return () => ipcRenderer.removeListener('room-state', listener)
  },
  onPetPlay: (handler) => {
    const listener = (_event, payload) => handler(payload)
    ipcRenderer.on('pet-play', listener)
    return () => ipcRenderer.removeListener('pet-play', listener)
  },
  onWeather: (handler) => {
    const listener = (_event, payload) => handler(payload)
    ipcRenderer.on('weather', listener)
    return () => ipcRenderer.removeListener('weather', listener)
  },
}

contextBridge.exposeInMainWorld('bbpet', api)

import { spawn } from 'node:child_process'
import { randomUUID } from 'node:crypto'
import { existsSync, mkdirSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const userData = join(root, '.bbpet-pet2')
const stateFile = join(userData, 'bbpet-state.json')
const electron = createRequire(import.meta.url)('electron')

mkdirSync(userData, { recursive: true })

if (!existsSync(stateFile)) {
  writeFileSync(
    stateFile,
    JSON.stringify(
      {
        onboarded: true,
        clientId: randomUUID(),
        pet: {
          name: '豆豆2',
          species: 'cat',
          colors: {
            outline: '#3D2C29',
            body: '#F4A261',
            shadow: '#E0762F',
            light: '#FFE0B8',
            accent: '#E76F51',
            eye: '#FFF8F0',
            pupil: '#2B211E',
            blush: '#FFB4C8',
          },
        },
        settings: {
          apiBaseUrl: process.env.LLM_BASE_URL || 'https://openrouter.ai/api/v1',
          apiKey: process.env.OPENROUTER_API_KEY || process.env.LLM_API_KEY || '',
          model: process.env.LLM_MODEL || 'minimax/minimax-m3:free',
          fallbackModel: process.env.LLM_FALLBACK_MODEL || 'minimax/minimax-m2.7:free',
          cityId: 'beijing',
          cityName: '北京',
          latitude: 39.9042,
          longitude: 116.4074,
          pushIntervalMin: 30,
          roomUrl: 'ws://127.0.0.1:18765',
          hostRoom: false,
          worldWidth: 820,
          worldHeight: 560,
        },
        chatHistory: [],
      },
      null,
      2,
    ),
    'utf8',
  )
}

if (!existsSync(join(root, 'dist-electron', 'main.js'))) {
  console.error('请先在另一个窗口运行 npm start，等第一个桌宠出来后再开测试号。')
  process.exit(1)
}

const child = spawn(electron, [root, `--user-data-dir=${userData}`], {
  cwd: root,
  env: {
    ...process.env,
    VITE_DEV_SERVER_URL: process.env.VITE_DEV_SERVER_URL || 'http://localhost:5173/',
    BBPET_OFFSET_X: process.env.BBPET_OFFSET_X || '110',
  },
  stdio: 'inherit',
  windowsHide: false,
})

child.on('exit', (code) => process.exit(code ?? 0))

import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

declare const __dirname: string

function runtimeDir() {
  try {
    return __dirname
  } catch {
    return process.cwd()
  }
}

export function loadDotEnv() {
  const here = runtimeDir()
  const candidates = [
    join(process.cwd(), '.env'),
    join(here, '../.env'),
    join(here, '../../.env'),
  ]
  for (const file of candidates) {
    if (!existsSync(file)) continue
    const text = readFileSync(file, 'utf8')
    for (const rawLine of text.split(/\r?\n/)) {
      const line = rawLine.trim()
      if (!line || line.startsWith('#')) continue
      const eq = line.indexOf('=')
      if (eq < 0) continue
      const key = line.slice(0, eq).trim()
      let value = line.slice(eq + 1).trim()
      if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1)
      }
      if (!process.env[key]) process.env[key] = value
    }
    break
  }
}

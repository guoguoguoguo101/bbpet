/// <reference types="vite/client" />

import type { BbPetApi } from '../electron/preload'

declare global {
  interface Window {
    bbpet: BbPetApi
  }
}

export {}

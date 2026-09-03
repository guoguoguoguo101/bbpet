import { copyFileSync, mkdirSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import electron from 'vite-plugin-electron'
import renderer from 'vite-plugin-electron-renderer'

function copyPreload(): Plugin {
  const write = () => {
    mkdirSync('dist-electron', { recursive: true })
    copyFileSync(resolve('electron/preload.cjs'), resolve('dist-electron/preload.cjs'))
    copyFileSync(resolve('electron/apply-shape.ps1'), resolve('dist-electron/apply-shape.ps1'))
  }
  return {
    name: 'copy-preload',
    writeBundle: write,
    closeBundle: write,
  }
}

export default defineConfig({
  plugins: [
    react(),
    electron({
      entry: 'electron/main.ts',
      vite: {
        plugins: [copyPreload()],
        build: {
          outDir: 'dist-electron',
          rollupOptions: {
            external: ['electron', 'ws', 'bufferutil', 'utf-8-validate'],
            output: {
              format: 'cjs',
              entryFileNames: 'main.js',
              inlineDynamicImports: true,
            },
          },
        },
      },
    }),
    renderer(),
  ],
})

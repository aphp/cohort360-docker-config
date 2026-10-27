/// <reference types="vitest" />
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'
import svgr from 'vite-plugin-svgr'

import { buildDevProxy } from './vite-dev-proxy'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const proxy = buildDevProxy(env)
  const proxyKeys = Object.keys(proxy)

  if (mode === 'development') {
    if (proxyKeys.length > 0) {
      console.info(`[admin-portal] dev proxy /api/back → ${proxy['/api/back'].target}`)
    } else if ((env.VITE_BACK_API_URL ?? '').startsWith('/')) {
      console.warn(
        '[admin-portal] Aucun VITE_DEV_PROXY_BACK/BACK_URL : les URLs relatives VITE_BACK_API_URL ne seront pas routées.'
      )
    }
  }

  return {
    build: {
      outDir: 'build'
    },
    server: {
      port: 3000,
      ...(proxyKeys.length > 0 ? { proxy } : {})
    },
    plugins: [react(), tsconfigPaths(), svgr()],
    test: {
      globals: true,
      environment: 'jsdom',
      setupFiles: ['./src/setupTests.ts'],
      css: false,
      coverage: {
        provider: 'v8',
        reporter: ['text', 'lcov'],
        reportsDirectory: './coverage',
        include: ['src/**/*.{ts,tsx}'],
        exclude: [
          'src/**/*.test.{ts,tsx}',
          'src/setupTests.ts',
          'src/react-app-env.d.ts',
          'src/index.tsx',
          'src/assets/**'
        ]
      }
    }
  }
})

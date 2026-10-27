import type { ProxyOptions } from 'vite'

/**
 * Proxy dev : même principe que Cohort360-FrontEnd/vite-dev-proxy.ts.
 * VITE_DEV_PROXY_BACK (ou BACK_URL à défaut) vide = proxy désactivé.
 */
function tlsVerify(envVal: string | undefined): boolean {
  const x = (envVal ?? 'true').trim().toLowerCase()
  return !['0', 'false', 'no'].includes(x)
}

export function buildDevProxy(env: Record<string, string | undefined>): Record<string, ProxyOptions> {
  const proxy: Record<string, ProxyOptions> = {}
  const back = (env.VITE_DEV_PROXY_BACK || env.BACK_URL)?.trim()

  if (back) {
    proxy['/api/back'] = {
      target: back,
      changeOrigin: true,
      secure: tlsVerify(env.VITE_DEV_PROXY_SECURE),
      rewrite: (path) => path.replace(/^\/api\/back/, '') || '/'
    }
  }

  return proxy
}

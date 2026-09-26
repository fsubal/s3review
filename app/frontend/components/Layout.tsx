import { Link, router, usePage } from '@inertiajs/react'
import type { ReactNode } from 'react'

export function Layout({ children }: { children: ReactNode }) {
  const { auth, config, flash } = usePage().props

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      <header className="border-b border-gray-200 bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <div className="flex items-center gap-4">
            <Link href="/objects" className="text-lg font-semibold">
              s3review
            </Link>
            <span className="text-sm text-gray-500">
              s3://{config.bucket}/{config.target_prefix}
            </span>
          </div>
          <nav className="flex items-center gap-4 text-sm">
            {auth.identity && (
              <Link href="/whoami" className="text-gray-700 hover:underline" title={`provider: ${auth.provider}`}>
                {auth.identity.email}
                {auth.identity.role === 'admin' && <span className="ml-1 rounded bg-gray-800 px-1.5 py-0.5 text-xs text-white">admin</span>}
              </Link>
            )}
            {auth.provider === 'developer' && auth.identity && (
              <button type="button" className="text-gray-500 hover:underline" onClick={() => router.delete('/dev/logout')}>
                ログアウト
              </button>
            )}
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 py-6">
        {flash.notice && <p className="mb-4 rounded border border-green-200 bg-green-50 px-3 py-2 text-sm text-green-800">{flash.notice}</p>}
        {flash.alert && <p className="mb-4 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">{flash.alert}</p>}
        {children}
      </main>
    </div>
  )
}

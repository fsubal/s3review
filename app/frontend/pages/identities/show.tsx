import { Head } from '@inertiajs/react'
import type { Identity } from '@/types'

type Props = {
  identity: Identity
  provider: Record<string, string | string[] | null>
  admin_emails_configured: boolean
  headers_present: string[]
}

export default function IdentitiesShow({ identity, provider, admin_emails_configured, headers_present }: Props) {
  return (
    <>
      <Head title="whoami" />
      <h1 className="mb-4 text-xl font-semibold">あなたは誰として見えているか</h1>
      <div className="grid gap-4 md:grid-cols-2">
        <section className="rounded border border-gray-200 bg-white p-4 text-sm">
          <h2 className="mb-2 font-semibold text-gray-700">身元</h2>
          <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
            <dt className="text-gray-500">email</dt>
            <dd>{identity.email}</dd>
            <dt className="text-gray-500">name</dt>
            <dd>{identity.name}</dd>
            <dt className="text-gray-500">role</dt>
            <dd>
              {identity.role}
              {!admin_emails_configured && <span className="ml-2 text-xs text-amber-700">ADMIN_EMAILS が未設定のため admin はいません</span>}
            </dd>
          </dl>
        </section>
        <section className="rounded border border-gray-200 bg-white p-4 text-sm">
          <h2 className="mb-2 font-semibold text-gray-700">認証プロバイダ</h2>
          <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
            {Object.entries(provider).map(([k, v]) => (
              <div key={k} className="contents">
                <dt className="text-gray-500">{k}</dt>
                <dd className={k === 'warning' ? 'text-amber-700' : 'break-all'}>{Array.isArray(v) ? v.join(', ') : String(v)}</dd>
              </div>
            ))}
          </dl>
          <h3 className="mt-4 mb-1 font-semibold text-gray-700">届いている認証ヘッダ</h3>
          {headers_present.length === 0 ? (
            <p className="text-gray-500">なし</p>
          ) : (
            <ul className="list-disc pl-5">
              {headers_present.map((h) => (
                <li key={h}>
                  <code>{h}</code>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </>
  )
}

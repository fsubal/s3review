import { Head, Link, router, usePage } from '@inertiajs/react'
import { STATUS_LABELS, StatusBadge } from '@/components/StatusBadge'
import type { ReviewStatus, ReviewedObject } from '@/types'
import { breadcrumbsOf, formatBytes, formatDate } from '@/utils/format'

type Props = {
  prefix: string
  status: ReviewStatus | null
  folders: string[]
  objects: ReviewedObject[]
  pagination: { page: number; per: number; total: number }
  counts: Partial<Record<ReviewStatus, number>>
  indexed: boolean
  last_indexed_at: string | null
}

const STATUS_ORDER: ReviewStatus[] = ['pending', 'approved', 'changes_requested', 'rejected']

export default function ObjectsIndex({ prefix, status, folders, objects, pagination, counts, indexed, last_indexed_at }: Props) {
  const { auth, config } = usePage().props
  const total = Object.values(counts).reduce((a, b) => a + (b ?? 0), 0)
  const pages = Math.max(1, Math.ceil(pagination.total / pagination.per))
  const query = (next: { prefix?: string; status?: ReviewStatus | null; page?: number }) => {
    const params = new URLSearchParams()
    const p = next.prefix ?? prefix
    const s = next.status === undefined ? status : next.status
    if (p) params.set('prefix', p)
    if (s) params.set('status', s)
    if (next.page && next.page > 1) params.set('page', String(next.page))
    const qs = params.toString()
    return `/objects${qs ? `?${qs}` : ''}`
  }

  return (
    <>
      <Head title="オブジェクト一覧" />
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <nav className="text-sm">
          <Link href={query({ prefix: '' })} className="text-blue-700 hover:underline">
            {config.target_prefix || '/'}
          </Link>
          {breadcrumbsOf(prefix).map((b) => (
            <span key={b.prefix}>
              <span className="mx-1 text-gray-400">/</span>
              <Link href={query({ prefix: b.prefix })} className="text-blue-700 hover:underline">
                {b.label}
              </Link>
            </span>
          ))}
        </nav>
        <div className="flex items-center gap-2 text-xs text-gray-500">
          {last_indexed_at && <span>最終索引: {formatDate(last_indexed_at)}</span>}
          {auth.identity?.role === 'admin' && (
            <button type="button" onClick={() => router.post('/reindex')} className="rounded border border-gray-300 bg-white px-2 py-1 hover:bg-gray-100">
              再索引
            </button>
          )}
        </div>
      </div>

      <div className="mb-4 flex flex-wrap gap-2 text-sm">
        <Link href={query({ status: null })} className={`rounded px-3 py-1 ${status ? 'bg-white border border-gray-300' : 'bg-gray-800 text-white'}`}>
          すべて {total}
        </Link>
        {STATUS_ORDER.map((s) => (
          <Link key={s} href={query({ status: s })} className={`rounded px-3 py-1 ${status === s ? 'bg-gray-800 text-white' : 'bg-white border border-gray-300'}`}>
            {STATUS_LABELS[s]} {counts[s] ?? 0}
          </Link>
        ))}
      </div>

      {!indexed && (
        <div className="rounded border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
          <p className="font-medium">索引がまだありません。</p>
          <p className="mt-1">
            起動時に再索引ジョブがキューに入ります。数秒待ってから再読み込みしてください。ジョブワーカーが動いていない場合は{' '}
            <code className="rounded bg-white px-1">bin/rails review:reindex</code> を実行してください。
          </p>
        </div>
      )}

      <table className="w-full border-collapse overflow-hidden rounded border border-gray-200 bg-white text-sm">
        <thead className="bg-gray-100 text-left text-xs uppercase text-gray-600">
          <tr>
            <th className="px-3 py-2">名前</th>
            <th className="px-3 py-2">ステータス</th>
            <th className="px-3 py-2">種類</th>
            <th className="px-3 py-2 text-right">サイズ</th>
            <th className="px-3 py-2">更新日時</th>
          </tr>
        </thead>
        <tbody>
          {folders.map((f) => (
            <tr key={f} className="border-t border-gray-100 hover:bg-gray-50">
              <td className="px-3 py-2" colSpan={5}>
                <Link href={query({ prefix: prefix + f })} className="text-blue-700 hover:underline">
                  📁 {f}
                </Link>
              </td>
            </tr>
          ))}
          {objects.map((o) => (
            <tr key={o.key} className="border-t border-gray-100 hover:bg-gray-50">
              <td className="px-3 py-2">
                <Link href={`/objects/${o.key}`} className="text-blue-700 hover:underline">
                  {status ? o.key.slice(config.target_prefix.length + prefix.length) : o.name}
                </Link>
              </td>
              <td className="px-3 py-2">
                <StatusBadge status={o.status} />
              </td>
              <td className="px-3 py-2 text-gray-600">{o.content_type ?? '-'}</td>
              <td className="px-3 py-2 text-right text-gray-600">{formatBytes(o.size)}</td>
              <td className="px-3 py-2 text-gray-600">{formatDate(o.last_modified)}</td>
            </tr>
          ))}
          {folders.length === 0 && objects.length === 0 && (
            <tr>
              <td className="px-3 py-6 text-center text-gray-500" colSpan={5}>
                オブジェクトがありません
              </td>
            </tr>
          )}
        </tbody>
      </table>

      {pages > 1 && (
        <nav className="mt-4 flex items-center justify-center gap-3 text-sm">
          {pagination.page > 1 && (
            <Link href={query({ page: pagination.page - 1 })} className="text-blue-700 hover:underline">
              ← 前
            </Link>
          )}
          <span className="text-gray-600">
            {pagination.page} / {pages}
          </span>
          {pagination.page < pages && (
            <Link href={query({ page: pagination.page + 1 })} className="text-blue-700 hover:underline">
              次 →
            </Link>
          )}
        </nav>
      )}
    </>
  )
}

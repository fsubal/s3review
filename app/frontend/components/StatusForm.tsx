import { router } from '@inertiajs/react'
import { useState } from 'react'
import { STATUS_LABELS, StatusBadge } from '@/components/StatusBadge'
import type { ReviewStatus, ReviewedObject } from '@/types'
import { formatDate } from '@/utils/format'

const ACTIONS: Array<{ status: ReviewStatus; className: string }> = [
  { status: 'approved', className: 'bg-green-600 hover:bg-green-700 text-white' },
  { status: 'changes_requested', className: 'bg-amber-500 hover:bg-amber-600 text-white' },
  { status: 'rejected', className: 'bg-red-600 hover:bg-red-700 text-white' },
  { status: 'pending', className: 'bg-gray-200 hover:bg-gray-300 text-gray-800' },
]

export function StatusForm({ object }: { object: ReviewedObject }) {
  const [busy, setBusy] = useState(false)

  const update = (status: ReviewStatus) => {
    setBusy(true)
    router.patch(`/objects/${object.key}/status`, { status }, { preserveScroll: true, onFinish: () => setBusy(false) })
  }

  return (
    <section className="rounded border border-gray-200 bg-white p-4">
      <h2 className="mb-2 text-sm font-semibold text-gray-700">承認ステータス</h2>
      <div className="mb-3 flex items-center gap-2 text-sm">
        <StatusBadge status={object.status} />
        {object.reviewer && (
          <span className="text-gray-500">
            {object.reviewer} · {formatDate(object.status_updated_at)}
          </span>
        )}
      </div>
      <div className="flex flex-wrap gap-2">
        {ACTIONS.filter((a) => a.status !== object.status).map((a) => (
          <button
            key={a.status}
            type="button"
            disabled={busy}
            onClick={() => update(a.status)}
            className={`rounded px-3 py-1.5 text-sm disabled:opacity-50 ${a.className}`}
          >
            {STATUS_LABELS[a.status]}
          </button>
        ))}
      </div>
    </section>
  )
}

import { useForm } from '@inertiajs/react'
import type { Comment, ReviewedObject } from '@/types'
import { formatDate } from '@/utils/format'

export function CommentThread({ object, comments }: { object: ReviewedObject; comments: Comment[] }) {
  const form = useForm({ body: '' })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post(`/objects/${object.key}/comments`, { preserveScroll: true, onSuccess: () => form.reset() })
  }

  return (
    <section className="rounded border border-gray-200 bg-white p-4">
      <h2 className="mb-3 text-sm font-semibold text-gray-700">コメント ({comments.length})</h2>
      <ul className="space-y-3">
        {comments.length === 0 && <li className="text-sm text-gray-500">まだコメントはありません</li>}
        {comments.map((c) => (
          <li key={c.id} className="rounded bg-gray-50 p-3 text-sm">
            <div className="mb-1 flex items-baseline justify-between gap-2 text-xs text-gray-500">
              <span className="font-medium text-gray-700">{c.author_name ?? c.author_email}</span>
              <time dateTime={c.created_at}>{formatDate(c.created_at)}</time>
            </div>
            <p className="whitespace-pre-wrap">{c.body}</p>
          </li>
        ))}
      </ul>
      <form onSubmit={submit} className="mt-4 space-y-2">
        <textarea
          value={form.data.body}
          onChange={(e) => form.setData('body', e.target.value)}
          rows={3}
          placeholder="ファイル全体へのコメント（位置指定コメントは今後対応）"
          className="w-full rounded border border-gray-300 p-2 text-sm"
        />
        {form.errors.body && <p className="text-xs text-red-600">{form.errors.body}</p>}
        <div className="text-right">
          <button type="submit" disabled={form.processing} className="rounded bg-gray-800 px-3 py-1.5 text-sm text-white disabled:opacity-50">
            投稿
          </button>
        </div>
      </form>
    </section>
  )
}

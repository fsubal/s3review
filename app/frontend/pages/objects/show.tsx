import { Head, Link } from '@inertiajs/react'
import { CommentThread } from '@/components/CommentThread'
import { Preview } from '@/components/Preview'
import { StatusForm } from '@/components/StatusForm'
import type { Comment, Preview as PreviewData, ReviewedObject } from '@/types'
import { formatBytes, formatDate } from '@/utils/format'

type Props = {
  object: ReviewedObject
  comments: Comment[]
  preview: PreviewData
}

export default function ObjectsShow({ object, comments, preview }: Props) {
  const parentPrefix = object.key.includes('/') ? object.key.slice(0, object.key.lastIndexOf('/') + 1) : ''

  return (
    <>
      <Head title={object.name} />
      <div className="mb-4 text-sm">
        <Link href="/objects" className="text-blue-700 hover:underline">
          一覧
        </Link>
        {parentPrefix && (
          <>
            <span className="mx-1 text-gray-400">/</span>
            <span className="text-gray-600">{parentPrefix}</span>
          </>
        )}
      </div>

      <div className="mb-4 flex flex-wrap items-start justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold break-all">{object.name}</h1>
          <p className="mt-1 text-xs text-gray-500">
            {object.content_type ?? '不明'} · {formatBytes(object.size)} · 更新 {formatDate(object.last_modified)} · ETag {object.etag}
          </p>
        </div>
        <a href={preview.download_url} className="rounded border border-gray-300 bg-white px-3 py-1.5 text-sm hover:bg-gray-100">
          ダウンロード
        </a>
      </div>

      <div className="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(320px,1fr)]">
        <div className="overflow-hidden rounded border border-gray-200 bg-white">
          <Preview object={object} preview={preview} />
        </div>
        <div className="space-y-4">
          <StatusForm object={object} />
          <CommentThread object={object} comments={comments} />
        </div>
      </div>
    </>
  )
}

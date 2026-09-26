import type { Preview as PreviewData, ReviewedObject } from '@/types'

/**
 * content_type に応じてプレビューを出し分ける。
 * ブラウザは presigned URL で S3 から直接取得する（アプリを経由しない）。
 * 位置指定コメント（画像領域・動画時間・PDF ページ）はここに W3C Annotation の selector を重ねていく予定
 */
export function Preview({ object, preview }: { object: ReviewedObject; preview: PreviewData }) {
  switch (preview.kind) {
    case 'image':
      return (
        <div className="flex items-center justify-center bg-[repeating-conic-gradient(#f3f4f6_0%_25%,#fff_0%_50%)] bg-[length:20px_20px] p-4">
          <img src={preview.url} alt={object.name} className="max-h-[70vh] max-w-full object-contain" />
        </div>
      )
    case 'video':
      return <video src={preview.url} controls className="max-h-[70vh] w-full bg-black" />
    case 'audio':
      return (
        <div className="p-6">
          <audio src={preview.url} controls className="w-full" />
        </div>
      )
    case 'pdf':
      return <iframe src={preview.url} title={object.name} className="h-[75vh] w-full" />
    case 'text':
      return (
        <div>
          <pre className="max-h-[70vh] overflow-auto p-4 text-sm leading-relaxed">{preview.text}</pre>
          {preview.truncated && <p className="border-t border-gray-200 px-4 py-2 text-xs text-gray-500">先頭 256KB のみ表示しています</p>}
        </div>
      )
    default:
      return (
        <div className="p-10 text-center text-sm text-gray-600">
          <p>この形式（{object.content_type ?? '不明'}）はブラウザでプレビューできません。</p>
          <a href={preview.download_url} className="mt-3 inline-block rounded bg-gray-800 px-3 py-1.5 text-white">
            ダウンロードしてレビュー
          </a>
        </div>
      )
  }
}

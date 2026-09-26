import { Head } from '@inertiajs/react'

export default function Unauthenticated({ provider }: { provider: Record<string, string | string[] | null> }) {
  return (
    <>
      <Head title="認証されていません" />
      <div className="mx-auto max-w-xl rounded border border-red-200 bg-white p-6 text-sm">
        <h1 className="mb-2 text-lg font-semibold text-red-800">認証情報が届いていません</h1>
        <p className="mb-3 text-gray-700">
          このアプリは前段のプロキシ（{String(provider.provider)}）が付ける認証ヘッダを前提にしています。プロキシを経由せずにアクセスしているか、プロキシの設定（audience など）が合っていない可能性があります。
        </p>
        <pre className="overflow-auto rounded bg-gray-50 p-3 text-xs">{JSON.stringify(provider, null, 2)}</pre>
      </div>
    </>
  )
}

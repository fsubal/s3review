import { Head } from '@inertiajs/react'

export default function Forbidden() {
  return (
    <>
      <Head title="権限がありません" />
      <div className="mx-auto max-w-xl rounded border border-gray-200 bg-white p-6 text-sm">
        <h1 className="mb-2 text-lg font-semibold">この操作には admin 権限が必要です</h1>
        <p className="text-gray-700">ADMIN_EMAILS にあなたのメールアドレスを追加してください。</p>
      </div>
    </>
  )
}

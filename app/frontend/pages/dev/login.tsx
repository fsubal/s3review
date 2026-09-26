import { Head, useForm } from '@inertiajs/react'

export default function DevLogin({ warning }: { warning: string }) {
  const form = useForm({ email: '', name: '' })

  return (
    <>
      <Head title="開発用ログイン" />
      <div className="mx-auto max-w-md rounded border border-gray-200 bg-white p-6">
        <h1 className="mb-1 text-lg font-semibold">開発用ログイン</h1>
        <p className="mb-4 text-xs text-amber-700">{warning}</p>
        <form
          onSubmit={(e) => {
            e.preventDefault()
            form.post('/dev/login')
          }}
          className="space-y-3"
        >
          <label className="block text-sm">
            <span className="text-gray-700">メールアドレス</span>
            <input
              type="email"
              required
              value={form.data.email}
              onChange={(e) => form.setData('email', e.target.value)}
              className="mt-1 w-full rounded border border-gray-300 p-2"
            />
            {form.errors.email && <p className="mt-1 text-xs text-red-600">{form.errors.email}</p>}
          </label>
          <label className="block text-sm">
            <span className="text-gray-700">表示名（任意）</span>
            <input value={form.data.name} onChange={(e) => form.setData('name', e.target.value)} className="mt-1 w-full rounded border border-gray-300 p-2" />
          </label>
          <button type="submit" disabled={form.processing} className="w-full rounded bg-gray-800 py-2 text-sm text-white disabled:opacity-50">
            ログイン
          </button>
        </form>
      </div>
    </>
  )
}

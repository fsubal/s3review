export function formatBytes(bytes: number | null): string {
  if (bytes === null || bytes === undefined) return '-'
  if (bytes < 1024) return `${bytes} B`
  const units = ['KB', 'MB', 'GB', 'TB']
  let value = bytes / 1024
  let i = 0
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024
    i++
  }
  return `${value.toFixed(value < 10 ? 1 : 0)} ${units[i]}`
}

export function formatDate(iso: string | null): string {
  if (!iso) return '-'
  return new Date(iso).toLocaleString()
}

/** "a/b/c.png" → [["a", "a/"], ["b", "a/b/"]] のように、prefix ナビ用のパンくずを作る */
export function breadcrumbsOf(prefix: string): Array<{ label: string; prefix: string }> {
  const parts = prefix.split('/').filter(Boolean)
  return parts.map((label, i) => ({ label, prefix: parts.slice(0, i + 1).join('/') + '/' }))
}

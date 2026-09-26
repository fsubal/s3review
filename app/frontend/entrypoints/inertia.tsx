import { createInertiaApp } from '@inertiajs/react'
import type { ReactNode } from 'react'
import { Layout } from '@/components/Layout'

type PageModule = {
  default: React.ComponentType & { layout?: (page: ReactNode) => ReactNode }
}

const pages = import.meta.glob<PageModule>('../pages/**/*.tsx', { eager: true })

void createInertiaApp({
  resolve: (name) => {
    const page = pages[`../pages/${name}.tsx`]
    if (!page) throw new Error(`Unknown page: ${name}`)
    page.default.layout ??= (children) => <Layout>{children}</Layout>
    return page
  },

  strictMode: true,

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({ queryStringArrayFormat: 'brackets' }),
  },
}).catch((error) => {
  if (document.getElementById('app')) throw error
})

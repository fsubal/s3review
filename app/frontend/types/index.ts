export type FlashData = {
  notice?: string
  alert?: string
}

export type Identity = {
  email: string
  name: string
  provider: string
  role: 'admin' | 'reviewer'
}

export type SharedProps = {
  auth: {
    identity: Identity | null
    provider: string
    login_path: string | null
  }
  config: {
    bucket: string
    target_prefix: string
    status_strategy: 'tags' | 'sidecar'
  }
  flash: FlashData
}

export type ReviewStatus = 'pending' | 'approved' | 'changes_requested' | 'rejected'

export type ReviewedObject = {
  bucket: string
  key: string
  name: string
  etag: string | null
  size: number | null
  content_type: string | null
  kind: 'image' | 'video' | 'audio' | 'pdf' | 'text' | 'other'
  last_modified: string | null
  status: ReviewStatus
  status_updated_at: string | null
  reviewer: string | null
  indexed_at: string | null
}

export type Comment = {
  id: string
  author_email: string
  author_name: string | null
  body: string
  selector: unknown | null
  created_at: string
}

export type Preview = {
  kind: ReviewedObject['kind']
  download_url: string
  url?: string
  text?: string
  truncated?: boolean
}

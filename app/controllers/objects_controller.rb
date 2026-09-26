# frozen_string_literal: true

class ObjectsController < InertiaController
  PER_PAGE = 100
  TEXT_PREVIEW_BYTES = 256.kilobytes

  def index
    relative_prefix = ObjectStore::Config.normalize_prefix(params[:prefix].to_s)
    full_prefix = ObjectStore.config.target_prefix + relative_prefix
    status = params[:status].presence
    status = nil unless ReviewedObject::STATUSES.include?(status.to_s) || status.nil?

    scope = ReviewedObject.in_bucket(bucket)
    if status
      # ステータスで絞るときはフォルダを無視して prefix 以下を平らに並べる（「承認済み一覧」の意味）
      files = scope.under(full_prefix).with_status(status)
      folders = []
    else
      files = scope.direct_children_of(full_prefix)
      folders = ReviewedObject.child_prefixes_of(bucket, full_prefix)
    end

    page = [ params[:page].to_i, 1 ].max
    total = files.count
    objects = files.order(:key).offset((page - 1) * PER_PAGE).limit(PER_PAGE)

    render inertia: "objects/index", props: {
      prefix: relative_prefix,
      status: status,
      folders: folders,
      objects: objects.map(&:as_json),
      pagination: { page: page, per: PER_PAGE, total: total },
      counts: scope.under(full_prefix).group(:status).count,
      indexed: scope.exists?,
      last_indexed_at: scope.maximum(:indexed_at)&.iso8601
    }
  end

  def show
    key = target_key!(params[:key])
    record = ReviewedObject.sync_from_s3!(key) or raise ActiveRecord::RecordNotFound
    comments = record.replace_comments!(object_store.comment_store.list(key))

    render inertia: "objects/show", props: {
      object: record.as_json,
      comments: comments.map(&:as_json),
      preview: preview_for(record),
      statuses: ReviewedObject::STATUSES
    }
  end

  private

  def preview_for(record)
    client = object_store.client
    preview = { kind: record.kind, download_url: client.presigned_url(record.key, inline: false) }
    case record.kind
    when "image", "video", "audio"
      preview[:url] = client.presigned_url(record.key)
    when "pdf"
      preview[:url] = client.presigned_url(record.key, content_type: "application/pdf")
    when "text"
      text = client.read_head(record.key, max_bytes: TEXT_PREVIEW_BYTES).to_s
      preview[:text] = text.dup.force_encoding("UTF-8").scrub("�")
      preview[:truncated] = record.size.to_i > TEXT_PREVIEW_BYTES
    end
    preview
  end
end

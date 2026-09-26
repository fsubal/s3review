# frozen_string_literal: true

# レビュー対象オブジェクト（S3 の一覧 + 承認ステータス）の SQLite 上の写し。
# 真実は S3 側にあり、この行は ReindexJob や sync_from_s3! で作り直せる。
class ReviewedObject < ApplicationRecord
  STATUSES = ObjectStore::StatusStore::STATUSES

  has_many :comments, -> { order(:ulid) }, dependent: :destroy

  validates :key, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :in_bucket, ->(bucket) { where(bucket: bucket) }
  scope :with_status, ->(status) { status.present? ? where(status: status) : all }
  scope :under, ->(prefix) { prefix.present? ? where("key LIKE ? ESCAPE '\\'", "#{sanitize_sql_like(prefix)}%") : all }

  # prefix の直下にあるファイル（それ以上 "/" を含まないもの）
  scope :direct_children_of, ->(prefix) {
    under(prefix).where("substr(key, ?) NOT LIKE '%/%'", prefix.length + 1)
  }

  # prefix の直下にある「フォルダ」名（"foo/" の形）を返す
  def self.child_prefixes_of(bucket, prefix)
    offset = prefix.length + 1
    in_bucket(bucket).under(prefix)
      .where("substr(key, ?) LIKE '%/%'", offset)
      .distinct
      .pluck(Arel.sql("substr(key, #{offset.to_i}, instr(substr(key, #{offset.to_i}), '/'))"))
      .sort
  end

  # S3 から 1 件読み直して upsert する。オブジェクトが無ければ行を消して nil を返す
  def self.sync_from_s3!(key, client: ObjectStore.client, status_store: ObjectStore.status_store)
    head = client.head(key)
    if head.nil?
      in_bucket(client.bucket).where(key: key).destroy_all
      return nil
    end

    record = find_or_initialize_by(bucket: client.bucket, key: key)
    record.apply_head(head)
    record.apply_status(status_store.read(key) || ObjectStore::StatusStore::Status.pending)
    record.indexed_at = Time.current
    record.save!
    record
  end

  def apply_head(head)
    self.etag = head.etag
    self.size = head.size
    self.content_type = head.content_type
    self.last_modified = head.last_modified
  end

  def apply_status(status)
    self.status = status.status
    self.status_updated_at = status.updated_at
    self.reviewer = status.reviewer
  end

  # S3 上のコメント一覧で comments テーブルを置き換える
  def replace_comments!(annotations)
    transaction do
      comments.destroy_all
      annotations.each { |annotation| Comment.upsert_from_annotation!(self, annotation) }
    end
    comments.reload
  end

  def name = key.split("/").last.to_s
  def basename = name

  # プレビューの出し分けに使う大分類
  def kind
    type = content_type.to_s
    return "image" if type.start_with?("image/")
    return "video" if type.start_with?("video/")
    return "audio" if type.start_with?("audio/")
    return "pdf" if type == "application/pdf"
    return "text" if type.start_with?("text/") || %w[application/json application/xml application/javascript].include?(type.split(";").first)
    "other"
  end

  def as_json(*)
    {
      "bucket" => bucket, "key" => key, "name" => name, "etag" => etag, "size" => size,
      "content_type" => content_type, "kind" => kind,
      "last_modified" => last_modified&.iso8601,
      "status" => status, "status_updated_at" => status_updated_at&.iso8601, "reviewer" => reviewer,
      "indexed_at" => indexed_at&.iso8601
    }
  end
end

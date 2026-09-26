# frozen_string_literal: true

module ObjectStore
  # バケットをクロールして SQLite の索引（reviewed_objects / comments）を作り直す。
  # ステータスはオブジェクトごとに読む（tags 戦略なら GetObjectTagging が N 回飛ぶ。数千件までは許容。
  # 大規模化したら S3 イベント通知や S3 Inventory で差分化する）。
  class Indexer
    Result = Struct.new(:objects, :comments, :removed, keyword_init: true)

    def initialize(client: ObjectStore.client, config: ObjectStore.config, status_store: ObjectStore.status_store, comment_store: ObjectStore.comment_store)
      @client = client
      @config = config
      @status_store = status_store
      @comment_store = comment_store
    end

    def run
      started_at = Time.current
      objects = index_objects(started_at)
      comments = index_comments
      removed = ReviewedObject.in_bucket(@client.bucket).where("indexed_at < ?", started_at).destroy_all.size
      Result.new(objects: objects, comments: comments, removed: removed)
    end

    private

    def index_objects(started_at)
      count = 0
      @client.each_object(prefix: @config.target_prefix) do |entry|
        next if skip?(entry.key)

        record = ReviewedObject.find_or_initialize_by(bucket: @client.bucket, key: entry.key)
        if record.new_record? || record.etag != entry.etag || record.content_type.nil?
          head = @client.head(entry.key) or next
          record.apply_head(head)
        end
        record.apply_status(@status_store.read(entry.key) || StatusStore::Status.pending)
        record.indexed_at = started_at
        record.save!
        count += 1
      end
      count
    end

    def index_comments
      count = 0
      seen = Set.new
      @comment_store.each_annotation do |annotation|
        bucket, key = Annotation.parse_source(annotation.dig("target", "source"))
        next unless bucket == @client.bucket && key

        record = ReviewedObject.in_bucket(bucket).find_by(key: key) or next
        Comment.upsert_from_annotation!(record, annotation)
        seen << Annotation.ulid_of(annotation)
        count += 1
      end
      Comment.where.not(ulid: seen.to_a).delete_all
      count
    end

    # サイドカーの prefix と、"フォルダ" を表す 0 バイトのプレースホルダは対象外
    def skip?(key)
      key.end_with?("/") ||
        (@config.review_prefix_in_target_bucket? && key.start_with?(@config.review_prefix))
    end
  end
end

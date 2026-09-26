# frozen_string_literal: true

module ObjectStore
  module StatusStore
    class Tags
      # タグ値の制約（S3: 256 文字、使える記号は + - = . _ : / @ と空白）に収まる値だけを書く。
      # ISO8601 の日時とメールアドレスはそのまま入る
      STATUS_TAG = "review-status"
      UPDATED_AT_TAG = "review-updated-at"
      REVIEWER_TAG = "review-reviewer"

      def initialize(client:, config:)
        @client = client
        @config = config
      end

      def read(key)
        tags = @client.get_tags(key)
        return nil if tags.nil?
        return Status.pending unless tags.key?(STATUS_TAG)

        Status.new(
          status: STATUSES.include?(tags[STATUS_TAG]) ? tags[STATUS_TAG] : DEFAULT,
          updated_at: tags[UPDATED_AT_TAG].presence && Time.iso8601(tags[UPDATED_AT_TAG]),
          reviewer: tags[REVIEWER_TAG].presence
        )
      rescue ArgumentError
        Status.new(status: tags[STATUS_TAG], updated_at: nil, reviewer: tags[REVIEWER_TAG].presence)
      end

      def write(key, status:, reviewer:, now: Time.now.utc)
        StatusStore.validate!(status)
        @client.merge_tags(key, {
          STATUS_TAG => status,
          UPDATED_AT_TAG => now.iso8601,
          REVIEWER_TAG => reviewer.to_s.gsub(/[^A-Za-z0-9 +\-=._:\/@]/, "_")[0, 256]
        })
        Status.new(status: status, updated_at: now, reviewer: reviewer)
      end
    end
  end
end

# frozen_string_literal: true

module ObjectStore
  # 承認ステータスの読み書き。バックエンドによって置き場所を切り替える:
  #   tags    — オブジェクトタグ（AWS S3 / MinIO / Ceph RGW）。コピー不要で更新でき、ライフサイクルやポリシーの条件にも使える
  #   sidecar — <review_prefix>objects/<sha256(key)>/status.json（タグのない GCS などの逃げ道）
  module StatusStore
    STATUSES = %w[pending approved changes_requested rejected].freeze
    DEFAULT = "pending"

    Status = Struct.new(:status, :updated_at, :reviewer, keyword_init: true) do
      def self.pending = new(status: DEFAULT)
      def pending? = status == DEFAULT
    end

    def self.for(strategy, client:, config:)
      case strategy
      when "tags" then Tags.new(client: client, config: config)
      when "sidecar" then Sidecar.new(client: client, config: config)
      else raise Error, "unknown STATUS_STRATEGY: #{strategy}"
      end
    end

    def self.validate!(status)
      raise ArgumentError, "invalid status: #{status}" unless STATUSES.include?(status)
      status
    end
  end
end

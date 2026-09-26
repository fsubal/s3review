# frozen_string_literal: true

module ObjectStore
  # 環境変数から組み立てる設定。README の env 一覧と対応させる
  Config = Struct.new(
    :endpoint,            # S3_ENDPOINT: MinIO / Ceph / GCS など S3 互換 API のエンドポイント。AWS なら未設定
    :public_endpoint,     # S3_PUBLIC_ENDPOINT: presigned URL に使うエンドポイント（ブラウザから見えるホスト）。未設定なら endpoint
    :region,              # S3_REGION
    :access_key_id,       # S3_ACCESS_KEY_ID（未設定なら SDK の既定の認証チェーン）
    :secret_access_key,   # S3_SECRET_ACCESS_KEY
    :force_path_style,    # S3_FORCE_PATH_STYLE: MinIO などは true
    :bucket,              # S3_BUCKET: レビュー対象のバケット
    :target_prefix,       # TARGET_PREFIX: レビュー対象の prefix（"" で全体）
    :review_bucket,       # REVIEW_BUCKET: サイドカーを置くバケット。未設定なら bucket と同じ
    :review_prefix,       # REVIEW_PREFIX: サイドカーを置く prefix（既定 ".review/"）
    :status_strategy,     # STATUS_STRATEGY: tags | sidecar
    :presign_expires_in,  # PRESIGN_EXPIRES_IN: presigned URL の有効秒数
    keyword_init: true
  ) do
    STATUS_STRATEGIES = %w[tags sidecar].freeze

    def self.from_env(env = ENV)
      endpoint = env["S3_ENDPOINT"].presence
      new(
        endpoint: endpoint,
        public_endpoint: env["S3_PUBLIC_ENDPOINT"].presence || endpoint,
        region: env.fetch("S3_REGION", "us-east-1"),
        access_key_id: env["S3_ACCESS_KEY_ID"].presence,
        secret_access_key: env["S3_SECRET_ACCESS_KEY"].presence,
        force_path_style: env.fetch("S3_FORCE_PATH_STYLE", endpoint ? "true" : "false") == "true",
        bucket: env["S3_BUCKET"].presence,
        target_prefix: env.fetch("TARGET_PREFIX", ""),
        review_bucket: env["REVIEW_BUCKET"].presence || env["S3_BUCKET"].presence,
        review_prefix: normalize_prefix(env.fetch("REVIEW_PREFIX", ".review/")),
        status_strategy: env.fetch("STATUS_STRATEGY", "tags"),
        presign_expires_in: env.fetch("PRESIGN_EXPIRES_IN", "900").to_i
      ).tap(&:validate!)
    end

    def self.normalize_prefix(prefix)
      prefix = prefix.to_s.delete_prefix("/")
      prefix.empty? || prefix.end_with?("/") ? prefix : "#{prefix}/"
    end

    def validate!
      raise Error, "S3_BUCKET is required" if bucket.blank?
      raise Error, "REVIEW_PREFIX must not be empty when REVIEW_BUCKET is the target bucket" if review_bucket == bucket && review_prefix.empty?
      raise Error, "STATUS_STRATEGY must be one of #{STATUS_STRATEGIES.join(', ')}" unless STATUS_STRATEGIES.include?(status_strategy)
      self
    end

    # サイドカーが同じバケットにあるとき、一覧から除外すべきか
    def review_prefix_in_target_bucket?
      review_bucket == bucket
    end
  end
end

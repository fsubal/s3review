# frozen_string_literal: true

# S3 互換ストレージとのやりとりをまとめる名前空間。
# 「S3 が真実の源、SQLite は再構築可能なキャッシュ」という設計なので、
# コメントや承認ステータスの読み書きはすべてこの下のクラスを通る。
module ObjectStore
  class Error < StandardError; end
  class NotFound < Error; end

  class << self
    def config
      @config ||= Config.from_env
    end

    def client
      @client ||= Client.new(config)
    end

    def status_store
      @status_store ||= StatusStore.for(config.status_strategy, client: client, config: config)
    end

    def comment_store
      @comment_store ||= CommentStore.new(client: client, config: config)
    end

    # テストや設定変更時にメモ化をやり直す
    def reset!(config: nil, client: nil)
      @config = config
      @client = client
      @status_store = nil
      @comment_store = nil
    end

    # レビュー対象のキーごとに、サイドカーを置く prefix。キーをそのまま使うと長さ制限や
    # 特殊文字の問題があるので SHA-256 で畳む
    def sidecar_prefix(key)
      "#{config.review_prefix}objects/#{Digest::SHA256.hexdigest(key)}/"
    end
  end
end

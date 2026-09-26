# frozen_string_literal: true

require "aws-sdk-s3"

module ObjectStore
  # Aws::S3::Client の薄いラッパ。バックエンド差分（MinIO の path-style、GCS の presign 等）と
  # JSON / タグの読み書きをここに閉じ込める。
  class Client
    Listing = Struct.new(:objects, :prefixes, :next_token, keyword_init: true)
    Entry = Struct.new(:key, :etag, :size, :last_modified, keyword_init: true)
    Head = Struct.new(:key, :etag, :size, :content_type, :last_modified, :metadata, keyword_init: true)

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def bucket = config.bucket
    def review_bucket = config.review_bucket

    # 1 ページ分の一覧。delimiter を渡すとディレクトリ風に common prefixes も返す
    def list(prefix:, bucket: self.bucket, delimiter: nil, token: nil, max_keys: 1000)
      response = s3.list_objects_v2(
        bucket: bucket, prefix: prefix, delimiter: delimiter,
        continuation_token: token, max_keys: max_keys
      )
      Listing.new(
        objects: response.contents.map { |o| Entry.new(key: o.key, etag: strip_quotes(o.etag), size: o.size, last_modified: o.last_modified) },
        prefixes: response.common_prefixes.map(&:prefix),
        next_token: response.is_truncated ? response.next_continuation_token : nil
      )
    end

    # prefix 以下の全オブジェクトを Enumerator で返す（ページングを隠す）
    def each_object(prefix:, bucket: self.bucket)
      return to_enum(:each_object, prefix: prefix, bucket: bucket) unless block_given?

      token = nil
      loop do
        page = list(prefix: prefix, bucket: bucket, token: token)
        page.objects.each { |entry| yield entry }
        token = page.next_token
        break if token.nil?
      end
    end

    def head(key, bucket: self.bucket)
      response = s3.head_object(bucket: bucket, key: key)
      Head.new(
        key: key, etag: strip_quotes(response.etag), size: response.content_length,
        content_type: response.content_type, last_modified: response.last_modified,
        metadata: response.metadata
      )
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      nil
    end

    # テキストプレビュー用。先頭 max_bytes だけ読む
    def read_head(key, max_bytes:, bucket: self.bucket)
      response = s3.get_object(bucket: bucket, key: key, range: "bytes=0-#{max_bytes - 1}")
      response.body.read
    rescue Aws::S3::Errors::InvalidRange
      "" # 0 バイトのオブジェクト
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    def get_json(key, bucket: review_bucket)
      response = s3.get_object(bucket: bucket, key: key)
      JSON.parse(response.body.read)
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      nil
    end

    def put_json(key, payload, bucket: review_bucket)
      s3.put_object(bucket: bucket, key: key, body: JSON.pretty_generate(payload), content_type: "application/json")
      payload
    end

    def delete(key, bucket: review_bucket)
      s3.delete_object(bucket: bucket, key: key)
    end

    def get_tags(key, bucket: self.bucket)
      s3.get_object_tagging(bucket: bucket, key: key).tag_set.to_h { |t| [ t.key, t.value ] }
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      nil
    end

    # PutObjectTagging は全置換なので、既存のタグを読んでからマージして書く。
    # nil の値を渡したキーは削除する
    def merge_tags(key, changes, bucket: self.bucket)
      current = get_tags(key, bucket: bucket) || {}
      merged = current.merge(changes.transform_values { |v| v&.to_s }).compact
      s3.put_object_tagging(
        bucket: bucket, key: key,
        tagging: { tag_set: merged.map { |k, v| { key: k, value: v } } }
      )
      merged
    end

    # ブラウザが直接取得するための URL。S3_PUBLIC_ENDPOINT があればそのホストで署名する
    def presigned_url(key, bucket: self.bucket, inline: true, content_type: nil)
      params = { bucket: bucket, key: key, expires_in: config.presign_expires_in }
      params[:response_content_disposition] = inline ? "inline" : "attachment"
      params[:response_content_type] = content_type if content_type
      presigner.presigned_url(:get_object, **params)
    end

    def s3
      @s3 ||= Aws::S3::Client.new(**client_options(config.endpoint))
    end

    private

    def presigner
      @presigner ||= Aws::S3::Presigner.new(client: Aws::S3::Client.new(**client_options(config.public_endpoint)))
    end

    def client_options(endpoint)
      options = { region: config.region, force_path_style: config.force_path_style }
      options[:endpoint] = endpoint if endpoint
      if config.access_key_id && config.secret_access_key
        options[:credentials] = Aws::Credentials.new(config.access_key_id, config.secret_access_key)
      end
      options
    end

    def strip_quotes(etag)
      etag&.delete('"')
    end
  end
end

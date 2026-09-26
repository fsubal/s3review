# frozen_string_literal: true

module ObjectStore
  # ObjectStore::Client と同じインターフェースを持つインメモリ実装。テスト用
  class FakeClient
    Stored = Struct.new(:body, :content_type, :last_modified, :tags, keyword_init: true) do
      def etag = Digest::MD5.hexdigest(body)
    end

    attr_reader :config, :store

    def initialize(config)
      @config = config
      @store = {}
    end

    def bucket = config.bucket
    def review_bucket = config.review_bucket

    def put(key, body, bucket: self.bucket, content_type: "application/octet-stream", last_modified: Time.now.utc)
      @store[[ bucket, key ]] = Stored.new(body: body, content_type: content_type, last_modified: last_modified, tags: {})
    end

    def list(prefix:, bucket: self.bucket, delimiter: nil, token: nil, max_keys: 1000)
      keys = @store.keys.select { |b, k| b == bucket && k.start_with?(prefix) }.map(&:last).sort
      keys = keys.drop(token.to_i) if token
      page = keys.first(max_keys)
      objects = []
      prefixes = []
      page.each do |key|
        rest = key.delete_prefix(prefix)
        if delimiter && rest.include?(delimiter)
          prefixes << prefix + rest.split(delimiter).first + delimiter
        else
          s = @store[[ bucket, key ]]
          objects << Client::Entry.new(key: key, etag: s.etag, size: s.body.bytesize, last_modified: s.last_modified)
        end
      end
      next_token = keys.size > max_keys ? (token.to_i + max_keys).to_s : nil
      Client::Listing.new(objects: objects, prefixes: prefixes.uniq, next_token: next_token)
    end

    def each_object(prefix:, bucket: self.bucket, &block)
      return to_enum(:each_object, prefix: prefix, bucket: bucket) unless block

      token = nil
      loop do
        page = list(prefix: prefix, bucket: bucket, token: token, max_keys: 2)
        page.objects.each(&block)
        token = page.next_token
        break unless token
      end
    end

    def head(key, bucket: self.bucket)
      s = @store[[ bucket, key ]] or return nil
      Client::Head.new(key: key, etag: s.etag, size: s.body.bytesize, content_type: s.content_type, last_modified: s.last_modified, metadata: {})
    end

    def read_head(key, max_bytes:, bucket: self.bucket)
      @store[[ bucket, key ]]&.body&.byteslice(0, max_bytes)
    end

    def get_json(key, bucket: review_bucket)
      s = @store[[ bucket, key ]] or return nil
      JSON.parse(s.body)
    end

    def put_json(key, payload, bucket: review_bucket)
      put(key, JSON.generate(payload), bucket: bucket, content_type: "application/json")
      payload
    end

    def delete(key, bucket: review_bucket)
      @store.delete([ bucket, key ])
    end

    def get_tags(key, bucket: self.bucket)
      @store[[ bucket, key ]]&.tags&.dup
    end

    def merge_tags(key, changes, bucket: self.bucket)
      s = @store[[ bucket, key ]] or raise Aws::S3::Errors::NoSuchKey.new(nil, "no such key")
      s.tags = s.tags.merge(changes.transform_values { |v| v&.to_s }).compact
    end

    def presigned_url(key, bucket: self.bucket, inline: true, content_type: nil)
      "https://fake.example/#{bucket}/#{key}?inline=#{inline}#{content_type ? "&ct=#{content_type}" : ''}"
    end
  end
end

# frozen_string_literal: true

module ObjectStore
  # コメントは 1 件 = 1 オブジェクト（<review_prefix>objects/<sha256(key)>/comments/<ULID>.json）。
  # 追記のみなので同時書き込みで競合せず、CAS（If-Match）に頼らなくてよい。
  class CommentStore
    def initialize(client:, config:)
      @client = client
      @config = config
    end

    def list(key)
      prefix = comments_prefix(key)
      @client.each_object(prefix: prefix, bucket: @config.review_bucket)
             .select { |entry| entry.key.end_with?(".json") }
             .sort_by(&:key)
             .filter_map { |entry| @client.get_json(entry.key) }
    end

    def append(key, body:, creator:, selector: nil)
      ulid = Ulid.generate
      annotation = Annotation.build(
        source: Annotation.source_for(@config.bucket, key), body: body, creator: creator, selector: selector, ulid: ulid
      )
      @client.put_json("#{comments_prefix(key)}#{ulid}.json", annotation)
    end

    # 再索引用。すべてのコメントを列挙する（対象キーは annotation の target.source から復元する）
    def each_annotation
      return to_enum(:each_annotation) unless block_given?

      @client.each_object(prefix: "#{@config.review_prefix}objects/", bucket: @config.review_bucket) do |entry|
        next unless entry.key.match?(%r{/comments/[0-9A-Z]{26}\.json\z})

        annotation = @client.get_json(entry.key)
        yield annotation if annotation
      end
    end

    private

    def comments_prefix(key) = "#{ObjectStore.sidecar_prefix(key)}comments/"
  end
end

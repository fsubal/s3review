# frozen_string_literal: true

module ObjectStore
  # コメント 1 件を W3C Web Annotation Data Model（https://www.w3.org/TR/annotation-model/）の JSON として表す。
  # MVP は selector なし（ファイル全体へのコメント）だが、後で画像領域（xywh）・動画時間（t=）・PDF ページ（page=）を
  # target.selector に足すだけで位置指定コメントに拡張できる。
  module Annotation
    CONTEXT = "http://www.w3.org/ns/anno.jsonld"

    def self.build(source:, body:, creator:, selector: nil, ulid: Ulid.generate, created: Time.now.utc)
      target = { "source" => source }
      target["selector"] = selector if selector.present?
      {
        "@context" => CONTEXT,
        "id" => "urn:ulid:#{ulid}",
        "type" => "Annotation",
        "motivation" => "commenting",
        "created" => created.iso8601,
        "creator" => { "type" => "Person", "email" => creator.email, "name" => creator.name }.compact,
        "body" => { "type" => "TextualBody", "value" => body, "format" => "text/plain" },
        "target" => target
      }
    end

    def self.ulid_of(annotation)
      annotation["id"].to_s.delete_prefix("urn:ulid:")
    end

    # target.source は "s3://bucket/key" 形式
    def self.source_for(bucket, key) = "s3://#{bucket}/#{key}"

    def self.parse_source(source)
      match = source.to_s.match(%r{\As3://([^/]+)/(.+)\z})
      match && [ match[1], match[2] ]
    end
  end
end

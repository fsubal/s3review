# frozen_string_literal: true

# S3 上のコメント（W3C Annotation JSON）の写し
class Comment < ApplicationRecord
  belongs_to :reviewed_object

  validates :ulid, :author_email, :body, :commented_at, presence: true

  def self.upsert_from_annotation!(reviewed_object, annotation)
    ulid = ObjectStore::Annotation.ulid_of(annotation)
    comment = find_or_initialize_by(ulid: ulid)
    comment.reviewed_object = reviewed_object
    comment.author_email = annotation.dig("creator", "email").to_s
    comment.author_name = annotation.dig("creator", "name")
    comment.body = annotation.dig("body", "value").to_s
    comment.selector = annotation.dig("target", "selector")
    comment.commented_at = Time.iso8601(annotation["created"]) rescue Time.current
    comment.save!
    comment
  end

  # API には W3C Annotation の形で返す
  def to_annotation
    ObjectStore::Annotation.build(
      source: ObjectStore::Annotation.source_for(reviewed_object.bucket, reviewed_object.key),
      body: body,
      creator: Auth::Identity.new(email: author_email, name: author_name),
      selector: selector,
      ulid: ulid,
      created: commented_at.utc
    )
  end

  def as_json(*)
    {
      "id" => ulid, "author_email" => author_email, "author_name" => author_name,
      "body" => body, "selector" => selector, "created_at" => commented_at.iso8601
    }
  end
end

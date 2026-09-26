# frozen_string_literal: true

require "test_helper"

class ObjectStore::StoresTest < ActiveSupport::TestCase
  setup do
    fake_client.put("submissions/a/cover.png", "PNG", content_type: "image/png")
    fake_client.put("submissions/a/body.pdf", "PDF", content_type: "application/pdf")
    fake_client.put("submissions/readme.txt", "hello", content_type: "text/plain")
    fake_client.put("other/ignored.txt", "x", content_type: "text/plain")
  end

  test "CommentStore は 1 コメント 1 オブジェクトで追記し、ULID 順に返す" do
    store = ObjectStore.comment_store
    a1 = store.append("submissions/a/cover.png", body: "first", creator: identity)
    a2 = store.append("submissions/a/cover.png", body: "second", creator: identity("bob@example.com", name: "Bob"))

    keys = fake_client.store.keys.map(&:last).grep(/comments/)
    assert_equal 2, keys.size
    assert keys.all? { |k| k.start_with?(".review/objects/#{Digest::SHA256.hexdigest('submissions/a/cover.png')}/comments/") }

    listed = store.list("submissions/a/cover.png")
    assert_equal [ a1["id"], a2["id"] ], listed.map { |a| a["id"] }
    assert_equal "http://www.w3.org/ns/anno.jsonld", a1["@context"]
    assert_equal "s3://test-bucket/submissions/a/cover.png", a1.dig("target", "source")
    assert_nil a1.dig("target", "selector"), "MVP はファイル全体へのコメントなので selector は持たない"
    assert_equal "Bob", a2.dig("creator", "name")
    assert_empty store.list("submissions/a/body.pdf")
  end

  test "StatusStore::Tags はオブジェクトタグに書き、他のタグを壊さない" do
    fake_client.store[[ "test-bucket", "submissions/a/cover.png" ]].tags = { "project" => "x" }
    store = ObjectStore::StatusStore.for("tags", client: fake_client, config: fake_client.config)

    assert store.read("submissions/a/cover.png").pending?
    written = store.write("submissions/a/cover.png", status: "approved", reviewer: "alice@example.com")
    assert_equal "approved", written.status

    tags = fake_client.get_tags("submissions/a/cover.png")
    assert_equal "x", tags["project"]
    assert_equal "approved", tags["review-status"]
    assert_equal "alice@example.com", tags["review-reviewer"]
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, tags["review-updated-at"])

    read = store.read("submissions/a/cover.png")
    assert_equal "approved", read.status
    assert_equal "alice@example.com", read.reviewer
    assert_in_delta Time.now, read.updated_at, 5
    assert_nil store.read("submissions/missing.png")
    assert_raises(ArgumentError) { store.write("submissions/a/cover.png", status: "bogus", reviewer: "x") }
  end

  test "StatusStore::Sidecar はレビュー用 prefix の JSON に書く" do
    store = ObjectStore::StatusStore.for("sidecar", client: fake_client, config: fake_client.config)
    assert store.read("submissions/a/body.pdf").pending?
    store.write("submissions/a/body.pdf", status: "rejected", reviewer: "alice@example.com")

    json = fake_client.get_json(".review/objects/#{Digest::SHA256.hexdigest('submissions/a/body.pdf')}/status.json")
    assert_equal "rejected", json["status"]
    assert_equal "s3://test-bucket/submissions/a/body.pdf", json["source"]
    assert_equal "rejected", store.read("submissions/a/body.pdf").status
    assert_empty fake_client.get_tags("submissions/a/body.pdf"), "sidecar 戦略ではタグを触らない"
  end

  test "Indexer は TARGET_PREFIX 以下を索引し、サイドカーと対象外を除き、消えたものを削除する" do
    ObjectStore.status_store.write("submissions/a/cover.png", status: "approved", reviewer: "alice@example.com")
    ObjectStore.comment_store.append("submissions/a/cover.png", body: "hi", creator: identity)
    ObjectStore.comment_store.append("submissions/readme.txt", body: "text comment", creator: identity)
    ReviewedObject.create!(bucket: "test-bucket", key: "submissions/gone.txt", indexed_at: 1.day.ago)

    result = ObjectStore::Indexer.new.run
    assert_equal 3, result.objects
    assert_equal 2, result.comments
    assert_equal 1, result.removed

    keys = ReviewedObject.order(:key).pluck(:key)
    assert_equal %w[submissions/a/body.pdf submissions/a/cover.png submissions/readme.txt], keys
    cover = ReviewedObject.find_by!(key: "submissions/a/cover.png")
    assert_equal "approved", cover.status
    assert_equal "image/png", cover.content_type
    assert_equal 1, cover.comments.count
    assert_equal "hi", cover.comments.first.body

    # 2 回目は冪等
    ObjectStore::Indexer.new.run
    assert_equal 3, ReviewedObject.count
    assert_equal 2, Comment.count
  end

  test "ReviewedObject.sync_from_s3! は 1 件だけ読み直し、無くなっていれば行を消す" do
    record = ReviewedObject.sync_from_s3!("submissions/readme.txt")
    assert_equal "text", record.kind
    assert_equal 5, record.size

    fake_client.delete("submissions/readme.txt", bucket: "test-bucket")
    assert_nil ReviewedObject.sync_from_s3!("submissions/readme.txt")
    assert_nil ReviewedObject.find_by(key: "submissions/readme.txt")
  end

  test "ULID は 26 文字で時刻順にソートできる" do
    a = ObjectStore::Ulid.generate(time: Time.at(1_700_000_000))
    b = ObjectStore::Ulid.generate(time: Time.at(1_700_000_001))
    assert_equal 26, a.length
    assert_match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/, a)
    assert a < b
  end

  test "Config は S3_BUCKET を必須にし、prefix を正規化する" do
    assert_raises(ObjectStore::Error) { ObjectStore::Config.from_env({}) }
    config = ObjectStore::Config.from_env("S3_BUCKET" => "b", "REVIEW_PREFIX" => "/meta", "S3_ENDPOINT" => "http://minio:9000")
    assert_equal "meta/", config.review_prefix
    assert config.force_path_style, "エンドポイント指定時は path-style が既定"
    assert_equal "http://minio:9000", config.public_endpoint
    assert_raises(ObjectStore::Error) { ObjectStore::Config.from_env("S3_BUCKET" => "b", "STATUS_STRATEGY" => "metadata") }
  end
end

# frozen_string_literal: true

require "test_helper"

# 実際の S3 互換ストレージ（RustFS / versitygw / MinIO / AWS など）に対する統合テスト。
#   S3_TEST_ENDPOINT=http://localhost:9000 S3_TEST_BUCKET=s3review-test \
#   S3_TEST_ACCESS_KEY_ID=rustfsadmin S3_TEST_SECRET_ACCESS_KEY=rustfsadmin bin/rails test test/lib/object_store/s3_compat_test.rb
class ObjectStore::S3CompatTest < ActiveSupport::TestCase
  setup do
    skip "S3_TEST_ENDPOINT が未設定なので実ストレージのテストは飛ばす" if ENV["S3_TEST_ENDPOINT"].blank?

    @config = ObjectStore::Config.from_env(
      "S3_ENDPOINT" => ENV["S3_TEST_ENDPOINT"],
      "S3_BUCKET" => ENV.fetch("S3_TEST_BUCKET", "s3review-test"),
      "S3_ACCESS_KEY_ID" => ENV["S3_TEST_ACCESS_KEY_ID"],
      "S3_SECRET_ACCESS_KEY" => ENV["S3_TEST_SECRET_ACCESS_KEY"],
      "TARGET_PREFIX" => "it-#{SecureRandom.hex(4)}/",
      "REVIEW_PREFIX" => ".review-test/"
    )
    @client = ObjectStore::Client.new(@config)
    ObjectStore.reset!(config: @config, client: @client)
    begin
      @client.s3.create_bucket(bucket: @config.bucket)
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
      nil
    end
    @key = "#{@config.target_prefix}dir/photo.png"
    @client.s3.put_object(bucket: @config.bucket, key: @key, body: "png-bytes", content_type: "image/png")
  end

  teardown do
    next if @client.nil?

    [ @config.target_prefix, @config.review_prefix ].each do |prefix|
      @client.each_object(prefix: prefix).each { |e| @client.s3.delete_object(bucket: @config.bucket, key: e.key) }
    end
    ObjectStore.reset!
  end

  test "一覧・HEAD・タグ・JSON・presigned URL が実ストレージで動く" do
    listing = @client.list(prefix: @config.target_prefix, delimiter: "/")
    assert_equal [ "#{@config.target_prefix}dir/" ], listing.prefixes

    head = @client.head(@key)
    assert_equal "image/png", head.content_type
    assert_equal 9, head.size

    ObjectStore.status_store.write(@key, status: "approved", reviewer: "alice@example.com")
    assert_equal "approved", @client.get_tags(@key)["review-status"]
    assert_equal "approved", ObjectStore.status_store.read(@key).status

    ObjectStore.comment_store.append(@key, body: "looks good", creator: identity)
    assert_equal [ "looks good" ], ObjectStore.comment_store.list(@key).map { |a| a.dig("body", "value") }

    url = @client.presigned_url(@key, inline: true)
    assert_includes url, "X-Amz-Signature"
    assert_includes url, "response-content-disposition=inline"

    result = ObjectStore::Indexer.new.run
    assert_equal 1, result.objects
    assert_equal "approved", ReviewedObject.find_by!(key: @key).status
  end
end

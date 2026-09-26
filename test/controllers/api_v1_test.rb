# frozen_string_literal: true

require "test_helper"

class ApiV1Test < ActionDispatch::IntegrationTest
  setup do
    fake_client.put("submissions/a.png", "PNG", content_type: "image/png")
    fake_client.put("submissions/b.png", "PNG", content_type: "image/png")
    ObjectStore.status_store.write("submissions/a.png", status: "approved", reviewer: "alice@example.com")
    ObjectStore.comment_store.append("submissions/a.png", body: "ok", creator: identity)
    ObjectStore::Indexer.new.run
  end

  def auth = { "Authorization" => "Bearer test-api-token" }

  test "Bearer トークンが無い・違うと 401" do
    get "/api/v1/objects"
    assert_response :unauthorized
    get "/api/v1/objects", headers: { "Authorization" => "Bearer nope" }
    assert_response :unauthorized
  end

  test "承認済み一覧をフィルタして返す" do
    get "/api/v1/objects", params: { status: "approved" }, headers: auth
    assert_response :success
    body = response.parsed_body
    assert_equal [ "submissions/a.png" ], body["objects"].map { |o| o["key"] }
    assert_equal 1, body["total"]

    get "/api/v1/objects", params: { updated_since: 1.hour.from_now.iso8601 }, headers: auth
    assert_equal 0, response.parsed_body["total"]

    get "/api/v1/objects", params: { updated_since: "garbage" }, headers: auth
    assert_response :bad_request
  end

  test "詳細とコメントは W3C Annotation 形式で返す" do
    get "/api/v1/objects/submissions/a.png", headers: auth
    assert_response :success
    body = response.parsed_body
    assert_equal "approved", body.dig("object", "status")
    assert_equal "Annotation", body["comments"].first["type"]
    assert_equal "s3://test-bucket/submissions/a.png", body["comments"].first.dig("target", "source")

    get "/api/v1/objects/submissions/a.png/comments", headers: auth
    assert_equal [ "ok" ], response.parsed_body["comments"].map { |c| c.dig("body", "value") }

    get "/api/v1/objects/submissions/nope.png", headers: auth
    assert_response :not_found
  end

  test "ブラウザ経由（developer セッション）でも API を叩ける" do
    post "/dev/login", params: { email: "someone@example.com" }
    get "/api/v1/objects"
    assert_response :success
  end
end

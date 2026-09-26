# frozen_string_literal: true

require "test_helper"

class ObjectsFlowTest < ActionDispatch::IntegrationTest
  setup do
    fake_client.put("submissions/2026/cover.png", "PNG", content_type: "image/png")
    fake_client.put("submissions/2026/body.pdf", "PDF", content_type: "application/pdf")
    fake_client.put("submissions/notes.txt", "some notes", content_type: "text/plain")
    fake_client.put(".review/objects/zzz/comments/01ARZ3NDEKTSV4RRFFQ69G5FAV.json", "{}", content_type: "application/json")
    ObjectStore::Indexer.new.run
  end

  def sign_in(email = "reviewer@example.com")
    post "/dev/login", params: { email: email, name: "Rev" }
    assert_redirected_to "/objects"
  end

  test "未ログインなら developer ログインへ誘導される" do
    get "/objects"
    assert_redirected_to "/dev/login"
  end

  test "一覧: フォルダとファイルを分けて出し、ステータスで絞ると平らになる" do
    sign_in
    get "/objects"
    assert_response :success
    assert_equal "objects/index", inertia.component
    assert_equal [ "2026/" ], inertia.props[:folders]
    assert_equal [ "submissions/notes.txt" ], inertia.props[:objects].map { |o| o[:key] }
    assert_equal "reviewer@example.com", inertia.props.dig(:auth, :identity, :email)

    get "/objects", params: { prefix: "2026/" }
    assert_equal %w[submissions/2026/body.pdf submissions/2026/cover.png], inertia.props[:objects].map { |o| o[:key] }

    ObjectStore.status_store.write("submissions/2026/cover.png", status: "approved", reviewer: "x@example.com")
    ObjectStore::Indexer.new.run
    get "/objects", params: { status: "approved" }
    assert_equal [ "submissions/2026/cover.png" ], inertia.props[:objects].map { |o| o[:key] }
    assert_empty inertia.props[:folders]
    assert_equal 1, inertia.props.dig(:counts, :approved)
  end

  test "詳細: presigned URL とコメントを返し、対象外のキーは 404" do
    sign_in
    get "/objects/submissions/2026/cover.png"
    assert_response :success
    assert_equal "objects/show", inertia.component
    assert_equal "image", inertia.props.dig(:preview, :kind)
    assert_match %r{fake.example/test-bucket/submissions/2026/cover.png}, inertia.props.dig(:preview, :url)

    get "/objects/submissions/notes.txt"
    assert_equal "some notes", inertia.props.dig(:preview, :text)

    get "/objects/other/secret.txt"
    assert_response :not_found
    get "/objects/.review/objects/zzz/comments/01ARZ3NDEKTSV4RRFFQ69G5FAV.json"
    assert_response :not_found
    get "/objects/submissions/missing.png"
    assert_response :not_found
  end

  test "コメント投稿は S3 に書いてから SQLite に写す" do
    sign_in("alice@example.com")
    post "/objects/submissions/2026/cover.png/comments", params: { body: "  needs a bleed margin  " }
    assert_redirected_to "/objects/submissions/2026/cover.png"

    annotations = ObjectStore.comment_store.list("submissions/2026/cover.png")
    assert_equal [ "needs a bleed margin" ], annotations.map { |a| a.dig("body", "value") }
    assert_equal "alice@example.com", annotations.first.dig("creator", "email")

    follow_redirect!
    assert_equal [ "needs a bleed margin" ], inertia.props[:comments].map { |c| c[:body] }

    post "/objects/submissions/2026/cover.png/comments", params: { body: "   " }
    assert_redirected_to "/objects/submissions/2026/cover.png"
    follow_redirect!
    assert inertia.props[:errors][:body].present?
  end

  test "ステータス変更は S3 のタグに書き戻す" do
    sign_in("alice@example.com")
    patch "/objects/submissions/2026/body.pdf/status", params: { status: "changes_requested" }
    assert_redirected_to "/objects/submissions/2026/body.pdf"

    tags = fake_client.get_tags("submissions/2026/body.pdf")
    assert_equal "changes_requested", tags["review-status"]
    assert_equal "alice@example.com", tags["review-reviewer"]
    assert_equal "changes_requested", ReviewedObject.find_by!(key: "submissions/2026/body.pdf").status

    patch "/objects/submissions/2026/body.pdf/status", params: { status: "bogus" }
    follow_redirect!
    assert inertia.props[:errors][:status].present?
  end

  test "再索引は admin だけ" do
    sign_in("reviewer@example.com")
    post "/reindex"
    assert_response :forbidden

    sign_in("admin@example.com")
    assert_enqueued_with(job: ReindexJob) { post "/reindex" }
    assert_redirected_to "/objects"
  end

  test "whoami はプロバイダ情報を返す" do
    sign_in
    get "/whoami"
    assert_equal "developer", inertia.props.dig(:provider, :provider)
    assert_equal "reviewer", inertia.props.dig(:identity, :role)
  end
end

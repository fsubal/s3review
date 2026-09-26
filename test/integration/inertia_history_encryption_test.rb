# frozen_string_literal: true

require "test_helper"

class InertiaHistoryEncryptionTest < ActionDispatch::IntegrationTest
  def page_json
    html = response.body
    JSON.parse(CGI.unescapeHTML(html[%r{<script[^>]*type="application/json"[^>]*>(.*?)</script>}m, 1]))
  end

  setup do
    post "/dev/login", params: { email: "reviewer@example.com" }
  end

  test "平文 HTTP では履歴を暗号化しない（crypto.subtle が無く遷移が壊れるため）" do
    get "/objects"
    assert_response :success
    assert_equal false, page_json["encryptHistory"]
  end

  test "HTTPS（前段プロキシの X-Forwarded-Proto を含む）では履歴を暗号化する" do
    get "/objects", headers: { "X-Forwarded-Proto" => "https" }
    assert_response :success
    assert_equal true, page_json["encryptHistory"]

    get "https://www.example.com/objects"
    assert_equal true, page_json["encryptHistory"]
  end
end

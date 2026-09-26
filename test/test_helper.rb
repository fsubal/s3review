ENV["RAILS_ENV"] ||= "test"
# テストは前段プロキシなしで動かすので developer プロバイダ。S3 はインメモリの FakeClient に差し替える
ENV["AUTH_PROVIDER"] ||= "developer"
ENV["S3_BUCKET"] ||= "test-bucket"
ENV["TARGET_PREFIX"] ||= "submissions/"
ENV["ADMIN_EMAILS"] ||= "admin@example.com"
ENV["API_TOKENS"] ||= "test-api-token"

require_relative "../config/environment"
require "rails/test_help"
require "inertia_rails/minitest"
Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # FakeClient はプロセス内メモリなので並列実行しない
    parallelize(workers: 1)

    setup do
      @fake_client = ObjectStore::FakeClient.new(ObjectStore::Config.from_env)
      ObjectStore.reset!(config: @fake_client.config, client: @fake_client)
    end

    teardown do
      ObjectStore.reset!
    end

    def fake_client = @fake_client

    def identity(email = "reviewer@example.com", name: "Reviewer")
      Auth::Identity.new(email: email, name: name, provider: "test")
    end
  end
end

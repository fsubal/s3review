# frozen_string_literal: true

module Auth
  module Providers
    # Google Cloud Identity-Aware Proxy。
    # IAP は X-Goog-IAP-JWT-Assertion に ES256 で署名した JWT を付ける。
    # aud はバックエンドサービスごとに "/projects/<番号>/global/backendServices/<ID>"（GCE/GKE）または
    # "/projects/<番号>/apps/<プロジェクトID>"（App Engine）になる。IAP_AUDIENCE に設定する。
    class GcpIap < JwtBase
      JWKS_URL = "https://www.gstatic.com/iap/verify/public_key-jwk"
      ISSUER = "https://cloud.google.com/iap"

      def validate!
        require_env("IAP_AUDIENCE")
        self
      end

      private

      def header_name = "X-Goog-IAP-JWT-Assertion"
      def algorithms = %w[ES256]
      def expected_issuer = ISSUER
      def expected_audience = require_env("IAP_AUDIENCE")
      def default_key_source = KeySources::Jwks.new(JWKS_URL)
    end
  end
end

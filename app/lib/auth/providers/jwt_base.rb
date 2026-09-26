# frozen_string_literal: true

require "jwt"

module Auth
  module Providers
    # 署名付き JWT をヘッダで受け取るプロバイダの共通部分。
    # メールアドレスのヘッダ（X-Goog-Authenticated-User-Email など）は偽装できるので信用せず、
    # 必ず JWT の署名を検証してからクレームを読む。
    class JwtBase < Base
      # key_source: JWT ヘッダ（kid など）を受け取って検証鍵（OpenSSL::PKey）を返す callable。
      # テストではここにテスト用の公開鍵を渡す
      def initialize(env: ENV, key_source: nil)
        super(env: env)
        @key_source = key_source
      end

      def identify(request)
        token = request.get_header(rack_header_name).presence
        return nil unless token

        claims, = JWT.decode(token, nil, true, decode_options) { |header, _payload| key_source.call(header) }
        Identity.from_claims(normalize_claims(claims), provider: name)
      rescue JWT::DecodeError, Auth::Error, OpenSSL::PKey::PKeyError => e
        Rails.logger.warn("[auth:#{name}] rejected token: #{e.class}: #{e.message}")
        nil
      end

      def describe
        super.merge("header" => header_name, "algorithms" => algorithms, "issuer" => expected_issuer, "audience" => expected_audience).compact
      end

      private

      def header_name = raise(NotImplementedError)
      def algorithms = raise(NotImplementedError)
      def expected_issuer = nil
      def expected_audience = nil
      def default_key_source = raise(NotImplementedError)

      def key_source
        @key_source ||= default_key_source
      end

      # 例: "X-Goog-IAP-JWT-Assertion" → "HTTP_X_GOOG_IAP_JWT_ASSERTION"
      def rack_header_name = "HTTP_#{header_name.upcase.tr('-', '_')}"

      def decode_options
        options = { algorithms: algorithms, verify_expiration: true, verify_iat: false }
        if expected_issuer
          options[:iss] = expected_issuer
          options[:verify_iss] = true
        end
        if expected_audience
          options[:aud] = expected_audience
          options[:verify_aud] = true
        end
        options
      end

      def normalize_claims(claims) = claims
    end
  end
end

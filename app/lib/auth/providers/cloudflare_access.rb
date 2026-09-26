# frozen_string_literal: true

module Auth
  module Providers
    # Cloudflare Access。Cf-Access-Jwt-Assertion に RS256 の JWT が付く。
    # CF_ACCESS_TEAM_DOMAIN（例: myteam.cloudflareaccess.com）と、アプリケーションごとの
    # CF_ACCESS_AUD（Application Audience タグ）を設定する。
    class CloudflareAccess < JwtBase
      def validate!
        require_env("CF_ACCESS_TEAM_DOMAIN")
        require_env("CF_ACCESS_AUD")
        self
      end

      private

      def header_name = "Cf-Access-Jwt-Assertion"
      def algorithms = %w[RS256]
      def team_domain = require_env("CF_ACCESS_TEAM_DOMAIN").sub(%r{\Ahttps?://}, "").chomp("/")
      def expected_issuer = "https://#{team_domain}"
      def expected_audience = require_env("CF_ACCESS_AUD")
      def default_key_source = KeySources::Jwks.new("https://#{team_domain}/cdn-cgi/access/certs")
    end
  end
end

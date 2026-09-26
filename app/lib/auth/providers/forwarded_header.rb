# frozen_string_literal: true

module Auth
  module Providers
    # oauth2-proxy / Pomerium / Authelia / Authentik などのフォワード認証プロキシ。
    # メールアドレスがヘッダに平文で入るだけで署名はないので、
    # **アプリがプロキシ以外から到達できないネットワーク構成であること** が前提になる。
    class ForwardedHeader < Base
      DEFAULT_EMAIL_HEADER = "X-Forwarded-Email"
      DEFAULT_NAME_HEADER = "X-Forwarded-Preferred-Username"

      def identify(request)
        email = request.get_header(rack_name(email_header)).presence
        return nil unless email

        Identity.from_claims({ "email" => email, "name" => request.get_header(rack_name(name_header)).presence }, provider: name)
      end

      def describe
        super.merge("email_header" => email_header, "name_header" => name_header, "warning" => "headers are not signed; restrict network access to the proxy")
      end

      private

      def email_header = env.fetch("AUTH_EMAIL_HEADER", DEFAULT_EMAIL_HEADER)
      def name_header = env.fetch("AUTH_NAME_HEADER", DEFAULT_NAME_HEADER)
      def rack_name(header) = "HTTP_#{header.upcase.tr('-', '_')}"
    end
  end
end

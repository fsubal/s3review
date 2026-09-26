# frozen_string_literal: true

module Auth
  module KeySources
    # JWKS（JSON Web Key Set）の URL から kid に一致する鍵を返す。
    # 鍵がローテーションされて kid が見つからないときは一度だけキャッシュを捨てて取り直す
    class Jwks
      include Remote

      def initialize(url)
        @url = url
      end

      def call(header)
        kid = header["kid"]
        find(kid) || find(kid, force: true) || raise(Auth::Error, "no JWK for kid=#{kid.inspect}")
      end

      private

      def find(kid, force: false)
        set = JWT::JWK::Set.new(JSON.parse(fetch_text(@url, force: force)))
        jwk = kid ? set.find { |key| key[:kid] == kid } : set.first
        jwk&.verify_key
      end
    end
  end
end

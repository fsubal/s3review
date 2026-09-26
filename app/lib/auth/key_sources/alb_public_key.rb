# frozen_string_literal: true

module Auth
  module KeySources
    # ALB は kid ごとに PEM 形式の公開鍵を配る
    class AlbPublicKey
      include Remote

      def initialize(region)
        @region = region
      end

      def call(header)
        kid = header["kid"].to_s
        raise Auth::Error, "kid is missing or malformed" unless kid.match?(/\A[0-9a-f-]{20,64}\z/)

        OpenSSL::PKey.read(fetch_text("https://public-keys.auth.elb.#{@region}.amazonaws.com/#{kid}"))
      end
    end
  end
end

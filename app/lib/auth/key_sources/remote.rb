# frozen_string_literal: true

require "net/http"

module Auth
  module KeySources
    # 検証鍵を HTTP で取ってきて Rails.cache に置く共通部分
    module Remote
      CACHE_TTL = 1.hour

      def fetch_text(url, force: false)
        cache_key = "auth/keys/#{url}"
        Rails.cache.delete(cache_key) if force
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          response = Net::HTTP.get_response(URI(url))
          raise Auth::Error, "failed to fetch #{url}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
          response.body
        end
      end
    end
  end
end

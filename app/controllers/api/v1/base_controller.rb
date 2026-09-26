# frozen_string_literal: true

module Api
  module V1
    # JSON API。ブラウザ経由なら前段プロキシの身元、サーバ間連携なら API_TOKENS の Bearer トークンで認証する
    class BaseController < ActionController::API
      include Authentication

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not_found" }, status: :not_found
      end

      private

      def identify_request
        token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
        if token
          Auth.valid_api_token?(token) ? Auth::Identity.new(email: "api-token", name: "API token", provider: "api_token") : nil
        else
          super
        end
      end

      def unauthenticated!
        render json: { error: "unauthenticated" }, status: :unauthorized
      end

      def forbidden!
        render json: { error: "forbidden" }, status: :forbidden
      end

      def bucket = ObjectStore.config.bucket

      def target_key!(key)
        config = ObjectStore.config
        raise ActiveRecord::RecordNotFound unless key.present? && key.start_with?(config.target_prefix)
        key
      end
    end
  end
end

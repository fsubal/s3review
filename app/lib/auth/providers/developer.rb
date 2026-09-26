# frozen_string_literal: true

module Auth
  module Providers
    # 開発・デモ専用。/dev/login でメールアドレスを入力するとセッションに入る。
    # production では AUTH_ALLOW_DEVELOPER_IN_PRODUCTION=true を明示しないと起動時に拒否する
    # （compose のデモ構成だけがこれを使う）。
    class Developer < Base
      SESSION_KEY = "developer_identity"

      def initialize(env: ENV, production: Rails.env.production?)
        super(env: env)
        @production = production
      end

      def identify(request)
        data = request.session[SESSION_KEY]
        return nil unless data.is_a?(Hash) && data["email"].present?

        Identity.new(email: data["email"], name: data["name"].presence || data["email"], provider: name)
      end

      def login_path = "/dev/login"

      def sign_in(session, email:, name:)
        session[SESSION_KEY] = { "email" => email.to_s.strip.downcase, "name" => name.to_s.strip.presence }
      end

      def sign_out(session)
        session.delete(SESSION_KEY)
      end

      def validate!
        if @production && env["AUTH_ALLOW_DEVELOPER_IN_PRODUCTION"] != "true"
          raise ConfigurationError, "AUTH_PROVIDER=developer is for development only. Set AUTH_ALLOW_DEVELOPER_IN_PRODUCTION=true if this is a demo."
        end
        Rails.logger.warn("[auth] developer provider is enabled: anyone can sign in as anyone") if @production
        self
      end

      def describe
        super.merge("warning" => "anyone can sign in as anyone; development and demo only")
      end
    end
  end
end

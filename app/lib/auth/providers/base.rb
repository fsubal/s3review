# frozen_string_literal: true

module Auth
  module Providers
    class Base
      attr_reader :env

      def initialize(env: ENV)
        @env = env
      end

      def name = self.class.name.demodulize.underscore

      # ActionDispatch::Request から Identity を取り出す。認証できなければ nil
      def identify(request)
        raise NotImplementedError
      end

      # 認証されていないときに誘導する先。プロキシ方式では nil（プロキシが先に弾くので、ここに来るのは設定ミス）
      def login_path = nil

      # 起動時に設定不備を検出する。問題があれば ConfigurationError
      def validate! = self

      # /whoami で見せる、秘密でない設定
      def describe
        { "provider" => name }
      end

      private

      def require_env(key)
        env[key].presence or raise ConfigurationError, "#{key} is required for AUTH_PROVIDER=#{name}"
      end
    end
  end
end

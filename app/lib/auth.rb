# frozen_string_literal: true

# 認証は前段のプロキシ（Google IAP / AWS ALB / Cloudflare Access / oauth2-proxy 等）に委譲し、
# アプリは「検証済みのメールアドレス」を受け取るだけにする（Trusted Header 方式）。
# どのプロキシを信用するかは AUTH_PROVIDER で選ぶ。ユーザーテーブルは持たない。
module Auth
  class Error < StandardError; end
  class ConfigurationError < Error; end

  PROVIDERS = {
    "gcp_iap" => "Auth::Providers::GcpIap",
    "aws_alb" => "Auth::Providers::AwsAlb",
    "cloudflare_access" => "Auth::Providers::CloudflareAccess",
    "forwarded_header" => "Auth::Providers::ForwardedHeader",
    "developer" => "Auth::Providers::Developer"
  }.freeze

  class << self
    def provider
      @provider ||= build_provider(provider_name)
    end

    def provider_name
      ENV["AUTH_PROVIDER"].presence || (Rails.env.production? ? nil : "developer")
    end

    def build_provider(name, env: ENV)
      raise ConfigurationError, "AUTH_PROVIDER is required in production (one of: #{PROVIDERS.keys.join(', ')})" if name.blank?

      class_name = PROVIDERS[name] or raise ConfigurationError, "unknown AUTH_PROVIDER: #{name}"
      class_name.constantize.new(env: env)
    end

    # ADMIN_EMAILS（カンマ区切り）に含まれるメールだけが admin。それ以外の認証済みユーザーは全員 reviewer
    def admin_emails
      ENV.fetch("ADMIN_EMAILS", "").split(",").map { |email| email.strip.downcase }.reject(&:empty?)
    end

    def admin?(email)
      email.present? && admin_emails.include?(email.downcase)
    end

    # サーバ間連携用の Bearer トークン（API_TOKENS、カンマ区切り）
    def api_tokens
      ENV.fetch("API_TOKENS", "").split(",").map(&:strip).reject(&:empty?)
    end

    def valid_api_token?(token)
      return false if token.blank?

      api_tokens.any? { |candidate| ActiveSupport::SecurityUtils.secure_compare(candidate, token) }
    end

    def reset!(provider: nil)
      @provider = provider
    end
  end
end

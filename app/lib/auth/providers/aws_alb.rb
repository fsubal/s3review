# frozen_string_literal: true

module Auth
  module Providers
    # AWS Application Load Balancer の認証アクション（Cognito または任意の OIDC IdP。Google も可）。
    # 認証を通った要求には x-amzn-oidc-data に ALB が ES256 で署名した JWT が付く。
    # 検証鍵は JWT ヘッダの kid を使って https://public-keys.auth.elb.<region>.amazonaws.com/<kid> から取る。
    # 任意で ALB_ARN を設定すると、JWT ヘッダの signer が一致することも確認する。
    class AwsAlb < JwtBase
      def validate!
        region
        self
      end

      def describe
        super.merge("region" => region, "alb_arn" => env["ALB_ARN"].presence).compact
      end

      private

      def header_name = "x-amzn-oidc-data"
      def algorithms = %w[ES256]

      def region
        env["ALB_REGION"].presence || env["AWS_REGION"].presence || env["AWS_DEFAULT_REGION"].presence ||
          raise(ConfigurationError, "ALB_REGION (or AWS_REGION) is required for AUTH_PROVIDER=aws_alb")
      end

      def default_key_source
        base = KeySources::AlbPublicKey.new(region)
        expected_signer = env["ALB_ARN"].presence
        lambda do |header|
          if expected_signer && header["signer"] != expected_signer
            raise Auth::Error, "unexpected signer: #{header['signer']}"
          end
          base.call(header)
        end
      end
    end
  end
end

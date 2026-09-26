# frozen_string_literal: true

# サーバ起動時に AUTH_PROVIDER の設定不備を検出して、分かるメッセージで落とす。
# rake タスク（assets:precompile 等）では環境変数が無いのが普通なので、サーバ起動時だけ検証する
Rails.application.config.after_initialize do
  next unless defined?(Rails::Server) || ENV["AUTH_VALIDATE_ON_BOOT"] == "true"

  Auth.provider.validate!
rescue Auth::ConfigurationError => e
  abort "[auth] #{e.message}"
end

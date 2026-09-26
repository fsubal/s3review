# frozen_string_literal: true

InertiaRails.configure do |config|
  config.version = ViteRuby.digest
  # 履歴の暗号化は window.crypto.subtle に依存し、HTTPS（か localhost）以外では利用できず
  # "Unable to encrypt history" でページ遷移が失敗する。なので実際に HTTPS で届いた要求
  # （前段プロキシ経由なら X-Forwarded-Proto: https）のときだけ有効にする
  config.encrypt_history = -> { request.ssl? }
  config.always_include_errors_hash = true
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true
end

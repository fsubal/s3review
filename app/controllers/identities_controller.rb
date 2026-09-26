# frozen_string_literal: true

# 前段プロキシの設定確認用。自分が誰として見えているか、どのヘッダが届いているかを表示する
class IdentitiesController < InertiaController
  AUTH_HEADERS = %w[
    HTTP_X_GOOG_IAP_JWT_ASSERTION HTTP_X_GOOG_AUTHENTICATED_USER_EMAIL
    HTTP_X_AMZN_OIDC_DATA HTTP_X_AMZN_OIDC_IDENTITY
    HTTP_CF_ACCESS_JWT_ASSERTION HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL
    HTTP_X_FORWARDED_EMAIL HTTP_X_FORWARDED_USER HTTP_X_FORWARDED_PREFERRED_USERNAME
  ].freeze

  def show
    render inertia: "identities/show", props: {
      identity: current_identity.as_json,
      provider: Auth.provider.describe,
      admin_emails_configured: Auth.admin_emails.any?,
      # 値は見せない（JWT やメールが丸見えになる）。届いているかどうかだけ
      headers_present: AUTH_HEADERS.select { |h| request.get_header(h).present? }.map { |h| h.delete_prefix("HTTP_").tr("_", "-") }
    }
  end
end

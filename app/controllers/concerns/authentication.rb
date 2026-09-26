# frozen_string_literal: true

# 前段プロキシが付けた身元（Auth.provider）を Current.identity に入れる。
# ブラウザ向け（ApplicationController）と API 向け（Api::V1::BaseController）で共有し、
# 未認証時の振る舞いだけを各コントローラの unauthenticated! で変える
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  def current_identity = Current.identity

  private

  def authenticate!
    Current.identity = identify_request
    unauthenticated! unless Current.identity
  end

  def identify_request
    Auth.provider.identify(request)
  end

  def require_admin!
    forbidden! unless current_identity&.admin?
  end

  def unauthenticated!
    raise NotImplementedError
  end

  def forbidden!
    raise NotImplementedError
  end
end

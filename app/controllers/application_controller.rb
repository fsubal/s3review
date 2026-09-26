# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def unauthenticated!
    if (path = Auth.provider.login_path)
      redirect_to path
    else
      render inertia: "errors/unauthenticated", props: { provider: Auth.provider.describe }, status: :unauthorized
    end
  end

  def forbidden!
    render inertia: "errors/forbidden", status: :forbidden
  end

  def object_store = ObjectStore
  def bucket = ObjectStore.config.bucket

  # /objects/*key で受けたキーが対象範囲（TARGET_PREFIX 以下、サイドカー以外）か確かめる
  def target_key!(key)
    config = ObjectStore.config
    unless key.present? && key.start_with?(config.target_prefix) &&
           !(config.review_prefix_in_target_bucket? && key.start_with?(config.review_prefix))
      raise ActiveRecord::RecordNotFound, "key is outside TARGET_PREFIX"
    end
    key
  end
end

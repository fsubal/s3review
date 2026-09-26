# frozen_string_literal: true

class InertiaController < ApplicationController
  inertia_share do
    {
      auth: {
        identity: current_identity&.as_json,
        provider: Auth.provider_name,
        login_path: Auth.provider.login_path
      },
      config: {
        bucket: bucket,
        target_prefix: ObjectStore.config.target_prefix,
        status_strategy: ObjectStore.config.status_strategy
      },
      flash: flash.to_hash
    }
  end
end

# frozen_string_literal: true

module Dev
  # AUTH_PROVIDER=developer のときだけルーティングされる。メールを入力するだけでその人になれる
  class SessionsController < InertiaController
    skip_before_action :authenticate!, only: %i[new create]

    def new
      render inertia: "dev/login", props: { warning: provider.describe["warning"] }
    end

    def create
      email = params[:email].to_s.strip
      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        redirect_to dev_login_path, inertia: { errors: { email: [ "メールアドレスの形式が不正です" ] } }
        return
      end

      provider.sign_in(session, email: email, name: params[:name])
      redirect_to objects_path
    end

    def destroy
      provider.sign_out(session)
      redirect_to dev_login_path
    end

    private

    def provider
      Auth.provider.tap { |p| raise ActionController::RoutingError, "developer auth is disabled" unless p.is_a?(Auth::Providers::Developer) }
    end
  end
end

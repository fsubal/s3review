Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/objects")

  # オブジェクトのキーはスラッシュやドットを含むので glob + format: false で受ける。
  # 動詞つきのルート（comments / status）は show より先に定義する
  get "objects", to: "objects#index", as: :objects
  post "objects/*key/comments", to: "comments#create", as: :object_comments, format: false
  patch "objects/*key/status", to: "statuses#update", as: :object_status, format: false
  get "objects/*key", to: "objects#show", as: :object, format: false

  post "reindex", to: "reindexes#create", as: :reindex
  get "whoami", to: "identities#show", as: :whoami

  # 開発・デモ専用のログイン。AUTH_PROVIDER=developer のときだけ生える
  if Auth.provider_name == "developer"
    get "dev/login", to: "dev/sessions#new", as: :dev_login
    post "dev/login", to: "dev/sessions#create"
    delete "dev/logout", to: "dev/sessions#destroy", as: :dev_logout
  end

  namespace :api do
    namespace :v1 do
      get "objects", to: "objects#index"
      get "objects/*key/comments", to: "comments#index", format: false
      get "objects/*key", to: "objects#show", format: false
    end
  end
end

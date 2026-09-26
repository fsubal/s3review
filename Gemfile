source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Inertia.js（Rails 側アダプタ）。コントローラは render inertia: "objects/show", props: {...} でページを返す
gem "inertia_rails"
# フロントエンド（React + TypeScript）のビルド。app/frontend 以下を Vite でバンドルする
gem "vite_rails"

# S3 互換ストレージ（AWS S3 / MinIO / Ceph RGW / GCS の S3 互換 API）へのアクセス
gem "aws-sdk-s3"
# 前段プロキシ（Google IAP / AWS ALB / Cloudflare Access）が付ける署名付き JWT の検証
gem "jwt"

# json 3.0 は ActiveSupport 8.1.3 の JSON.parse 呼び出しと非互換（ArgumentError）なので 2 系に固定
gem "json", "~> 2.15"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# DB（SQLite）をバックエンドにしたキャッシュとジョブキュー。Action Cable は使わないので solid_cable は入れない
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

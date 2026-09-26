# frozen_string_literal: true

# サーバ起動時に一度だけ再索引をキューに入れる。SQLite はいつ消えてもよい前提なので、起動のたびに S3 から埋め直す。
# REINDEX_ON_BOOT=false で止められる
Rails.application.config.after_initialize do
  next unless defined?(Rails::Server)
  next unless ENV.fetch("REINDEX_ON_BOOT", "true") == "true"

  begin
    ReindexJob.perform_later if ActiveRecord::Base.connection.table_exists?(:reviewed_objects)
  rescue StandardError => e
    Rails.logger.warn("[reindex] could not enqueue on boot: #{e.class}: #{e.message}")
  end
end

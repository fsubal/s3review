# frozen_string_literal: true

class ReindexJob < ApplicationJob
  queue_as :default

  # 同時に走らせない（Solid Queue の concurrency control）
  limits_concurrency to: 1, key: "reindex", duration: 30.minutes

  def perform
    result = ObjectStore::Indexer.new.run
    Rails.logger.info("[reindex] objects=#{result.objects} comments=#{result.comments} removed=#{result.removed}")
  end
end

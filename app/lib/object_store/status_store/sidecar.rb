# frozen_string_literal: true

module ObjectStore
  module StatusStore
    class Sidecar
      def initialize(client:, config:)
        @client = client
        @config = config
      end

      def read(key)
        json = @client.get_json(sidecar_key(key))
        return Status.pending if json.nil?

        Status.new(
          status: STATUSES.include?(json["status"]) ? json["status"] : DEFAULT,
          updated_at: json["updated_at"].presence && Time.iso8601(json["updated_at"]),
          reviewer: json["reviewer"].presence
        )
      end

      def write(key, status:, reviewer:, now: Time.now.utc)
        StatusStore.validate!(status)
        @client.put_json(sidecar_key(key), {
          "source" => Annotation.source_for(@config.bucket, key),
          "status" => status,
          "updated_at" => now.iso8601,
          "reviewer" => reviewer
        })
        Status.new(status: status, updated_at: now, reviewer: reviewer)
      end

      private

      def sidecar_key(key) = "#{ObjectStore.sidecar_prefix(key)}status.json"
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class ObjectsController < BaseController
      MAX_PER = 500

      # GET /api/v1/objects?status=approved&prefix=2026/&updated_since=...&page=1&per=100
      def index
        scope = ReviewedObject.in_bucket(bucket)
        scope = scope.under(ObjectStore.config.target_prefix + params[:prefix].to_s)
        scope = scope.with_status(params[:status].presence)
        scope = scope.where("status_updated_at >= ?", Time.iso8601(params[:updated_since])) if params[:updated_since].present?

        page = [ params[:page].to_i, 1 ].max
        per = params[:per].to_i.clamp(1, MAX_PER)
        per = 100 if params[:per].blank?

        render json: {
          objects: scope.order(:key).offset((page - 1) * per).limit(per).map(&:as_json),
          page: page, per: per, total: scope.count
        }
      rescue ArgumentError
        render json: { error: "invalid updated_since" }, status: :bad_request
      end

      # GET /api/v1/objects/*key
      def show
        key = target_key!(params[:key])
        record = ReviewedObject.in_bucket(bucket).find_by(key: key) || ReviewedObject.sync_from_s3!(key) or raise ActiveRecord::RecordNotFound
        render json: { object: record.as_json, comments: record.comments.map(&:to_annotation) }
      end
    end
  end
end

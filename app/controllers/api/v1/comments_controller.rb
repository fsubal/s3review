# frozen_string_literal: true

module Api
  module V1
    class CommentsController < BaseController
      # GET /api/v1/objects/*key/comments — W3C Web Annotation の配列で返す
      def index
        key = target_key!(params[:key])
        record = ReviewedObject.in_bucket(bucket).find_by(key: key) or raise ActiveRecord::RecordNotFound
        render json: { comments: record.comments.map(&:to_annotation) }
      end
    end
  end
end

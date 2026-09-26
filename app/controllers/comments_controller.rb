# frozen_string_literal: true

class CommentsController < InertiaController
  def create
    key = target_key!(params[:key])
    body = params[:body].to_s.strip
    if body.empty?
      redirect_to object_path(key), inertia: { errors: { body: [ "コメントを入力してください" ] } }
      return
    end

    record = ReviewedObject.in_bucket(bucket).find_by(key: key) || ReviewedObject.sync_from_s3!(key) or raise ActiveRecord::RecordNotFound
    annotation = object_store.comment_store.append(key, body: body, creator: current_identity)
    Comment.upsert_from_annotation!(record, annotation)

    redirect_to object_path(key), notice: "コメントを投稿しました"
  end
end

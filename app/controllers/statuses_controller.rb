# frozen_string_literal: true

class StatusesController < InertiaController
  def update
    key = target_key!(params[:key])
    status = params[:status].to_s
    unless ReviewedObject::STATUSES.include?(status)
      redirect_to object_path(key), inertia: { errors: { status: [ "不正なステータスです" ] } }
      return
    end

    record = ReviewedObject.in_bucket(bucket).find_by(key: key) || ReviewedObject.sync_from_s3!(key) or raise ActiveRecord::RecordNotFound
    written = object_store.status_store.write(key, status: status, reviewer: current_identity.email)
    record.apply_status(written)
    record.save!

    redirect_to object_path(key), notice: "ステータスを #{status} にしました"
  end
end

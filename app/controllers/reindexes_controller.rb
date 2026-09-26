# frozen_string_literal: true

class ReindexesController < InertiaController
  before_action :require_admin!

  def create
    ReindexJob.perform_later
    redirect_back_or_to objects_path, notice: "再索引をキューに入れました"
  end
end

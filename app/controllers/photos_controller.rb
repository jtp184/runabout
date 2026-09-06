class PhotosController < ApplicationController
  def show
    model = { "person" => Person, "episode" => Episode }[params[:kind]]
    record = model&.find_by(id: params[:id])
    return head :not_found unless record&.photo_data.present?
    expires_in 1.year, public: true
    send_data record.photo_data, type: record.photo_path.to_s.end_with?(".png") ? "image/png" : "image/jpeg", disposition: "inline"
  end
end

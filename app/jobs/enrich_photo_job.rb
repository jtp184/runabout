class EnrichPhotoJob < ApplicationJob
  def perform(kind, id)
    model = { "person" => Person, "episode" => Episode }.fetch(kind)
    record = model.find_by(id: id)
    Enrichment::Tmdb.new.fetch(record) if record
  end
end

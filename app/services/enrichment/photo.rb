module Enrichment
  class Photo
    def initialize(record)
      @record = record
    end

    def path
      return nil unless @record&.photo_data.present?
      Rails.application.routes.url_helpers.photo_path(kind: @record.is_a?(Person) ? "person" : "episode", id: @record.id)
    end
  end
end

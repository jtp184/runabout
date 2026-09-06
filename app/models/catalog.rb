class Catalog < ApplicationRecord
  belongs_to :ingest, optional: true
  def self.current_id
    find_by(id: 1)&.ingest_id
  end
end

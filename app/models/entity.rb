class Entity < ApplicationRecord
  belongs_to :ingest
  has_many :entity_mentions, dependent: :destroy
  scope :current, -> { where(ingest_id: Catalog.current_id) }
end

class Person < ApplicationRecord
  belongs_to :ingest
  has_many :credits, dependent: :destroy
  scope :current, -> { where(ingest_id: Catalog.current_id) }
end

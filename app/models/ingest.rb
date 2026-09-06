class Ingest < ApplicationRecord
  has_many :episodes, dependent: :destroy
  has_many :entities, dependent: :destroy
  has_many :people, dependent: :destroy
end

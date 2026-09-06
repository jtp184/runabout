class MediaFile < ApplicationRecord
  validates :path, presence: true, uniqueness: true
end

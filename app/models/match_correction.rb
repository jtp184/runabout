class MatchCorrection < ApplicationRecord
  validates :path, presence: true, uniqueness: true
  validates :episode_keys, presence: true
end

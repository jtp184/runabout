class EntityMention < ApplicationRecord
  belongs_to :episode
  belongs_to :entity
end

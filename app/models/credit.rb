class Credit < ApplicationRecord
  belongs_to :episode
  belongs_to :person
end

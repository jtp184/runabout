class Article < ApplicationRecord
  validates :page, presence: true, uniqueness: true
end

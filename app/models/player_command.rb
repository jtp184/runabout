class PlayerCommand < ApplicationRecord
  ACTIONS = %w[Play Pause Stop Next Previous SetPosition Volume].freeze
  validates :action, inclusion: { in: ACTIONS }
  validates :value, numericality: { greater_than_or_equal_to: 0 }, if: -> { %w[SetPosition Volume].include?(action) }
  validates :value, numericality: { less_than_or_equal_to: 1 }, if: -> { action == "Volume" }
end

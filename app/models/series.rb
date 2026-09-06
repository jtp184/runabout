class Series < ApplicationRecord
  THEMES = %w[classic nemesis-blue voyager lower-decks lower-decks-padd picard].freeze
  has_many :episodes
  validates :theme, inclusion: { in: THEMES }

  def self.resolve(token)
    normalized = normalize(token)
    all.detect { |series| ([ series.name, series.code ] + series.aliases).any? { |name| normalize(name) == normalized } }
  end

  def self.normalize(token)
    token.to_s.downcase.gsub(/[^a-z0-9]/, "").sub(/\Astartrek/, "")
  end
end

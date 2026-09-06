class Episode < ApplicationRecord
  belongs_to :series
  belongs_to :ingest
  has_many :credits, dependent: :destroy
  has_many :quotes, -> { order(:ordinal) }, dependent: :destroy
  has_many :entity_mentions, dependent: :destroy
  scope :current, -> { where(ingest_id: Catalog.current_id) }

  def key
    { "series" => series.code, "season" => season, "number" => number, "page" => page }
  end

  def self.for_keys(keys)
    catalog = where(ingest_id: Catalog.current_id)
    Array(keys).filter_map do |key|
      if key["number"]
        catalog.joins(:series).find_by(series: { code: key["series"] }, season: key["season"], number: key["number"])
      else
        catalog.find_by(page: key["page"])
      end
    end
  end

  def label
    "#{series.code} #{season ? 'S%02dE%02d' % [ season, number.to_i ] : 'Film'} · #{title}"
  end
end

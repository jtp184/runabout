module CatalogHelpers
  def seed_rules
    load Rails.root.join("db/seeds.rb")
  end

  def import_fixture
    seed_rules
    MemoryAlpha::Importer.new.call(Rails.root.join("test/fixtures/files/memory_alpha.xml"))
  end

  def seed_coordinates
    seed_rules
    ingest = Ingest.create!(status: "complete")
    series = Series.all.index_by(&:code)
    JSON.parse(File.read(Rails.root.join("test/fixtures/files/episode_coordinates.json"))).each do |row|
      Episode.create!(ingest: ingest, series: series.fetch(row["series"]), title: row["title"], page: "#{row['title']} (episode)", season: row["season"], number: row["number"])
    end
    Catalog.find(1).update!(ingest: ingest)
  end
end

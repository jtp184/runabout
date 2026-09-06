require "test_helper"
require "tempfile"

class ImporterTest < ActiveSupport::TestCase
  test "imports module numbering, double episodes, credits, quotes and independent references" do
    ingest = import_fixture
    assert_equal 5, ingest.episodes.count
    episode = Episode.current.find_by(title: "The Inner Light")
    assert_equal [ 5, 25, "1 June 1992" ], [ episode.season, episode.number, episode.airdate ]
    assert_equal "A captain encounters a mysterious probe.", episode.blurb
    assert_equal "A synthetic fixture quotation.", episode.quotes.first.text.delete('"')
    assert_equal "Picard", episode.quotes.first.speaker
    assert_equal 2, episode.credits.count
    assert_equal "A performer biography.", Person.current.find_by(name: "Patrick Stewart").biography
    flute = Entity.current.find_by(page: "Ressikan flute")
    assert_equal "Technology", flute.display_type
    assert_equal %w[references citation], episode.entity_mentions.find_by(entity: flute).sources
    unseen = episode.entity_mentions.find_by(entity: Entity.current.find_by(page: "Starbase 218"))
    assert_not unseen.seen
    assert_equal %w[references citation], unseen.sources
    assert_not Entity.current.exists?(page: "Do not import me")
    assert_equal "Other", Entity.current.find_by(page: "Reverse-only subject").display_type
    assert_equal [ 1, 2 ], Episode.current.where(title: "Emissary").order(:number).pluck(:number)
  end

  test "failed XML leaves the active snapshot intact and later refresh prunes old data" do
    first = import_fixture
    Tempfile.create([ "broken", ".xml" ]) do |file|
      file.write("<mediawiki><page><title>broken"); file.flush
      assert_raises(StandardError) { MemoryAlpha::Importer.new.call(file.path) }
    end
    assert_equal first.id, Catalog.current_id
    second = import_fixture
    assert Ingest.exists?(first.id)
    third = import_fixture
    assert_not Ingest.exists?(first.id)
    assert Ingest.exists?(second.id)
    assert_equal third.id, Catalog.current_id
  end

  test "text extraction strips unknown templates and expands small readable forms" do
    text = "{{real world}}\nAboard the {{USS|Enterprise|NCC-1701-D|-D}}, {{dis|Kataan|star}} with {{revname|Richard|Wagner}}. [[File:Photo.jpg|thumb|caption]]"
    assert_equal "Aboard the USS Enterprise, Kataan with Richard Wagner.", MemoryAlpha::Wikitext.clean(text)
  end
  test "module metadata identifies an episode even when its article is missing" do
    seed_rules
    xml = File.read(Rails.root.join("test/fixtures/files/memory_alpha.xml"))
    document = Nokogiri::XML(xml).remove_namespaces!
    document.xpath("//page[title='The Inner Light (episode)']").remove
    Tempfile.create([ "metadata-only", ".xml" ]) do |file|
      file.write(document.to_xml); file.flush
      MemoryAlpha::Importer.new.call(file.path)
    end
    episode = Episode.current.find_by(title: "The Inner Light")
    assert episode
    assert_nil episode.blurb
    assert Identification::Resolver.new.call("Star.Trek.TNG.S05E25.mkv").matched?
  end

  test "lead excludes wiki control words and leading quotations" do
    text = "__NOTOC__\n{{aquote|An opening quotation.|Someone}}\nA readable lead. ({{TNG|The Inner Light}})"
    assert_equal "A readable lead.", MemoryAlpha::Wikitext.lead(text)
    assert_includes MemoryAlpha::Wikitext.templates("{{outer|{{TNG|The Inner Light}}}}", nested: true), "{{TNG|The Inner Light}}"
  end
end

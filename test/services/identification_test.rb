require "test_helper"

class IdentificationTest < ActiveSupport::TestCase
  setup { seed_coordinates }

  test "all 517 library episodes resolve and all 221 extras stay unmatched" do
    matched, extras, doubles = 0, 0, 0
    File.readlines(Rails.root.join("test/fixtures/files/library_filenames.txt"), chomp: true).each do |path|
      result = Identification::Resolver.new.call(path)
      if File.basename(path).include?(" Episode ")
        assert result.matched?, path
        matched += 1
        doubles += 1 if result.episodes.length == 2
      else
        assert_not result.matched?, path
        extras += 1
      end
    end
    assert_equal [ 517, 221, 9 ], [ matched, extras, doubles ]
  end

  test "scene names aliases and title errors resolve by coordinates" do
    [ "Star.Trek.TNG.S05E25.The.Inner.Light.1080p.mkv", "Star_Trek_TNG_S05E25_The_Inner_Light.mkv", "Star Trek The Next Generation 5x25 The Inner Light.avi", "Star Trek TNG Season 1 Episode 05 - The Last Post.avi", "Star Trek Deep Space Nine Season 03 Episode 11 - Past Tense (Part 1).avi" ].each do |path|
      assert Identification::Resolver.new.call(path).matched?, path
    end
    result = Identification::Resolver.new.call("Star.Trek.Voyager.S01E01E02.Caretaker.mkv")
    assert_equal [ 1, 2 ], result.episodes.map(&:number)
  end

  test "exact path corrections precede stale library indexes and survive refresh" do
    path = "/video/odd + name.avi"
    episode = Episode.current.find_by(title: "The Inner Light")
    MediaFile.create!(path: path, episode_keys: Episode.current.first.then { |record| [ record.key ] })
    MatchCorrection.create!(path: path, episode_keys: [ episode.key ])
    result = Identification::Resolver.new.call("file:///video/odd%20+%20name.avi")
    assert_equal [ episode.id ], result.episodes.map(&:id)
    assert_equal "correction", result.source
    seed_coordinates
    assert_equal "The Inner Light", Identification::Resolver.new.call(path).episodes.first.title
  end
end

require "test_helper"

class EnrichmentTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls
    def initialize(response: nil, fail: false)
      @response, @fail, @calls = response, fail, 0
    end
    def json(*)
      @calls += 1
      raise IOError, "offline" if @fail
      @response
    end
    def get(*)
      raise IOError, "offline"
    end
  end

  test "article HTML is sanitized, links rewritten and cache reused permanently" do
    client = FakeClient.new(response: { "parse" => { "text" => { "*" => '<script>alert(1)</script><p onclick="bad()">Text <a href="/wiki/Kamin">Kamin</a><a href="javascript:alert(1)">bad</a><img src="https://evil.test/a"></p>' } } })
    cache = MemoryAlpha::ArticleCache.new(client: client)
    article = cache.fetch("Flute")
    assert_no_match(/script|onclick|<img/, article.html)
    assert_includes article.html, "/article?page=Kamin"
    assert_includes article.html, 'data-turbo-frame="detail"'
    cache.fetch("Flute")
    assert_equal 1, client.calls
  end

  test "offline uncached articles and missing photo credentials return null results" do
    client = FakeClient.new(fail: true)
    assert_nil MemoryAlpha::ArticleCache.new(client: client).fetch("Absent")
    person = Person.new(name: "Someone")
    assert_nil Enrichment::Tmdb.new(client: client, key: nil).fetch(person).path
    assert_nil Enrichment::Tmdb.new(client: client, key: "test").fetch(person).path
  end
  test "TMDB photograph bytes are stored locally and reused without another request" do
    import_fixture
    person = Person.current.find_by(name: "Patrick Stewart")
    client = FakeClient.new(response: { "results" => [ { "name" => person.name, "id" => 2387, "profile_path" => "/headshot.jpg" } ] })
    def client.get(*) = "\xFF\xD8fixture".b
    tmdb = Enrichment::Tmdb.new(client: client, key: "test-key")
    photo = tmdb.fetch(person)
    assert_equal "/photos/person/#{person.id}", photo.path
    assert_equal "\xFF\xD8fixture".b, person.reload.photo_data
    tmdb.fetch(person)
    assert_equal 1, client.calls
  end
end

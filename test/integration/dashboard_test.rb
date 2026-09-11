require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "first run and no player render in theme" do
    get root_path
    assert_response :success
    assert_select "h1", "Awaiting transmission"
    assert_select ".first-run", text: /bin\/rake runabout:ingest/
    assert_select "#cast"
    assert_select "#refs"
    assert_select "#quotes"
    assert_select "#log"
    assert_select "input[type=submit][disabled]", count: 5
  end

  test "identified episode has every panel, spoilers closed, attribution and inline cast records" do
    import_fixture
    episode = Episode.current.find_by(title: "The Inner Light")
    PlayerState.current.update!(episode_keys: [ episode.key ], status: "IDLE", confidence: 1)
    get root_path
    assert_response :success
    assert_select "h1", "The Inner Light"
    assert_select "#cast", text: /Patrick Stewart/
    assert_select "#refs", text: /Ressikan flute/
    assert_select "#log details:not([open])"
    assert_select "#log a[href*='memory-alpha.fandom.com']"
    assert_select "#cast details.cast-record:not([open])" do
      assert_select "summary", text: /Patrick Stewart/
      assert_select ".cast-preview p"
      assert_select 'a[target="_blank"][rel="noopener"]', text: "Open full person record ↗"
    end
  end

  test "manual double match persists and invalid commands cannot enter the queue" do
    import_fixture
    state = PlayerState.current
    state.update!(path: "/bonus.avi", status: "UNMATCHED", bus_name: "org.mpris.MediaPlayer2.vlc", track_id: "/track/1")
    episodes = Episode.current.where(title: "Emissary")
    post corrections_path, params: { path: state.path, episode_ids: episodes.pluck(:id) }
    assert_response :see_other
    assert_equal 2, MatchCorrection.find_by(path: state.path).episode_keys.length
    assert_no_difference "PlayerCommand.count" do
      post commands_path, params: { command: "Delete", bus_name: state.bus_name, track_id: state.track_id }
      assert_response :unprocessable_entity
      post commands_path, params: { command: "Volume", value: -1, bus_name: state.bus_name, track_id: state.track_id }
      assert_response :unprocessable_entity
    end
    assert_difference "PlayerCommand.count" do
      post commands_path, params: { command: "Pause", bus_name: state.bus_name, track_id: state.track_id }
      assert_response :accepted
    end
  end

  test "cached detail renders with spoiler boundary and unknown record degrades" do
    import_fixture
    entity = Entity.current.find_by(page: "Ressikan flute")
    Article.create!(page: entity.page, html: "<p>Cached text</p>", fetched_at: Time.current)
    get entity_path(entity), headers: { "Turbo-Frame" => "detail" }
    assert_response :success
    assert_select "turbo-frame#detail details:not([open])", text: /Cached text/
    get entity_path(id: 99999999), headers: { "Turbo-Frame" => "detail" }
    assert_response :success
    assert_select ".diagnostic", text: /unavailable offline/
  end
end

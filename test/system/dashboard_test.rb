require "application_system_test_case"

class DashboardSystemTest < ApplicationSystemTestCase
  setup do
    import_fixture
    episode = Episode.current.find_by(title: "The Inner Light")
    PlayerState.current.update!(episode_keys: [ episode.key ], confidence: 1, status: "PLAYING", bus_name: "org.mpris.MediaPlayer2.vlc", track_id: "/track/1", playback_status: "Playing", position: 20, duration: 120, captured_at: Time.current, capabilities: { "CanControl" => true, "CanPlay" => true, "CanPause" => true, "CanSeek" => true })
    entity = Entity.current.find_by(page: "Ressikan flute")
    Article.create!(page: entity.page, html: "<p>A cached article.</p>", fetched_at: Time.current)
  end

  test "desktop controls theme pin mobile tabs and detail back navigation" do
    visit root_path
    assert_text "The Inner Light"
    %w[cast refs quotes log].each { |panel| assert_selector "##{panel}" }
    click_button "Pin theme"
    assert_button "Unpin theme"
    refresh
    assert_button "Unpin theme"
    click_button "Pause"
    assert_text "Command queued."
    assert_equal "Pause", PlayerCommand.last.action
    page.save_screenshot(Rails.root.join("tmp/runabout-desktop.png"))
    page.driver.browser.manage.window.resize_to(430, 932)
    assert_selector "#cast"
    assert_no_selector "#refs"
    click_link "02 · REFS"
    assert_selector "#refs"
    assert_no_selector "#cast"
    click_link "Ressikan flute"
    assert_selector "#detail .detail-content"
    assert_text "Reveal full article"
    assert_no_text "A cached article."
    page.save_screenshot(Rails.root.join("tmp/runabout-mobile.png"))
    click_link "← Back to dashboard"
    assert_no_selector "#detail .detail-content"
    assert_selector "#refs"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "Mobile dashboard must not overflow horizontally"
  end
end

require "application_system_test_case"

class DashboardSystemTest < ApplicationSystemTestCase
  setup do
    import_fixture
    episode = Episode.current.find_by(title: "The Inner Light")
    PlayerState.current.update!(episode_keys: [ episode.key ], confidence: 1, status: "PLAYING", bus_name: "org.mpris.MediaPlayer2.vlc", track_id: "/track/1", playback_status: "Playing", position: 20, duration: 120, captured_at: Time.current, capabilities: { "CanControl" => true, "CanPlay" => true, "CanPause" => true, "CanSeek" => true })
    entity = Entity.current.find_by(page: "Ressikan flute")
    Article.create!(page: entity.page, html: "<p>A cached article.</p>", fetched_at: Time.current)
  end

  test "desktop controls theme pin mobile tabs and inline record previews" do
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
    assert_selector "#log"
    assert_no_selector "#refs"
    click_link "04 · REFS"
    assert_selector "#refs"
    assert_no_selector "#log"
    category = find("#refs .reference-category", text: "Ressikan flute", visible: :all)
    category.find(":scope > summary").click
    find(".reference-record > summary", text: "Ressikan flute").click
    assert_link "Open full entity ↗", href: entity_path(Entity.current.find_by(page: "Ressikan flute"))
    page.save_screenshot(Rails.root.join("tmp/runabout-mobile.png"))
    click_link "02 · CAST"
    record = find(".cast-record", text: "Patrick Stewart")
    record.find("summary").click
    within(record) do
      assert_selector ".cast-preview p"
      assert_selector 'a[target="_blank"]', text: "Open full person record ↗"
    end
    record.find("summary").click
    assert_no_selector ".cast-preview"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "Mobile dashboard must not overflow horizontally"
  end
end

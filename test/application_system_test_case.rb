require "test_helper"
ENV["SE_OFFLINE"] ||= "true"
ENV["SE_AVOID_STATS"] ||= "true"
ENV["SE_CACHE_PATH"] ||= Rails.root.join("tmp/selenium").to_s

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1600, 1000 ] do |options|
    options.binary = "/usr/bin/chromium"
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--user-data-dir=/tmp/runabout-browser-#{Process.pid}")
  end
end

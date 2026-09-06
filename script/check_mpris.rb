# Run with: dbus-run-session -- bin/rails runner script/check_mpris.rb
require "open3"
abort "Use an isolated bus: dbus-run-session -- bin/rails runner script/check_mpris.rb" unless ENV["RUNABOUT_TEST_BUS"] == "1"
Open3.popen2(RbConfig.ruby, Rails.root.join("test/support/fake_mpris_player.rb").to_s) do |stdin, stdout, process|
  stdin.close
  raise "Fake player failed to start" unless stdout.gets&.strip == "READY"
  adapter = Mpris::Adapter.new
  name = "org.mpris.MediaPlayer2.runabout_test"
  raise "Discovery failed" unless adapter.snapshot.dig(name, "PlaybackStatus") == "Playing"
  command = Struct.new(:action, :value, :bus_name, :track_id)
  adapter.execute(command.new("Pause", nil, name, "/track/1"))
  raise "PropertiesChanged signal missing" unless adapter.wait(1)
  raise "Pause failed" unless adapter.snapshot.dig(name, "PlaybackStatus") == "Paused"
  adapter.execute(command.new("SetPosition", 42.0, name, "/track/1"))
  raise "Seeked signal missing" unless adapter.wait(1)
  raise "Seek units wrong" unless adapter.snapshot.dig(name, "Position") == 42_000_000
  adapter.execute(command.new("Volume", 0.25, name, "/track/1"))
  raise "Volume failed" unless adapter.snapshot.dig(name, "Volume") == 0.25
  Process.kill("TERM", process.pid)
  process.value
  adapter.wait(1)
  raise "Player disappearance missed" unless adapter.snapshot.empty?
  puts "MPRIS discovery, PropertiesChanged, Seeked, pause, seek, volume, and disappearance passed."
ensure
  adapter&.close
  Process.kill("TERM", process.pid) rescue Errno::ESRCH
end

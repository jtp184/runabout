require "test_helper"

class WatcherTest < ActiveSupport::TestCase
  class FakeAdapter
    attr_accessor :players, :failure
    attr_reader :executed
    def initialize(players)
      @players, @executed = players, []
    end
    def snapshot = players
    def execute(command)
      raise IOError, "Player rejected command" if failure
      @executed << command.action
    end
  end

  setup do
    import_fixture
    @name = "org.mpris.MediaPlayer2.vlc"
    @properties = { "PlaybackStatus" => "Playing", "Position" => 20_000_000, "Rate" => 1,
      "CanControl" => true, "CanPause" => true, "CanSeek" => true,
      "Metadata" => { "xesam:url" => "file:///Star.Trek.TNG.S05E25.The.Inner.Light.mkv", "mpris:trackid" => "/track/1", "mpris:length" => 120_000_000 } }
    @adapter = FakeAdapter.new(@name => @properties)
    @watcher = Mpris::Watcher.new(adapter: @adapter)
    @watcher.reconcile
  end

  test "viewing retains furthest position through seek and closes on player disappearance" do
    viewing = PlayerState.current.viewing
    @properties["Position"] = 10_000_000
    @watcher.reconcile
    assert_equal 20, viewing.reload.furthest_position
    assert_equal viewing.id, PlayerState.current.viewing_id
    @adapter.players = {}
    @watcher.reconcile
    assert viewing.reload.ended_at
    assert_equal "The Inner Light", PlayerState.current.episodes.first.title
    assert_equal "NO_PLAYER", PlayerState.current.status
  end

  test "commands use watcher connection and failures become notices" do
    command = PlayerCommand.create!(action: "Pause", bus_name: @name, track_id: "/track/1")
    @watcher.process_commands
    assert_equal "done", command.reload.status
    assert_equal [ "Pause" ], @adapter.executed
    @adapter.failure = true
    failed = PlayerCommand.create!(action: "Pause", bus_name: @name, track_id: "/track/1")
    @watcher.process_commands
    assert_equal "failed", failed.reload.status
    assert_equal "Player rejected command", PlayerState.current.notice
  end

  test "reconciliation prevents commands hitting a new track and expired commands are rejected" do
    stale = PlayerCommand.create!(action: "Pause", bus_name: @name, track_id: "/track/1")
    @properties["Metadata"]["mpris:trackid"] = "/track/2"
    @watcher.process_commands
    assert_equal "failed", stale.reload.status
    assert_empty @adapter.executed
    expired = PlayerCommand.create!(action: "Pause", bus_name: @name, track_id: "/track/2", created_at: 30.seconds.ago)
    @watcher.process_commands
    assert_equal "Command expired", expired.reload.error
  end
end

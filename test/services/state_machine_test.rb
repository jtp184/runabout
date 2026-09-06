require "test_helper"

class StateMachineTest < ActiveSupport::TestCase
  setup do
    import_fixture
    @machine = Mpris::StateMachine.new(resolver: Identification::Resolver.new)
    @name = "org.mpris.MediaPlayer2.vlc"
    @properties = { "PlaybackStatus" => "Playing", "Position" => 19_612_094, "Rate" => 1.0, "Volume" => 0.5,
      "CanControl" => true, "CanSeek" => true, "Metadata" => { "xesam:url" => "file:///video/Star.Trek.TNG.S05E25.The.Inner.Light.mkv", "mpris:trackid" => "/track/1", "mpris:length" => 120_023_000 } }
  end

  test "appearance seek pause resume rate reconciliation media change and disappearance" do
    state = @machine.reconcile({ @name => @properties })
    assert_equal "PLAYING", state[:status]
    assert_in_delta 19.612094, state[:position]
    @properties["Position"] = 40_000_000
    @properties["PlaybackStatus"] = "Paused"
    assert_equal "IDLE", @machine.reconcile({ @name => @properties })[:status]
    assert_equal 40, @machine.state[:position]
    @properties.merge!("PlaybackStatus" => "Playing", "Rate" => 1.5, "Position" => 70_000_000)
    assert_equal 1.5, @machine.reconcile({ @name => @properties })[:rate]
    assert_equal 70, @machine.state[:position]
    keys = @machine.state[:episode_keys]
    @properties["Metadata"]["xesam:url"] = "file:///bonus.avi"
    assert_equal "UNMATCHED", @machine.reconcile({ @name => @properties })[:status]
    assert_equal keys, @machine.state[:episode_keys]
    assert_equal "NO_PLAYER", @machine.reconcile({})[:status]
    assert_equal keys, @machine.state[:episode_keys]
  end

  test "playing players win before configurable priority and idle has no loaded media" do
    paused = @properties.merge("PlaybackStatus" => "Paused")
    state = @machine.reconcile({ @name => paused, "org.mpris.MediaPlayer2.mpv" => @properties })
    assert_equal "org.mpris.MediaPlayer2.mpv", state[:bus_name]
    assert_equal @name, @machine.reconcile({ @name => @properties, "org.mpris.MediaPlayer2.mpv" => @properties })[:bus_name]
    assert_equal "IDLE", @machine.reconcile({ @name => { "Metadata" => {} } })[:status]
  end
end

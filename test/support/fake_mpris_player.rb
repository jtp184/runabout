require "dbus"

class FakeMprisPlayer < DBus::Object
  dbus_interface "org.mpris.MediaPlayer2.Player" do
    dbus_attr_accessor :playback_status, "s", dbus_name: "PlaybackStatus"
    dbus_attr_accessor :volume, "d", dbus_name: "Volume"
    dbus_attr_reader :position, "x", dbus_name: "Position", emits_changed_signal: false
    dbus_attr_reader :metadata, "a{sv}", dbus_name: "Metadata"
    dbus_attr_reader :rate, "d", dbus_name: "Rate"
    dbus_attr_reader :can_control, "b", dbus_name: "CanControl"
    dbus_attr_reader :can_seek, "b", dbus_name: "CanSeek"
    dbus_attr_reader :can_pause, "b", dbus_name: "CanPause"
    dbus_attr_reader :can_play, "b", dbus_name: "CanPlay"
    dbus_method :Pause do
      self.playback_status = "Paused"
    end
    dbus_method :Play do
      self.playback_status = "Playing"
    end
    dbus_method :SetPosition, "in track:o, in position:x" do |track, position|
      if track == "/track/1"
        @position = position
        Seeked(position)
      end
    end
    dbus_signal :Seeked, "position:x"
  end

  def initialize
    super("/org/mpris/MediaPlayer2")
    @playback_status, @position, @rate, @volume = "Playing", 19_612_094, 1.0, 0.5
    @can_control = @can_seek = @can_pause = @can_play = true
    @metadata = { "xesam:url" => "file:///Star.Trek.TNG.S05E25.The.Inner.Light.mkv", "mpris:trackid" => DBus::ObjectPath.new("/track/1"), "mpris:length" => DBus::Data::Int64.new(120_023_000) }
  end
end

bus = DBus::ASessionBus.new
bus.object_server.export(FakeMprisPlayer.new)
bus.request_name("org.mpris.MediaPlayer2.runabout_test")
puts "READY"
STDOUT.flush
DBus::Main.new.tap { |main| main << bus }.run

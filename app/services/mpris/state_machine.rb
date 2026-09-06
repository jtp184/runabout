module Mpris
  # No Rails or D-Bus dependencies: consumes complete property snapshots.
  class StateMachine
    attr_reader :state

    def initialize(resolver:, priority: %w[vlc mpv])
      @resolver, @priority = resolver, priority
      @state = { status: "NO_PLAYER", episode_keys: [], position: 0, rate: 1, playback_status: "Stopped" }
    end

    def reconcile(players, now: Time.now)
      chosen = players.keys.min_by do |name|
        token = name.delete_prefix("org.mpris.MediaPlayer2.").split(".").first
        [ players[name]["PlaybackStatus"] == "Playing" ? 0 : 1, @priority.index(token) || @priority.length, name ]
      end
      unless chosen
        @state = @state.merge(status: "NO_PLAYER", bus_name: nil, playback_status: "Stopped", captured_at: now, capabilities: {}, path: nil, track_id: nil, diagnostic: "No MPRIS player found. Start a local media player.")
        return @state
      end
      properties = players.fetch(chosen)
      metadata = properties.fetch("Metadata", {})
      path = metadata["xesam:url"].to_s
      loaded = !path.empty?
      result = @resolver.call(path) if loaded
      playback = properties.fetch("PlaybackStatus", "Stopped")
      keys = result&.matched? ? result.keys : @state[:episode_keys]
      status = if !loaded then "IDLE"
      elsif !result.matched? then "UNMATCHED"
      elsif playback == "Playing" then "PLAYING"
      else "IDLE"
      end
      @state = {
        status: status, bus_name: chosen, playback_status: playback,
        path: loaded ? path : nil, track_id: metadata["mpris:trackid"],
        position: [ properties.fetch("Position", 0).to_f / 1_000_000, 0 ].max,
        duration: [ metadata.fetch("mpris:length", 0).to_f / 1_000_000, 0 ].max,
        rate: properties.fetch("Rate", 1).to_f, volume: properties.fetch("Volume", 1).to_f,
        captured_at: now, episode_keys: keys, confidence: result&.confidence || 0,
        capabilities: properties.select { |key, _| key.start_with?("Can") },
        diagnostic: status == "UNMATCHED" ? "File not identified. Select its episode below." : nil
      }
    end
  end
end

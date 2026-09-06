module Mpris
  class Watcher
    def initialize(adapter: nil)
      @adapter = adapter
      @machine = StateMachine.new(resolver: Identification::Resolver.new, priority: ENV.fetch("RUNABOUT_PLAYER_PRIORITY", "vlc,mpv").split(","))
      @machine.state[:episode_keys] = PlayerState.current.episode_keys
    end

    def run
      @running = true
      %w[INT TERM].each { |signal| Signal.trap(signal) { @running = false } }
      while @running
        begin
          @adapter ||= Adapter.new
          reconcile
          next_poll = monotonic + 10
          while @running
            dirty = @adapter.wait
            if dirty || monotonic >= next_poll
              reconcile
              next_poll = monotonic + 10
            end
            process_commands
          end
        rescue StandardError => error
          Rails.logger.warn("MPRIS: #{error.class}: #{error.message}")
          persist(@machine.reconcile({}).merge(diagnostic: "D-Bus unavailable: #{error.message.to_s.truncate(180)}"))
          @adapter&.close rescue nil
          @adapter = nil
          40.times { break unless @running; sleep 0.25 }
        end
      end
    ensure
      @adapter&.close
    end

    def reconcile
      persist(@machine.reconcile(@adapter.snapshot, now: Time.current))
    end

    def process_commands
      commands = PlayerCommand.where(status: "pending").order(:id).limit(50).to_a
      return if commands.empty?
      commands.each do |command|
        begin
          reconcile
          state = PlayerState.current
          raise "Command expired" if command.created_at < 15.seconds.ago
          raise "Player or track changed" unless command.bus_name.present? && command.bus_name == state.bus_name && command.track_id == state.track_id
          capability = { "Play" => "CanPlay", "Pause" => "CanPause", "Next" => "CanGoNext", "Previous" => "CanGoPrevious", "SetPosition" => "CanSeek" }[command.action]
          raise "Player does not support this control" unless state.capabilities["CanControl"] && (!capability || state.capabilities[capability])
          raise "Seek exceeds duration" if command.action == "SetPosition" && command.value > state.duration
          @adapter.execute(command)
          command.update!(status: "done")
        rescue StandardError => error
          command.update!(status: "failed", error: error.message)
          PlayerState.current.update!(notice: error.message.to_s.truncate(180), notice_at: Time.current)
        end
      end
      PlayerCommand.where("created_at < ?", 1.day.ago).delete_all
    end

    private

    def persist(attributes)
      state = PlayerState.current
      attributes[:path] = Identification::Resolver.path(attributes[:path]) if attributes[:path]
      identified = attributes[:path].present? && !%w[UNMATCHED NO_PLAYER].include?(attributes[:status])
      state.transaction do
        viewing = state.viewing
        if viewing && (viewing.path != attributes[:path] || !identified || viewing.episode_keys != attributes[:episode_keys])
          viewing.update!(ended_at: Time.current)
          viewing = nil
        end
        if identified && !viewing
          viewing = Viewing.create!(path: attributes[:path], episode_keys: attributes[:episode_keys], started_at: Time.current)
        end
        viewing&.update!(furthest_position: [ viewing.furthest_position, attributes[:position] ].max)
        media = MediaFile.find_or_initialize_by(path: attributes[:path]) if attributes[:path].present?
        media&.update!(episode_keys: identified ? attributes[:episode_keys] : [], confidence: attributes[:confidence], kind: identified ? "episode" : "extra")
        state.update!(attributes.merge(viewing: viewing, media_file: media))
      end
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

class PlayerState < ApplicationRecord
  belongs_to :media_file, optional: true
  belongs_to :viewing, optional: true
  after_update_commit :broadcast_updates

  def self.current
    find_or_create_by!(id: 1)
  end

  def episodes
    Episode.for_keys(episode_keys)
  end

  def theme
    episodes.first&.series&.theme || "classic"
  end

  def broadcast_updates
    if previous_changes.key?("episode_keys") && episode_keys.any? && ENV["TMDB_API_KEY"].present?
      EnrichEpisodeJob.perform_later(episode_keys)
    end
    if previous_changes.key?("episode_keys")
      broadcast_dashboard
    else
      Turbo::StreamsChannel.broadcast_replace_to("player", target: "now-playing", partial: "dashboard/now_playing", locals: { state: self })
      if previous_changes.keys.intersect?(%w[path confidence status])
        Turbo::StreamsChannel.broadcast_replace_to("player", target: "match-controls", partial: "dashboard/match_picker", locals: { state: self })
      end
    end
  end

  def broadcast_dashboard
    broadcast = { target: "dashboard", partial: "dashboard/dashboard", locals: { state: self } }
    Turbo::StreamsChannel.broadcast_replace_to("player", **broadcast)
  end
end

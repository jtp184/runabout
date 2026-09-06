class CorrectionsController < ApplicationController
  def create
    state = PlayerState.current
    ids = Array(params[:episode_ids]).reject(&:blank?).uniq
    episodes = Episode.current.where(id: ids).includes(:series).sort_by { |episode| [ episode.series_id, episode.season.to_i, episode.number.to_i ] }
    if state.path.blank? || state.path != params[:path] || episodes.empty? || episodes.length != ids.length || episodes.length > 2 || episodes.map(&:series_id).uniq.length > 1
      redirect_to root_path, alert: "Choose one or two episodes for the current file.", status: :see_other
      return
    end
    MatchCorrection.transaction do
      MatchCorrection.find_or_initialize_by(path: state.path).update!(episode_keys: episodes.map(&:key))
      MediaFile.find_or_initialize_by(path: state.path).update!(episode_keys: episodes.map(&:key), confidence: 1, kind: "episode")
      state.update!(episode_keys: episodes.map(&:key), confidence: 1, status: state.playback_status == "Playing" ? "PLAYING" : "IDLE", diagnostic: nil)
    end
    redirect_to root_path, notice: "Match saved for this file.", status: :see_other
  end
end

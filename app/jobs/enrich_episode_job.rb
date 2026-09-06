class EnrichEpisodeJob < ApplicationJob
  def perform(keys)
    episodes = Episode.for_keys(keys)
    people = Credit.where(episode: episodes).includes(:person).map(&:person).uniq(&:id)
    photos = Enrichment::Tmdb.new
    (episodes + people).each { |record| photos.fetch(record) }
    state = PlayerState.current
    state.broadcast_dashboard if state.episode_keys == keys
  end
end

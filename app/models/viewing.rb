class Viewing < ApplicationRecord
  def episodes
    Episode.for_keys(episode_keys)
  end
end

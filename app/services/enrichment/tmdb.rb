module Enrichment
  class Tmdb
    def initialize(client: HttpClient.new, key: ENV["TMDB_API_KEY"])
      @client, @key = client, key
    end

    def fetch(record)
      return Photo.new(record) if @key.blank? || record.photo_data.present?
      if record.is_a?(Person)
        result = api("search/person", query: record.name).fetch("results", []).find { |person| person["name"].to_s.casecmp?(record.name) }
        path = result&.fetch("profile_path", nil)
        record.tmdb_id = result["id"] if result
      elsif record.series.tmdb_id && record.season && record.number
        path = api("tv/#{record.series.tmdb_id}/season/#{record.season}/episode/#{record.number}")["still_path"]
      end
      if path.present? && path.match?(%r{\A/[\w.-]+\.(?:jpg|png)\z}i)
        bytes = @client.get("https://image.tmdb.org/t/p/w500#{path}")
        raise "Invalid image" unless bytes.start_with?("\xFF\xD8".b, "\x89PNG".b)
        record.update!(photo_path: path, photo_data: bytes)
      end
      Photo.new(record)
    rescue StandardError => error
      Rails.logger.info("TMDB unavailable: #{error.class}")
      Photo.new(record)
    end

    private

    def api(path, **query)
      @client.json("https://api.themoviedb.org/3/#{path}?" + URI.encode_www_form(query.merge(api_key: @key)))
    end
  end
end

require "uri"

module Identification
  class Resolver
    Result = Data.define(:episodes, :confidence, :source, :parsed) do
      def keys = episodes.map(&:key)
      def matched? = episodes.any?
    end
    BOXSET = /\AStar\s+Trek\s+(?<series>.+?)\s+Season\s+(?<season>\d{1,2})\s+Episode\s+(?<ep>\d{1,2})(?:\s*&\s*(?<ep2>\d{1,2}))?\s*-\s*(?<title>.+)\z/i
    SCENE = /\A(?<series>.*?)S(?<season>\d{1,2})E(?<ep>\d{2})(?:(?:E|[ ._-]*&[ ._-]*)(?<ep2>\d{2}))?[ ._-]*(?<title>.*)\z/i
    CROSS = /\A(?<series>.*?)(?<season>\d{1,2})x(?<ep>\d{2})(?:[&-](?<ep2>\d{2}))?[ ._-]*(?<title>.*)\z/i
    LOOSE = /\AStar[ ._-]+Trek[ ._-]+(?<series>.+?)[ ._-]+(?<season>\d{1,2})[ ._-]+(?<ep>\d{2})[ ._-]+(?<title>.+)\z/i

    def self.path(url)
      return url.to_s unless url.to_s.start_with?("file:")
      uri = URI.parse(url)
      return url unless uri.host.nil? || [ "", "localhost" ].include?(uri.host)
      URI::DEFAULT_PARSER.unescape(uri.path)
    rescue URI::InvalidURIError
      url.to_s
    end

    def call(path, indexed: true)
      path = self.class.path(path)
      correction = MatchCorrection.find_by(path: path)
      if correction
        return Result.new(episodes: Episode.for_keys(correction.episode_keys), confidence: 1.0, source: "correction", parsed: {})
      end
      media = MediaFile.find_by(path: path) if indexed
      if media && media.episode_keys.any?
        episodes = Episode.for_keys(media.episode_keys)
        return Result.new(episodes: episodes, confidence: media.confidence, source: "library", parsed: {}) if episodes.length == media.episode_keys.length
      end
      stem = File.basename(path).sub(/\.(mkv|avi|mp4|m4v|webm|mov)\z/i, "")
      parsed = {}
      [ BOXSET, SCENE, CROSS, LOOSE ].each_with_index do |pattern, rung|
        match = pattern.match(stem)
        next unless match
        parsed = match.named_captures
        series = Series.resolve(parsed["series"])
        next unless series
        numbers = [ parsed["ep"], parsed["ep2"] ].compact.map(&:to_i).uniq
        episodes = numbers.map { |number| Episode.current.find_by(series: series, season: parsed["season"].to_i, number: number) }
        next if episodes.any?(&:nil?)
        title = Series.normalize(parsed["title"])
        canonical = Series.normalize(episodes.first.title)
        similarity = title.include?(canonical) || canonical.include?(title) ? 1.0 : overlap(title, canonical)
        confidence = ([ 0.92, 0.86, 0.82, 0.65 ][rung] + similarity * 0.08).round(2)
        return Result.new(episodes: episodes, confidence: confidence, source: pattern == BOXSET ? "boxset" : "filename", parsed: parsed)
      end
      Result.new(episodes: [], confidence: 0, source: "unmatched", parsed: parsed.merge("filename" => stem))
    end

    private

    def overlap(a, b)
      left = a.chars.each_cons(2).to_a
      right = b.chars.each_cons(2).to_a
      return 0 if left.empty? || right.empty?
      2.0 * (left & right).length / (left.length + right.length)
    end
  end
end

module Identification
  class Scanner
    def call(root = ENV.fetch("RUNABOUT_LIBRARY", "/mnt/dhd/video/tv/Star Trek"))
      raise ArgumentError, "Library not found: #{root}" unless File.directory?(root)
      counts = Hash.new(0)
      Dir.glob(File.join(root, "**", "*")).sort.each do |path|
        next unless File.file?(path) && path.match?(/\.(mkv|avi|mp4|m4v|webm|mov)\z/i)
        result = Resolver.new.call(File.expand_path(path), indexed: false)
        kind = result.matched? ? "episode" : "extra"
        MediaFile.find_or_initialize_by(path: File.expand_path(path)).update!(episode_keys: result.keys, confidence: result.confidence, kind: kind, scanned_at: Time.current)
        counts[kind] += 1
      end
      counts
    end
  end
end

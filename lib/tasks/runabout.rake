namespace :runabout do
  desc "Import Memory Alpha atomically (XML=/path/to/dump.xml skips download)"
  task ingest: :environment do
    progress = TaskProgress.new
    progress.call("Starting Memory Alpha ingest")
    load Rails.root.join("db/seeds.rb")
    ActiveRecord.verbose_query_logs = false
    ActiveRecord::Base.logger.level = Logger::WARN
    path = ENV["XML"].presence || MemoryAlpha::Dump.prepare(progress: progress)
    ingest = MemoryAlpha::Importer.new.call(path, progress: progress)
    progress.call "Activated ingest #{ingest.id}: #{ingest.episodes.count} episodes, #{ingest.entities.count} entities, #{ingest.people.count} performers"
  end

  desc "Index the local media library (RUNABOUT_LIBRARY overrides the root)"
  task scan: :environment do
    abort "Run runabout:ingest first" unless Catalog.current_id
    puts Identification::Scanner.new.call.inspect
  end

  desc "Cache article HTML and TMDB images for all indexed episodes"
  task backfill: :environment do
    progress = TaskProgress.new
    progress.call("Collecting indexed episodes for backfill")
    keys = MediaFile.all.flat_map(&:episode_keys) + MatchCorrection.all.flat_map(&:episode_keys)
    episodes = Episode.for_keys(keys.uniq).uniq(&:id)
    abort "No indexed episodes. Run runabout:scan first." if episodes.empty?
    people = Credit.where(episode: episodes).includes(:person).map(&:person).uniq(&:id)
    entities = EntityMention.where(episode: episodes).includes(:entity).map(&:entity).uniq(&:id)
    pages = (episodes + people + entities).map(&:page).uniq
    progress.call("Backfill scope: #{episodes.length} episodes, #{people.length} performers, #{entities.length} entities; #{pages.length} unique articles")
    cache = MemoryAlpha::ArticleCache.new
    format_counts = ->(counts) { counts.map { |status, count| "#{count} #{status}" }.join(", ") }
    article_counts = { cached: 0, fetched: 0, unavailable: 0 }
    pages.each_with_index do |page, index|
      cached = Article.where(page: page).where.not(fetched_at: nil).exists?
      progress.call("Articles #{index + 1}/#{pages.length}: #{cached ? 'checking cache' : 'fetching'} #{page}", force: !cached)
      article = cache.fetch(page)
      outcome = if cached then :cached
      elsif article&.fetched_at then :fetched
      else :unavailable
      end
      article_counts[outcome] += 1
      progress.call("Articles #{index + 1}/#{pages.length}: #{outcome} — #{page}; #{format_counts.call(article_counts)}", force: !cached)
    end
    progress.call("Articles complete: #{format_counts.call(article_counts)}")

    records = episodes + people
    photo_counts = { cached: 0, fetched: 0, unavailable: 0, skipped: 0 }
    photos = Enrichment::Tmdb.new
    has_key = ENV["TMDB_API_KEY"].present?
    progress.call("TMDB_API_KEY is not set; uncached photographs will be skipped") unless has_key
    records.each_with_index do |record, index|
      cached = record.photo_data.present?
      label = record.is_a?(Episode) ? record.label : record.name
      fetch = !cached && has_key
      progress.call("Photos #{index + 1}/#{records.length}: #{fetch ? 'fetching' : 'checking cache'} #{label}", force: fetch)
      outcome = if cached then :cached
      elsif !has_key then :skipped
      elsif photos.fetch(record).path then :fetched
      else :unavailable
      end
      photo_counts[outcome] += 1
      progress.call("Photos #{index + 1}/#{records.length}: #{outcome} — #{label}; #{format_counts.call(photo_counts)}", force: fetch)
    end
    progress.call("Backfill complete: articles #{format_counts.call(article_counts)}; photos #{format_counts.call(photo_counts)}")
  end
end

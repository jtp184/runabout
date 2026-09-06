require "nokogiri"

module MemoryAlpha
  class Importer
    BILLING = { "Starring" => "starring", "Also starring" => "also starring", "Guest stars" => "guest", "Co-star" => "co-star", "Co-stars" => "co-star", "Uncredited co-stars" => "uncredited" }.freeze

    def call(path, progress: nil)
      @progress = progress
      @page_total = nil
      # The lock spans parsing and activation; two imports must never prune each other.
      File.open("#{ActiveRecord::Base.connection_db_config.database}.ingest.lock", "w") do |lock|
        raise "Another ingest is running" unless lock.flock(File::LOCK_EX | File::LOCK_NB)
        @ingest = Ingest.create!
        @progress&.call("Building ingest #{@ingest.id} from #{path}; active catalog remains unchanged until activation")
        @modules = {}
        @series = Series.all.to_a
        @series_by_alias = @series.each_with_object({}) do |series, index|
          ([ series.name, series.code ] + series.aliases).each { |name| index[Series.normalize(name)] = series }
        end
        @rules = ClassificationRule.order(priority: :desc).map { |rule| [ Regexp.new(rule.pattern, Regexp::IGNORECASE), rule.display_type ] }
        @entities = {}
        pages(path, "1/3 Episode metadata") do |title, _namespace, text|
          if title.match?(%r{\AModule:EpisodeData/[ANSDMY]\z})
            @modules[title.split("/").last] = text.scan(/\["((?:\\.|[^"\\])*)"\]\s*=\s*"((?:\\.|[^"\\])*)"/).to_h.transform_keys { |key| key.gsub('\\"', '"') }
          end
        end
        @progress&.call("Loaded #{@modules.length} episode data modules; creating episode records")
        seed_episode_metadata
        @progress&.call("Seeded #{@ingest.episodes.count} episode records")
        pages(path, "2/3 Episode articles") do |title, namespace, text|
          next unless namespace.zero? && !text.match?(/\A\s*#redirect/i)
          import_episode(title, text) if text.match?(/\{\{sidebar (?:episode|film)\b/i)
        end
        raise "No episodes found; catalog was not changed" if @ingest.episodes.empty?
        @progress&.call("Episode articles complete: #{@ingest.episodes.count} episode records, #{@ingest.people.count} performers, #{@entities.length} referenced entities")
        @people = @ingest.people.index_by(&:page)
        @episodes_by_title = @ingest.episodes.to_a.group_by { |episode| [ episode.series_id, episode.title ] }
        pages(path, "3/3 Subjects and reverse citations") do |title, namespace, text|
          next unless namespace.zero? && !text.match?(/\A\s*#redirect/i)
          import_subject(title, text)
        end
        @progress&.call("Activating ingest #{@ingest.id}: #{@ingest.episodes.count} episodes, #{@ingest.entities.count} entities, #{@ingest.people.count} performers")
        @ingest.transaction do
          Catalog.find_or_create_by!(id: 1).update!(ingest: @ingest)
          @ingest.update!(status: "complete")
        end
        # Keep the preceding good snapshot until the next successful refresh.
        keep = Ingest.where(status: "complete").order(id: :desc).limit(2).pluck(:id)
        obsolete = Ingest.where.not(id: keep)
        @progress&.call("Catalog activated; pruning #{obsolete.count} old or failed ingests")
        obsolete.find_each do |old|
          @progress&.call("Pruning ingest #{old.id}")
          old.destroy!
        end
        PlayerState.current.broadcast_dashboard
        @progress&.call("Ingest #{@ingest.id} complete; dashboard notified")
        @ingest
      rescue StandardError => error
        @progress&.call("Ingest failed: #{error.class}: #{error.message}; active catalog is #{Catalog.current_id || 'unset'}")
        @ingest&.update!(status: "failed", error: error.message) unless @ingest&.status == "complete"
        raise
      end
    end

    private

    def pages(path, phase)
      @progress&.call("#{phase}: scanning XML")
      count = 0
      title = nil
      File.open(path, "rb") do |file|
        reader = Nokogiri::XML::Reader(file, nil, nil, Nokogiri::XML::ParseOptions::NONET)
        reader.each do |node|
          next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT && node.local_name == "page"
          page = Nokogiri::XML(node.outer_xml) { |config| config.strict.nonet }.remove_namespaces!
          title = page.at_xpath("/page/title").text
          yield title, page.at_xpath("/page/ns")&.text.to_i, page.at_xpath("/page/revision/text")&.text.to_s
          count += 1
          @progress&.call("#{phase}: #{count}#{@page_total ? "/#{@page_total}" : ""} pages scanned; last page: #{title}", force: false)
        end
        raise reader.errors.first if reader.errors.any? { |error| error.error? || error.fatal? }
      end
      @page_total = count
      @progress&.call("#{phase}: finished scanning #{count} pages")
    end

    def seed_episode_metadata
      @ingest.transaction do
        @modules.fetch("A", {}).each do |title, code|
          series = @series_by_alias[Series.normalize(code == "FLM" ? "FILM" : code)]
          next unless series
          coordinate = @modules.dig("N", title).to_s.match(/(\d+)x(\d+)(?:\/(\d+))?/)
          numbers = coordinate ? [ coordinate[2], coordinate[3] ].compact.map(&:to_i) : []
          numbers = [ nil ] if code == "FLM"
          numbers.each do |number|
            @ingest.episodes.create!(series: series, season: coordinate&.[](1)&.to_i, number: number, title: title,
              page: "#{title} (#{code == 'FLM' ? 'film' : 'episode'})",
              airdate: [ @modules.dig("D", title), @modules.dig("M", title), @modules.dig("Y", title) ].compact.join(" "))
          end
        end
      end
    end

    def import_episode(page, text)
      title = page.sub(/ \((?:episode|film)\)\z/, "")
      film = text.match?(/\{\{sidebar film\b/i)
      fields = Wikitext.fields(text, film ? "sidebar film" : "sidebar episode")
      code = fields["series"].presence || @modules.dig("A", title)
      code = "FILM" if film || code == "FLM"
      series = @series_by_alias[Series.normalize(code)]
      return unless series
      coordinates = @modules.dig("N", title).to_s.match(/(\d+)x(\d+)(?:\/(\d+))?/)
      season = fields["season"]&.to_i || coordinates&.[](1)&.to_i
      numbers = fields["episode"].present? ? fields["episode"].scan(/\d+/).map(&:to_i) : [ coordinates&.[](2), coordinates&.[](3) ].compact.map(&:to_i)
      numbers = [ nil ] if film
      return if numbers.empty?
      airdate = fields["airdate"] || [ @modules.dig("D", title), @modules.dig("M", title), @modules.dig("Y", title) ].compact.join(" ")
      @ingest.transaction do
        numbers.each do |number|
          episode = @ingest.episodes.find_or_initialize_by(series: series, season: season, number: number, title: title)
          episode.update!(page: page,
            stardate: Wikitext.clean(fields["date"] || fields["stardate"]), airdate: airdate,
            director: Wikitext.clean(fields["director"]), writers: %w[writer writers teleplay story].filter_map { |key| Wikitext.clean(fields[key]).presence }.uniq.join("; "),
            image: fields["image"], blurb: Wikitext.lead(text), summary: Wikitext.clean(Wikitext.section(text, "Summary")),
            background: Wikitext.clean(Wikitext.section(text, "Background information")))
          references = Wikitext.section(text, "References")
          unseen = Wikitext.section(references, "Unreferenced material")
          seen = references.split(/^====\s*Unreferenced material/i).first
          [ [ seen, true ], [ unseen, false ] ].each do |content, visible|
            Wikitext.links(content).each { |name| mention(episode, entity(name), visible, "references") }
          end
          BILLING.each do |heading, billing|
            Wikitext.section(text, heading).lines.each do |line|
              match = line.match(/^\*\s*\[\[([^\]|]+)(?:\|([^\]]+))?\]\]\s+as\s+(.+)/i)
              next unless match
              person = @ingest.people.find_or_create_by!(page: match[1]) { |record| record.name = match[2] || match[1] }
              episode.credits.create!(person: person, character: Wikitext.clean(match[3]), billing: billing)
            end
          end
          quote_lines = []
          Wikitext.section(text, "Memorable quotes").lines.each do |line|
            if line.match?(/^:\s*[-–]/)
              attribution = Wikitext.clean(line.sub(/^:\s*[-–]\s*/, ""))
              speaker, context = attribution.split(/,\s*/, 2)
              episode.quotes.create!(text: Wikitext.clean(quote_lines.join).strip, speaker: speaker, context: context, ordinal: episode.quotes.count) if quote_lines.any?
              quote_lines = []
            elsif line.strip.present?
              quote_lines << line
            end
          end
        end
      end
    end

    def entity(page)
      @entities[page] ||= @ingest.entities.find_or_create_by!(page: page) { |record| record.name = page }
    end

    def mention(episode, subject, seen, source)
      row = EntityMention.find_or_initialize_by(episode: episode, entity: subject, seen: seen)
      row.sources = (row.sources + [ source ]).uniq
      row.save!
    end

    def import_subject(page, text)
      return if text.match?(/\{\{sidebar (?:episode|film)\b/i)
      person = @people[page]
      person ||= @ingest.people.new(page: page, name: page) if text.match?(/\{\{sidebar (?:performer|actor)\b/i)
      if person
        person.update!(biography: Wikitext.lead(text))
        return
      end
      return if text.match?(/\{\{real world\b/i)
      categories = text.scan(/\[\[Category:([^\]|]+)(?:\|[^\]]*)?\]\]/i).flatten
      citations = Wikitext.templates(text, nested: true).filter_map do |template|
        code, *titles = Wikitext.parts(template)
        series = @series_by_alias[Series.normalize(code)]
        [ series, titles.reject { |title| title.include?("=") } ] if series
      end
      subject = @entities[page]
      return unless subject || citations.any?
      subject ||= entity(page)
      subject.update!(gloss: Wikitext.lead(text), categories: categories, display_type: @rules.find { |pattern, _type| categories.any? { |category| pattern.match?(category) } }&.last || "Other")
      citations.each do |series, titles|
        titles.each do |title|
          Array(@episodes_by_title[[ series.id, title ]]).each do |episode|
            existing = EntityMention.where(episode: episode, entity: subject)
            if existing.any?
              existing.each { |row| row.update!(sources: (row.sources + [ "citation" ]).uniq) }
            else
              # A citation alone does not establish that a subject appeared on screen.
              mention(episode, subject, false, "citation")
            end
          end
        end
      end
    end
  end
end

module MemoryAlpha
  class ArticleCache
    TAGS = %w[p br b strong i em ul ol li dl dt dd blockquote h2 h3 h4 h5 table thead tbody tr th td a sup sub span].freeze

    def initialize(client: Enrichment::HttpClient.new)
      @client = client
    end

    def fetch(page)
      cached = Article.find_by(page: page)
      return cached if cached&.fetched_at
      url = "https://memory-alpha.fandom.com/api.php?" + URI.encode_www_form(action: "parse", page: page, prop: "text", format: "json", disableeditsection: 1)
      response = @client.json(url)
      html = response.fetch("parse").fetch("text").fetch("*")
      sanitized = sanitize(html)
      cached ||= Article.new(page: page)
      cached.update!(html: sanitized, fetched_at: Time.current)
      cached
    rescue StandardError => error
      Rails.logger.info("Article cache unavailable: #{error.class}")
      cached
    end

    def sanitize(html)
      fragment = Nokogiri::HTML.fragment(html)
      fragment.css("script, style, iframe, form, object, embed, .mw-editsection").remove
      fragment.css("a").each do |link|
        href = link["href"].to_s
        uri = URI.parse(href) rescue nil
        if href.start_with?("/wiki/") || (uri&.host == "memory-alpha.fandom.com" && uri.path.start_with?("/wiki/"))
          title = URI::DEFAULT_PARSER.unescape((uri&.path || href).delete_prefix("/wiki/")).tr("_", " ")
          link["href"] = Rails.application.routes.url_helpers.article_path(page: title)
          link["data-turbo-frame"] = "detail"
        elsif href.start_with?("#")
          link.remove_attribute("href")
        elsif !uri || !%w[http https].include?(uri.scheme)
          link.remove_attribute("href")
        else
          link["rel"] = "noopener noreferrer"
          link["target"] = "_blank"
        end
      end
      Rails::HTML5::SafeListSanitizer.new.sanitize(fragment.to_html, tags: TAGS, attributes: %w[href title rel target data-turbo-frame])
    end
  end
end

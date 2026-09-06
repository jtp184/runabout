require "net/http"
require "json"

module Enrichment
  class HttpClient
    def get(url, headers: {}, limit: 8.megabytes)
      uri = URI(url)
      raise "HTTPS required" unless uri.is_a?(URI::HTTPS)
      body = +"".b
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Mozilla/5.0 Runabout/1.0 (personal second screen)"
        headers.each { |key, value| request[key] = value }
        http.request(request) do |response|
          raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
          response.read_body do |chunk|
            body << chunk
            raise "Response too large" if body.bytesize > limit
          end
        end
      end
      body
    end

    def json(url, **options)
      JSON.parse(get(url, **options))
    end
  end
end

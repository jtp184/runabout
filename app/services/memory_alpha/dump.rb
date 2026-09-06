require "net/http"
require "open3"

module MemoryAlpha
  class Dump
    URL = "https://s3.amazonaws.com/wikia_xml_dumps/e/en/enmemoryalpha_pages_current.xml.7z"

    def self.prepare(progress: nil)
      directory = Pathname.new(ENV.fetch("RUNABOUT_DATA_DIR", Rails.root.join("tmp", "second-screen")))
      FileUtils.mkdir_p(directory)
      archive = directory.join("memory-alpha.xml.7z")
      temporary = directory.join("download-#{Process.pid}.part")
      begin
        progress&.call("Downloading Memory Alpha dump from #{URL}")
        uri = URI(URL)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 120) do |http|
          http.request(Net::HTTP::Get.new(uri)) do |response|
            raise "Dump download failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
            total = response["content-length"].to_i
            received = 0
            File.open(temporary, "wb") do |file|
              response.read_body do |chunk|
                file.write(chunk)
                received += chunk.bytesize
                percent = total.positive? ? " / #{(total / 1048576.0).round(1)} MiB (#{received * 100 / total}%)" : ""
                progress&.call("Download: #{(received / 1048576.0).round(1)} MiB#{percent}", force: false)
              end
            end
          end
        end
        File.rename(temporary, archive)
        progress&.call("Download complete: #{(File.size(archive) / 1048576.0).round(1)} MiB; extracting with 7z")
        xml = directory.join("memory-alpha.xml")
        partial = directory.join("extract-#{Process.pid}.part")
        File.open(partial, "wb") do |output|
          Open3.popen3("7z", "x", "-so", archive.to_s) do |stdin, stdout, stderr, waiter|
            stdin.close
            errors = Thread.new { stderr.read }
            extracted = 0
            while (chunk = stdout.read(1024 * 1024))
              output.write(chunk)
              extracted += chunk.bytesize
              progress&.call("Extraction: #{(extracted / 1048576.0).round(1)} MiB written", force: false)
            end
            raise "7z extraction failed: #{errors.value}" unless waiter.value.success?
            errors.value
          end
        end
        File.rename(partial, xml)
        progress&.call("Extraction complete: #{xml} (#{(File.size(xml) / 1048576.0).round(1)} MiB)")
        xml.to_s
      ensure
        FileUtils.rm_f(temporary)
        FileUtils.rm_f(partial) if partial
      end
    end
  end
end

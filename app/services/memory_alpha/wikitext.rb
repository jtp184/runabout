require "cgi"

module MemoryAlpha
  class Wikitext
    def self.templates(text, nested: false)
      stack, found = [], []
      text.to_s.to_enum(:scan, /\{\{|\}\}/).each do
        match = Regexp.last_match
        if match[0] == "{{"
          stack << match.begin(0)
        elsif stack.any?
          start = stack.pop
          found << text[start...match.end(0)] if nested || stack.empty?
        end
      end
      found
    end

    def self.parts(template)
      inner = template.sub(/\A\{\{/, "").sub(/\}\}\z/, "")
      parts, buffer, depth = [], +"", 0
      inner.scan(/\{\{|\}\}|\[\[|\]\]|\||[^{}\[\]|]+|./m).each do |token|
        depth += 1 if [ "{{", "[[" ].include?(token)
        depth -= 1 if [ "}}", "]]" ].include?(token)
        if token == "|" && depth.zero?
          parts << buffer.strip
          buffer = +""
        else
          buffer << token
        end
      end
      parts << buffer.strip
    end

    def self.fields(text, name)
      template = templates(text).find { |value| parts(value).first.to_s.casecmp?(name) }
      return {} unless template
      parts(template).drop(1).filter_map do |part|
        key, value = part.split("=", 2)
        [ key.strip.downcase, value.strip ] if value
      end.to_h
    end

    def self.links(text)
      result = text.to_s.scan(/\[\[([^\]|#]+)(?:[^\]]*)\]\]/).flatten
      templates(text).each do |template|
        name, *args = parts(template)
        case name.downcase
        when "dis" then result << "#{args[0]} (#{args[1]})"
        when "uss" then result << "USS #{args[0]}#{args[1].present? ? " (#{args[1]})" : ''}"
        when "revname" then result << args.join(" ")
        end
      end
      result.map(&:strip).reject { |link| link.include?(":") || link.empty? }.uniq
    end

    def self.clean(text)
      text = text.to_s.gsub(/__[A-Z_]+__/, "").gsub(/<!--.*?-->/m, "").gsub(/<ref\b[^>]*>.*?<\/ref>|<ref\b[^>]*\/>/mi, "")
      templates(text).each do |template|
        name, *args = parts(template)
        replacement = case name.to_s.downcase
        when "uss" then "USS #{args[0]}"
        when "dis" then args[2] || args[0]
        when "revname" then args.join(" ")
        when "aquote", "quote" then args[0]
        when "nowrap", "small", "w", "wikipedia" then args.last
        when "born", "birth date", "death date" then args.join("-")
        else ""
        end
        text = text.gsub(template, replacement.to_s)
      end
      text = text.gsub(/\[\[(?:File|Image|Category):[^\]]*\]\]/i, "")
      text = text.gsub(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/) { Regexp.last_match(2) || Regexp.last_match(1) }
      text = text.gsub(/\[https?:\/\/\S+\s+([^\]]+)\]/, '\1').gsub(/'{2,5}/, "")
      CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(text)).gsub(/\(\s*[;,]?\s*\)/, "").gsub(/[ \t]+/, " ").strip
    end

    def self.lead(text)
      text = text.to_s.split(/^==/).first.to_s
      templates(text).each do |template|
        text = text.sub(template, "") if %w[aquote quote].include?(parts(template).first.to_s.downcase)
      end
      clean(text).split(/\n\s*\n/).find(&:present?).to_s
    end

    def self.section(text, heading)
      lines = text.to_s.lines
      start = lines.index { |line| line.match?(/^={2,6}\s*#{Regexp.escape(heading)}\s*={2,6}\s*$/i) }
      return "" unless start
      level = lines[start][/\A=+/].length
      lines.drop(start + 1).take_while { |line| !(match = line.match(/\A(={2,6})[^=]/)) || match[1].length > level }.join
    end
  end
end

# coding: utf-8

if RUBY_VERSION =~ /^1\.9\./
  $: << "."
  require "csv"
  FasterCSV = CSV
end

require "fileutils"
require "set"

require "lib" / "asset_store"
require "lib" / "conversion"
require "lib" / "indexer"
require "lib" / "mailer"
require "lib" / "password"
require "lib" / "speller"

require "lib" / "partners" / "marine_store"

use_orm :datamapper
use_test :rspec
use_template_engine :erb

Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = "datamapper"
  c[:session_expiry] = 100 * 365 * Merb::Const::DAY
  c[:adapter] = 'thin'  # Added this line to use Thin
end

Merb::BootLoader.before_app_loads do

  # These methods are handy to have available in general

  class Array
    def friendly_join(andor)
      size <= 1 ? first : self[0..-2].join(", ") + " #{andor} #{last}"
    end

    def hash_by(method = nil)
      hash = {}
      each do |item|
        key = (method.nil? ? (yield item) : item.send(method))
        hash[key] = item
      end
      hash
    end

    def repeated
      counts = Hash.new(0)
      each { |item| counts[item] += 1 }
      counts.reject { |item, count| count < 2 }.keys
    end
  end

  class Hash
    def keep(*keys)
      hash = {}
      keys.each { |key| hash[key] = self[key] if self.has_key?(key) }
      hash
    end
  end

  class String
    def attribute_escape(inner_escape_single_quotes = false)
      escaped = Merb::Parse.escape_xml(self)
      escaped.gsub!(/(')/) { "\\'" } if inner_escape_single_quotes
      escaped
    end

    # temporary mechanism to cope with encoding problems in 1.9
    # alias_method :orig_concat, :concat
    # def concat(other)
    #   begin
    #     orig_concat(other)
    #   rescue Encoding::CompatibilityError
    #     p [encoding, self]
    #     p [other.encoding, other]
    #     encode("utf-8").concat(other.endcode("utf-8"))
    #   end
    # end

    def desuperscript
      gsub(%r{<sup>(.*?)</sup>}, '\1')
    end

    def pluralize_count(count)
      "#{count} #{self}#{count == 1 ? '' : 's'}"
    end

    def superscript(matcher = /([®™])/)
      gsub(matcher) { |c| "<sup>#{c}</sup>" }
    end

    def superscript_numeric
      parts = split(" ")
      last_part = parts.pop
      return self unless last_part =~ /[a-z]/
      (parts << last_part.superscript(/(\d)/)).join(" ")
    end

    def truncate_utf8(size)
      self =~ /^(.{1,#{size}})/
      ($1.size + 3) < self.size ? "#{$1}..." : self
    end
  end

  # TODO: both compile steps should happen in server mode only

  # Merge all JS files - TODO: lint + minify
  path = "public/javascripts/compiled.js"
  File.delete(path) if File.exist?(path)
  raise $?.inspect unless system("cat public/javascripts/*.js > #{path}")

  # Merge all CSS files - TODO: lint + minify
  path = "public/stylesheets/compiled.css"
  File.delete(path) if File.exist?(path)
  raise $?.inspect unless system("cat public/stylesheets/*.css > #{path}")

end

Merb::BootLoader.after_app_loads do
  require "lib" / "data_mapper_session_store"
  begin
    Indexer.compile unless Indexer.facilities
  rescue => e
    Merb.logger.error("Failed to compile Indexer: #{e.message}")
  end
end

Encoding.default_internal = 'UTF-8'
Encoding.default_external = 'UTF-8'

if RUBY_VERSION =~ /^1\.9\./
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
 
use_orm :datamapper
use_test :rspec
use_template_engine :erb
 
Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = "datamapper"
end
 
Merb::BootLoader.before_app_loads do
    
  # These methods are handy to have available in general
  
  class Array
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
  # Monkey-patch DM session storage to persist an update time _and_ base expiry thereon
  class Merb::DataMapperSessionStore
    EXPIRY_TIME = Merb::Const::WEEK
    
    property :updated_at, DateTime
    before(:save) { self.updated_at = DateTime.now }
    
    def self.expired
      all(:updated_at.lt => EXPIRY_TIME.ago)
    end
  end
end
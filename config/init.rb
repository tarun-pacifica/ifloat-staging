if RUBY_VERSION =~ /^1\.9\./
  require "csv"
  FasterCSV = CSV
end

require "fileutils"

require "lib" / "asset_store"
require "lib" / "conversion"
require "lib" / "indexer"
require "lib" / "password"
 
use_orm :datamapper
use_test :rspec
use_template_engine :erb
 
Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = "datamapper"
  c[:session_ttl] = Merb::Const::WEEK
end
 
Merb::BootLoader.before_app_loads do
    
  # These methods are handy to have available in general
  class Array
    def hash_by(method = nil) # TODO: check for opportunities to use this
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
  
end

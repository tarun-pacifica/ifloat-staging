require 'config/dependencies.rb'
 
use_orm :datamapper
use_test :rspec
use_template_engine :erb
 
Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = 'memory'  # can also be 'cookie', 'memcache', 'container', 'datamapper'
  c[:memory_session_ttl] = Merb::Const::WEEK
  # TODO: switch to a DB based session store
  
  # cookie session store configuration
  # c[:session_secret_key]  = '73b8ddd39dfcb0589db9e62307f42a6955e22640'  # required for cookie session store
  # c[:session_id_key] = '_pristine_session_id' # cookie session id key, defaults to "_session_id"
end
 
Merb::BootLoader.before_app_loads do
  # Override storage for YAML type (which is normally set to String)
  # TODO: Remove once the dm-types maintainers come to their senses
  module DataMapper
    module Types
      class Yaml < DataMapper::Type
        primitive Text
      end
    end
  end
  
  # This method is handy to have available in general
  class Array
    def repeated
      counts = Hash.new(0)
      each { |item| counts[item] += 1 }
      counts.reject { |item, count| count < 2 }.keys
    end
  end
end

# Load low-level database adapters first
require 'rubygems'
require 'data_objects'
require 'do_mysql'

# Initialize DataObjects MySQL before DataMapper
module DataObjects
  module Mysql
    def self.logger
      @logger ||= DataObjects::Logger.new(STDOUT, :off)
    end
  end
end

# Now load DataMapper and its components
require 'dm-core'
require 'dm-migrations'
require 'dm-mysql-adapter'

# Set up the connection with proper MySQL encoding
DataMapper.setup(:default, {
                   :adapter  => 'mysql',
                   :host     => 'localhost',
                   :username => 'ifloat_app',
                   :password => 'j4hd7ag234',
                   :database => 'ifloat_prod',
                   :encoding => 'utf8',
                   :reconnect => true,
                   :variables => {
                     :charset => 'utf8',
                     :collation => 'utf8_unicode_ci'
                   }
})

Merb.logger.info("Loaded PRODUCTION Environment...")

Merb::Config.use { |c|
  c[:exception_details] = false
  c[:reload_templates] = false
  c[:reload_classes] = false
  c[:log_auto_flush ] = false
  c[:log_level] = :error
  c[:log_stream] = nil
  c[:log_file] = Merb.root / "log" / "production.log"
  c[:registration_host] = "http://www.ifloat.biz"
}

Merb::BootLoader.after_app_loads do
  AssetStore.config(:mosso, :user => "pristine", :key => "b7db73b0bd047f7292574d7c9f0d16de", :container => "ifloat-production", :url_stem => "http://assets.ifloat.biz")
  Mail.defaults do
    delivery_method :smtp, :address              => "mail.authsmtp.com",
      :port                 => 2525,
      :domain               => "www.ifloat.biz",
      :user_name            => "ac47472",
      :password             => "UOE869",
      :authentication       => :cram_md5,
      :enable_starttls_auto => false
  end
end

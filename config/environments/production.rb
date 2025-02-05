require 'rubygems'
require 'dm-core'
require 'dm-migrations'
require 'dm-mysql-adapter'

# Setup the DataMapper connection before configuring MySQL logger
DataMapper.setup(:default, {
                   :adapter  => 'mysql',
                   :host     => 'localhost',
                   :username => 'ifloat_app',
                   :password => 'j4hd7ag234',
                   :database => 'ifloat_prod',
                   :encoding => 'utf8mb4',
                   :reconnect => true
})

# Now configure the MySQL logger
require 'data_objects'
require 'do_mysql'
DataObjects::MySQL.logger = DataObjects::Logger.new(STDOUT, :off)
DataObjects::Connection.quote_identifier = false

# Rest of your production.rb configuration
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

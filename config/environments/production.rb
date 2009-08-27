Merb.logger.info("Loaded PRODUCTION Environment...")
Merb::Config.use { |c|
  c[:exception_details] = false
  c[:reload_templates] = false
  c[:reload_classes] = false
  
  c[:log_auto_flush ] = false
  c[:log_level] = :error
  c[:log_stream] = nil
  c[:log_file] = Merb.root / "log" / "production.log"
}

Merb::BootLoader.after_app_loads do
  # Merb::Mailer.config = {:host => 'mail.freedom255.com', :port => 25}
  AssetStore.config(:mosso, :user => "pristine", :key => "b7db73b0bd047f7292574d7c9f0d16de", :url_stem => "http://c0210061.cdn.cloudfiles.rackspacecloud.com")
end

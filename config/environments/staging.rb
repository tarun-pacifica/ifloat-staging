Merb.logger.info("Loaded STAGING Environment...")
Merb::Config.use { |c|
  c[:exception_details] = false
  c[:reload_templates] = false
  c[:reload_classes] = false
  
  c[:log_auto_flush ] = false
  c[:log_level] = :error
  c[:log_stream] = nil
  c[:log_file] = Merb.root / "log" / "staging.log"
}

Merb::BootLoader.after_app_loads do
  # Merb::Mailer.config = {:host => 'mail.freedom255.com', :port => 25}
  AssetStore.config(:mosso, :user => "pristine", :key => "b7db73b0bd047f7292574d7c9f0d16de", :container => "ifloat-staging", :url_stem => "http://c0210071.cdn.cloudfiles.rackspacecloud.com")
end

Merb.logger.info("Loaded DEVELOPMENT Environment...")
Merb::Config.use { |c|
  c[:exception_details] = true
  c[:reload_templates] = true
  c[:reload_classes] = true
  c[:reload_time] = 0.5
  c[:ignore_tampered_cookies] = true
  
  c[:log_auto_flush ] = true
  c[:log_level] = :debug
  c[:log_stream] = STDOUT
  c[:log_file] = nil
}

Merb::BootLoader.after_app_loads do
  Merb::Mailer.delivery_method = :test_send
  AssetStore.config(:local, :local_root => Merb.root / "public" / "assets", :url_stem => "/assets")
end

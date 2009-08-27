Merb.logger.info("Loaded RAKE Environment...")
Merb::Config.use { |c|
  c[:exception_details] = true
  c[:reload_templates] = false
  c[:reload_classes] = false
  
  c[:log_auto_flush ] = true
  c[:log_level] = :debug
  c[:log_stream] = STDOUT
  c[:log_file] = nil
}

Merb::BootLoader.after_app_loads do
  Merb::Mailer.delivery_method = :test_send
  AssetStore.config(:local, :local_root => "/tmp/ifloat_assets", :url_stem => "http://194.74.168.178:4000/assets")
  # ln -s /tmp/ifloat_assets public/assets
end

Merb.logger.info("Loaded TEST Environment...")
Merb::Config.use { |c|
  c[:testing] = true
  c[:exception_details] = true
  c[:reload_templates] = false
  c[:reload_classes] = false
  
  c[:log_auto_flush ] = true
  c[:log_level] = :error
  c[:log_stream] = STDOUT
  c[:log_file] = nil
  
  c[:registration_host] = "http://localhost:4000"
}

Merb::BootLoader.after_app_loads do
  Mail.defaults { delivery_method :test }
  AssetStore.config(:local, :local_root => "/tmp/ifloat_assets", :url_stem => "http://localhost:4000/assets")
end

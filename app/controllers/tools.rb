class Tools < Application
  before :ensure_authenticated
  
  def icons
    @properties = Indexer.property_display_cache.values.sort_by { |info| info[:seq_num] }
    @blank_icon_url = Asset.first(:bucket => "property_icons", :name => "blank.png").url
    
    used_checksums = @properties.map { |info| File.basename(info[:icon_url].split("/").last, ".png") }
    @unused_icons = Asset.all(:bucket => "property_icons", :checksum.not => used_checksums).sort_by { |a| a.name }
    
    @skip_javascript = true
    render
  end
  
  
  private
  
  def ensure_authenticated
    redirect "/" unless Merb.environment == "development" or session.admin?
  end
end

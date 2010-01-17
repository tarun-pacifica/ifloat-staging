class Tools < Application
  before :ensure_authenticated
  
  def icons
    @properties = PropertyDefinition.all.sort_by { |property| property.sequence_number }
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(@properties)
    
    used_checksums = @icon_urls_by_property_id.values.map { |url| File.basename(url.split("/").last, ".png") }
    @unused_property_icons = Asset.all(:bucket => "property_icons", :checksum.not => used_checksums).sort_by { |a| a.name }
    
    @skip_javascript = true
    render
  end
  
  
  private
  
  def ensure_authenticated
    redirect "/" unless Merb.environment == "development" or session.admin?
  end
end

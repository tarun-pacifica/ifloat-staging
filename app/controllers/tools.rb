class Tools < Application
  before :ensure_authenticated
  
  def ensure_authenticated
    redirect "/" unless Merb.environment == "development" or session.admin?
  end
  
  def icons
    @properties = PropertyDefinition.all.sort_by { |property| property.sequence_number }
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(@properties)
    
    used_names = @icon_urls_by_property_id.values.map { |url| url.split("/").last }
    @unused_property_icons = Asset.all(:bucket => "property_icons", :name.not => used_names).sort_by { |a| a.name }
    
    @skip_javascript = true
    render
  end
end

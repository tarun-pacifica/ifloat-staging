class Tools < Application
  # TODO: protect as admin area
  
  def icons
    @properties = PropertyDefinition.all.sort_by { |property| property.sequence_number }
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(@properties)
    
    used_names = @icon_urls_by_property_id.values.map { |url| url.split("/").last }
    @unused_property_icons = Asset.all(:bucket => "property_icons", :name.not => used_names).sort_by { |a| a.name }
    
    @skip_javascript = true
    render
  end
end

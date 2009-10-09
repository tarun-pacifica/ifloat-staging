class Tools < Application
  CSV_REPO = "../ifloat_csvs"
  
  before :ensure_authenticated
  
  def caches(basename, ext)
    filename = "#{basename}.#{ext}"
    path = "caches" / filename
    return "no such file: #{path}" unless File.exists?(path)
    return "file unreadable: #{path}" unless File.readable?(path)
    
    headers["Content-Disposition"] = "attachment; filename=#{filename}"
    
    headers["Content-Type"] =
      case ext
      when "csv" then "text/csv"
      end
    
    File.open(path)
  end
  
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

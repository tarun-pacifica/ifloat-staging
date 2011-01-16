class Tools < Application
  before :ensure_authenticated
  
  def cached_find_events(ext)
    return "TO BE RE-IMPLEMENTED"
    
    @events_by_spec = CachedFindEvent.all(:order => [:created_at]).group_by { |cfe| cfe.specification }.sort_by { |spec, events| [events.size, spec] }.reverse
    
    if ext == "csv"
      data = FasterCSV.generate do |csv|
        csv << %w(count specification most_recent_event)
        @events_by_spec.each { |spec, events| csv << [events.size, spec, events.last.created_at] }
      end
      send_data(data, :filename => "cached_find_events.csv", :type => "text/csv")
    else
      @skip_javascript = true
      render
    end
  end
  
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

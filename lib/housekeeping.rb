# === General Housekeeping ===

begin
  Merb::DataMapperSessionStore.expired.destroy!
  
  cached_find_ids = Set.new
  picked_product_ids = Set.new
  Merb::DataMapperSessionStore.all.each do |session|
    cached_find_ids += (session.data["cached_find_ids"] || [])
    picked_product_ids += (session.data["picked_product_ids"] || [])
  end
  
  CachedFind.unused.update!(:user_id => nil)
  CachedFind.all(:user_id => nil, :id.not => cached_find_ids).destroy!
  
  ControllerError.obsolete.destroy!
  
  PickedProduct.all(:user_id => nil, :id.not => picked_product_ids).destroy!
  
  Purchase.obsolete.destroy!
  
  User.expired.destroy!
  
rescue Exception => e
  Mailer.deliver(:exception, :exception => e, :whilst => "performing housekeeping")
  
end


# === Partner Store Price Import ===

PRICES_REPO = "../ifloat_prices"

facilities_by_url = Facility.all.hash_by(:primary_url)

Dir[PRICES_REPO / "*"].each do |path|
  next unless File.directory?(path)

  url = File.basename(path)
  facility = facilities_by_url[url]
  next if facility.nil?

  begin
    product_info_by_ref = YAML.load(File.open(path / "prices.yaml"))
    reports = facility.update_products(product_info_by_ref)
    next if reports.empty?
    
    FasterCSV.open("/tmp/report.csv", "w") do |report|
      report << ["facility reference", "notice", "detail..."]
      reports.each { |line| report << line }
    end
    Mailer.deliver(:facility_import_success, :attach => "/tmp/report.csv", :whilst => "importing #{url} prices")
  rescue Exception => e
    Mailer.deliver(:exception, :exception => e, :whilst => "importing #{url} prices")
  end
end

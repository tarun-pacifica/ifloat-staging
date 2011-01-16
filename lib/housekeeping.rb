# === General Housekeeping ===

begin
  Merb::DataMapperSessionStore.expired.destroy
  
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
    
  User.expired.destroy!
  
rescue Exception => e
  Mailer.deliver(:exception, :exception => e, :whilst => "performing housekeeping")
  
end


# === Partner Store Price Import ===

PRICES_REPO = "../ifloat_prices"

facilities_by_url = Facility.all.hash_by(:primary_url)

checkpoint_path = "/tmp/partner_store_import.checkpoint"
repo_mtime = Time.at(`git --git-dir='#{PRICES_REPO}/.git' log -n1 --pretty='format:%at'`.to_i)
exit if File.exist?(checkpoint_path) and File.mtime(checkpoint_path) > repo_mtime

success = true
Dir[PRICES_REPO / "*"].each do |path|
  next unless File.directory?(path)

  url = File.basename(path)
  facility = facilities_by_url[url]
  next if facility.nil?

  begin
    product_info_by_ref = YAML.load(File.open(path / "prices.yaml"))
    reports = facility.update_products(product_info_by_ref)
    next if reports.empty? or Merb.environment != "production"
    
    FasterCSV.open("/tmp/report.csv", "w") do |report|
      report << ["facility reference", "notice", "detail..."]
      reports.each { |line| report << line }
    end
    system "bzip2", "-f", "/tmp/report.csv"
    Mailer.deliver(:facility_import_success, :attach => "/tmp/report.csv.bz2", :whilst => "importing #{url} prices")
  rescue Exception => e
    Mailer.deliver(:exception, :exception => e, :whilst => "importing #{url} prices")
    success = false
  end
end

FileUtils.touch(checkpoint_path) if success

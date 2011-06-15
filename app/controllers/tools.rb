class Tools < Application
  before :ensure_authenticated
  
  def index
    @skip_javascript = true
    render
  end
  
  def icons
    @properties = Indexer.property_display_cache.values.sort_by { |info| info[:seq_num] }
    @blank_icon_url = Asset.first(:bucket => "property_icons", :name => "blank.png").url
    
    used_checksums = @properties.map { |info| File.basename(info[:icon_url].split("/").last, ".png") }
    @unused_icons = Asset.all(:bucket => "property_icons", :checksum.not => used_checksums).sort_by { |a| a.name }
    
    @skip_javascript = true
    render
  end
  
  IMPORTER_CHECKPOINT_PATH = "/tmp/ifloat_importer.running"
  IMPORTER_ERROR_PATH = "/tmp/ifloat_importer_errors.csv"
  IMPORTER_LOG_PATH = "/tmp/ifloat_importer.log"
  def importer
    @error_csv_mtime = (File.mtime(IMPORTER_ERROR_PATH) rescue nil)
    @importer_running_since = (File.mtime(IMPORTER_CHECKPOINT_PATH) rescue nil)
    
    unless @importer_running_since.nil? or @importer_running_since > 1.hour.ago
      @error = "the importer has been running for more than an hour - contact tech support"
      return render
    end
    
    operation = params[:operation]
    unless @importer_running_since.nil? or operation.nil?
      @error = "cannot run #{operation} operation while the importer is running"
      return render
    end
    
    case operation
    when "import"
      # mark import as being in progress (touch checkpoint file)
      # start import with checkpoint file params - redirect STDERR / STDOUT to log file
      # may also need to supply an error CSV output path?
    when "remove"
      # remove path recursively
      # use git rmpath if tracked
    when "revert"
      # checkout old path recursively
      # only available for modified, tracked paths
    when "upload"
      # validate file
      # move file into relevant DIR
    end
    
    render
  end
  
  def importer_error_report
    send_data(File.read(IMPORTER_ERROR_PATH), :filename => File.basename(IMPORTER_ERROR_PATH), :type => "text/csv")
  end
  
  def importer_log
    stat = (File.stat(IMPORTER_LOG_PATH) rescue nil)
    log = (stat.nil? or stat.zero?) ? "{log empty}" : File.read(IMPORTER_LOG_PATH)
    log += "\n\n{importer finished}" unless File.exist?(IMPORTER_CHECKPOINT_PATH)
    log
  end
  
  def ms_variant_reporter
    @expected_name = "provide.xml.zip"
    file = params[:file]
    return render if file.nil?
    
    unless file[:filename] == @expected_name
      @error = "expected a file named #{@expected_name.inspect} but you supplied one named #{file[:filename].inspect}"
      return render
    end
    
    marine_store = Company.first(:reference => "GBR-02934378")
    if marine_store.nil?
      @error = "unable to locate company reference GBR-02934378 in the database"
      return render
    end
    
    classes_by_product_id, classes_by_product_ref = {}, {}
    products_by_product_id = Product.all.hash_by(:id)
    TextPropertyValue.all(:property_definition_id => Indexer.class_property_id).each do |tpv|
      prod_id = tpv.product_id
      ref = products_by_product_id[prod_id].reference.upcase
      classes_by_product_id[prod_id] = tpv.to_s
      (classes_by_product_ref[ref] ||= []) << tpv.to_s
    end
    
    classes_by_ms_prod_code = {}
    full_ms_refs = []
    marine_store.product_mappings.each do |m|
      klass = classes_by_product_id[m.product_id]
      next if klass.nil?
      
      prod_code = m.reference_parts.first.upcase
      (classes_by_ms_prod_code[prod_code] ||= []) << klass
      full_ms_refs << m.reference.upcase
    end
    full_ms_refs = full_ms_refs.to_set
    
    includer = proc { |ref| not full_ms_refs.include?(ref.upcase) }
    
    guesser = proc do |prod_code|
      justification = ""
      
      prod_code = prod_code.upcase
      classes = classes_by_ms_prod_code[prod_code]
      justification = "from products with MS mappings starting with #{prod_code}" unless classes.nil?
      
      if classes.nil? and prod_code =~ /^[A-Z]{2}([A-Z0-9]+)/
        classes = classes_by_product_ref[$1]
        justification = "from products with the reference #{$1}" unless classes.nil?
      end
      
      return "" if classes.nil?
      classes.uniq.sort.join(", ") + " (#{justification})"
    end
    
    to_csv_path = "/tmp/ms_variant_report.csv"
    GC.disable
    begin
      Zip::ZipFile.foreach(file[:tempfile].path) do |entry|
        Partners::MarineStore.dump_report(entry.get_input_stream, to_csv_path, includer, guesser)
        break
      end
    rescue Exception => e
      @error = "unexpected error while attempting to decompress / parse the supplied file: #{e}"
    end
    GC.enable
    return render unless @error.nil?
    
    file_name = "ms_variant_report_#{DateTime.now.strftime('%Y%m%d_%H%M')}.csv"
    send_data(File.read(to_csv_path), :filename => file_name, :type => "text/csv")
  end
  
  def purchase_reporter
    @purchases = Purchase.all(:order => [:completed_at])
    return render if params[:ext].nil?
    
    to_csv_path = "/tmp/purchase_report.csv"
    FasterCSV.open(to_csv_path, "w") do |csv|
      csv << %w(ID Facility Order Completed Cookie Days Item Description Quantity Price Total Net)
      
      @purchases.each do |purchase|
        fields = [purchase.id]
        fields << purchase.facility.primary_url
        fields << purchase.response[:reference]
        fields << purchase.completed_at.strftime("%Y-%m-%d %H:%M:%S")
        fields << purchase.session.created_at.strftime("%Y-%m-%d %H:%M:%S")
        fields << (purchase.completed_at - purchase.session.created_at).to_i
        
        purchase.response[:items].each do |i|
          quantity = i['quantity'].to_i
          price = i['price'].to_f
          total = quantity * price
          csv << fields.dup.push(i['reference'], i['name'], quantity, "%0.2f" % price, "%0.2f" % total, "%0.2f" % (total / 1.2))
        end
      end
    end
    
    file_name = "purchase_report_#{DateTime.now.strftime('%Y%m%d_%H%M')}.csv"
    send_data(File.read(to_csv_path), :filename => file_name, :type => "text/csv")
  end
  
  private
  
  def ensure_authenticated
    redirect "/" unless Merb.environment == "development" or session.admin?
  end
end

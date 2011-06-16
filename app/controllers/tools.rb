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
  IMPORTER_DATA_DIRS = Hash[%w(Asset CSV).map { |group| [group, Merb.root / ".." / "ifloat_#{group.downcase}s"] }]
  IMPORTER_ERROR_PATH = "/tmp/ifloat_importer_errors.csv"
  IMPORTER_LOG_PATH = "/tmp/ifloat_importer.log"
  IMPORTER_SUCCESS_PATH = "/tmp/ifloat_importer.success"
  IMPORTER_UNZIP_DIR = "/tmp/ifloat_importer_unzips"
  def importer
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
    
    # TODO: what to do when a success - i.e. need to emphasize no error report somehow - do we have enough state to do this?
    case operation
    when "import"
      @importer_running_since = Time.now
      FileUtils.touch(IMPORTER_CHECKPOINT_PATH)
      [IMPORTER_ERROR_PATH, IMPORTER_LOG_PATH, IMPORTER_SUCCESS_PATH].each do |path|
        File.delete(path) if File.exist?(path)
      end
      
      fork do
        $stdout = $stderr = File.open(IMPORTER_LOG_PATH, "w")
        $stdout.sync = $stderr.sync = true
        begin
          require Merb.root / "importer" / "import"
        ensure
          File.delete(IMPORTER_CHECKPOINT_PATH)
          File.touch(IMPORTER_SUCCESS_PATH) unless File.exist?(IMPORTER_ERROR_PATH)
        end
      end
      
    when /^remove_(Asset|CSV)$/
      path = params[:path]
      FileUtils.rmtree(IMPORTER_DATA_DIRS[$1] / path) unless path.blank?
      
    when /^revert_(Asset|CSV)$/
      dir = IMPORTER_DATA_DIRS[$1]
      @error = git_revert(dir)
      
    when /^upload_(Asset|CSV)$/
      file = params[:file]
      if file.blank?
        @error = "please choose a file"
      elsif params[:bucket].blank?
        @error = "please choose a bucket"
      else
        group = $1
        expected_ext = {"Asset" => ".zip", "CSV" => ".csv"}[group]
        @error =
          if File.extname(file[:filename]) == expected_ext then unzip_move(file, IMPORTER_DATA_DIRS[group] / params[:bucket])
          else "#{group} upload names should end in #{expected_ext}"
          end
      end
      
    end
    
    if @importer_running_since.nil?
      @available_by_group = Hash[IMPORTER_DATA_DIRS.map { |group, path| [group, git_available(group, path)] }]
      @changes_by_group = Hash[IMPORTER_DATA_DIRS.map { |group, path| [group, git_changes(path)] }]
      @error_csv_mtime = (File.mtime(IMPORTER_ERROR_PATH) rescue nil)
      @success_time = (File.mtime(IMPORTER_SUCCESS_PATH) rescue nil)
      @upload_info_by_group = {"Asset" => ["an asset ZIP", Asset::BUCKETS], "CSV" => ["a CSV", %w(/ products)]}
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
  
  def git_available(group, dir)
    glob = (group == "Asset" ? (dir / "*" / "*") : (dir / "**" / "**.csv"))
    matcher = /^#{dir}\/(.+?)$/
    Dir[glob].map { |path| path =~ matcher; $1 }.reject { |path| path == "assets.csv" }
  end
  
  def git_changes(dir)
    report = `git --git-dir=#{dir}/.git --work-tree=#{dir} status -s 2>&1`
    return "unable to get the git status of #{dir.inspect}: #{report}" unless $?.success?
    
    statuses = {"?" => "  added", "D" => "deleted", "M" => "updated"}
    report = report.lines.map do |line|
      return "unable to parse #{line.inspect} from the git status for #{dir.inspect}" unless line =~ /^(.)(.) (.+?)$/
      x, y, path = $1, $2, $3
      "#{statuses[y]}: #{path}"
    end.join("\n")
    
    report.blank? ? "{none}" : report
  end
  
  def git_revert(dir)
    report = `git --git-dir=#{dir}/.git --work-tree=#{dir} clean -df 2>&1`
    return "unable to clean #{dir.inspect}: #{report}" unless $?.success?
    
    report = `git --git-dir=#{dir}/.git --work-tree=#{dir} reset --hard`
    return "unable to reset #{dir.inspect}: #{report}" unless $?.success?
    
    nil
  end
  
  def unzip_move(file, target_dir)
    name = file[:filename]
    ext = File.extname(name)
    
    from_path = file[:tempfile].path
    
    if ext == ".zip"
      name = File.basename(name, ext)
      return "the supplied file's name was not a company reference" unless name =~ Company::REFERENCE_FORMAT
      
      FileUtils.rmtree(IMPORTER_UNZIP_DIR)
      FileUtils.mkpath(IMPORTER_UNZIP_DIR)
      unzip_path = IMPORTER_UNZIP_DIR / name
      return "failed to unzip the supplied file" unless system("unzip", from_path, "-d", IMPORTER_UNZIP_DIR)
      return "unzipping the supplied file did not produce a folder called #{name.inspect}" unless File.directory?(unzip_path)
      
      FileUtils.rmtree(IMPORTER_UNZIP_DIR / "__MACOSX")
      return "failed to clean up #{unzip_path.inspect}" unless
        system("find", unzip_path, "-type", "d", "-exec", "chmod", "755", "{}", ";") and
        system("find", unzip_path, "-type", "f", "-exec", "chmod", "644", "{}", ";") and
        system("find", unzip_path, "-name", "Thumbs.db", "-exec", "rm", "{}", ";")
      from_path = unzip_path
    end
    
    to_path = target_dir / name
    FileUtils.rmtree(to_path)
    FileUtils.mv(from_path, to_path)
    nil
  end
end

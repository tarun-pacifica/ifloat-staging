class ImportableAssets
  include ErrorWriter
  
  CSV_HEADERS = %w(path mtime bucket company_ref name checksum pixel_size path_wm path_small path_tiny)
  ERROR_HEADERS = %w(asset error)
  VARIANT_SIZES = {:small => "200x200", :tiny => "100x100"}
  
  def initialize(source_dir, csv_path, variant_dir, watermark_path)
    @source_dir = source_dir
    @csv_path = csv_path
    @variant_dir = variant_dir
    @watermark_path = watermark_path
    
    @errors = []
  end
  
  def error(a, message)
    @errors << [a.nil? ? "N/A" : a[:relative_path], message]
  end
  
  def read_from_csv
    return [] unless File.exist?(@csv_path)
    
    assets = []
    FasterCSV.foreach(@csv_path, :headers => :first_row, :return_headers => true, :encoding => "UTF-8") do |row|
      if row.header_row?
        missing_headers = (CSV_HEADERS - row.map { |header, value| value })
        unless missing_headers.empty?
          puts " ! missing headers in #{@csv_path}: #{missing_headers.join(', ')} (erasing and starting again)"
          File.delete(@csv_path)
          return []
        end
      else
        a = Hash[row.map { |header, value| [header.to_sym, value] }]
        a[:mtime] = a[:mtime].to_i
        assets << a
      end
    end
    assets
  end
  
  def relative_path(path)
    raise "unable to extract relative path from #{path.inspect}" unless path =~ /^#{@source_dir}\/(.+)/
    $1
  end
  
  def scan_asset(a)
    path_parts = a[:relative_path].split("/")
    error(a, "not in a bucket/company(/class) directory") and return a unless (3..4).include?(path_parts.size)
    
    error(a, "unknown bucket") unless Asset::BUCKETS.include?(a[:bucket] = path_parts.shift)
    
    company_ref = path_parts.shift
    company_ref = $1 if company_ref =~ /^(.+?)___/
    error(a, "invalid company reference format") unless company_ref =~ Company::REFERENCE_FORMAT
    
    name = path_parts.pop
    error(a, "invalid asset name format") unless name =~ Asset::NAME_FORMAT
    error(a, "extension not jpg, pdf or png") unless name =~ /(jpg|pdf|png)$/
    
    a.update(:company_ref => company_ref, :name => name, :checksum => Digest::MD5.file(a[:path]).hexdigest)
  end
  
  def scan_image_sizes(assets)
    image_path_matcher = /(jpg|png)$/
    images_by_path = assets.select { |a| a[:path] =~ image_path_matcher }.hash_by { |a| a[:path] }
    
    identified = 0
    images_by_path.keys.each_slice(500) do |paths|
      to_identify = paths.map { |path| path.inspect }.join(" ")
      
      `gm identify #{to_identify} 2>&1`.lines.each do |line|
        unless line =~ /^(.+?\.(jpg|png)).*?(\d+x\d+)/
          error(nil, "unable to read GM.identify report line: #{line.inspect}")
          next
        end
        
        image = images_by_path[$1]
        if image.nil?
          error(nil, "unable to associate GM.identify report line: #{line.inspect}")
        else
          image[:pixel_size] = $3
          error($1, "category image not 100x100 (#{$3})") if image[:bucket] == "category_image" and $3 != "100x100"
        end
      end
      
      identified += paths.size
      puts " - identifed #{identified}/#{images_by_path.size} image sizes"
    end
  end
  
  def scan_source_dir
    empty_paths = []
    mtimes_by_path = {}
    
    Dir[@source_dir / "**" / "*"].map do |path|
      stat = File::Stat.new(path)
      empty_paths << path if stat.zero?
      mtimes_by_path[path] = stat.mtime.to_i if stat.file?
    end
    
    [empty_paths.to_set, mtimes_by_path]
  end
  
  def update
    empty_paths, mtimes_by_path = scan_source_dir
    unchanged = read_from_csv.select { |a| a[:mtime] == mtimes_by_path[a[:path]] }
    paths_to_scan = (mtimes_by_path.keys - unchanged.map { |a| a[:path] })
    
    scanned = []
    paths_to_scan.each_slice(500) do |paths|
      scanned += paths.map do |path|
        a = {:path => path, :relative_path => relative_path(path), :mtime => mtimes_by_path[path]}
        empty_paths.include?(path) ? error(a, "empty file") : scan_asset(a)
        a
      end
      puts " - scanned #{scanned.size}/#{paths_to_scan.size} assets"
    end
    
    @all = unchanged + scanned
    @all.group_by { |a| a.values_at(:company_ref, :name) }.each do |key, assets|
      first, *rest = assets
      rest.each { |a| error(a, "duplicate of #{relative_path(first[:path])}") }
    end
    return false unless @errors.empty?
    
    scan_image_sizes(scanned)
    return false unless @errors.empty?
    
    scanned_product_images = scanned.select { |a| a[:bucket] == "products" and a.has_key?(:pixel_size) }
    scanned_product_images.each { |image| image.update(variants_by_name(image)) }
    variants = variants_missing(scanned_product_images)
    created = 0
    variants.each_slice(500) do |specs|
      specs.each_with_index do |spec, i|
        image, name, path = spec.values_at(:image, :name, :path)
        variant_create(image, name, path)
        created += 1
      end
      puts " - created #{created}/#{variants.size} image variants"
    end
    return false unless @errors.empty?
    
    write_to_csv unless scanned.empty?
    puts " > managing #{@all.size} assets"
    
    all_variant_paths = @all.map { |a| a.values_at(:path_wm, :path_small, :path_tiny) }.flatten.compact
    (Dir[@variant_dir / "*"] - all_variant_paths).delete_and_log("obsolete variants")
    true
  end
  
  def variants_by_name(image)
    ext = File.extname(image[:path])
    stem = @variant_dir / image[:checksum]
    variants = [:wm]
    variants += [:small, :tiny] if image[:pixel_size] == "400x400"
    Hash[variants.map { |v| ["path_#{v}".to_sym, "#{stem}#{v == :wm ? "" : "-#{v}"}#{ext}" ]}]
  end
  
  def variant_create(image, name, path)
    report =
      if name == :wm
        placement = (image[:pixel_size] == "400x400" ? "-geometry +10+10 -gravity SouthEast" : "-gravity Center")
        `gm composite #{placement} #{@watermark_path.inspect} #{image[:path].inspect} #{path.inspect} 2>&1`
      else
        variant_size = VARIANT_SIZES[name]
        wm_path = image[:path_wm]
        return false if wm_path.nil?
        `gm convert -size #{variant_size} #{wm_path.inspect} -resize #{variant_size} +profile '*' #{path.inspect} 2>&1`
      end
    
    if $?.success? then image["path_#{name}".to_sym] = path
    else error(image, "GM command failed: #{report.inspect}")
    end
  end
  
  def variants_missing(product_images)
    product_images.map do |image|
      [:wm, :small, :tiny].map do |name|
        path = image["path_#{name}".to_sym]
        {:image => image, :name => name, :path => path} unless path.nil? or File.exist?(path)
      end
    end.flatten.compact
  end
  
  def write_to_csv
    headers = CSV_HEADERS.map { |h| h.to_sym }
    FasterCSV.open("/tmp/ifloat_assets.csv.tmp", "w") do |csv|
      csv << CSV_HEADERS
      @all.each { |a| csv << a.values_at(*headers).map { |v| v.nil? ? "N/A" : v } }
    end
    FileUtils.move("/tmp/ifloat_assets.csv.tmp", @csv_path)
  end
end

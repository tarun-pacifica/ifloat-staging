class ImportableAssets
  def initialize(source_dir, csv_path, variant_dir)
    @source_dir = source_dir
    @csv_path = csv_path
    @variant_dir = variant_dir
    
    mtimes_by_path = {}
    Dir[source_dir / "**" / "*"].map do |path|
      stat = File::Stat.new(path)
      mtimes_by_path[path] = stat.mtime if stat.file?
    end
    
    unchanged = read_from_csv.select { |a| a[:mtime] == mtimes_by_path[a[:path]] }
    paths_to_scan = (mtimes_by_path.keys - unchanged.map { |a| a[:path] })
    scanned = paths_to_scan.map { |path| scan_asset(:path => path, :mtime => mtimes_by_path[:path], :errors => []) }
    puts " - #{scanned.size} changed / new" if scanned.size > 0
    
    # TODO:
    # paths_by_name = (paths_by_names_by_company_refs[company_ref] ||= {})
    # existing_path = paths_by_name[name]
    # if existing_path.nil? then paths_by_name[name] = relative_path
    # else errors << [relative_path, "duplicate of #{existing_path}"]
    # end
    
    @assets = unchanged + scanned
    @assets_with_errors = scanned.select { |a| a[:error].any? }
  end
  
  def ensure_variants
    
  end
  
  def read_from_csv
    return [] unless File.exist?(@csv_path)
    
    
  end
  
  def scan_asset(a)
    raise "unable to extract relative path from #{path.inspect}" unless path =~ /^#{@source_dir}\/(.+)/
    a[:relative_path] = $1
    
    path_parts = a[:relative_path].split("/")
    a[:errors] << "not in a bucket/company(/class) directory" and return a unless (3..4).include?(path_parts.size)
    
    a[:errors] << "empty file" if File.size(path) == 0
    
    a[:errors] << "unknown bucket" unless Asset::BUCKETS.include?(a[:bucket] = path_parts.shift)
    
    company_ref = path_parts.shift
    company_ref = $1 if company_ref =~ /^(.+?)___/
    a[:errors] << "invalid company reference format" unless company_ref =~ Company::REFERENCE_FORMAT
    
    name = path_parts.pop
    a[:errors] << "invalid asset name format" unless name =~ Asset::NAME_FORMAT
    a[:errors] << "extension not jpg, pdf or png" unless name =~ /(jpg|pdf|png)$/
    
    a.update(:company_ref => company_ref, :name => name, :checksum => Digest::MD5.file(path).hexdigest)
  end
  
  def write_errors(path)
    return false if @assets_with_errors.empty?
    
    true
  end
  
  def write_to_csv
    # remeber to safe write
    # don't bother with relative path
  end
end

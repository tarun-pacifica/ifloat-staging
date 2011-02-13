class CSVCatalogue
  INFO_FILE_NAME = "_info"
  SKIP_HEADER_MATCHER = /^raw::/
  
  def initialize(dir)
    @dir = dir
    @errors = []
    @info_by_md5 = {}
  end
  
  def add(path)
    @row_md5s = nil
    
    md5 = Digest::MD5.file(path).hexdigest
    name = (File.dirname(path) =~ /products$/ ? "products/" : "") + File.basename(path)
    index_dir = @dir / md5
    info_path = index_dir / INFO_FILE_NAME
    
    if File.exist?(info_path)
      @info_by_md5[md5] = Marshal.load(File.open(info_path))
      return
    end
    
    if File.directory?(index_dir)
      puts " ! #{name} partial update detected (erasing and starting again)"
      FileUtils.rmtree(index_dir)
    end
    FileUtils.mkpath(index_dir)
    
    info = add_rows(path, index_dir).update(:name => name)
    
    errors = info.delete(:errors)
    if(errors.any?)
      @errors += errors.map { |e| [name, e] }
      FileUtils.rmtree(index_dir)
      puts " ! #{name} #{errors.size} errors"
      return
    end
    
    @info_by_md5[md5] = info
    info_file_path = index_dir / INFO_FILE_NAME
    Marshal.dump(info, File.open("#{info_file_path}.tmp", "w"))
    FileUtils.move("#{info_file_path}.tmp", info_file_path)
    puts " - #{name}"
  end
  
  def add_rows(from_path, into_dir)
    errors = []
    header = nil
    row_md5s = []
    
    row_index = 0
    FasterCSV.foreach(from_path, :headers => :first_row, :return_headers => true, :encoding => "UTF-8") do |row|
      row_index += 1
      
      row.map { |h, v| value }.compact.repeated.each { |v| errors << "duplicate header #{v.inspect} detected" } if row.header_row?
      
      if row.any? { |header, value| value.nil? }
        errors << "blank cells detected in row #{row_index}"
        row.header_row? ? break : next
      end
      
      values = row.map { |header, value| header =~ SKIP_HEADER_MATCHER ? nil : value }.compact
      header = values and next if row.header_row?
      next if row["IMPORT"] == "N"
      
      marshaled = Marshal.dump(values)
      row_md5s << Digest::MD5.hexdigest(marshaled)
      File.open(into_dir / row_md5s.last, "w") { |f| f.write(marshaled) }
    end
    
    errors << "no header row" if header.nil?
    {:errors => errors, :header => header, :row_md5s => row_md5s}
  end
  
  def delete_obsolete
    Dir[@dir / "*"].reject { |path| @info_by_md5.has_key?(File.basename(path)) }.delete_and_log("obsolete CSV indexes")
  end
  
  def row_md5s
    @row_md5s ||= @info_by_md5.map { |md5, info| info[:row_md5s] }.flatten
  end
  
  def row_md5s_for_name(matcher)
    @info_by_md5.map { |md5, info| info[:name] =~ matcher ? info[:row_md5s] : [] }.flatten
  end
  
  def summarize
    puts " > managing #{row_md5s.size} rows from #{@info_by_md5.size} CSVs"
  end
  
  def write_errors(path)
    return false if @errors.empty?
    
    FasterCSV.open(path, "w") do |csv|
      csv << %w(csv error)
      @errors.each { |path, message| csv << [path, message] }
    end
    true
  end
end

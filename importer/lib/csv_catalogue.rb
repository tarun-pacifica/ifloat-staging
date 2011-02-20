class CSVCatalogue
  INFO_FILE_NAME = "_info"
  NIL_VALUES = %w(N/A NIL)
  SKIP_HEADER_MATCHER = /^(raw:)|(IMPORT)/
  
  def initialize(dir)
    @dir = dir
    @errors = []
    @info_by_csv_md5 = {}
    @info_by_row_md5 = {}
  end
  
  def add(path)
    @row_md5s = nil
    
    md5 = Digest::MD5.file(path).hexdigest
    name = (File.dirname(path) =~ /products$/ ? "products/" : "") + File.basename(path)
    index_dir = @dir / md5
    info_path = index_dir / INFO_FILE_NAME
    
    add_info(md5, Marshal.load(File.open(info_path))) and return if File.exist?(info_path)
    
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
    
    add_info(md5, info)
    info_file_path = index_dir / INFO_FILE_NAME
    File.open("#{info_file_path}.tmp", "w") { |f| Marshal.dump(info, f) }
    FileUtils.move("#{info_file_path}.tmp", info_file_path)
    puts " - #{name}"
  end
  
  def add_info(csv_md5, info)
    @info_by_csv_md5[csv_md5] = info.merge(:md5 => csv_md5)
    name = info[:name]
    info[:row_md5s].each_with_index { |row_md5, i| @info_by_row_md5[row_md5] = {:name => name, :index => i + 2} }
  end
  
  def add_rows(from_path, into_dir)
    errors = []
    headers = nil
    row_md5s = []
    
    row_index = 0
    FasterCSV.foreach(from_path, :headers => :first_row, :return_headers => true, :encoding => "UTF-8") do |row|
      row_index += 1
      
      row_errors = []
      row_errors += row.repeated_non_nil_values.map { |v| "duplicate header #{v.inspect} detected" } if row.header_row?
      row_errors << "blank cells detected in row #{row_index}" if row.has_nil_values?
      unless row_errors.empty?
        errors += row_errors
        row.header_row? ? break : next
      end
      
      values = row.map { |header, value| header =~ SKIP_HEADER_MATCHER ? nil : value.strip }.compact
      headers = values and next if row.header_row?
      next if row["IMPORT"] == "N"
      
      marshaled = Marshal.dump(values.map { |v| NIL_VALUES.include?(v) ? nil : v })
      row_md5s << Digest::MD5.hexdigest(marshaled)
      File.open(into_dir / row_md5s.last, "w") { |f| f.write(marshaled) }
    end
    
    errors << "no header row" if headers.nil?
    {:errors => errors, :headers => headers, :row_md5s => row_md5s}
  end
  
  def delete_obsolete
    Dir[@dir / "*"].reject do |path|
      @info_by_csv_md5.has_key?(File.basename(path))
    end.delete_and_log("obsolete CSV indexes")
  end
  
  def infos_for_name(matcher)
    @info_by_csv_md5.map { |md5, info| info[:name] =~ matcher ? info.merge(:md5 => md5) : nil }.compact
  end
  
  def row(csv_md5, row_md5)
    File.open(@dir / csv_md5 / row_md5) { |f| Marshal.load(f) }
  end
  
  def row_info(row_md5)
    @info_by_row_md5[row_md5]
  end
  
  def row_md5s
    @info_by_row_md5.keys
  end
  
  # TODO: may not need?
  def row_md5s_for_name(matcher)
    infos_for_name(matcher).map { |info| info[:row_md5s] }.flatten
  end
  
  def summarize
    puts " > managing #{row_md5s.size} rows from #{@info_by_csv_md5.size} CSVs"
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

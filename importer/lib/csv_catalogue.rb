class CSVCatalogue
  INFO_FILE_NAME = "_info"
  SKIP_HEADER_MATCHER = /^raw::/
  
  def initialize(dir)
    @dir = dir
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
    
    info = @info_by_md5[md5] = add_rows(path, index_dir).update(:name => name)
    info_file_path = index_dir / INFO_FILE_NAME
    Marshal.dump(info, File.open("#{info_file_path}.tmp", "w"))
    FileUtils.move("#{info_file_path}.tmp", info_file_path)
    
    puts " - #{name}"
  end
  
  def add_rows(from_path, into_dir)
    header = nil
    row_md5s = []
    
    FasterCSV.foreach(from_path, :headers => :first_row, :return_headers => true, :encoding => "UTF-8") do |row|
      values = row.map { |header, value| header =~ SKIP_HEADER_MATCHER ? nil : value }.compact
      
      header = values and next if row.header_row?
      next if row["IMPORT"] == "N"
      
      marshaled = Marshal.dump(values)
      row_md5s << Digest::MD5.hexdigest(marshaled)
      File.open(into_dir / row_md5s.last, "w") { |f| f.write(row) }
    end
    
    {:header => header, :row_md5s => row_md5s}
  end
  
  def delete_obsolete
    Dir[@dir / "*"].reject { |path| @info_by_md5.has_key?(File.basename(path)) }.delete_and_log("obsolete CSV indexes")
  end
  
  def row_md5s
    @row_md5s ||= @info_by_md5.map { |md5, info| info[:row_md5s] }.flatten
  end
  
  def summarize
    puts " > managing #{row_md5s.size} rows from #{@info_by_md5.size} CSVs"
  end
end

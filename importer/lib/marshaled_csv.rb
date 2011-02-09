class MarshaledCSV < FasterCSV
  def self.marshal_rows(from_path, into_dir)
    row_md5s = []
    FasterCSV.foreach(from_path, :headers => :first_row, :return_headers => true, :encoding => "UTF-8") do |row|
      row = Marshal.dump(row.map { |header, value| value })
      row_md5 = Digest::MD5.hexdigest(row)
      row_md5s << row_md5
      File.open(into_dir / row_md5, "w") { |f| f.write(row) }
    end
    
    Marshal.dump({:name => name, :row_md5s => row_md5s}, File.open(into_dir / "info", "w"))
  end
  
  def self.marshal_updated(path, into_dir)
    csv_md5 = Digest::MD5.file(path).hexdigest(path)
    name = (File.dirname(path) =~ /products$/ ? "products/" : "") + File.basename(path)
    index_dir = into_dir / csv_md5
    info_path = index_dir / "info"
    return csv_md5 if File.exist?(info_path)
    
    puts " ! #{name} PARTIAL UPDATE DETECTED (erasing and starting again)" if File.directory?(index_dir)
    FileUtils.rmtree(index_dir)
    FileUtils.mkpath(index_dir)
    MarshaledCSV.marshal_rows(path, index_dir)  
    puts " - #{name}"
    
    csv_md5
  end
end

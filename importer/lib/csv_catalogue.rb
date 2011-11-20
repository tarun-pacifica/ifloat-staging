class CSVCatalogue
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv error)
  IMPROPER_NIL_VALUES = %w(n/a N/a n/A nil niL nIl nIL Nil NiL NIl).to_set
  NIL_VALUES = %w(N/A NIL)
  NON_PRODUCT_CSV_PATHS = %w(assets.csv associated_words.csv banners.csv brands.csv companies.csv facilities.csv property_definitions.csv property_hierarchies.csv property_types.csv property_value_definitions.csv title_strategies.csv unit_of_measures.csv).to_set
  SKIP_HEADER_MATCHER = /^(raw:)|(IMPORT)/
  
  def initialize(dir)
    @errors = []
    
    @added_csv_md5s = Set.new
    @csv_info_by_csv_md5 = OklahomaMixer.open(dir / "catalogue.tch")
    @row_data_by_row_md5 = OklahomaMixer.open(dir / "data.tch")
    @row_locations_by_row_md5 = OklahomaMixer.open(dir / "locations.tch")
    
    delete_inconsistent
  end
  
  def add(csv_path)
    name = (File.dirname(csv_path) =~ /products$/ ? "products/" : "") + File.basename(csv_path)
    
    unless name =~ /^products\// or NON_PRODUCT_CSV_PATHS.include?(name)
      @errors << [name, "is not a system/global CSV"]
      return
    end
    
    file_info = `file #{csv_path.inspect}`
    unless file_info =~ /UTF-8 Unicode/ or file_info =~ /ASCII/
      @errors << [name, "does not appear to be UTF-8 / ASCII encoded: #{file_info.squeeze(' ')}"]
      return
    end
    
    csv_md5 = Digest::MD5.file(csv_path).hexdigest
    @added_csv_md5s << csv_md5
    return if @csv_info_by_csv_md5.has_key?(csv_md5)
    
    errors, info, locations_by_row_md5, rows_by_row_md5 = parse_rows(csv_path, name)
    
    unless errors.empty?
      @errors += errors.map { |e| [name, e] }
      puts " ! #{name} #{errors.size} errors"
      return
    end
    
    rows_by_row_md5.each do |row_md5, row|
      @row_locations_by_row_md5[row_md5] = Marshal.dump(locations_by_row_md5[row_md5])
      @row_data_by_row_md5[row_md5] = Marshal.dump(row) unless @row_data_by_row_md5.has_key?(row_md5)
    end
    @csv_info_by_csv_md5[csv_md5] = Marshal.dump(info)
    flush
    puts " - #{name}"
  end
  
  def delete_inconsistent
    csv_md5s_by_row_md5s = {}
    @csv_info_by_csv_md5.each do |csv_md5, info|
      Marshal.load(info)[:row_md5s].each { |row_md5| csv_md5s_by_row_md5s[row_md5] = csv_md5 }
    end
    
    row_md5_sets = [csv_md5s_by_row_md5s, @row_data_by_row_md5, @row_locations_by_row_md5].map(&:keys)
    bad_row_md5s = row_md5_sets.inject(:|) - row_md5_sets.inject(:&)
    return if bad_row_md5s.empty?
    
    bad_row_md5s.each do |row_md5|
      csv_md5 = csv_md5s_by_row_md5s[row_md5]
      @csv_info_by_csv_md5.delete(csv_md5) unless csv_md5.nil?
      @row_data_by_row_md5.delete(row_md5)
      @row_locations_by_row_md5.delete(row_md5)
    end
    flush
    
    puts " ! #{bad_row_md5s.size} inconsistent rows deleted"
    delete_inconsistent
  end
  
  def delete_obsolete
    row_md5s_by_csv_md5 = Hash[@csv_info_by_csv_md5.map { |md5, info| [md5, Marshal.load(info)[:row_md5s]] }]
    good_row_md5s = row_md5s_by_csv_md5.values_at(*@added_csv_md5s).flatten.to_set
    
    csv_deleter = @csv_info_by_csv_md5.method(:delete)
    row_deleter = @row_data_by_row_md5.method(:delete)
    loc_deleter = @row_locations_by_row_md5.method(:delete)
    
    @csv_info_by_csv_md5.keys.delete_if { |md5| @added_csv_md5s.include?(md5) }.each do |md5|
      (row_md5s_by_csv_md5[md5].to_set - good_row_md5s).each(&row_deleter).each(&loc_deleter)
    end.each(&csv_deleter)
    flush
    
    stores.each(&:defrag)
  end
  
  def flush
    stores.each(&:flush)
  end
  
  def infos_for_name(matcher)
    @csv_info_by_csv_md5.map do |md5, info|
      info = Marshal.load(info)
      info[:name] =~ matcher ? info.merge(:md5 => md5) : nil
    end.compact
  end
  
  def location(row_md5, join_with = ":")
    location = @row_locations_by_row_md5[row_md5]
    return nil if location.nil?
    fields = Marshal.load(location)
    join_with.nil? ? fields : fields.join(join_with)
  end
  
  def parse_rows(csv_path, name)
    errors = []
    headers = nil
    locations_by_md5 = {}
    rows_by_md5 = {}
    row_md5s = []
    
    row_index = 0
    FasterCSV.foreach(csv_path, :headers => :first_row, :return_headers => true, :encoding => "UTF-8") do |row|
      row_index += 1
      
      row_errors = []
      row_errors += row.repeated_non_nil_values.map { |v| "duplicate header #{v.inspect} detected" } if row.header_row?
      row_errors << "blank cells detected in row #{row_index}" if row.has_nil_values?
      row_errors << "improperly capitalized N/A / NIL values detected in row #{row_index}" if row.has_values_in(IMPROPER_NIL_VALUES)
      unless row_errors.empty?
        errors += row_errors
        row.header_row? ? break : next
      end
      
      values = row.map { |header, value| header =~ SKIP_HEADER_MATCHER ? nil : value.strip }.compact
      headers = values and next if row.header_row?
      next if row["IMPORT"] == "N"
      
      values.map! { |v| NIL_VALUES.include?(v) ? nil : v }
      md5 = Digest::MD5.hexdigest(Marshal.dump(values))
      
      if rows_by_md5.has_key?(md5)
        errors << "row #{row_index} duplicates a previous row"
      else
        locations_by_md5[md5] = [name, row_index]
        rows_by_md5[md5] = values
        row_md5s << md5
      end
    end
    
    errors << "no header row" if rows_by_md5.empty?
    info = {:headers => headers, :name => name, :row_md5s => row_md5s}
    [errors, info, locations_by_md5, rows_by_md5]
  end
  
  def row(row_md5)
    Marshal.load(@row_data_by_row_md5[row_md5])
  end
  
  def row_md5s
    @row_data_by_row_md5.keys
  end
  
  def stores
    [@csv_info_by_csv_md5, @row_data_by_row_md5, @row_locations_by_row_md5]
  end
  
  def summarize
    puts " > managing #{@row_data_by_row_md5.size} rows from #{@csv_info_by_csv_md5.size} CSVs"
  end
end

class RowObjectGenerator
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row column error)
  
  def initialize(csv_catalogue, object_catalogue)
    @csvs = csv_catalogue
    @objects = object_catalogue
    
    @errors = []
  end
  
  def generate_for(model)
    name = model.storage_name
    
    @csvs.infos_for_name(/^#{name}/).each do |csv_info|
      csv_row_md5s_to_parse = (csv_info[:row_md5s] & row_md5s_to_parse) # not using sets to avoid extra sort operation
      next if csv_row_md5s_to_parse.empty?
      
      parser = Kernel.const_get("#{model}Parser").new(csv_info, @objects)
      @errors += parser.header_errors.map { |col, e| [csv_info[:name], 1, col, e] }
      next unless parser.header_errors.empty?
      
      parsed_count, error_count = 0, 0
      csv_rows_by_md5 = @csvs.rows_by_md5(csv_info[:md5])
      csv_row_md5s_to_parse.each do |row_md5|
        row_objects, errors = parser.parse_row(csv_rows_by_md5[row_md5])
        if row_objects.empty? and errors.empty? then errors << [nil, "no objects parsed from this row"]
        else errors += @objects.add(row_objects, row_md5).map { |e| [nil, e] }
        end
        @errors += errors.map { |col, e| @csvs.location(row_md5, nil) + [col, e] }
        
        parsed_count += row_objects.size
        error_count += errors.size
      end
      
      puts " - parsed #{parsed_count} objects from #{csv_row_md5s_to_parse.size}/#{csv_info[:row_md5s].size} rows of #{csv_info[:name]}" if parsed_count > 0
      puts " ! #{error_count} errors reported from #{csv_info[:name]}" if error_count > 0
      @objects.commit(csv_info[:name].tr("/", "_")) unless error_count > 0
    end
  end
  
  def row_md5s_to_parse
    @row_md5s_to_parse ||= (@csvs.row_md5s - @objects.row_md5s_by_ref.values.flatten.uniq)
  end
end

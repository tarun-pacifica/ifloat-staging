class AbstractParser
  HEADERS = []
  KCODE = "UTF-8"
  REQUIRED_VALUE_HEADERS = []
  
  def initialize(import_set)
    @import_set = import_set
  end
  
  def parse(csv_path)
    klass = Kernel.const_get(self.class.to_s.sub(/Parser$/, ""))
    nice_path = File.basename(csv_path)
    nice_path = File.basename(File.dirname(csv_path)) / nice_path unless nice_path == "#{klass.storage_name}.csv"
    
    errors = preflight_check
    unless errors.empty?
      errors.each { |message| @import_set.error(klass, nice_path, nil, nil, message) }
      return
    end
    
    old_kcode = nil
    unless RUBY_VERSION =~ /^1\.9\./
      old_kcode = $KCODE
      $KCODE = self.class.const_get("KCODE")
    end
    
    @headers = {}
    row_number = 0
    
    FasterCSV.foreach(csv_path, :headers => :first_row, :return_headers => true, :encoding => "UTF-8") do |row|
      row_number += 1
      
      if row.header_row?
        errors = parse_headers(row)
        errors += validate_headers(@headers).map { |message| [nil, message] }
        errors.each { |column, message| @import_set.error(klass, nice_path, row_number, column, message) }
        break unless errors.empty?
        
      else
        fields, deferred, errors = parse_row(row)
        
        while errors.empty?
          deferred_count = deferred.size
          break if deferred_count == 0
          
          fields, deferred, def_errors = parse_deferred(deferred, fields)
          errors += def_errors
          
          if deferred.size == deferred_count
            errors += deferred.map { |head, value| [@headers.index(head), "deferral loop: #{value.inspect}"] }
            break
          end
        end
        
        errors.each { |column, message| @import_set.error(klass, nice_path, row_number, column, message) }
        next unless errors.empty?
        
        generate_objects(fields).each do |object|
          object.set_source(nice_path, row_number)
          @import_set.add(object)
        end 
      end
    end
    
    $KCODE = old_kcode unless RUBY_VERSION =~ /^1\.9\./
  end
  
  
  private
  
  def parse_deferred(deferred, fields)
    parse_fields(deferred, fields)
  end
  
  def parse_field(head, value, fields)
    value
  end
  
  def parse_fields(set, fields)
    first_pass = fields.nil?
    
    deferred = []
    errors = []
    fields ||= {}
    
    set.each do |header, value|
      head = (first_pass ? @headers[header] : header)
      
      begin
        raise "blank field detected" if first_pass and value.blank? and reject_blank_value?(head)
        
        value.strip! unless value.nil?
        
        parsed_field = parse_field(head, value, fields)
        if parsed_field == :deferred then deferred << [head, value]
        else fields[head] = parsed_field
        end
      rescue Exception => e
        errors << [header, e.message]
      end
    end
    
    [fields, deferred, errors]
  end
  
  def parse_header(value)
    value
  end
  
  def parse_headers(row)
    errors = []
    
    row.each do |header, value|
      begin
        raise "blank header detected" if header.blank?
        raise "duplicate header #{header.inspect} detected" if @headers.has_key?(header)
        @headers[header] = parse_header(value)
      rescue Exception => e
        errors << [header, e.message]
      end
    end
    
    errors
  end
  
  def parse_row(row)
    parse_fields(row, nil)
  end
  
  def preflight_check
    []
  end
  
  def reject_blank_value?(head)
    self.class.const_get("REQUIRED_VALUE_HEADERS").include?(head)
  end
  
  def validate_headers(headers)
    self.class.const_get("HEADERS").map do |header|
      headers.has_key?(header) ? nil : "header missing: #{header}"
    end.compact
  end
end

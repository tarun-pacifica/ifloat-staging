class AbstractParser
  ESSENTIAL_HEADERS = []
  KCODE = "NONE"
  
  def initialize(import_set)
    @import_set = import_set
  end
  
  def parse(csv_path)
    old_kcode = $KCODE
    $KCODE = self.class.const_get("KCODE")
    
    klass = Kernel.const_get(self.class.to_s.sub(/Parser$/, ""))
    nice_path = File.basename(csv_path)
    nice_path = File.basename(File.dirname(csv_path)) / nice_path unless nice_path == "#{klass.storage_name}.csv"
    
    @headers = {}
    row_number = 0
    
    FasterCSV.foreach(csv_path, :headers => :first_row, :return_headers => true) do |row|
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
          break if deferred_count.zero?
          
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
    
    $KCODE = old_kcode
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
  
  def reject_blank_value?(head)
    true
  end
  
  def validate_headers(headers)
    self.class.const_get("ESSENTIAL_HEADERS").map do |header|
      headers.has_key?(header) ? nil : "essential header missing: #{header}"
    end.compact
  end
end

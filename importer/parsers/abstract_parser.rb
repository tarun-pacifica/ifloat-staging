class AbstractParser
  REQUIRED_HEADERS = []
  REQUIRED_VALUE_GROUPS = []
  REQUIRED_VALUE_HEADERS = []
  
  attr_reader :header_errors
  
  def initialize(csv_info, object_catalogue)
    @info = csv_info
    @objects = object_catalogue
    
    @original_headers = csv_info[:headers]
    @header_errors = validate_headers(@original_headers).map { |e| [nil, e] }
    return unless @header_errors.empty?
    @headers, @header_errors = parse_headers(@original_headers)
  end
  
  def parse_row(row)
    errors = []
    values_by_header = Hash[@headers.zip(row)]
    
    rvg, rvh = %w(REQUIRED_VALUE_GROUPS REQUIRED_VALUE_HEADERS).map { |c| self.class.const_get(c) }
    unless rvg.empty? and rvh.empty?
      values_by_original_header = Hash[@original_headers.zip(row)]
      
      rvg.each do |headers|
        errors << [nil, "value required for any of #{headers.join(', ')}"] if values_by_original_header.values_at(*headers).compact.empty?
      end
      
      rvh.each { |header| errors << [nil, "value required for #{header}"] if values_by_original_header[header].nil? }
    end
    
    parsed_by_header = {}
    partition_fields(values_by_header).each do |headed_values|
      headed_values.each do |header, value|
        begin
          parsed_by_header[header] = parse_field(header, value, parsed_by_header)
        rescue Exception => e
          errors << [@info[:headers][@headers.index(header)], e.message + " " + e.backtrace.inspect]
        end
      end
    end if errors.empty?
    
    objects = generate_objects(parsed_by_header)
    errors += validate_objects(objects).map { |error| [nil, error] } if respond_to?(:validate_objects)
    
    [errors.empty? ? objects : [], errors]
  end
  
  
  private
  
  def lookup(klass, *pk_values)
    ObjectRef.for(klass, pk_values)
  end
  
  def lookup!(klass, *pk_values)
    ref = ObjectRef.for(klass, pk_values)
    raise "invalid/unknown #{klass}[#{lookup_error_values(klass, pk_values)}]" unless @objects.has_ref?(ref)
    ref
  end
  
  def lookup_error_values(klass, pk_values)
    pk_values.map { |pkv| pkv.is_a?(ObjectRef) ? pkv.inspect_friendly : pkv }.join(" / ")
  end
  
  def parse_field(header, value, fields)
    value
  end
  
  def parse_headers(headers)
    return [headers, []] unless respond_to?(:parse_header)
    
    errors = []
    headers = headers.map do |header|
      begin
        parse_header(header)
      rescue Exception => e
        errors << [header, e.message]
        header
      end
    end
    [headers, errors]
  end
  
  def partition_fields(values_by_header)
    [values_by_header]
  end
  
  def validate_headers(headers)
    errors = (self.class.const_get("REQUIRED_HEADERS") - headers).map { |header| "header missing: #{header}" }
  end
end

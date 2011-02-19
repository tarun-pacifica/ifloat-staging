class AbstractParser
  REQUIRED_HEADERS = []
  REQUIRED_VALUE_GROUPS = []
  REQUIRED_VALUE_HEADERS = []
  
  attr_reader :header_errors
  
  def initialize(csv_info, object_catalogue)
    @info = csv_info
    @objects = object_catalogue
    
    headers = csv_info[:headers]
    @header_errors = validate_headers(headers).map { |e| [nil, e] }
    return unless @header_errors.empty?
    @headers, @header_errors = parse_headers(headers)
  end
  
  def parse_row(row)
    errors = []
    parsed_by_header = Hash[@headers.zip(row)]
    
    self.class.const_get("REQUIRED_VALUE_GROUPS").each do |headers|
      errors << "value required for any of #{headers.join(', ')}" if parsed_by_header.values_at(*headers).compact.empty?
    end
    
    self.class.const_get("REQUIRED_VALUE_HEADERS").each do |header|
      errors << "value required for #{header}" if parsed_by_header[header].nil?
    end
    
    partition_fields(parsed_by_header).each do |headed_values|
      headed_values.each do |header, value|
        begin
          parsed_by_header[header] = parse_field(header, value, parsed_by_header)
        rescue Exception => e
          errors << [@info[:headers][@headers.index(header)], e.message]
        end
      end
    end if errors.empty? and respond_to?(:parse_field)
    
    errors.empty? ? [generate_objects(parsed_by_header), []] : [[], errors]
  end
  
  
  private
  
  def lookup(klass, *pk_values)
    ObjectReference.loose(klass, pk_values)
  end
  
  def lookup!(klass, *pk_values)
    loose_ref = lookup(klass, *pk_values)
    raise "invalid/unknown #{klass}: #{pk_values.inspect}" unless @objects.has_object?(klass, loose_ref.pk_md5)
    loose_ref
  end
  
  # TODO: use anywhere we previously used :defer
  # - i.e. product needs to divide into 3 - company, concrete, concrete tolerance, AUTO, AUTO tolerance
  # CAN WE TAKE OUT TOLERANCE VALUE SUPPORT?
  def partition_fields(values_by_header)
    [values_by_header]
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
  
  def validate_headers(headers)
    errors = (self.class.const_get("REQUIRED_HEADERS") - headers).map { |header| "header missing: #{header}" }
  end
end

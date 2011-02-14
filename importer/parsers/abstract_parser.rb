class AbstractParser
  REQUIRED_HEADERS = []
  
  attr_reader :header_errors
  
  def initialize(csv_info, object_catalogue)
    @info = csv_info
    @objects = object_catalogue
    
    @headers, @header_errors = parse_headers(csv_info[:header])
    @header_errors += validate_headers.map { |e| [nil, e] }
  end
  
  def parse_row(row)
    errors = []
    parsed_by_header = {}
    
    partition_fields(Hash[@headers.zip(row)]).each do |headed_values|
      headed_values.each do |header, value|
        begin
          parsed_by_header[header] = parse_field(header, value, parsed_values_by_header)
        rescue Exception => e
          errors << [csv_info[:header][@headers.index(head)], e.message]
        end
      end
    end
    
    errors.empty? ? generate_objects(parsed_by_header) : [[], errors]
  end
  
  
  private
  
  # TODO: use anywhere we previously used :defer
  # - i.e. product needs to divide into 3 - company, concrete, concrete tolerance, AUTO, AUTO tolerance
  # CAN WE TAKE OUT TOLERANCE VALUE SUPPORT?
  def partition_fields(values_by_header)
    [values_by_header]
  end
  
  def parse_headers(row)
    return [row, []] unless respond_to?(:parse_header)
    
    errors = []
    headers = row.map do |header, value|
      begin
        parse_header(value)
      rescue Exception => e
        errors << [header, e.message]
        value
      end
    end
    errors
  end
  
  def validate_headers
    (self.class.const_get("REQUIRED_HEADERS") - @headers).map { |header| "header missing: #{header}" }
  end
end

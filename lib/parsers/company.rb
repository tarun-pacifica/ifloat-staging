class CompanyParser < AbstractParser
  HEADERS = %w(reference name primary_url description)
  REQUIRED_VALUE_HEADERS = %w(reference name).to_set
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = {}
    HEADERS.each { |head| attributes[head.to_sym] = parsed_fields[head] }
    [ImportObject.new(Company, attributes)]
  end
  
  def parse_field(head, value, fields)
    value = nil if (value == "N/A" or value == "NIL")
    return value unless head == "reference"
    raise "invalid format: #{value.inspect}" unless value =~ Company::REFERENCE_FORMAT
    raise "longer than 50 characters: #{value.inspect}" unless value.size <= 50
    value
  end
end

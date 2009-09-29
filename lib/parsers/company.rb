class CompanyParser < AbstractParser
  ESSENTIAL_HEADERS = ["reference", "name", "primary_url", "description"]
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = {}
    ESSENTIAL_HEADERS.each { |head| attributes[head.to_sym] = parsed_fields[head] }
    [ImportObject.new(Company, attributes)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "reference"
    raise "invalid format: #{value.inspect}" unless value =~ Company::REFERENCE_FORMAT
    raise "longer than 50 characters: #{value.inspect}" unless value.size <= 50
    value
  end
  
  def reject_blank_value?(head)
    ESSENTIAL_HEADERS[0..1].include?(head)
  end
end

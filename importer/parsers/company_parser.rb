class CompanyParser < AbstractParser
  REQUIRED_HEADERS = %w(reference name primary_url description)
  REQUIRED_VALUE_HEADERS = %w(reference name)
  
  def generate_objects(parsed_fields)
    attributes = REQUIRED_HEADERS.map { |head| [head.to_sym, parsed_fields[head]] }
    [Hash[attributes].update(:class => Company)]
  end
  
  def parse_field(head, value, fields)
    return value unless head == "reference"
    raise "invalid format: #{value.inspect}" unless value =~ Company::REFERENCE_FORMAT
    raise "longer than 50 characters: #{value.inspect}" unless value.size <= 50
    value
  end
end

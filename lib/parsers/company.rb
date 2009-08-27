class CompanyParser < AbstractParser
  ESSENTIAL_HEADERS = ["reference", "name", "primary_url", "description"]
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = {}
    ESSENTIAL_HEADERS.each { |head| attributes[head.to_sym] = parsed_fields[head] }
    [ImportObject.new(Company, attributes)]
  end
  
  def reject_blank_value?(head)
    ESSENTIAL_HEADERS[0..1].include?(head)
  end
end

class FacilityParser < AbstractParser
  REQUIRED_HEADERS = %w(company.reference name primary_url description purchase_ttl)
  REQUIRED_VALUE_HEADERS = %w(company.reference)
  
  def generate_objects(parsed_fields)
    attributes = [:company, :name, :primary_url, :description, :purchase_ttl].zip(parsed_fields.values_at(*REQUIRED_HEADERS))
    [Hash[attributes].update(:class => Facility)]
  end
  
  def parse_field(head, value, fields)
    head == "company.reference" ? lookup!(Company, value) : value
  end
end

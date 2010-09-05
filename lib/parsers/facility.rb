class FacilityParser < AbstractParser
  HEADERS = %w(company.reference name primary_url description)
  REQUIRED_VALUE_HEADERS = %w(company.reference).to_set
  
  
  private
  
  def generate_objects(parsed_fields)
    company, name, url, description = parsed_fields.values_at(*HEADERS)
    [ImportObject.new(Facility, :company => company, :name => name, :primary_url => url, :description => description)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "company.reference"
    @import_set.get!(Company, value)
  end
end

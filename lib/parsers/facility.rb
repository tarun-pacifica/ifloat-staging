class FacilityParser < AbstractParser
  ESSENTIAL_HEADERS = ["company.reference", "name", "primary_url"]
  
  
  private
  
  def generate_objects(parsed_fields)
    company, name, url = parsed_fields.values_at(*ESSENTIAL_HEADERS)
    [ImportObject.new(Facility, :company => company, :name => name, :primary_url => url)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "company.reference"
    @import_set.get!(Company, value)
  end
  
  def reject_blank_value?(head)
    ESSENTIAL_HEADERS[0..1].include?(head)
  end
end

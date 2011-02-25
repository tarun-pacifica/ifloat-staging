class BrandParser < AbstractParser
  HEADERS = %w(company.reference marketing:brand logo description)
  REQUIRED_VALUE_HEADERS = %w(company.reference marketing:brand logo)
    
  def generate_objects(parsed_fields)
    attributes = [:company, :name, :logo, :description].zip(parsed_fields.values_at(*HEADERS))
    [Hash[attributes].update(:class => Brand)]
  end
  
  def parse_field(head, value, fields)
    case head
    when "company.reference" then lookup!(Company, value)
    when "logo" then lookup!(Asset, "brand_logos", fields["company.reference"], value)
    else value
    end
  end
  
  def partition_fields(values_by_header)
    values_by_header.group_by { |header, value| header == "company.reference" ? 0 : 1 }.sort.map { |i, fields| fields }
  end
end

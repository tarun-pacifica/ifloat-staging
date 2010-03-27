class BrandParser < AbstractParser
  HEADERS = %w(company.reference marketing:brand logo)
  REQUIRED_VALUE_HEADERS = HEADERS.to_set
  
  
  private
  
  def generate_objects(parsed_fields)
    company, name, logo = parsed_fields.values_at(*HEADERS)
    [ImportObject.new(Brand, :asset => logo, :company => company, :name => name)]
  end
  
  def parse_field(head, value, fields)
    case head
    when "company.reference" then @import_set.get!(Company, value)
    when "logo" then @import_set.get!(Asset, "brand_logos", fields["company.reference"], value)
    else super
    end
  end
end

class BrandParser < AbstractParser
  HEADERS = %w(company.reference marketing:brand logo description)
  REQUIRED_VALUE_HEADERS = HEADERS[0..-2].to_set
  
  
  private
  
  def generate_objects(parsed_fields)
    company, name, logo, description = parsed_fields.values_at(*HEADERS)
    [ImportObject.new(Brand, :asset => logo, :company => company, :name => name, :description => description)]
  end
  
  def parse_field(head, value, fields)
    return nil if value == "NIL"
    
    case head
    when "company.reference" then @import_set.get!(Company, value)
    when "logo" then @import_set.get!(Asset, "brand_logos", fields["company.reference"], value)
    else super
    end
  end
end

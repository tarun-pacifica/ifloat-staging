class PropertyValueDefinitionParser < AbstractParser
  HEADERS = %w(type value definition)
  REQUIRED_VALUE_HEADERS = HEADERS.to_set
  
  
  private
  
  def generate_objects(parsed_fields)
    type, value, definition = parsed_fields.values_at(*HEADERS)
    [ImportObject.new(PropertyValueDefinition, :property_type => type, :language_code => "ENG", :value => value, :definition => definition)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "type"
    @import_set.get!(PropertyType, value)
  end
end

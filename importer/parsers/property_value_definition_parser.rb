class PropertyValueDefinitionParser < AbstractParser
  REQUIRED_HEADERS = REQUIRED_VALUE_HEADERS = %w(type value definition)
  
  def generate_objects(parsed_fields)
    type, value, definition = parsed_fields.values_at(*REQUIRED_HEADERS)
    [{:class => PropertyValueDefinition, :property_type => type, :language_code => "ENG", :value => value, :definition => definition}]
  end
  
  def parse_field(head, value, fields)
    head == "type" ? lookup!(PropertyType, value) : value
  end
end

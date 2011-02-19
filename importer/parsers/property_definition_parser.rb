class PropertyDefinitionParser < AbstractParser
  REQUIRED_HEADERS = ["sort", "first-level", "second-level", "property type", "findable", "filterable", "displayed as data", "ui first level name", "ui second level name wording"]
  REQUIRED_VALUE_HEADERS = REQUIRED_HEADERS[0..-3]
  
  def generate_objects(parsed_fields)
    name = parsed_fields.values_at("first-level", "second-level").join(":")
    find, filter, display = parsed_fields.values_at("findable", "filterable", "displayed as data").map { |v| v == "Y" }
    
    pd_attributes = {
      :class           => PropertyDefinition,
      :property_type   => parsed_fields["property type"],
      :name            => name,
      :findable        => find,
      :filterable      => filter,
      :display_as_data => display,
      :sequence_number => parsed_fields["sort"]
    }
    objects = [pd_attributes]
    
    translations = parsed_fields.values_at("ui first level name", "ui second level name wording")
    return objects if translations.any? { |t| t.nil? }
    
    definition, value = lookup(PropertyDefinition, name), translations.join(":")
    objects << {:class => Translation, :property_definition => definition, :language_code => "ENG", :value => value}
    
    objects
  end
  
  def parse_field(head, value, fields)
    head == "property type" ? lookup!(PropertyType, value) : value
  end
end

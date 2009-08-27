class PropertyValueDefinitionParser < AbstractParser
  ESSENTIAL_HEADERS = ["type", "value", "definition"]
  
  
  private
  
  def generate_objects(parsed_fields)
    type, value, definition = parsed_fields.values_at("type", "value", "definition")
    [ImportObject.new(PropertyValueDefinition, :property_type => type, :language_code => "ENG", :value => value, :definition => definition[0, 255])]
    # TODO: remove auto-truncation when data better
  end
  
  def parse_field(head, value, fields)
    return super unless head == "type"
    @import_set.get!(PropertyType, value)
  end
end

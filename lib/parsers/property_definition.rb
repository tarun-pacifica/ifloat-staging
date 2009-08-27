class PropertyDefinitionParser < AbstractParser
  ESSENTIAL_HEADERS = ["sort", "first-level", "second-level", "property type", "findable", "filterable", "displayed as data", "ui first level name", "ui second level name wording"]
    
  
  private
  
  def generate_objects(parsed_fields)
    name = parsed_fields.values_at("first-level", "second-level").join(":")
    find, filter, display = parsed_fields.values_at("findable", "filterable", "displayed as data").map { |v| v == "Y" }
    
    attributes = {
      :property_type => parsed_fields["property type"],
      :name => name,
      :findable => find,
      :filterable => filter,
      :display_as_data => display,
      :sequence_number => parsed_fields["sort"]
    }
    objects = [ImportObject.new(PropertyDefinition, attributes)]
    
    translations = parsed_fields.values_at("ui first level name", "ui second level name wording")
    unless translations.include?("N/A")
      value = translations.join(":")
      objects << ImportObject.new(Translation, :property_definition => objects[0], :language_code => "ENG", :value => value)
    end
    
    objects
  end
  
  def parse_field(head, value, fields)
    return super unless head == "property type"
    @import_set.get!(PropertyType, value)
  end
  
  def reject_blank_value?(head)
    ESSENTIAL_HEADERS.include?(head)
  end
end

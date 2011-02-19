class UnitOfMeasureParser < AbstractParser
  REQUIRED_HEADERS = REQUIRED_VALUE_HEADERS = %w(reference:class unit value_property)
  
  def generate_objects(parsed_fields)
    attributes = [:class_name, :unit, :property_definition].zip(parsed_fields.values_at(*REQUIRED_HEADERS))
    [Hash[attributes].update(:class => UnitOfMeasure)]
  end
  
  def parse_field(head, value, fields)
    head == "value_property" ? lookup!(PropertyDefinition, value) : value
  end
end

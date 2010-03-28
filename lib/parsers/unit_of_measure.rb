class UnitOfMeasureParser < AbstractParser
  HEADERS = %w(reference:class unit value_property)
  REQUIRED_VALUE_HEADERS = HEADERS.to_set
  
  
  private
  
  def generate_objects(parsed_fields)
    class_name, unit, property = parsed_fields.values_at(*HEADERS)
    [ImportObject.new(UnitOfMeasure, :property_definition => property, :class_name => class_name, :unit => unit)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "value_property"
    @import_set.get!(PropertyDefinition, value)
  end
end

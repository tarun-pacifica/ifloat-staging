class PropertyTypeParser < AbstractParser
  ESSENTIAL_HEADERS = ["property type", "raw type", "unit-1", "unit-2", "unit-3", "unit-4"]
  
  
  private
  
  def generate_objects(parsed_fields)
    name, core_type = parsed_fields.values_at("property type", "raw type")
    units = parsed_fields.values_at("unit-1", "unit-2", "unit-3", "unit-4").compact
    [ImportObject.new(PropertyType, :name => name, :core_type => core_type, :units => units)]
  end
  
  def reject_blank_value?(head)
    ESSENTIAL_HEADERS[0..1].include?(head)
  end
end

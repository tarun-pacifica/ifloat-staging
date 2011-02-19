class PropertyTypeParser < AbstractParser
  REQUIRED_HEADERS = ["property type", "raw type", "unit-1", "unit-2", "unit-3", "unit-4", "unit-5"]
  REQUIRED_VALUE_HEADERS = ["property type", "raw type"]
  
  def generate_objects(parsed_fields)
    name, core_type = parsed_fields.values_at("property type", "raw type")
    units = parsed_fields.values_at("unit-1", "unit-2", "unit-3", "unit-4", "unit-5").compact
    [{:class => PropertyType, :name => name, :core_type => core_type, :units => units}]
  end
end

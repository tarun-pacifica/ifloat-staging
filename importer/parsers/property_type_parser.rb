class PropertyTypeParser < AbstractParser
  UNIT_HEADERS = 10.times.map { |i| "unit-#{i + 1}" }
  REQUIRED_HEADERS = ["property type", "raw type"] + UNIT_HEADERS
  REQUIRED_VALUE_HEADERS = ["property type", "raw type"]
  
  def generate_objects(parsed_fields)
    name, core_type = parsed_fields.values_at("property type", "raw type")
    units = parsed_fields.values_at(*UNIT_HEADERS).compact
    [{:class => PropertyType, :name => name, :core_type => core_type, :units => units}]
  end
end

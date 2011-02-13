class PropertyTypeParser < AbstractParser
  HEADERS = ["property type", "raw type", "unit-1", "unit-2", "unit-3", "unit-4", "unit-5"]
  REQUIRED_VALUE_HEADERS = ["property type", "raw type"].to_set
  
  
  private
  
  def generate_objects(parsed_fields)
    name, core_type = parsed_fields.values_at("property type", "raw type")
    units = parsed_fields.values_at("unit-1", "unit-2", "unit-3", "unit-4", "unit-5")
    units = units.map { |u| u == "N/A" ? nil : u }.compact
    [ImportObject.new(PropertyType, :name => name, :core_type => core_type, :units => units)]
  end
end

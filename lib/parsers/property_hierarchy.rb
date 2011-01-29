class PropertyHierarchyParser < AbstractParser
  HEADERS = %w(reference:class property_set_1)
  REQUIRED_VALUE_HEADERS = %w(reference:class property_set_1)
  
  
  private
  
  def generate_objects(parsed_fields)
    class_name = parsed_fields.delete("reference:class")
    
    parsed_fields.map do |head, value|
      next unless head =~ /^property_set_(\d+)$/
      ImportObject.new(PropertyHierarchy, :class_name => class_name, :sequence_number => $1, :property_names => value)
    end.compact
  end
  
  def parse_field(head, value, fields)
    return value unless head =~ /^property_set_\d+$/
    
    value.to_s.split(",").map do |part|
      part.strip!
      @import_set.get!(PropertyDefinition, part)
      part
    end
  end
end

class PropertyHierarchyParser < AbstractParser
  REQUIRED_HEADERS = REQUIRED_VALUE_HEADERS = %w(reference:class)
  REQUIRED_VALUE_GROUPS = [%w(property_set_1 property_set_2 property_set_3 property_set_4 property_set_5)]
  
  PSET_HEADER_MATCH = /^property_set_(\d+)$/
  
  def generate_objects(parsed_fields)
    class_name = parsed_fields.delete("reference:class")
    
    property_sets = parsed_fields.select { |head, value| head =~ PSET_HEADER_MATCH and not value.blank? }
    property_sets = property_sets.sort_by { |head, value| head =~ PSET_HEADER_MATCH; $1.to_i }
    property_sets.each_with_index.map do |head_value, i|
      {:class => PropertyHierarchy, :class_name => class_name, :sequence_number => i + 1, :property_names => head_value.last}
    end
  end
  
  def parse_field(head, value, fields)
    return value unless head =~ PSET_HEADER_MATCH
    value.to_s.split(",").map { |part| lookup!(PropertyDefinition, part.strip); part }
  end
end

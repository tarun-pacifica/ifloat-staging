class PropertyHierarchyParser < AbstractParser
  HEADERS = %w(reference:class property_set_1)
  REQUIRED_VALUE_HEADERS = %w(reference:class property_set_1)
  
  
  private
  
  def generate_objects(parsed_fields)
    class_name = parsed_fields.delete("reference:class")
    
    parsed_fields.map do |head, value|
      next if value.blank?
      next unless head =~ /^property_set_(\d+)$/
      ImportObject.new(PropertyHierarchy, :class_name => class_name, :sequence_number => $1.to_i, :property_names => value)
    end.compact
  end
  
  def parse_field(head, value, fields)
    return nil if (value.blank? or value == "N/A")
    return value unless head =~ /^property_set_(\d+)$/
    
    previous_ps = ($1.to_i - 1)
    if previous_ps > 0
      previous_ps_head = "property_set_#{previous_ps}"
      raise "value follows a blank in the previous field" if fields[previous_ps_head].blank?
    end
    
    value.to_s.split(",").map do |part|
      part.strip!
      @import_set.get!(PropertyDefinition, part)
      part
    end
  end
end
